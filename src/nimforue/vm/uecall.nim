include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar, enumerate, tables, strutils, strformat, typetraits]
import runtimefield

proc makeUEFunc*(name, className : string) : UEFunc = 
  result.name = name
  result.className = className

proc makeUECall*(fn : UEFunc, self : int, value : RuntimeField) : UECall = 
  result.fn = fn
  result.self = self
  result.value = value

proc makeUECall*(fn : UEFunc, self : UObjectPtr, value : RuntimeField) : UECall = 
  result.fn = fn
  result.self = cast[int](self)
  result.value = value

# proc getValueFromPropMemoryBlock*(prop:FPropertyPtr, returnMemoryRegion : ByteAddress) : JsonNode 

proc setProp(rtField : RuntimeField, prop : FPropertyPtr, memoryBlock:pointer) =
  case rtField.kind
  of Int:
    setPropertyValue(prop, memoryBlock, rtField.getInt)
  of Float:
    if prop.isFloat32():
      setPropertyValue(prop, memoryBlock, rtField.getFloat.float32)
    else:
      setPropertyValue(prop, memoryBlock, rtField.getFloat)
  of String:
    setPropertyValue(prop, memoryBlock, makeFString rtField.getStr)
  of Struct:
    let structProp = castField[FStructProperty](prop)
    let scriptStruct = structProp.getScriptStruct()
    let structProps = scriptStruct.getFPropsFromUStruct() #Lets just do this here before making it recursive
    var structMemoryRegion = memoryBlock
    for paramProp in structProps:
      let name = paramProp.getName().firstToLow()
      if name in rtField:
        let val = rtField[name]
        val.setProp(paramProp, structMemoryRegion)
      else:
        UE_Error &"Field {name} not found in struct"

  else:
    discard
  # of Object:
  #   setPropertyValue(prop, memoryBlock, rtField.intVal)

proc getProp(prop:FPropertyPtr, memoryBlock:pointer) : RuntimeField = 
  if prop.isInt() or prop.isObjectBased():
    result.kind = Int
    copyMem(addr result.intVal, memoryBlock, prop.getSize())  
  elif prop.isFString():
    result.kind = String
    var returnValue = f""
    copyMem(addr returnValue, memoryBlock, prop.getSize())
    result.stringVal = returnValue
  elif prop.isFloat():
    result.kind = Float
    copyMem(addr result.floatVal, memoryBlock, prop.getSize())
  elif prop.isStruct():
    let structProp = castField[FStructProperty](prop)
    let scriptStruct = structProp.getScriptStruct()
    let structProps = scriptStruct.getFPropsFromUStruct()
    let structMemoryRegion = cast[ByteAddress](memoryBlock)
    result = RuntimeField(kind:Struct)
    for paramProp in structProps:
      let name = paramProp.getName().firstToLow() #So when we parse the type in the vm it matches
      let value = getProp(paramProp,  cast[pointer](structMemoryRegion + paramProp.getOffset()))
      result.structVal.add((name, value))
   
func isStatic*(fn : UFunctionPtr) : bool = FUNC_Static in fn.functionFlags

proc uCall*(call : UECall) : Option[RuntimeField] = 
  result = none(RuntimeField)
  let cls = getClassByName(call.fn.className.removeFirstLetter())
  if cls.isNil():
    UE_Error "uCall: Class " & $call.fn.className & " not found"
    return none(RuntimeField)
  let fn = cls.findFunctionByName(n call.fn.name.capitalizeAscii())
  if fn.isNil():
    UE_Error "uCall: Function " & $call.fn.name & " not found in class " & $call.fn.className
    return result

  let self = 
    if fn.isStatic():
      getDefaultObjectFromClassName(call.fn.className.removeFirstLetter())
    else:
      cast[UObjectPtr](call.self)

  let propParams = fn.getFPropsFromUStruct().filterIt(it != fn.getReturnProperty())

  
  if propParams.any() or fn.doesReturn():
    var memoryBlock = alloc0(fn.parmsSize)
    let memoryBlockAddr = cast[ByteAddress](memoryBlock)    

    var allocatedStrings = makeTArray[pointer]()
    #TODO check return param and out params
    for paramProp in propParams:
      try:
        UE_Log "Param prop name: " & $paramProp.getName() & " type: " & paramProp.getCppType()
        let propName = paramProp.getName().firstToLow() #So when we parse the type in the vm it matches (should we tried both?)
        if propName notin call.value:
          UE_Warn "Param " & $propName & " not in call value"
          continue
        let rtField = call.value[propName]
        rtField.setProp(paramProp, memoryBlock)
      except:
       UE_Error "Error setting the value in  " & $paramProp.getName()  & " for " & $fn.getName()
       UE_Error getCurrentExceptionMsg()
       UE_Error getStackTrace()    

 
    self.processEvent(fn, memoryBlock)

    if fn.doesReturn():
      # let returnProp = fn.getFPropsFromUStruct().filterIt(it.getName() == call.fn.getReturnProp.get.name).head().get()
      let returnProp = fn.getReturnProperty()
      let returnOffset = fn.returnValueOffset
      var returnMemoryRegion = memoryBlockAddr + returnOffset.int
      result = some(getProp(returnProp, cast[pointer](returnMemoryRegion)))

    dealloc(memoryBlock)
    for str in allocatedStrings:
      dealloc(str) 
  else: #no params no return
    self.processEvent(fn, nil)
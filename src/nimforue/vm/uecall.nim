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
  result.kind = uecFunc

proc makeUECall*(fn : UEFunc, self : UObjectPtr, value : RuntimeField) : UECall = 
  result.fn = fn
  result.self = cast[int](self)
  result.value = value
  result.kind = uecFunc

proc getProp*(prop:FPropertyPtr, sourceAddr:pointer) : RuntimeField
proc setProp*(rtField : RuntimeField, prop : FPropertyPtr, memoryBlock:pointer)
proc setStructProp*(rtField : RuntimeField, prop : FPropertyPtr, memoryBlock:pointer): pointer =
  assert rtField.kind == Struct, "Only structs can be set as structs got " & $rtField.kind
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
  structMemoryRegion

proc setProp*(rtField : RuntimeField, prop : FPropertyPtr, memoryBlock:pointer) =
  case rtField.kind
  of Int:    
    setPropertyValue(prop, memoryBlock, rtField.getInt)
  of Bool:
    setPropertyValue(prop, memoryBlock, rtField.getBool)
  of Float:
    if prop.isFloat32():
      setPropertyValue(prop, memoryBlock, rtField.getFloat.float32)
    else:
      setPropertyValue(prop, memoryBlock, rtField.getFloat)
  of String:
    setPropertyValue(prop, memoryBlock, makeFString rtField.getStr)
  of Struct:
    discard setStructProp(rtField, prop, memoryBlock)
  of Array:
    let arrayProp = castField[FArrayProperty](prop)
    let innerProp = arrayProp.getInnerProp()
    let arrayHelper = makeScriptArrayHelperInContainer(arrayProp, memoryBlock)
    arrayHelper.emptyAndAddUninitializedValues(rtField.getArray().len.int32)
 
    for idx, elem in enumerate(rtField.getArray()):
      setProp(elem, innerProp, arrayHelper.getRawPtr(idx.int32))
  of Map:
    let mapProp = castField[FMapProperty](prop)
    let kProp = mapProp.getKeyProp()
    let vProp = mapProp.getValueProp()
    let helper = makeScriptMapHelperInContainer(mapProp, memoryBlock)

    helper.emptyValues(rtField.getMap().len.int32)# the size is actually the elements not the bytes
    for idx, (key, value) in enumerate(rtField.getMap()):
      helper.addDefaultValue_Invalid_NeedsRehash()    
      setProp(key, kProp, helper.getKeyPtr(idx.int32))
      case value.kind:
        of Int:
          vProp.copySingleValue(helper.getValuePtr(idx.int32), value.intVal.addr)
        of String:          
          var fstring = f value.stringVal
          vProp.copySingleValue(helper.getValuePtr(idx.int32), fstring.addr)
        of Bool:
          vProp.copySingleValue(helper.getValuePtr(idx.int32), value.boolVal.addr)
        of Struct:           
            let structMemoryRegion = setStructProp(value, vProp, helper.getValuePtr(idx.int32))
            vProp.copySingleValue(helper.getValuePtr(idx.int32), structMemoryRegion)

        else:
          setProp(key, vProp, helper.getValuePtr(idx.int32))
      

    helper.rehash()
  else:
    raise newException(ValueError, "Unknown property type")

proc getProp*(prop:FPropertyPtr, sourceAddr:pointer) : RuntimeField = 
  if prop.isInt() or prop.isObjectBased() or prop.isEnum():
    result.kind = Int        
    if prop.isEnum():
      result.intVal = getPropertyValuePtr[uint8](prop, sourceAddr)[].int
    else:
      copyMem(addr result.intVal, sourceAddr, prop.getSize())   
  elif prop.isBool():
    result.kind = Bool
    copyMem(addr result.boolVal, sourceAddr, prop.getSize())
  elif prop.isFString():
    result.kind = String
    var returnValue = f""
    copyMem(addr returnValue, sourceAddr, prop.getSize())
    result.stringVal = returnValue
  elif prop.isFloat():
    result.kind = Float
    copyMem(addr result.floatVal, sourceAddr, prop.getSize())
  elif prop.isStruct():
    let structProp = castField[FStructProperty](prop)
    let scriptStruct = structProp.getScriptStruct()
    let structProps = scriptStruct.getFPropsFromUStruct()
    let structMemoryRegion = cast[uint](sourceAddr)
    
    result = RuntimeField(kind:Struct)
    for paramProp in structProps:      
      let name = paramProp.getName().firstToLow() #So when we parse the type in the vm it matches
      let ad = cast[ptr float](structMemoryRegion + paramProp.getOffset().uint)
      let value = getProp(paramProp,  cast[pointer](structMemoryRegion + paramProp.getOffset().uint))
      result.structVal.add((name, value))
  elif prop.isTArray():
    let arrayProp = castField[FArrayProperty](prop)
    let innerProp = arrayProp.getInnerProp()
    let arrayHelper = makeScriptArrayHelperInContainer(arrayProp, sourceAddr)
    result = RuntimeField(kind:Array)
    for idx in 0 ..< arrayHelper.num():
      result.arrayVal.add(getProp(innerProp, arrayHelper.getRawPtr(idx.int32)))
  elif prop.isTMap():
    let mapProp = castField[FMapProperty](prop)
    let keyProp = mapProp.getKeyProp()
    let valueProp = mapProp.getValueProp()
    let mapHelper = makeScriptMapHelperInContainer(mapProp, sourceAddr)
    result = RuntimeField(kind:Map)  
    for idx in 0 ..< mapHelper.num():
      let key = getProp(keyProp, mapHelper.getKeyPtr(idx.int32))
      let value = getProp(valueProp, mapHelper.getValuePtr(idx.int32))
      result.mapVal.add((key, value))
  else:
    raise newException(ValueError, "Unknown property type")
   
func isStatic*(fn : UFunctionPtr) : bool = FUNC_Static in fn.functionFlags

proc uCallFn*(call: UECall, cls: UClassPtr): Option[RuntimeField] =
  result = none(RuntimeField)
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
    let memoryBlockAddr = cast[uint](memoryBlock)    
    #TODO check return param and out params
    for paramProp in propParams:
      try:
        # UE_Log "Param prop name: " & $paramProp.getName() & " type: " & paramProp.getCppType()
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
      let returnProp = fn.getReturnProperty()
      let returnOffset = fn.returnValueOffset
      var returnMemoryRegion = memoryBlockAddr + returnOffset.uint
      let returnRuntimeField = getProp(returnProp, cast[pointer](returnMemoryRegion))
      result = some(returnRuntimeField)

    dealloc(memoryBlock)    
  else: #no params no return
    self.processEvent(fn, nil)

proc uCallProp*(call : UECall, cls:UClassPtr) : Option[RuntimeField] = 
  assert call.kind == uecGetProp or call.kind == uecSetProp
  let argField = call.value
  let propName = argField.getStruct()[0].getName()
  let prop = cls.getFPropertyByName(propName)  
  if prop.isNil():
    UE_Error &"uCall: Property {propName} not found in class {cls.getName()}"
    return none(RuntimeField)    
  let selfAddr = cast[uint](call.self)
  if call.kind == uecGetProp:
    let offset = if argField[propName].kind in {Struct, Map}: prop.getOffset() else: 0
    some getProp(prop,  cast[pointer](selfAddr + offset.uint))        
  else:
    #Dont ask why but we need to add the offset of the array    
    let offset = if argField[propName].kind in {Struct, Array, Map}: prop.getOffset() else: 0   
    argField[propName].setProp(prop, cast[pointer](selfAddr + offset.uint))
    none(RuntimeField)

proc uCall*(call : UECall) : Option[RuntimeField] = 
  let cls = getClassByName(call.getClassName.removeFirstLetter())
  if cls.isNil():
    UE_Error "uCall: Class " & $call.getClassName() & " not found"
    return none(RuntimeField)
  case call.kind:
  of uecFunc: uCallFn(call, cls)
  else: uCallProp(call, cls)



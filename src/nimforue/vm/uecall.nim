include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar, enumerate, tables, strutils, strformat, typetraits]



type
  FieldKind* = enum
    Int, Float, String, Struct,# Seq, Object
  
  RuntimeField* = object
    case kind*: FieldKind
    of Int:
      intVal: int
    of Float:
      floatVal: float
    of String:
      stringVal: string
    of Struct:
      structVal: RuntimeStruct
    
  RuntimeStruct* = seq[(string, RuntimeField)]
 
  UEFunc* = object #Light metadata we could ue UFunc but we dont want to pull all those types into the vm
    name* : string
    className* : string

   
  UECall* = object
    fn* : UEFunc 
    self* : int
    value* : RuntimeField #On uebind [name] = value #let's just do runtimeFields only for now and then we can put an object in here, although a field may contain an object

func getInt*(rtField : RuntimeField) : int = 
  case rtField.kind:
  of Int:
    return rtField.intVal
  else:
    raise newException(ValueError, "rtField is not an int")

func getFloat*(rtField : RuntimeField) : float =
  case rtField.kind:
  of Float:
    return rtField.floatVal
  else:
    raise newException(ValueError, "rtField is not a float")

func getStr*(rtField : RuntimeField) : string =
  case rtField.kind:
  of String:
    return rtField.stringVal
  else:
    raise newException(ValueError, "rtField is not a string")

func getStruct*(rtField : RuntimeField) : RuntimeStruct =
  case rtField.kind:
  of Struct:
    return rtField.structVal
  else:
    raise newException(ValueError, "rtField is not a struct")


func `[]`*(rtField : RuntimeField, name : string) : RuntimeField = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      if key == name:
        return value
    raise newException(ValueError, "Field " & name & " not found in struct")
  else:
    raise newException(ValueError, "rtField is not a struct")

# func `[]=`*(rtField : var RuntimeField, name : string, value : RuntimeField) = 
#   case rtField.kind:
#   of Struct:
#     for (key, val) in rtField.structVal:
#       if key == name:
#         val = value
#         return
#     raise newException(ValueError, "Field " & name & " not found in struct")
#   else:
#     raise newException(ValueError, "rtField is not a struct"

func contains*(rtField : RuntimeField, name : string) : bool = 
  case rtField.kind:
  of Struct:
    for (key, value) in rtField.structVal:
      if key == name:
        return true
    return false
  else:
    raise newException(ValueError, "rtField is not a struct")

func toRuntimeField*[T](value : T) : RuntimeField = 
  const typeName = typeof(T).name
  when T is int | int8 | int16 | int32 | int64 | uint | uint8 | uint16 | uint32 | uint64:
    result.kind = Int
    result.intVal = value
  elif T is float | float32 | float64:
    result.kind = Float
    result.floatVal = value
  elif T is string:
    result.kind = String
    result.stringVal = value
  elif T is (object | tuple):
    result.kind = Struct
    for name, val in fieldPairs(value):
      result.structVal.add((name, toRuntimeField(val)))
  else:
    UE_Error &"Unsupported {typeName} type for RuntimeField "
    RuntimeField()
    # raise newException(ValueError, &"Unsupported {typename} type for RuntimeField ")


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
    setPropertyValue(prop, memoryBlock, rtField.intVal)
  of Float:
    if prop.isFloat32():
      setPropertyValue(prop, memoryBlock, rtField.floatVal.float32)
    else:
      setPropertyValue(prop, memoryBlock, rtField.floatVal)
  of String:
    setPropertyValue(prop, memoryBlock, makeFString rtField.stringVal)
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


# proc jsonToRuntimeObject*(json:JsonNode) : RuntimeObject = 
#   for key, value in json.fields:
#     var rtField : RuntimeField
#     rtField.name = key
#     case value.kind
#     of JInt:
#       rtField.kind = Int
#       rtField.intVal = value.getInt()
#     of JFloat:
#       rtField.kind = Float
#       rtField.floatVal = value.getFloat()
#     of JString:
#       rtField.kind = String
#       rtField.stringVal = value.getStr()
#     # of JObject:
#     #   rtField.kind = Object
#     #   rtField.intVal = cast[int](jsonToRuntimeObject(value))
#     # of JArray:
#     #   rtField.kind = Seq
#     #   rtField.intVal = cast[int](jsonToRuntimeObject(value))
#     # of JNull:
#     #   discard
#     # of JBool:
#     #   discard
#     else:
#       discard
#     result.add((key, rtField))

# # proc setPropWithValueInMemoryBlock*(prop : FPropertyPtr, originalMemoryRegion:ByteAddress, value : JsonNode, allocatedStrings : var TArray[pointer], propOffset:int32 = prop.getOffset()) =
#   let propSize = prop.getSize()
#   let memoryRegion = (originalMemoryRegion) + propOffset
#   let memoryBlock = cast[pointer](memoryRegion)
#   if prop.isFString(): 
#     var fstringPtr =  cast[ptr FString](alloc0(sizeof(FString)))
#     fstringPtr[] = (FString)value.getStr()
#     allocatedStrings.add fstringPtr
#     copyMem(memoryBlock, fstringPtr, propSize) 
#   elif prop.isInt() or prop.isObjectBased():
#     var val = value.getInt()
#     copyMem(memoryBlock, addr val, propSize)
#   elif prop.isFloat(): #MAYBE we can just try to match against all floats here so it works for returns too
#     var val = value.getFloat()
#     if prop.isFloat32():
#       #For some reason copying the memory doesnt work. Let's try 
#       setPropertyValue(prop, cast[pointer](originalMemoryRegion), val.float32)

#     else:
#       setPropertyValue(prop, cast[pointer](originalMemoryRegion), val)

#   elif prop.isBool():
#     var val = value.getBool()
#     copyMem(memoryBlock, addr val, propSize)

#   # elif prop.isTArray(): TODO: This is not working
#   #   let elems = value.getElems()

#   #   let arrProp = castField[FArrayProperty](prop)
#   #   let innerProp = arrProp.getInnerProp()
#   #   UE_Log "Array prop name: " & $prop.getName() & " inner prop name: " & $innerProp.getName() & innerProp.getCppType()
#   #   UE_Log "Array prop size: " & $prop.getSize() & " inner prop size: " & $innerProp.getSize()
#   #   var arrayMemoryBlock = alloc0(sizeof(arrProp.getSize()))
#   #   var arrayMemoryRegion = cast[ByteAddress](arrayMemoryBlock)
#   #   allocatedStrings.add arrayMemoryBlock
#   #   for idx, elem in enumerate(elems):
#   #     let offset = idx.int32 * innerProp.getSize()
#   #     propWithValueToMemoryBlock(innerProp, arrayMemoryRegion, elem, allocatedStrings, offset)
#   #   var test = cast[ptr TArray[int]](arrayMemoryBlock)
#   #   UE_Log "Array " & $test[]
#     # copyMem(memoryBlock, arrayMemoryBlock, arrProp.getSize())
#   elif prop.isStruct():
#     let structProp = castField[FStructProperty](prop)
#     let scriptStruct = structProp.getScriptStruct()
#     let structProps = scriptStruct.getFPropsFromUStruct() #Lets just do this here before making it recursive
#     var structMemoryRegion = memoryRegion
#     # let structMemory 
#     for paramProp in structProps:
      
#       let name = paramProp.getName()
#       var val : JsonNode
#       if name in value:
#         val = value[name]
#       else:
#         val = value[name.firstToLow()] #Nim vs UE discrepancies
#       setPropWithValueInMemoryBlock(paramProp, structMemoryRegion, val, allocatedStrings)

proc getValueFromPropMemoryBlock*(prop:FPropertyPtr, returnMemoryRegion : ByteAddress) : JsonNode = 
  try:
    result = newJNull()
    let returnSize = prop.getSize()
    let returnMemoryBlock = cast[pointer](returnMemoryRegion)
    if prop.isFString():
      var returnValue = f""
      copyMem(addr returnValue, returnMemoryBlock, returnSize)
      result = newJString(returnValue)
    if prop.isInt() or prop.isObjectBased():
      var returnValue = 0
      copyMem(addr returnValue, returnMemoryBlock, returnSize)
      result = newJInt(returnValue)
    if prop.isFloat():
      var returnValue = 0.0
      copyMem(addr returnValue, returnMemoryBlock, returnSize)
      result = newJFloat(returnValue)
    if prop.isStruct():
      let structProp = castField[FStructProperty](prop)
      let scriptStruct = structProp.getScriptStruct()
      let structProps = scriptStruct.getFPropsFromUStruct()
      let structMemoryRegion = returnMemoryRegion #same but keeping it for clarity/simmetry
      result = newJObject()
      for paramProp in structProps:
        let name = paramProp.getName().firstToLow() #So when we parse the type in the vm it matches
        let value = getValueFromPropMemoryBlock(paramProp, structMemoryRegion + paramProp.getOffset())
        result[name] = value
  except:
    UE_Error "Error getting value from prop memory block " & $prop.getName() 
    UE_Error getCurrentExceptionMsg()
    UE_Error getStackTrace()    
  
func isStatic*(fn : UFunctionPtr) : bool = FUNC_Static in fn.functionFlags

proc uCall*(call : UECall) : Option[RuntimeField] = 
  result = none(RuntimeField)
  
  let fn = getClassByName(call.fn.className.removeFirstLetter()).findFunctionByName(n call.fn.name.capitalizeAscii())
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
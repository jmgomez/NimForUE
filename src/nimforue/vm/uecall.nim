include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar, enumerate, tables]





type 
  UEFunc* = object #Light metadata we could ue UFunc but we dont want to pull all those types into the vm
    name* : string
    className* : string

   
  UECall* = object
    fn* : UEFunc 
    self* : int
    value* : JsonNode #On uebind [name] = value

proc makeUEFunc*(name, className : string) : UEFunc = 
  result.name = name
  result.className = className

proc makeUECall*(fn : UEFunc, self : int, value : JsonNode) : UECall = 
  result.fn = fn
  result.self = self
  result.value = value

proc makeUECall*(fn : UEFunc, self : UObjectPtr, value : JsonNode) : UECall = 
  result.fn = fn
  result.self = cast[int](self)
  result.value = value


proc setPropWithValueInMemoryBlock*(prop : FPropertyPtr, memoryRegion:ByteAddress, value : JsonNode, allocatedStrings : var TArray[pointer], propOffset:int32 = prop.getOffset()) =
  let propSize = prop.getSize()
  let memoryRegion = (memoryRegion) + propOffset
  let memoryBlock = cast[pointer](memoryRegion)
  if prop.isFString(): 
    var fstringPtr =  cast[ptr FString](alloc0(sizeof(FString)))
    fstringPtr[] = (FString)value.getStr()
    allocatedStrings.add fstringPtr
    copyMem(memoryBlock, fstringPtr, propSize) 
  elif prop.isInt() or prop.isObjectBased():
    var val = value.getInt()
    copyMem(memoryBlock, addr val, propSize)
  elif prop.isFloat(): #MAYBE we can just try to match against all floats here so it works for returns too
    var val = value.getFloat()
    copyMem(memoryBlock, addr val, propSize)
  # elif prop.isTArray(): TODO: This is not working
  #   let elems = value.getElems()

  #   let arrProp = castField[FArrayProperty](prop)
  #   let innerProp = arrProp.getInnerProp()
  #   UE_Log "Array prop name: " & $prop.getName() & " inner prop name: " & $innerProp.getName() & innerProp.getCppType()
  #   UE_Log "Array prop size: " & $prop.getSize() & " inner prop size: " & $innerProp.getSize()
  #   var arrayMemoryBlock = alloc0(sizeof(arrProp.getSize()))
  #   var arrayMemoryRegion = cast[ByteAddress](arrayMemoryBlock)
  #   allocatedStrings.add arrayMemoryBlock
  #   for idx, elem in enumerate(elems):
  #     let offset = idx.int32 * innerProp.getSize()
  #     propWithValueToMemoryBlock(innerProp, arrayMemoryRegion, elem, allocatedStrings, offset)
  #   var test = cast[ptr TArray[int]](arrayMemoryBlock)
  #   UE_Log "Array " & $test[]
    # copyMem(memoryBlock, arrayMemoryBlock, arrProp.getSize())
  elif prop.isStruct():
    let structProp = castField[FStructProperty](prop)
    let scriptStruct = structProp.getScriptStruct()
    let structProps = scriptStruct.getFPropsFromUStruct() #Lets just do this here before making it recursive
    var structMemoryRegion = memoryRegion
    # let structMemory 
    for paramProp in structProps:
      let name = paramProp.getName()
      var val : JsonNode
      if name in value:
        val = value[name]
      else:
        val = value[name.firstToLow()] #Nim vs UE discrepancies
      setPropWithValueInMemoryBlock(paramProp, structMemoryRegion, val, allocatedStrings)

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

proc uCall*(call : UECall) : JsonNode = 
  result = newJNull()
  let fn = getClassByName(call.fn.className.removeFirstLetter()).findFunctionByName(n call.fn.name)

  let self = 
    if fn.isStatic():
      getDefaultObjectFromClassName(call.fn.className.removeFirstLetter())
    else:
      cast[UObjectPtr](call.self)

  let propParams = fn.getFPropsFromUStruct().filterIt(it != fn.getReturnProperty())

  
  if propParams.any():
    var memoryBlock = alloc0(fn.parmsSize)
    let memoryBlockAddr = cast[ByteAddress](memoryBlock)    

    var allocatedStrings = makeTArray[pointer]()
    #TODO check return param and out params
    for paramProp in propParams:
      try:
        let paramValue = call.value[paramProp.getName()]
        setPropWithValueInMemoryBlock(paramProp, memoryBlockAddr, paramValue, allocatedStrings)
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
      result = getValueFromPropMemoryBlock(returnProp, returnMemoryRegion)

    dealloc(memoryBlock)
    for str in allocatedStrings:
      dealloc(str) 
  else: #no params no return
    self.processEvent(fn, nil)
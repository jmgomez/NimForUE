include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, uebind, models, uemeta]
import std/[json, jsonutils, sequtils, options, sugar]




uClass UObjectPOC of UObject:
  (BlueprintType)
  ufuncs(Static):
    proc salute() = 
      UE_Log "Hola from UObjectPOC"
    proc saluteWithOneArg(arg : int) = 
      UE_Log "Hola from UObjectPOC with arg: " & $arg
    proc saluteWithOneArgStr(arg : FString) = 
      UE_Log "Hola from UObjectPOC with arg: " & $arg
    proc saluteWithTwoArgs(arg1 : int, arg2 : int) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc saluteWithTwoDifferentArgs(arg1 : FString, arg2 : FString) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc saluteWitthTwoDifferentIntSizes(arg1 : int32, arg2 : int64) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc saluteWitthTwoDifferentIntSizes2(arg1 : int64, arg2 : int32) = 
      UE_Log "Hola from UObjectPOC with arg1: " & $arg1 & " and arg2: " & $arg2
    proc printObjectName(obj:UObjectPtr) = 
      UE_Log "Object name: " & $obj.getName()
    proc printObjectNameWithSalute(obj:UObjectPtr, salute : FString) = 
      UE_Log "Object name: " & $obj.getName() & " Salute: " & $salute
    proc printObjectAndReturn(obj:UObjectPtr) : int = 
      UE_Log "Object name: " & $obj.getName() 
      10
    proc printObjectAndReturnPtr(obj:UObjectPtr) : UObjectPtr = 
      UE_Log "Object name: " & $obj.getName() 
      obj
    proc printObjectAndReturnStr(obj:UObjectPtr) : FString = 
      let str = "Object name: " & $obj.getName() 
      UE_Log str
      str
    proc printVector(vec : FVector) = 
      UE_Log "Vector: " & $vec

#[
1. [x] Create a function that makes a call by fn name
2. [x] Create a function that makes a call by fn name and pass a value argument
  2.1 [x] Create a function that makes a call by fn name and pass a two values of the same types as argument
  2.2 [x] Create a function that makes a call by fn name and pass a two values of different types as argument
  2.3 [x] Pass a int32 and a int64
3. [x] Create a function that makes a call by fn name and pass a pointer argument
4. [x] Create a function that makes a call by fn name and pass a value and pointer argument
5. [x] Create a function that makes a call by fn name and pass a value and pointer argument and return a value
6. [x] Create a function that makes a call by fn name and pass a value and pointer argument and return a pointer
  6.1 [x] Create a function that makes a call by fn name and pass a value and pointer argument and returns a string
7. [ ] Repeat 1-6 where value arguments are complex types
8. [ ] Add support for missing basic types
8. Arrays
9. TMaps

]#

# type FString2 = FString




type 
  UECall = object
    fn : UEField 
    #The json is used as a table where we will be finding the values as keys. We know the params of a function (we are at runtime)
    value : JsonNode #make this binary data?

# type VMType = 


proc propWithValueToMemoryBlock(prop : FPropertyPtr, value : JsonNode, memoryBlock : pointer, allocatedStrings : var TArray[FString]) =
  let propSize = prop.getSize()
  let propOffset = prop.getOffset()
  var memoryRegion = cast[pointer](cast[int](memoryBlock) + propOffset)
  case value.kind: #this could be templatized 
    of JString: 
      allocatedStrings.add value.getStr() #FStrings need to be kept alive since they have a ptr to the content
      copyMem(memoryRegion, addr allocatedStrings[allocatedStrings.len - 1], propSize)
    of JInt: 
      if propSize == 4: #probably it doesnt really matter if we use int32 or int64 because we are just copying the memory and it will get overriden by the next offset calc
        var paramValue = value.getInt().int32
        copyMem(memoryRegion, addr paramValue, propSize)
      else: #8 #This could also be a pointer. but do we care here? If it's a pointer we just copy it it, right?
        var paramValue = value.getInt()
        copyMem(memoryRegion, addr paramValue, propSize)
    of JFloat:
      var paramValue = value.getFloat()
      copyMem(memoryRegion, addr paramValue, propSize)
    # of JArray: 
    #   var paramValue = value.getElems()
    #   copyMem(memoryRegion, addr paramValue, propSize)
    of JObject: 
      #At this point the prop must be a FStructProperty
      assert prop.isStruct()
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
        else: #TODO test and assert?
          val = value[name.firstToLow()] #Nim vs UE discrepancies
        propWithValueToMemoryBlock(paramProp, val, structMemoryRegion, allocatedStrings)

      #   let paramValue = value[paramProp.getName()]
        

      # var paramValue = value.getElems()
      # copyMem(memoryRegion, addr paramValue, propSize)
    else: discard

proc uCall(call : UECall) : JsonNode = 
  result = newJNull()
  let self {.inject.} = getDefaultObjectFromClassName(call.fn.className.removeFirstLetter())
  UE_Log $call
  let fn = getClassByName(call.fn.className.removeFirstLetter()).findFunctionByName(n call.fn.name)
  
  if call.fn.signature.any():
    var memoryBlock = alloc0(fn.parmsSize)
    let memoryBlockAddr = cast[int](memoryBlock)    

    let propParams = fn.getFPropsFromUStruct().filterIt(it != fn.getReturnProperty())
    var allocatedStrings = makeTArray[FString]()
    #TODO check return param and out params
    for paramProp in propParams:
      let paramValue = call.value[paramProp.getName()]
      propWithValueToMemoryBlock(paramProp, paramValue, memoryBlock, allocatedStrings)

    self.processEvent(fn, memoryBlock)

    
    if call.fn.doesReturn():
      # let returnProp = fn.getFPropsFromUStruct().filterIt(it.getName() == call.fn.getReturnProp.get.name).head().get()
      let returnProp = fn.getReturnProperty()
      let returnOffset = fn.returnValueOffset
      let returnSize = returnProp.getSize()
      var returnMemoryRegion = cast[pointer](memoryBlockAddr + returnOffset.int)

      if returnProp.isFString():
        var returnValue = f""
        copyMem(addr returnValue, returnMemoryRegion, returnSize)
        result = newJString(returnValue)
      else:
        var returnValue = 0
        copyMem(addr returnValue, returnMemoryRegion, returnSize)
        result = newJInt(returnValue)

    dealloc(memoryBlock)

  else: #no params no return
    self.processEvent(fn, nil)
    



uClass AActorPOCVMTest of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc test1() = 
      let callData = UECall( fn: makeFieldAsUFun("salute", @[], "UObjectPOC"))
      discard uCall(callData)
    proc test2() =
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithOneArg",  @[makeFieldAsUPropParam("arg", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg: 10).toJson()
        )
      discard uCall(callData)
    proc test21() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithOneArgStr",  @[makeFieldAsUPropParam("arg", "FString", CPF_Parm)], "UObjectPOC"), 
          value: (arg: "10 cadena").toJson()
        )
      discard uCall(callData)

    proc test23() =
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithTwoDifferentArgs",  @[makeFieldAsUPropParam("arg1", "int", CPF_Parm), makeFieldAsUPropParam("arg2", "FString", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: "10 cadena", arg2: "Hola").toJson()
        )
      discard uCall(callData)
    proc test24() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWitthTwoDifferentIntSizes",  @[makeFieldAsUPropParam("arg1", "int32", CPF_Parm), makeFieldAsUPropParam("arg2", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: 10, arg2: 10).toJson()
        )
      discard uCall(callData)

    proc test25() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWitthTwoDifferentIntSizes2",  @[makeFieldAsUPropParam("arg1", "int32", CPF_Parm), makeFieldAsUPropParam("arg2", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: 15, arg2: 10).toJson()
        )
      discard uCall(callData)


    proc test3() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithTwoArgs",  @[makeFieldAsUPropParam("arg1", "int", CPF_Parm), makeFieldAsUPropParam("arg2", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: 10, arg2: 20).toJson()
        )
      discard uCall(callData)

    proc test4() =
      let callData = UECall(
          fn: makeFieldAsUFun("printObjectName",  @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm)], "UObjectPOC"), 
          value: (obj: cast[int](self)).toJson()
        )
      discard uCall(callData)
    proc test5() = 
      let callData = UECall(
          fn: makeFieldAsUFun("printObjectNameWithSalute", @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm), makeFieldAsUPropParam("salute", "FString", CPF_Parm)], "UObjectPOC"),
          value: (obj: cast[int](self), salute: "Hola").toJson()
        )
      discard uCall(callData)
    proc test6() =
      let callData = UECall(
          fn: makeFieldAsUFun("printObjectAndReturn", 
            @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm), 
              makeFieldAsUPropParam("return", "int", CPF_ReturnParm)], "UObjectPOC"),
          value: (obj: cast[int](self)).toJson()
        )
      UE_Log $uCall(callData)

    proc test7() =
      let callData = UECall(
          fn: makeFieldAsUFun("printObjectAndReturnPtr", 
            @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm), 
              makeFieldAsUPropParam("return", "UObjectPtr", CPF_ReturnParm)], "UObjectPOC"),
          value: (obj: cast[int](self)).toJson()
        )
      let objAddr = uCall(callData).jsonTo(int)
      let obj = cast[UObjectPtr](objAddr)
      UE_Log $obj
    proc test8() = 
      let callData = UECall(
          fn: makeFieldAsUFun("printObjectAndReturnStr", 
            @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm), 
              makeFieldAsUPropParam("return", "FString", CPF_ReturnParm)], "UObjectPOC"),
          value: (obj: cast[int](self)).toJson()
        )
      UE_Log $uCall(callData).jsonTo(string)
    proc test9() = 
      let callData = UECall(
          fn: makeFieldAsUFun("printVector", 
              @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm)], "UObjectPOC"),
          value: (vec:FVector(x:12, y:10)).toJson()
        )
      UE_Log  $uCall(callData).jsonTo(string)



    proc vectorToJsonTest() =
      UE_Log $FVector(x:10, y:10).toJson()
      let vectorScriptStruct = staticStruct(FVector)
      let structProps = vectorScriptStruct.getFPropsFromUStruct()
      for prop in structProps:
        UE_Log $prop.getName()
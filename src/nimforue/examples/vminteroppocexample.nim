include ../unreal/prelude

import ../codegen/[modelconstructor, ueemit, models]
import std/[json, jsonutils]


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

#[
1. [x] Create a function that makes a call by fn name
2. [x] Create a function that makes a call by fn name and pass a value argument
  2.1 [x] Create a function that makes a call by fn name and pass a two values of the same types as argument
  2.2 [x] Create a function that makes a call by fn name and pass a two values of different types as argument
  2.3 [ ] Pass a int32 and a int64
3. [x] Create a function that makes a call by fn name and pass a pointer argument
4. [ ] Create a function that makes a call by fn name and pass a value and pointer argument
5. [ ] Create a function that makes a call by fn name and pass a value and pointer argument and return a value
6. [ ] Create a function that makes a call by fn name and pass a value and pointer argument and return a pointer
7. [ ] Repeat 1-6 where value arguments are complex types
8. Arrays
9. TMaps

]#
proc saluteImp*(): void {.exportcpp: "$1_".} =
  type
    Params {.inject.} = object
    
  var param {.inject.} = Params()
  let fnName {.inject, used.} = n "Salute"
  let self {.inject.} = getDefaultObjectFromClassName("ObjectPOC")
  let fn {.inject, used.} = getClassByName("ObjectPOC").findFunctionByName(
      fnName)
  self.processEvent(fn, param.addr)


type 
  UECall = object
    fn : UEField 
    #The json is used as a table where we will be finding the values as keys. We know the params of a function (we are at runtime)
    value : JsonNode #make this binary data?

# type VMType = 

proc uCall(call : UECall) = 
  let self {.inject.} = getDefaultObjectFromClassName(call.fn.className.removeFirstLetter())
  let fn = getClassByName(call.fn.className.removeFirstLetter()).findFunctionByName(n call.fn.name)
  if call.fn.signature.any():
    var memoryBlock = alloc0(fn.parmsSize)
    let memoryBlockAddr = cast[int](memoryBlock)

    let fprops = fn.getFPropsFromUStruct()
    var allocatedStrings = makeTArray[FString]()
    #TODO check return param and out params
    for paramProp in fprops:
      #We need to check the position, but right now there is only one
      let paramName = paramProp.getName()
      let paramAsJson = call.value[paramName]
      let paramSize = paramProp.getSize() #we cant trust this size, we need the actual param size
      let paramOffset = paramProp.getOffset()
      var paramMemoryRegion = cast[pointer](memoryBlockAddr + paramOffset)
      UE_Log "Param name: " & $paramName & " Param size: " & $paramSize & " Param offset: " & $paramOffset & " Param memory region: " & $paramMemoryRegion
      case paramAsJson.kind:
        of JString: 
          allocatedStrings.add paramAsJson.getStr() #FStrings need to be kept alive since they have a ptr to the content
          copyMem(paramMemoryRegion, addr allocatedStrings[allocatedStrings.len - 1], paramSize)
        of JInt: 
          if paramSize == 4: #probably it doesnt really matter if we use int32 or int64 because we are just copying the memory and it will get overriden by the next offset calc
            var paramValue = paramAsJson.getInt().int32
            copyMem(paramMemoryRegion, addr paramValue, paramSize)
          else: #8 #This could also be a pointer. but do we care here? If it's a pointer we just copy it it, right?
            var paramValue = paramAsJson.getInt()
            copyMem(paramMemoryRegion, addr paramValue, paramSize)
         
        else: discard

    
    self.processEvent(fn, memoryBlock)
    dealloc(memoryBlock)
  else:
    self.processEvent(fn, nil)



uClass AActorPOCVMTest of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc test1() = 
      let callData = UECall( fn: makeFieldAsUFun("salute", @[], "UObjectPOC"))
      uCall(callData)
    proc test2() =
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithOneArg",  @[makeFieldAsUPropParam("arg", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg: 10).toJson()
        )
      uCall(callData)
    proc test21() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithOneArgStr",  @[makeFieldAsUPropParam("arg", "FString", CPF_Parm)], "UObjectPOC"), 
          value: (arg: "10 cadena").toJson()
        )
      uCall(callData)

    proc test23() =
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithTwoDifferentArgs",  @[makeFieldAsUPropParam("arg1", "int", CPF_Parm), makeFieldAsUPropParam("arg2", "FString", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: "10 cadena", arg2: "Hola").toJson()
        )
      uCall(callData)
    proc test24() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWitthTwoDifferentIntSizes",  @[makeFieldAsUPropParam("arg1", "int32", CPF_Parm), makeFieldAsUPropParam("arg2", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: 10, arg2: 10).toJson()
        )
      uCall(callData)

    proc test25() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWitthTwoDifferentIntSizes2",  @[makeFieldAsUPropParam("arg1", "int32", CPF_Parm), makeFieldAsUPropParam("arg2", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: 15, arg2: 10).toJson()
        )
      uCall(callData)


    proc test3() = 
      let callData = UECall(
          fn: makeFieldAsUFun("saluteWithTwoArgs",  @[makeFieldAsUPropParam("arg1", "int", CPF_Parm), makeFieldAsUPropParam("arg2", "int", CPF_Parm)], "UObjectPOC"), 
          value: (arg1: 10, arg2: 20).toJson()
        )
      uCall(callData)

    proc test4() =
      let callData = UECall(
          fn: makeFieldAsUFun("printObjectName",  @[makeFieldAsUPropParam("obj", "UObjectPtr", CPF_Parm)], "UObjectPOC"), 
          value: (obj: cast[int](self)).toJson()
        )
      uCall(callData)


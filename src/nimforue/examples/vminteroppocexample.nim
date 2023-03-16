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

#[
1. [x] Create a function that makes a call by fn name
2. [x] Create a function that makes a call by fn name and pass a value argument
  2.1 [ ] Create a function that makes a call by fn name and pass a two values of the same types as argument
  2.2 [ ] Create a function that makes a call by fn name and pass a two values of different types as argument
3. [ ] Create a function that makes a call by fn name and pass a pointer argument
4. [ ] Create a function that makes a call by fn name and pass a value and pointer argument
5. [ ] Create a function that makes a call by fn name and pass a value and pointer argument and return a value
6. [ ] Create a function that makes a call by fn name and pass a value and pointer argument and return a pointer
7. [ ] Repeat 1-6 where value arguments are complex types


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




proc uCall(call : UECall) = 
  let self {.inject.} = getDefaultObjectFromClassName(call.fn.className.removeFirstLetter())
  let fn = getClassByName(call.fn.className.removeFirstLetter()).findFunctionByName(n call.fn.name)
  if call.fn.signature.any():
    var memoryBlock = alloc0(fn.parmsSize)

    let fprops = fn.getFPropsFromUStruct()
    #We need to check the position, but right now there is only one
    let param1Prop = fprops[0]
    var param1Value = call.value["arg"].getInt() #we cant trust this size, we need the actual param size
    var param1Size = param1Prop.getSize() 
    #TODO how we can trunc the size if we need to? Right now is int64 but what happens if the param is i32 and the value is i64?


    copyMem(memoryBlock, param1Value.unsafeAddr, param1Size) 
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
      


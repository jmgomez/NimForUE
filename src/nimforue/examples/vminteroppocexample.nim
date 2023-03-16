include ../unreal/prelude


uClass UObjectPOC of UObject:
  (BlueprintType)
  ufuncs(Static):
    proc salute() = 
      UE_Log "Hola from UObjectPOC"


#[
1. Create a function that makes a call by fn name
2. Create a function that makes a call by fn name and pass a value argument
3. Create a function that makes a call by fn name and pass a pointer argument
4. Create a function that makes a call by fn name and pass a value and pointer argument
5. Create a function that makes a call by fn name and pass a value and pointer argument and return a value
6. Create a function that makes a call by fn name and pass a value and pointer argument and return a pointer


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


type UECall = object
  fnName : string #This will be just an UEField holding the function


proc uCall(call : UECall) = 
  let self {.inject.} = getDefaultObjectFromClassName("ObjectPOC")
  let fn = getClassByName("ObjectPOC").findFunctionByName(n call.fnName)
  self.processEvent(fn, nil)



uClass AActorPOCVMTest of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc test() = 
      var call = UECall(fnName: "Salute")
      call.uCall()
      


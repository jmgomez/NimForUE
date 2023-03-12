include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../codegen/uemeta



proc vector4_Zero*(): FVector4 {.exportcpp: "$1_", noInit.} =
  type
    Params  = object
      returnValue : FVector4 = FVector4()

  var param {.noInit.}  = Params()
  let fnName {.used.} = n "Vector4_Zero"
  let self  = getDefaultObjectFromClassName("KismetMathLibrary")
  let fn {.used.} = getClassByName("KismetMathLibrary").findFunctionByName(
      fnName)
  self.processEvent(fn, param.addr)
  return param.returnValue



# proc makeColor() : FColor = 
#   FColor(r:100)
uClass AActorCoreUObjectTest of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintType):
    color : FColor = FColor(r:255, g:100, b:100, a:255)
    testTransform : FTransform
    testSet : TSet[int]
    
  ufuncs(CallInEditor):
    proc importCoreUObject() =
      let anotherColor = FColor()
      UE_Log $anotherColor
      # let obj = newUObject[UObject]()
      # self.myActor.bReplicates = true
      
      discard
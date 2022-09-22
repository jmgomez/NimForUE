include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta




# proc makeColor() : FColor = 
#   FColor(r:100)
uClass AActorCoreUObjectTest of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintType):
    color : FColor = FColor(r:255, g:0, b:0, a:255)

  ufuncs(CallInEditor):
    proc importCoreUObject() =
      let anotherColor = FColor()
      UE_Log $anotherColor
      # let obj = newUObject[UObject]()
      discard
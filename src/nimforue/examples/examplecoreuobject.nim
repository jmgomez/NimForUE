include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta


import ../unreal/bindings/coreuobject


# proc makeColor() : FColor = 
#   FColor(r:100)
uClass AActorCoreUObjectTest of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintType):
    color : FColor 

  ufuncs(CallInEditor):
    proc importCoreUObject() =
      
      # let obj = newUObject[UObject]()
      discard


include ../unreal/prelude

import ../codegen/[gencppclass, models]
# import ../unreal/bindings/[slate,slatecore, engine]
import std/[macros, sequtils, strutils]





uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test : FString 
    test322 : FString 
  uprops(EditAnywhere, DefaultComponent):
    testComp : USceneComponentPtr
    # test2 : FString = "adios"
  # defaults:
    # test = "s2"
  # ufuncs:
  #   proc beginPlay() = 
  #     UE_Warn "Non native begin Play called once "
  override:
    proc beginPlay() : void = 
      UE_Warn "Native BeginPlay called once! Nice"
    

# {.compile: "NimHeaders/Game.h".}





include ../unreal/prelude

import ../codegen/[gencppclass, models]
# import ../unreal/bindings/[slate,slatecore, engine]
import std/[macros, sequtils, strutils]





uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test : FString 
  
  
  override:
    proc beginPlay() : void = 
      UE_Warn "Native BeginPlay called twice! Nice"
    proc postLoad() : void = 
      self.super()
      UE_Warn "PostLoad called once"
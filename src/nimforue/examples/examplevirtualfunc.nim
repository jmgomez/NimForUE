

include ../unreal/prelude

import ../codegen/[gencppclass, models]
# import ../unreal/bindings/[slate,slatecore, engine]
import std/[macros, sequtils, strutils]




#[
  TODO
  [] Accept one parameter simple (bool)
  [] Accept one parameter pointer (no const)
  [] Accept multiple paramteres
  [] Accept return types
  [] Should function impl be a var so we can replace it in the next execution?

]#

uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test5 : FString 
  
  
  override:
    proc beginPlay() : void = 
      UE_Warn "Native BeginPlay called twice! Nice. Quite amazing I would say"
    
    proc postDuplicate(b : bool) : void = 
      UE_Warn "post duplicated called !"

    proc postLoad() : void = 
      self.super()
      UE_Warn "PostLoad called once"
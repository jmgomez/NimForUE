

include ../unreal/prelude

import ../codegen/[gencppclass, models]
# import ../unreal/bindings/[slate,slatecore, engine]
import std/[macros, sequtils, strutils]




#[
  TODO
  [x] override no params
  [x] super impl
  [x] Accept one parameter simple (bool)
  [x] Accept one parameter pointer (no const)
  [] Accept multiple paramteres
  [] Accept return types
  [] Review super for the scenarios above
  [] return const
  [] Should fnImpl be a var so we can replace it in the next execution?

]#

uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test6 : FString 
  
  
  override:
    proc beginPlay() : void = 
      UE_Warn "Native BeginPlay called twice! Nice. Quite amazing I would say"
    
    proc postDuplicate(b : bool) : void = 
      UE_Warn "post duplicated called !"
    proc preEditChange(p : FPropertyPtr) : void = 
      UE_Warn "PreEditChange called !" & p.getName()
    proc postLoad() : void = 
      self.super()
      UE_Warn "PostLoad called once"
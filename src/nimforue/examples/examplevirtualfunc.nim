

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
  [] Accept multiple paramteres (only need testing)
  [x] Accept return types
  [x] Const functions with return types
  [] Review super for the scenarios above
  [] Do the nim type maping (float->double float32->float etc)
  [] return const ? (is there any function that needs it?)
  [] Should fnImpl be a var so we can replace it in the next execution?

  [] Move into the gamedll (just import this actor from there)
  [] Interfaces

  [] Generics params
  [] Generics return

  [ ] When removing a function there is a linker issue for the already compiled.
      - [ ] Detect the functions that change between compilations
      - [ ] Detect all the files that uses the header and remove them so they get recompiled. 


]#

uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test8 : FString 
  
  
  override:
    proc beginPlay() = 
      UE_Warn "Native BeginPlay called twice! Nice. Quite amazing I would say"
    
    proc postDuplicate(b : bool) = 
      self.super(b)
      UE_Warn "post duplicated called !"
    proc preEditChange(p : FPropertyPtr) : void = 
      self.super(p)
      UE_Warn "PreEditChange called !" & p.getName()
    proc postLoad() : void = 
      self.super()
      UE_Warn "PostLoad called once"

    proc isListedInSceneOutliner() : bool {. constcpp .} = 
      UE_Log "IsListedInSceneOutliner called once"
      self.super()

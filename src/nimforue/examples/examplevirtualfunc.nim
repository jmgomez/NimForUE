

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
  [x] Accept multiple paramteres (only need testing)
  [x] Accept return types
  [x] Const functions with return types
  [x] Review super for the scenarios above
  [x] Do the nim type maping (float->double float32->float etc)
  [] return const ? (is there any function that needs it?)
  
  [x] Const in params
  [x] Raw references
  [] const ref in params
  [x] const ptr in params
  [ ] multiple fields with the same type
  
  [] Should fnImpl be a var so we can replace it in the next execution?

  [] Move into the gamedll (just import this actor from there)
  [] Interfaces

  [] Generics params
  [] Generics return

  [ ] When removing a function there is a linker issue for the already compiled.
      - [ ] Detect the functions that change between compilations
      - [ ] Detect all the files that uses the header and remove them so they get recompiled. 

  [ ] Investigate why tick doesnt work in native functions

]#

uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test16 : FString 
  
  
  override:
    proc beginPlay() = 
      UE_Warn "Native BeginPlay called in the parent"
    
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
      UE_Log "IsListedInSceneOutliner called in the parent"
      self.super()
    proc getLifeSpan() : float32 {. constcpp .} = 
      UE_Log "GetLifeSpan called in the parent" & $self.super()
      self.super()
    
    #virtual void PostRename( UObject* OldOuter, const FName OldName ) override;
    proc postRename(oldOuter : UObjectPtr, oldName {.constcpp.} : FName) = 
      self.super(oldOuter, oldName)
      UE_Warn "PostRename called !"

    #	virtual bool CanEditChange(const FProperty* InProperty) const;
    proc canEditChange(inProperty {. constcpp .} : FPropertyPtr) : bool {. constcpp .} = 
      UE_Log "CanEditChange called in the parent"
      self.super(inProperty)
    #	virtual bool EditorCanAttachTo(const AActor* InParent, FText& OutReason) const;
    proc editorCanAttachTo(inParent {. constcpp .} : AActorPtr, outReason : var FText) : bool {. constcpp .} = 
      UE_Log "EditorCanAttachTo called in the parent"
      self.super(inParent, outReason)
    
    # virtual void EditorApplyMirror(const FVector& MirrorScale, const FVector& PivotLocation);	
    proc editorApplyMirror(mirrorScale {. constcpp .} : var FVector, pivotLocation {. constcpp .} : var FVector) = 
      self.super(mirrorScale, pivotLocation)
      UE_Warn "EditorApplyMirror called !"


uClass ANimBeginPlayOverrideActorChild of ANimBeginPlayOverrideActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test12 : FString 
  
  default:
    primaryActorTick.bCanEverTick = true
    primaryActorTick.bStartWithTickEnabled = true;

  override:
    proc beginPlay() = 
      UE_Warn "Native BeginPlay called in the child!"
      super(self)

    proc isListedInSceneOutliner() : bool {. constcpp .} = 
      UE_Log "IsListedInSceneOutliner called in the child"
      self.super()
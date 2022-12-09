include ../unreal/prelude
import ../unreal/editor/editor
import std/[strformat, enumutils, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig

import ../../codegen/codegentemplate



# uEnum EMyEnum:
#   A
#   B
#   C

uStruct FMyStructTest:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    a: int
    b: float
    c : bool
    e: float32
    f: float32
    g: bool
    g4: TArray[int]
    g5 : UObjectPtr
    g7 : FString

uClass AActorScratchpad of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    testw: int32 = 1     
    # myEnum : EMyEnum
    myStruct : FMyStructTest
    structPtrName : FString 
    actorToInspect : AActorPtr
    testBool : bool
  uprops(EditAnywhere, BlueprintReadWrite, Category=Whatever):
    testCV : int32 = 1
                                                                                 
  uprops(EditAnywhere, BlueprintReadWrite):
    testC4 : int32 = 2     

  ufuncs():
    proc beginPlay() = 
      UE_Warn "Begin called in actor scratchpad"
      discard                                                          
      
  ufuncs(CallInEditor):

    proc toggleBool() = 
      self.testBool = not self.testBool
      UE_Log &"Bool is now {self.testBool}"
      
    proc printObj() = 
      UE_Log &"Object name {self.actorToInspect}"
    proc modifyStruct() = 
      self.myStruct.a = 10
    proc testEditorPIE() = 
      UE_Log &"IsInPie {GEditor.isInPIE()}"
    proc searchStructPtr() = 
      let obj = getUTypeByName[UClass]("ActorScratchpad")
      if obj.isNil(): 
        UE_Error &"Error struct is null"
        return
      
      let props = getFPropsFromUStruct(obj)

      for p in props:
        UE_Log $p
        let category = p.getMetadata("Category")
        UE_Log $category

      let funcs = getFuncsFromClass(obj, EFieldIterationFlags.IncludeSuper)
      for f in funcs:
        UE_Log $f
        


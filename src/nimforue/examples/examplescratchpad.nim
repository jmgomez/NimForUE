include ../unreal/prelude
import std/[strformat, enumutils, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig

import ../../codegen/codegentemplate



# uEnum EMyEnum:
#   A
#   B
#   C

# uStruct FMyStructTest:
#   uprops(EditAnywhere, BlueprintReadWrite):
#     a: int
#     b: float

uClass AActorScratchpad of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    testA : int32 = 1     
    # myEnum : EMyEnum
    # myStruct : FMyStructTest
    structPtrName : FString 
  uprops(EditAnywhere, BlueprintReadWrite, Category=Whatever):
    testB : int32 = 5  
                                                                                 
  uprops(EditAnywhere, BlueprintReadWrite):
    testC : int32 = 2     
                                                                                 
 
  ufuncs(CallInEditor):
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

      let ueType = obj.toUEType()
      UE_Log $ueType
      
      UE_Warn $obj


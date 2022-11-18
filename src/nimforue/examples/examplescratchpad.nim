include ../unreal/prelude
import std/[strformat, enumutils, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig

import ../../codegen/codegentemplate




uClass AActorScratchpad of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    testA : int32 = 1     
    structPtrName : FString 
                                                                                  
 
  ufuncs(CallInEditor):
    proc searchStructPtr() = 
      let obj = getUTypeByName[UClass]("TestActor")
      if obj.isNil(): 
        UE_Error &"Error struct is null"
        return
      
      let props = getFPropsFromUStruct(obj)

      for p in props:
        UE_Log $p

      let ueType = obj.toUEType()
      UE_Log $ueType
      
      UE_Warn $obj
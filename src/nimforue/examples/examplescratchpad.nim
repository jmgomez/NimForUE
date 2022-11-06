include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate



uStruct FAnotherStruct:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    stringProp : FString
   


uStruct FTestStruct:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    stringProp : FString
    intProp : int
    anotherStruct : FAnotherStruct

uClass UObjectScratchpad of UObject:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    testA : int
    testB : FTestStruct



uClass AActorScratchpad of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    structProp : FTestStruct

  ufuncs(CallInEditor):
    proc testModifyStructProp() =
      # var structProp = FTestStruct(stringProp: "Hello", intProp: 42)
      # structProp.stringProp = "World"
      self.structProp.stringProp = "World"
      let obj = newUObject[UObjectScratchpad]()

      obj.testA = 44
      obj.testB = FTestStruct(stringProp: "Hello", intProp: 42)
      obj.testB.stringProp = "this is perfect"
      obj.testB.anotherStruct = FAnotherStruct(stringProp: "this is another struct")
      obj.testB.anotherStruct.stringProp = "this is perfect"
      UE_LOG $obj.testA
      UE_LOG $obj.testB

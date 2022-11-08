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
    obj : UObjectScratchpadPtr
    arr : TArray[int] #= makeTArray[int](2, 1)
    arrStrs : TArray[FString] #= makeTArray[int](2, 1)
    mapTest : TMap[int32, int32] #= makeTArray[int](2, 1)
    mapTestStr : TMap[FString, FString] #= makeTArray[int](2, 1)

  ufuncs(CallInEditor):
    proc testModifyStructProp() =
      self.structProp.stringProp = "World yes!"
      # UE_Warn $self.structProp.stringProp
      if self.obj.isNil:
        self.obj = newUObject[UObjectScratchpad]()
      
      self.arr[0] = 2
      

      self.obj.testA = 44
      self.obj.testB = FTestStruct(stringProp: "Hello", intProp: 42)
      self.obj.testB.stringProp = "this is perfect"
      self.obj.testB.anotherStruct = FAnotherStruct(stringProp: "this is another struct")
      self.obj.testB.anotherStruct.stringProp = "this is perfect"
      UE_LOG $self.obj.testA
      UE_LOG $self.obj.testB

    proc playWithArray() =
      
      let arrLocal = makeTArray[int](1, 2, 3)
      arrLocal.add 2
      arrLocal[0] = 2
      UE_LOG $arrLocal #This works just fine

      self.arr = makeTArray[int](1, 2, 3)
      self.arr.add 2
      self.arr[0] = 2
      UE_LOG $self.arr

    proc playWithArraySetLocal() =
      
      let arrLocal = makeTArray[int](1, 2, 3)
      arrLocal.add 2
      arrLocal[0] = 2
      UE_LOG $arrLocal #This works just fine

      self.arr = arrLocal
      
      UE_LOG $self.arr

    proc playWithArrayStr() =
      self.arrStrs = makeTArray[FString](f"Hello", f"World")
      # self.arrStrs.add "2"
      # self.arrStrs[0] = "2"
      UE_LOG $self.arrStrs

    proc playWithMap() =
        self.mapTest = makeTMap[int32, int32]()
        self.mapTest.add(1, 2)
        self.mapTest.add(5, 2)
        UE_LOG $self.mapTest
    proc playWithMapStr() =
        self.mapTestStr = makeTMap[FString, FString]()
        self.mapTestStr.add(f"1", f"2bla")
        self.mapTestStr.add(f"5a", f"2")
        UE_LOG $self.mapTestStr

proc myExampleActorCostructor(self: AActorScratchpadPtr, initializer: FObjectInitializer) {.uConstructor.} =
  self.arr = makeTArray[int](1, 2, 3)
  self.arr.add 2
  self.arr[0] = 2
  UE_LOG $self.arr
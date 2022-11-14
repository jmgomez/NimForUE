include ../unreal/prelude
import std/[strformat, enumutils, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate



uStruct FAnotherStruct:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    stringProp : FString = "whatever"
   


uStruct FTestStruct:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    stringProp : FString = "whatever 1"
    intProp : int = 2
    anotherStruct : FAnotherStruct

uClass UObjectScratchpad of UObject:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    testA : int
    testB : FTestStruct
    testArray : TArray[UObjectPtr]
  ufuncs(BlueprintCallable, BlueprintPure):
    proc testFunc(a : int, b : int) : int =
      return a + b

type ATestActor = object of AActor
type ATestActorPtr = ptr ATestActor

uClass AActorSoftTest of ATestActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    testA : int
    arrayTest : TArray[int32]
 

uClass AActorScratchpad of ATestActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    structProp : FTestStruct = FTestStruct()
    testA : int32 = 7
    obj : UObjectScratchpadPtr
    arr : TArray[int32] #= makeTArray[int](2, 1)
    arrStrs : TArray[FString] #= makeTArray[int](2, 1)
    arrObjs : TArray[UObjectPtr] #= makeTArray[int](2, 1)
    mapTest : TMap[int32, int32] #= makeTArray[int](2, 1)
    mapTestStr : TMap[FString, FString] #= makeTArray[int](2, 1)
    mapTestObj : TMap[FString, UObjectPtr] = makeTMap[FString, UObjectPtr]()

  ufuncs(CallInEditor):
    proc garbageCollect() = 
      let engine = getEngine()
      engine.forceGarbageCollection(true)
    proc createArrayIssue() = 
      let obj = newUObject[UObjectScratchpad]()
      obj.testArray = makeTArray[UObjectPtr]()
      for i in countup(0, 100):
        obj.testArray.add(newUObject[UObjectScratchpad]())
      obj.conditionalBeginDestroy()


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
      self.arr = makeTArray[int32](1.int32, 2.int32, 3.int32)
      self.arr.add 2.int32
      self.arr[0] = 2.int32
      UE_LOG $self.arr

    proc playWithArraySetLocal() =
      
      let arrLocal = makeTArray[int32](1, 2, 3)
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
    proc updateA() = 
      self.testA = 2
      UE_LOG $self.testA
      
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
    # proc playWithMapObj() =
    #     self.mapTestObj = makeTMap[FString, UObjectPtr]()
    #     self.mapTestObj.add(f"1", newUObject[UObjectScratchpad]())
    #     self.mapTestObj.add(f"5a", newUObject[UObjectScratchpad]())
    #     UE_LOG $self.mapTestObj
    # proc playWithMapObj() =
    #     let mapTestObj = makeTMap[FString, UObjectScratchpadPtr]()
    #     mapTestObj.add(f"1", newUObject[UObjectScratchpad]())
    #     mapTestObj.add(f"5a", newUObject[UObjectScratchpad]())
    #     UE_LOG $mapTestObj
    proc showClassPropFlags() =
      try:
          
        let cls = self.getClass()
        let propName = ["arr", "RegularArray", "ObjMap", "mapTestObj"]
        let props = cls.getFPropsFromUStruct(IncludeSuper).filterIt(it.getName() in propName)
        for p in props:
          UE_Log &"Prop: {p.getName()} Flags: {p.getPropertyFlags()} obj flags: {p.getFlags()}"
      
        UE_Log $cls.classFlags
        UE_Log $cls.getFlags()
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
      
      # let a = EPropertyFlags.fields()
      # # UE_Log $a

      # UE_Log &"Props: arr {prop.getPropertyFlags()}"
      # UE_Log &"Props Num: {prop.getPropertyFlags().uint64}"
      # UE_Log &"Class flags {cls.classFlags}"


# proc myExampleActorCostructor(self: AActorScratchpadPtr, initializer: FObjectInitializer) {.uConstructor.} =
#   self.arr = makeTArray[int](1, 2, 3)
#   self.arr.add 2
#   self.arr[0] = 2
#   UE_LOG $self.arr
#   self.mapTest = makeTMap[int32, int32]()
#   self.mapTest.add(1.int32, 2.int32)


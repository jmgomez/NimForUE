include ../unreal/prelude
import ../unreal/bindings/[slate,slatecore]
# import ../unreal/bindings/exported/[slate, slatecore]
# import ../unreal/bindings/exported/nimforue
import ../typegen/[uemeta]
import std/[strformat, random]


uStruct FMyUStructDemoTest2:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
       intProp : int32
       int64Prop : int64
       intProp2 : int32

uStruct FStructWithString2:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
       intProp : int32
       int64Prop : int64
       strProp : FString
       intProp2 : int32

type FStructWithString2Cpp = object
    intProp : int32
    int64Prop : int64
    strProp : FString
    intProp2 : int32


uStruct FStructWithString:
    (BlueprintType)
    uprop(EditAnywhere, BlueprintReadWrite):
       strProp : FString


proc logScriptStruct(name : string) = 
  let str = getUTypeByName[UScriptStruct](name)
  if str.isNil(): 
    UE_Error &"UScriptStructPtr {name} is nil"
    return

  UE_Log &"UScriptStructPtr: {str.getName()} Size {str.getSize()} Aligment: {str.getAlignment()}"
  if str.hasAddStructReferencedObjects(): 
    UE_Warn &"The struct {str} has custom GC Code"
  
  #Print the offset perfield
  for prop in getFPropsFromUStruct(str):
    UE_Log &"  {prop.getName()} Offset: {prop.getOffset()} Size: {prop.getSize()}"


proc logNimStruct[T]() = 
    UE_Warn &"Nim: {$typeof(T)} Size {sizeof(T)} Aligment: {alignof(T)}"


type FTestAlignExposedEqual* = object
    intProp : int32
    intProp2 : int32

type FTestAlignExposedDifferent* = object
    intProp : int32
    intProp64 : int64
    intProp2 : int32

type FTestAlignNotExposed* = object
    intProp {.align(8).} : int32
    offset {.align(8).} : byte
    intProp2 {.align(8).}: int32

#This is just for testing/exploring, it wont be an actor
uClass AActorStructExampleIssue of AActor:
  (BlueprintType)
  uprop(EditAnywhere, BlueprintReadWrite):
    myStructNim : FMyUStructDemoTest2
    structWithString : FStructWithString
    structWithString2 : FStructWithString2
    structWithString2Cpp : FStructWithString2Cpp
    exposedEqual : FTestAlignExposedEqual
    exposedDifferent : FTestAlignExposedDifferent
    notExposed : FTestAlignNotExposed


    str : FString
  ufuncs(CallInEditor):
    proc printSlateBrush() =
      logScriptStruct("SlateBrush")
      logNimStruct[FSlateBrush]()
      

    proc modifyStr() = 
      self.str = "hello"

    proc modifyStructWithString() = 
      logScriptStruct("StructWithString")
      logNimStruct[FStructWithString]()
      self.structWithString = FStructWithString(strProp:"hello")
    
    proc modifyStructWithString2() = 
      logScriptStruct("StructWithString2")
      logNimStruct[FStructWithString2]()
      self.structWithString2 = FStructWithString2(strProp:"hello")

    proc modifyStructWithString2Cpp() = 
      logScriptStruct("StructWithString2Cpp")
      logNimStruct[FStructWithString2Cpp]()
      self.structWithString2Cpp = FStructWithString2Cpp(strProp:"hello")


    proc modifyNimDeclaredStruct() =
      if self.myStructNim.intProp == 0:
        self.myStructNim = FMyUStructDemoTest2(intProp: 1.int32, intProp2: 2.int32)
      else: 
        self.myStructNim = FMyUStructDemoTest2(intProp: self.myStructNim.intProp.int32 + 1, intProp2: 2.int32)
      UE_Log ($self.myStructNim)


    proc modifyProp2InCppStructs() =
      let val = 1.int32
      self.exposedEqual = FTestAlignExposedEqual(intProp2: val)
      self.exposedDifferent = FTestAlignExposedDifferent(intProp2: val)
      self.notExposed = FTestAlignNotExposed(intProp2: val)

    proc logFMyUStructDemoTest2() =
      logScriptStruct("MyUStructDemoTest2")
      logNimStruct[FMyUStructDemoTest2]()

    proc logCppStructs() = 
        logScriptStruct("TestAlignExposedEqual")
        logNimStruct[FTestAlignExposedEqual]()
        logScriptStruct("TestAlignExposedDifferent")
        logNimStruct[FTestAlignExposedDifferent]()
        logScriptStruct("TestAlignNotExposed")
        logNimStruct[FTestAlignNotExposed]()




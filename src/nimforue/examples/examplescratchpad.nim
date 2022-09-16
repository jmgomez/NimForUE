include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate

# import ../unreal/bindings/[nimforuebindings, testimport]

# {.experimental: "codeReordering".}

# type Base = AActor #to quickly test from the bindings



#gen this
type
  UMyClassToTest {.importcpp, header:"UEGenBindings.h".} = object of UObject
  UMyClassToTestPtr = ptr UMyClassToTest
proc getHelloWorld(obj : UMyClassToTestPtr) : FString {. importcpp:"$1(#)", header:"UEGenBindings.h" .}



proc nameProperty*(obj : UMyClassToTestPtr): FName {. importcpp:"$1(@)", header:"UEGenBindings.h" .}

proc `nameProperty=`*(obj : UMyClassToTestPtr; val : FName) {. importcpp:"set$1(@)", header:"UEGenBindings.h" .}


proc getHelloWorldStatic*(): FString {. importcpp:"$1(@)", header:"UEGenBindings.h" .}

#We should try first interop with a property (getter and setter)

#Also test static functions

#Return a custom object just for fun

#----

#Node interface -> 

# GOALS Make the engine bindings
  # Test the above manually
  # Generate the above and make it work automatically for NimForUEBindings
    # Generate the GenModule (UEType to Cpp) from Codegen
    # Generate the Consumer from Codegen?
  
  # We have to figure out the dependencies between types and modules. 
    # For each type that the module dont own:
        #Check what module it belongs to
        #Include it in the dependencies modules if it isnt already
        #Consider the dependency graph between types so we dont need to reorder anything
        #Consider if it will worth the trouble to have virtual modules
          #i.e. UKismet -> Module. 

#Graph each node is a {UEType e UEModule} there is an edge that given a type retuns its module. 

#A can holds B and B holds C and C holds A



#-------
#withEditor
#Platforms
#-------
uClass AActorScratchpad of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    objTest : TObjectPtr[AActor]
    objTest2 : TObjectPtr[AActor]
    # objTestInArray : TArray[TObjectPtr[AActor] g.packed[module].module
    # beatiful: EComponentMobility

    testColor : FLinearColor
  
    # intProp2 : int32
  
  ufuncs(CallInEditor):
    proc testHelloWorld() =
      let obj = newUObject[UMyClassToTest]()
      UE_Log "testHelloWorld: " & obj.getHelloWorld()

    proc testUProp() =
      let obj = newUObject[UMyClassToTest]()
      # obj.nameProperty=n"NameProperty"
      UE_Log nameProperty(obj).toFString()

    proc testStaticFunction() =
      UE_Warn getHelloWorldStatic() 
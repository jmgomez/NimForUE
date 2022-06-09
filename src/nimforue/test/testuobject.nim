
import ../unreal/nimforue/nimforuebindings
import ../macros/uebind
import ../unreal/coreuobject/[uobject, unrealtype]
import ../unreal/core/containers/[unrealstring, array]
import ../unreal/core/math/[vector]
import ../unreal/core/[enginetypes]
import macros

import testutils
{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"

""".}

let suiteName = "NimForUE.UObject."

ueTest suiteName & "ShouldBeAbleToGetAClassByName":
    let cls = getClassByName("Actor")

    assert not cls.isNil()
    assert cls.getName() == FString("Actor")
    
    
ueTest suiteName & "ShouldBeAbleToCreateAObjectByClass":
    let cls = getClassByName("Actor")
    let obj = newObjectFromClass(cls)

    assert not cls.isNil()
    assert cls.getName()==(obj.getClass().getName())


ueTest suiteName & "ShouldBeAbleToCallAFunctionInAnUObject":
    let cls = getClassByName("MyClassToTest")
    let obj = newObjectFromClass(cls)

    let expectedResult = FString("Hello World!")


    proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.}
    
    let result = obj.getHelloWorld()


    assert result == expectedResult

ueTest suiteName & "ShouldBeAbleToCallAStaticFunctionInAClass":
    let cls = getClassByName("MyClassToTest")

    let expectedResult = FString("Hello World!")

    proc getHelloWorld(): FString =
        type
            Params = object
                toReturn: FString

        let cls = getClassByName("MyClassToTest")
        var params = Params()
        var fnName: FString = "GetHelloWorld"
        callUFuncOn(cls, fnName, params.addr)
        return params.toReturn


    proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.}
    
    let result = getHelloWorld()


    assert result == expectedResult


ueTest suiteName & "ShouldBeAbleToCallAStaticFunctionInAClassWithUEBind":
    let cls = getClassByName("MyClassToTest")

    let expectedResult = FString("Hello World!")

    proc getHelloWorld() : FString {.uebindstatic:"MyClassToTest"}

    let result = getHelloWorld()
    assert result == expectedResult


ueTest suiteName & "ShouldBeAbleToGetThePropertyNameFromAClass":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 

    assert not prop.isNil()

    assert prop.getName() == propName


ueTest suiteName & "ShouldBeAbleToGetThePropertyValueFromAnObject":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 
    var obj = newObjectFromClass(cls)

    let result = getPropertyValuePtr[FString](prop, obj)[]

    let expectedResult = FString("Hello World!")


    assert result == expectedResult

ueTest suiteName & "ShouldBeAbleToGetThePropertyValueFromAnObjectUsingAGetter_PreMacro":
    type 
        UMyClassToTest = object of UObject
        UMyClassToTestPtr = ptr UMyClassToTest
     
    proc testProperty(obj:UMyClassToTestPtr) : FString = 
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        let prop = cls.getFPropertyByName propName 
        let result = getPropertyValuePtr[FString](prop, obj)[]
        # let result = cast[ptr FString](prop.getFPropertyValue(obj))[]
        result

    var obj = newUObject[UMyClassToTest]()

    let result = obj.testProperty
    let expectedResult = FString("Hello World!")

    assert result == expectedResult


ueTest suiteName & "ShouldBeAbleToSetThePropertyValueFromAnObject":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 
    var obj = newObjectFromClass(cls)
    var expectedResult = FString("New Value!")

    setPropertyValuePtr(prop, obj, expectedResult.addr) 
 
    let result = getPropertyValuePtr[FString](prop, obj)[]


    assert result == expectedResult

ueTest suiteName & "ShouldBeAbleToSetThePropertyValueFromAnObject_PreMacro":
    type 
        UMyClassToTest = object of UObject
        UMyClassToTestPtr = ptr UMyClassToTest

    proc testProperty(obj:UMyClassToTestPtr) : FString = 
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        let prop = cls.getFPropertyByName propName 
        let result = getPropertyValuePtr[FString](prop, obj)[]
        result 

    proc `testProperty=`(obj:UMyClassToTestPtr, val:FString) = 
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        var value : FString = val 
        let prop = cls.getFPropertyByName propName
        setPropertyValuePtr[FString](prop, obj, value.addr)
         
    
    var obj = newUObject[UMyClassToTest]()
    var expectedResult = FString("New Value!")
    
    assert obj.testProperty != expectedResult
    
    obj.testProperty = expectedResult

    assert obj.testProperty == expectedResult



const ueType = UEType(name: "UMyClassToTest", parent: "UObject", kind: uClass, 
                    properties: @[
                        UEProperty(name: "TestProperty", kind: "FString"),
                        UEProperty(name: "IntProperty", kind: "int32"),
                        UEProperty(name: "FloatProperty", kind: "float32"),
                        UEProperty(name: "BoolProperty", kind: "bool"),
                        UEProperty(name: "ArrayProperty", kind: "TArray[FString]"),
                    
                        ])
                        

genType(ueType) #Notice we wont be using genType directly

ueTest suiteName & "ShouldBeAbleToUseAutoGenGettersAndSettersForFString":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = FString("Hello from Test")
    obj.testProperty = expectedResult 
    assert expectedResult == obj.testProperty 

ueTest suiteName & "ShouldBeAbleToUseAutoGenGettersAndSettersForint32":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = int32 5
    obj.intProperty = expectedResult
    
    assert expectedResult == obj.intProperty 

ueTest suiteName & "ShouldBeAbleToUseAutoGenGettersAndSettersForFloat":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = 5.0f
    obj.floatProperty = expectedResult
      
    assert expectedResult == obj.floatProperty 



ueTest suiteName & "ShouldBeAbleToUseAutoGenGettersAndSettersForBool":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = true
    obj.boolProperty = expectedResult
      
    assert expectedResult == obj.boolProperty 



ueTest suiteName & "ShouldBeAbleToUseAutoGenGettersAndSettersForArray":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult : TArray[FString] = makeTArray[FString]()
    expectedResult.add(FString("Hello"))
    expectedResult.add(FString("World"))

    obj.arrayProperty = expectedResult
      
    assert expectedResult.num() == obj.arrayProperty.num()
    assert expectedResult[0] == obj.arrayProperty[0]
    assert expectedResult[1] == obj.arrayProperty[1]
    # assert expectedResult == obj.arrayProperty #TODO define comparison for TArray

     



# dumpTree:
#     type Whatever = object 
#         regularProperty : int32
#         genericProp : TArray[FString]
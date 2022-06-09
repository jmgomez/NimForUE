
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

ueTest "ShouldBeAbleToGetAClassByName":
    let cls = getClassByName("Actor")

    assert not cls.isNil()
    assert cls.getName() == FString("Actor")
    
    
ueTest  "ShouldBeAbleToCreateAObjectByClass":
    let cls = getClassByName("Actor")
    let obj = newObjectFromClass(cls)

    assert not cls.isNil()
    assert cls.getName()==(obj.getClass().getName())


ueTest "ShouldBeAbleToCallAFunctionInAnUObject":
    let cls = getClassByName("MyClassToTest")
    let obj = newObjectFromClass(cls)

    let expectedResult = FString("Hello World!")


    proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.}
    
    let result = obj.getHelloWorld()


    assert result == expectedResult

ueTest "ShouldBeAbleToCallAStaticFunctionInAClass":
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


ueTest "ShouldBeAbleToCallAStaticFunctionInAClassWithUEBind":
    let cls = getClassByName("MyClassToTest")

    let expectedResult = FString("Hello World!")

    proc getHelloWorld() : FString {.uebindstatic:"MyClassToTest"}

    let result = getHelloWorld()
    assert result == expectedResult


ueTest "ShouldBeAbleToGetThePropertyNameFromAClass":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 

    assert not prop.isNil()

    assert prop.getName() == propName


ueTest "ShouldBeAbleToGetThePropertyValueFromAnObject":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 
    var obj = newObjectFromClass(cls)

    let result = getPropertyValuePtr[FString](prop, obj)[]

    let expectedResult = FString("Hello World!")


    assert result == expectedResult

ueTest "ShouldBeAbleToGetThePropertyValueFromAnObjectUsingAGetter_PreMacro":
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


ueTest "ShouldBeAbleToSetThePropertyValueFromAnObject":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 
    var obj = newObjectFromClass(cls)
    var expectedResult = FString("New Value!")

    setPropertyValuePtr(prop, obj, expectedResult.addr) 
 
    let result = getPropertyValuePtr[FString](prop, obj)[]


    assert result == expectedResult

ueTest "ShouldBeAbleToSetThePropertyValueFromAnObject_PreMacro":
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

#This struct is defined in Cpp. TODO: Integrate it into the macro
type FStructToUseAsVar = object 
    testProperty : FString  


const ueVarType = UEType(name: "UClassToUseAsVar", parent: "UObject", kind: uClass, 
                    properties: @[
                        UEProperty(name: "TestProperty", kind: "FString"),
                        ])
                        

const ueType = UEType(name: "UMyClassToTest", parent: "UObject", kind: uClass, 
                    properties: @[
                        UEProperty(name: "TestProperty", kind: "FString"),
                        UEProperty(name: "IntProperty", kind: "int32"),
                        UEProperty(name: "FloatProperty", kind: "float32"),
                        UEProperty(name: "BoolProperty", kind: "bool"),
                        UEProperty(name: "ArrayProperty", kind: "TArray[FString]"),
                        UEProperty(name: "ObjectProperty", kind: "UClassToUseAsVarPtr"),
                        UEProperty(name: "StructProperty", kind: "FStructToUseAsVar"),
                    
                        ])
                        
genType(ueVarType)
genType(ueType) #Notice we wont be using genType directly

ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForFString":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = FString("Hello from Test")
    obj.testProperty = expectedResult 
    assert expectedResult == obj.testProperty 

ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForint32":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = int32 5
    obj.intProperty = expectedResult
    
    assert expectedResult == obj.intProperty 

ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForFloat":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = 5.0f
    obj.floatProperty = expectedResult
      
    assert expectedResult == obj.floatProperty 



ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForBool":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult = true
    obj.boolProperty = expectedResult
      
    assert expectedResult == obj.boolProperty 



ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForUObjectProps":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()
    let expectedResult : UClassToUseAsVarPtr = newUObject[UClassToUseAsVar]()
    expectedResult.testProperty = "Hello another prop!"
    
    obj.objectProperty = expectedResult

      
    assert obj.objectProperty.testProperty == expectedResult.testProperty
  

ueTest "ShouldBeAbleToUseAutoGenGettersAndSettersForStructs_PreMacro":
    let obj : UMyClassToTestPtr = newUObject[UMyClassToTest]()

    let expectedResult = FString("Some String")

    let structProp = FStructToUseAsVar(testProperty: expectedResult)

    obj.structProperty = structProp

    assert obj.structProperty.testProperty == expectedResult

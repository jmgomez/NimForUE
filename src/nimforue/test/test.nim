import ../unreal/nimforue/nimforuebindings
import ../macros/uebind
import ../unreal/coreuobject/[uobject, unrealtype]
import ../unreal/core/containers/[unrealstring, array]
import ../unreal/core/math/[vector]
import ../unreal/core/[enginetypes]
import macros
import unittest
import strutils
{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"

""".}

template suite* (suitName: static string, body:untyped) = 
    block:
        body
        

#TODO remove hooked tests
template ueTest*(name:string, body:untyped) = 
    block:
        when declared(suiteName):
            var test = makeFNimTestBase(suiteName & "." & name)
        else:
            var test = makeFNimTestBase(name)
        proc actualTest (test: var FNimTestBase){.cdecl.} =   
            try:
                body
            except Exception as e:
                let msg = e.msg
                test.testTrue(msg, false)

        test.ActualTest = actualTest
        test.reloadTest()


#suite NimForUE



ueTest "NimForUE.ShouldBeBleToCreateAndOperateWithVectors":
    let v : FVector = makeFVector(10, 50, 30)
    let v2 = v+v 

    let expectedResult = makeFVector(20, 100, 60)

    assert expectedResult == v2


#suite TArrays
ueTest "NimForUE.TArrays.ShouldbeAbleToInteropWithTArrays":
    let arr : TArray[FString] = makeTArray[FString]()
    arr.add FString("Hello")
    arr.add FString("World")

    assert arr.num() == 2
    


ueTest "NimForUE.TArrays.ShouldBeAbleToIterateArrays":
    let arr : TArray[int32] = makeTArray[int32]()
    arr.add 5
    arr.add 10

    var result = 0
    for n in arr:
        result = result + n

    assert result == 15
    
#suite uobjects

ueTest "NimForUE.UObjects.ShouldBeAbleToGetAClassByName":
    let cls = getClassByName("Actor")

    assert not cls.isNil()
    assert cls.getName() == FString("Actor")
    
    
ueTest "NimForUE.UObjects.ShouldBeAbleToCreateAObjectByClass":
    let cls = getClassByName("Actor")
    let obj = newObjectFromClass(cls)

    assert not cls.isNil()
    assert cls.getName()==(obj.getClass().getName())


ueTest "NimForUE.UObjects.ShouldBeAbleToCallAFunctionInAnUObject":
    let cls = getClassByName("MyClassToTest")
    let obj = newObjectFromClass(cls)

    let expectedResult = FString("Hello World!")


    proc getHelloWorld(obj:UObjectPtr) : FString {.uebind.}
    
    let result = obj.getHelloWorld()


    assert result == expectedResult

ueTest "NimForUE.UObjects.ShouldBeAbleToCallAStaticFunctionInAClass":
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


ueTest "NimForUE.UObjects.ShouldBeAbleToCallAStaticFunctionInAClassWithUEBind":
    let cls = getClassByName("MyClassToTest")

    let expectedResult = FString("Hello World!")

    proc getHelloWorld() : FString {.uebindstatic:"MyClassToTest"}

    let result = getHelloWorld()
    assert result == expectedResult


ueTest "NimForUE.UObjects.ShouldBeAbleToGetThePropertyNameFromAClass":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 

    assert not prop.isNil()

    assert prop.getName() == propName


ueTest "NimForUE.UObjects.ShouldBeAbleToGetThePropertyValueFromAnObject":
    let cls = getClassByName("MyClassToTest")
    var propName : FString = "TestProperty"
    let prop = cls.getFPropertyByName propName 
    var obj = newObjectFromClass(cls)

    let result = cast[ptr FString](prop.getFPropertyValue(obj))[]

    let expectedResult = FString("Hello World!")


    assert result == expectedResult

ueTest "NimForUE.UObjects.ShouldBeAbleToGetThePropertyValueFromAnObjectUsingAGetter_PreMacro":
    type 
        UMyClassToTest = object of UObject
        UMyClassToTestPtr = ptr UMyClassToTest
    
    proc testProperty(obj:UMyClassToTestPtr) : FString = 
        let cls = getClassByName("MyClassToTest")
        var propName : FString = "TestProperty"
        let prop = cls.getFPropertyByName propName 
        let result = cast[ptr FString](prop.getFPropertyValue(obj))[]
        result

    var obj = newUObject[UMyClassToTest]()

    let result = obj.testProperty
    let expectedResult = FString("Hello World!")

    assert result == expectedResult


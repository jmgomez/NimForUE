import ../unreal/nimforue/nimforuebindings
import ../macros/uebind
import ../unreal/coreuobject/[uobject, unrealtype]
import ../unreal/core/containers/[unrealstring, array]
import ../unreal/core/math/[vector]
import ../unreal/core/[enginetypes]

import testutils

import testuobject

{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"

""".}


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
    

ueTest "NimForUE.UStructs.ShouldBeAbleToGetTheClassOfAStruct":
    let scriptStruct = getUStructByName("StructToUseAsVar")
   
    assert not scriptStruct.isNil()


ueTest "NimForUE.UStructs.ShouldBeAbleToGetTheFPropOfAStruct":
    let scriptStruct = getScriptStructByName("StructToUseAsVar")
   
    var propName : FString = "TestProperty"
    let prop = scriptStruct.getFPropertyByName propName 

    assert not prop.isNil()

    assert prop.getName() == propName
    assert not scriptStruct.isNil()

#I think there is no need for adding getters and setters to ustructs, just mirroring the types should be enough. Not 100% sure though.

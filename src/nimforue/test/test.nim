include ../unreal/prelude

import testutils

import testuobject

suite "NimForUE":
 
    ueTest "FVectors.ShouldBeBleToCreateAndOperateWithVectors":
        let v : FVector = makeFVector(10, 50, 30)
        let v2 = v+v 

        let expectedResult = makeFVector(20, 100, 60)

        assert expectedResult == v2

    suite "TArrays": 
      
        ueTest "ShouldbeAbleToInteropWithTArrays":
            let arr : TArray[FString] = makeTArray[FString]()
            arr.add FString("Hello")
            arr.add FString("World")
                
            assert arr.num() == 2   

        ueTest "ShouldBeAbleToIterateArrays":
            let arr : TArray[int32] = makeTArray[int32]()
            arr.add 5
            arr.add 10

            var result = 0
            for n in arr:
                result = result + n

            assert result == 15
        
    suite "UStructs":
        ueTest "ShouldBeAbleToGetTheClassOfAStruct":
            let scriptStruct = getUStructByName("StructToUseAsVar")
        
            assert not scriptStruct.isNil()

        ueTest "ShouldBeAbleToGetTheFPropOfAStruct":
            let scriptStruct = getScriptStructByName("StructToUseAsVar")
        
            var propName : FString = "TestProperty"
            let prop = scriptStruct.getFPropertyByName propName 

            assert not prop.isNil()

            assert prop.getName() == propName
            assert not scriptStruct.isNil()

    suite "TMaps":
        ueTest "ShouldBeAbleToCreateAndOperateWithTMaps":
            let map : TMap[int, FString] = makeTMap[int, FString]()
            map.add makeTPair(1, FString("Hello"))
            map.add(2, FString("World"))
            map[2] = FString("World2")

            assert map.num() == 2
            assert map[1] == FString("Hello")
            assert map[2] != FString("World")
            assert map.contains(1)

#I think there is no need for adding getters and setters to ustructs, just mirroring the types should be enough. Not 100% sure though.
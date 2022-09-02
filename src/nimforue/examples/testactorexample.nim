include ../unreal/prelude
import ../typegen/[uemeta]




proc regularNimFunction() = 
    UE_Log "This is a regular nim function"
    UE_Log "This is a regular nim function"
    UE_Log "This is a regular nim function"



#bind the type
const testActorUEType = UEType(name: "ATestActor", parent: "AActor", kind: uetClass, 
                    fields: @[
                        makeFieldAsUFun("SetColorByStringInMesh",
                        @[
                            makeFieldAsUProp("color", "FString")
                        ], 
                        "ATestActor"),
                        ])
genType(testActorUEType)


proc nimFunctionCalledInTick() = UE_Log "This is a nim function called in tick"

uDelegate FTestDelegate(param:FString)

uClass ANimTestActor of ATestActor:
    (BlueprintType, Blueprintable)
    uprops(EditAnywhere, BlueprintReadWrite):
        name : FString = "Test2"
        name2 : FString = "Test2"
        name3 : FString = self.name
    uprops(BlueprintAssignable):
        myDelegate : FTestDelegate
    ufuncs(BlueprintCallable):
        proc testPrint2() = UE_Log "Hello test print"
        proc testStatic() {.static.} = 
            UE_Log "Test static"

        proc tick(deltaTime:float)  = 
            self.setColorByStringInMesh("(R=1,G=0.1,B=0.8,A=1)")
            #self.testPrint2()

        proc beginPlay() = 
            UE_Log "Que pasa another change did this carah"
            regularNimFunction()

        proc setColorInEditor() {.CallInEditor.} = 
            self.setColorByStringInMesh("(R=0,G=0.5,B=1.2,A=1)")
            testStatic()
            echo ""
        
        
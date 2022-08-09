include ../unreal/prelude
import ../typegen/[uemeta]




proc regularNimFunction() = 
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

uClass ANimTestActor of ATestActor:
    (BlueprintType, Blueprintable)
    uprops(EditAnywhere, BlueprintReadWrite):
        name : FString = "Test Default Value"

    ufuncs(BlueprintCallable):
        proc testStatic() {.static.} = 
            UE_Log "Test static"

        proc tick(deltaTime:float)  = 
            self.setColorByStringInMesh("(R=0,G=0.5,B=0.2,A=1)")
           

        proc beginPlay() = 
            UE_Log "Que pasa another change did this carah"
            regularNimFunction()

        proc setColorInEditor() {.CallInEditor.} = 
            self.setColorByStringInMesh("(R=0,G=0.5,B=0.2,A=1)")
            testStatic()
        

include ../unreal/prelude
import ../typegen/[uemeta]


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
        name : FString 


uFunctions:
    proc tick(self:ANimTestActorPtr, deltaTime:float)  = 
        self.setColorByStringInMesh("(R=1,G=0.5,B=0.2,A=1)")
        



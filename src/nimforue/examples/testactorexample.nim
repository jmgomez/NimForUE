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
    name : FString


uFunctions:
    proc tick(self:ANimTestActorPtr, deltaTime:float)  = 
        self.setColorByStringInMesh("(R=0,G=1,B=0,A=1)")
        



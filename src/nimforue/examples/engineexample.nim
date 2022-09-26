include ../unreal/prelude
import ../unreal/bindings/[slate,slatecore]



uClass AObjectEngineExample of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32
    # intProp2 : int32

  ufuncs(CallInEditor):
    proc testSlateAssignmetn() = 
      let slateObj = newUObject[UTextBlockWidgetStyle]()
      let testStr = FTextBlockStyle()
      slateObj.textBlockStyle = testStr

      UE_Log $slateObj.textBlockStyle 
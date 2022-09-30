include ../unreal/prelude
import ../unreal/bindings/[slate,slatecore]


uClass AActorSlateTest of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    
  ufuncs(CallInEditor):
    proc testHelloWorld() =
      discard
      let obj = newUObject[UButtonWidgetStyle]()
      UE_Log $obj
      # UE_Warn "testHelloWorld: " & obj.getHelloWorld()

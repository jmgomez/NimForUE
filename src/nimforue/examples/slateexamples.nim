include ../unreal/prelude
import ../unreal/bindings/[slate,slatecore]

# {.compile:".nimcache/guest/slatecore.cpp".}
when defined(macosx):
  {.compile:".nimcache/gencppbindingsmacos/@m..@snimforue@sunreal@sbindings@sexported@sslate.nim.cpp".}

uClass AActorSlateTest of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    
  ufuncs(CallInEditor):
    proc testHelloWorld() =
      # discard
      let obj = newUObject[USlateSettings]()
      obj.bExplicitCanvasChildZOrder=true
      # UE_Warn "testHelloWorld: " & obj.getHelloWorld()

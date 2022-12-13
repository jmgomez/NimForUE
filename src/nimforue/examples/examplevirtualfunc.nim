

include ../unreal/prelude

import ../codegen/gencppclass
# import ../unreal/bindings/[slate,slatecore, engine]


uClass ANimBeginPlayOverrideActor of AActor:
  (Blueprintable, BlueprintType)
  uprops(EditAnywhere):
    test : FString 
    test2 : FString = "adios"
  defaults:
    test = "s2"
  ufuncs:
    proc beginPlay() = 
      UE_Warn "Non native begin Play called once "

# {.compile: "NimHeaders/Game.h".}


# proc beginPlay(self:ANimBeginPlayOverrideActorPtr) {.overridetest.}= 
#   UE_Warn "Native Begin Play called once "

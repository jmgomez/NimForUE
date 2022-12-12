

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

macro overridetest(fn : untyped) =
  let beginPlayMeta = CppFunction(name: "BeginPlay", returnType: "void", params: @[])
  implementOverride(fn, beginPlayMeta, "ANimBeginPlayOverrideActor")



# proc beginPlay(self:ANimBeginPlayOverrideActorPtr) {.overridetest.}= 
#   UE_Warn "Native Begin Play called once "

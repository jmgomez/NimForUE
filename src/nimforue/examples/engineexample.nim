include ../unreal/prelude
import ../unreal/bindings/[engine]
# import ../unreal/bindings/exported/[slate, slatecore]
# import ../unreal/bindings/exported/nimforue
import ../codegen/[uemeta]
import std/random

uStruct FNimTableRowBase of FTableRowBase:
  (BlueprintType)
  uprop(EditAnywhere):
    testProperty: FString
    montage: UAnimMontagePtr

uStruct FNimPPSettings of FPostProcessSettings:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintType):
    testProperty: FString
 

#This is temp
# proc getCurrentActiveWorld() : UWorldPtr {.importcpp:"UReflectionHelpers::GetCurrentActiveWorld()", header:ueIncludes.}

proc getOwner2*(obj : UActorComponentPtr): AActorPtr {.importcpp: "#->GetOwner()", header: ueIncludes.}

uClass UNimActorComponentTest of UActorComponent:
  (BlueprintType, Blueprintable)
  uprops(EditAnywhere, BlueprintReadWrite):
    componentProp : FString
  
  ufuncs(BlueprintCallable):
    proc testFunc2() = 
      UE_Log "Test function 2 called"
      UE_Log $self
      # findObject[UPackage](nil, convertToLongScriptPackageName(packageName))
      # UE_Log $self.getOwner()
      let name = "BP_StaticMeshActor_C_1"
      # let actor = findObject[UObject](nil, name)
      let actor = self.getOwner2()
      UE_Log $actor
      UE_Log $actor.isNil()
      UE_Log "Ends testfunc"
      

      # let world = getCurrentActiveWorld()
      # UE_Log $world
      # UE_Log $world.isNil()




include ../unreal/prelude
import std/[strformat, options, sugar, sequtils]
import ../typegen/uemeta







uClass AActorScratchpad of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    # intProp2 : int32
  
  ufuncs(CallInEditor):
    proc generateUETypes() = 
      let moduleName = "NimForUEBindings"
      let pkg = getPackageByName(moduleName)
      if pkg.isNil(): return

      UE_Log &"Package found: {pkg}"
      let module = pkg.toUEModule()
      UE_Warn $module

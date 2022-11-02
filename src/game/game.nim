#The game entry point. 
include ../nimforue/unreal/prelude
import ../nimforue/ffinimforue



#[
  -Reduce the stuff we need to import
  -Bind the dll entry point

]#

uClass UTestGameCompilation of UObject:
    (BlueprintType, Blueprintable)
    uprop(BlueprintReadWrite):
      test : FString
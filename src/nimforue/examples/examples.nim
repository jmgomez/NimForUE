# import testactorexample
# import actorexample
# import structexample
# import objectexample

# import examplescratchpad

import examplescodegen
# import examplecoreuobject
# import engineexample
# import editorexample
# import slateexamples
#import nimconfexample
#import structexampleissue
# import examplevirtualfunc


# import ueborrowexample

# import vminteroppocexample
include ../unreal/prelude

uClass ATestExample of AActor:
  (Reinstance)
  uprops(EditAnywhere, BlueprintReadWrite, Category=CodegenInspect):
    testProp : FString = "hola"
    inspectName : FString = "EnhancedInputSubsystemInterface"
    otra : int
    otra2 : int

  ufunctions:
    proc testFun() : FString = "whatever"

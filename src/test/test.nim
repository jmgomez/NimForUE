import ../nimforue/ffinimforue 
import unittest
import ../nimforue/unreal/unreal
# import ../nimforue/unreal/launch/launch


{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
//#include "Definitions.NimForUEBindings.h"

#define WITH_EDITOR 0
#define WITH_ENGINE 0

#define UE_EDITOR 0
#define IS_PROGRAM 1
#define IS_MONOLITHIC 0
#include "Core.h"

//#include "Misc/QueuedThreadPool.h"
#include "../Private/Misc/QueuedThreadPoolWrapper.cpp"

//#include "Runtime/Launch/Public/RequiredProgramMainCPPInclude.h"
#include "../Private/LaunchEngineLoop.cpp"

""".}

{.emit: """

//IMPLEMENT_APPLICATION(GoogleTestApp, "GoogleTestApp");
//FEngineLoop GEngineLoop;
//GEngineLoop.PreInit(ArgC, ArgV);




""".}
#Try to import a custom type

# type UBindObjectTest* {.importcpp: "UBindObjectTest", inheritable, pure, header:  "UnrealTypes/BindObjectTest.h".} = object


# proc getHelloTestStaticFunction*() : FString {.importcpp: "UBindObjectTest::GetHelloTestStaticFunction()", header: "UnrealTypes/BindObjectTest.h", noSideEffect.}


test "should check an unreal type":
    let testStr : FString = "test"
    
    check testStr == "test"

test "should be able to reference a uobject":
    echo "test"


    # let gEngineLoop = makeFEngineLoop()
    let c = newObject()

    discard newObject()

    


# test "should be able to use a static binded function":
#     let expectedResult : FString = "Hello from C++"

#     let result = getHelloTestStaticFunction()

#     check expectedResult == result


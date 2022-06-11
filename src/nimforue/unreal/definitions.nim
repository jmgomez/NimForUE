#[This file only contains definitions and headers.
Cant include modules because it's used from the modules itself. 
The file that mixes them is prelude which is not used inside the unreal directory.
]#
{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UObject/UnrealType.h"
#include "Containers/UnrealString.h"
#include "Containers/Array.h"
#include "Math/Vector.h"
#include "CoreMinimal.h"
#include "Engine/EngineTypes.h"
#include "Misc/AutomationTest.h"


#include "UFunctionCaller.h"
#include "Test/NimTestBase.h"
#include "ReflectionHelpers.h"
""".}



# We need to disable C4101 for MSVC because Unreal headers elevates the warning to an error
# using #pragma warning(error: ...)
# and Nim sometimes generates variables without referencing them, e.g. exception handling.
when defined(vcc):
    {.emit: """
#pragma warning(disable: 4101) 
""".}
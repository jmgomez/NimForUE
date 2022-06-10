import ../macros/uebind
import ../unreal/nimforue/nimforuebindings
import ../unreal/coreuobject/[uobject, unrealtype]
import ../unreal/core/containers/[unrealstring, array]
import ../unreal/core/math/[vector]
import ../unreal/core/[enginetypes]

{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
""".}

# We need to disable C4101 for MSVC because Unreal headers elevates the warning to an error
# using #pragma warning(error: ...)
# and Nim sometimes generates variables without referencing them, e.g. exception handling.
when defined(vcc):
    {.emit: """
#pragma warning(disable: 4101) 
""".}
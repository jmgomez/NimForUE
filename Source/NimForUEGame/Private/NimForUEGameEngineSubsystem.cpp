
#include "NimForUEGameEngineSubsystem.h"


/*
*  NueLoadedFrom* {.size:sizeof(uint8), exportc .} = enum
nlfPreEngine = 0, #before the engine is loaded, when the plugin code is registered.
nlfPostDefault = 1, #after all modules are loaded (so all the types exists in the reflection system) this is also hot reloads. Should attempt to emit everything, layers before and after
nlfEditor = 2 # Dont act different as loaded. Just Livecoding
nlfCommandlet = 3 #while on the commandlet. Nothing special. Dont act different as loaded 

*/


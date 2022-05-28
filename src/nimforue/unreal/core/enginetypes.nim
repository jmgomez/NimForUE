import math/vector


{.push header:"Engine/EngineTypes.h" .}


type FHitResult* {.importc, bycopy} = object
  bBlockingHit: bool

proc makeFHitResult*(): FHitResult {.importcpp:"FHitResult()", constructor.}



type 
    ETeleportType* {.importcpp, size: sizeof(uint8).} = enum
        None,
        TeleportPhysics,
        ResetPhysics

{.pop.}
include ../definitions
import math/vector


type FHitResult* {.importc, bycopy} = object
  bBlockingHit: bool

proc makeFHitResult*(): FHitResult {.importcpp:"FHitResult()", constructor.}



type 
    ETeleportType* {.importcpp, size: sizeof(uint8).} = enum
        None,
        TeleportPhysics,
        ResetPhysics

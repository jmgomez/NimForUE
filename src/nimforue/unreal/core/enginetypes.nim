include ../definitions
import math/vector
import ../coreuobject/[uobject]

type 
  AActor*  = object of UObject
  AActorPtr* = ptr AActor
  UActorComponent* {.importcpp, inheritable, pure .} = object of UObject
  UActorComponentPtr* = ptr UActorComponent
  FHitResult* {.importc, bycopy} = object
    bBlockingHit: bool


proc makeFHitResult*(): FHitResult {.importcpp:"FHitResult()", constructor.}



type 
    ETeleportType* {.importcpp, size: sizeof(uint8).} = enum
        None,
        TeleportPhysics,
        ResetPhysic
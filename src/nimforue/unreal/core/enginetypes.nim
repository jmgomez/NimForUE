include ../definitions
import math/vector
import ../coreuobject/[uobject]

type 
  AActor*  = object of UObject
  AActorPtr* = ptr AActor
  AInfo* = object of AActor
  AInfoPtr* = ptr AInfo
  AGameSession* = object of AInfo
  AGameSessionPtr* = ptr AGameSession

  UActorComponent* {.importcpp, inheritable, pure .} = object of UObject
  UActorComponentPtr* = ptr UActorComponent
  USceneComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  USceneComponentPtr* = ptr USceneComponent
  UPrimitiveComponent* {.importcpp, inheritable, pure .} = object of USceneComponent
  UPrimitiveComponentPtr* = ptr UPrimitiveComponent
  UShapeComponent* {.importcpp, inheritable, pure .} = object of UPrimitiveComponent
  UShapeComponentPtr* = ptr UShapeComponent

  UBlueprintFunctionLibrary* {.importcpp, inheritable, pure .} = object of UObject
  UBlueprintGeneratedClass* {.importcpp, inheritable, pure .} = object of UClass
  UBlueprintGeneratedClassPtr* = ptr UBlueprintGeneratedClass
  UAnimBlueprintGeneratedClass* {.importcpp, inheritable, pure .} = object of UBlueprintGeneratedClass
  UAnimBlueprintGeneratedClassPtr* = ptr UAnimBlueprintGeneratedClass

  FHitResult* {.importc, bycopy} = object
    bBlockingHit: bool

  FGuid* {. importcpp .} = object

proc makeFHitResult*(): FHitResult {.importcpp:"FHitResult()", constructor.}





# type 
#     ETeleportType* {.importcpp, size: sizeof(uint8).} = enum
#         None,
#         TeleportPhysics,
#         ResetPhysic
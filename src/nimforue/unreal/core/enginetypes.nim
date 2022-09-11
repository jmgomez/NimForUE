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

  UBlueprint* {.importcpp, inheritable, pure .} = object of UObject
  UBlueprintPtr* = ptr UBlueprint

  UBlueprintFunctionLibrary* {.importcpp, inheritable, pure .} = object of UObject
  UBlueprintGeneratedClass* {.importcpp, inheritable, pure .} = object of UClass
  UBlueprintGeneratedClassPtr* = ptr UBlueprintGeneratedClass
  UAnimBlueprintGeneratedClass* {.importcpp, inheritable, pure .} = object of UBlueprintGeneratedClass
  UAnimBlueprintGeneratedClassPtr* = ptr UAnimBlueprintGeneratedClass


  UTexture* {.importcpp, inheritable, pure .} = object of UObject
  UTexturePtr* = ptr UTexture
  UTextureRenderTarget2D* {.importcpp, inheritable, pure .} = object of UTexture
  UTextureRenderTarget2DPtr* = ptr UTextureRenderTarget2D

  UAsyncActionLoadPrimaryAssetBase* {.importcpp, inheritable, pure .} = object of UObject

  ASceneCapture* {.importcpp, inheritable, pure .} = object of AActor
  ASceneCapturePtr* = ptr ASceneCapture

  UDataAsset* {.importcpp, inheritable, pure .} = object of UObject
  UDataAssetPtr* = ptr UDataAsset

  AVolume* {.importcpp, inheritable, pure .} = object of UObject
  AVolumePtr* = ptr AVolume

  UGameInstanceSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  UGameInstanceSubsystemPtr* = ptr UGameInstanceSubsystem
  UWorldSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  UWorldSubsystemPtr* = ptr UWorldSubsystem
  UTickableWorldSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  UTickableWorldSubsystemPtr* = ptr UTickableWorldSubsystem



  UVectorField* {.importcpp, inheritable, pure .} = object of UObject
  UVectorFieldPtr* = ptr UVectorField


  FHitResult* {.importc, bycopy} = object
    bBlockingHit: bool

  FGuid* {. importcpp .} = object

proc makeFHitResult*(): FHitResult {.importcpp:"FHitResult()", constructor.}





# type 
#     ETeleportType* {.importcpp, size: sizeof(uint8).} = enum
#         None,
#         TeleportPhysics,
#         ResetPhysic
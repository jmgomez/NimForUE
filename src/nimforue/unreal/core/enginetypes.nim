include ../definitions
import math/vector
import ../coreuobject/[uobject, coreuobject]
import ../nimforue/nimforuebindings

type 
  UEngine* {.importcpp, importcpp, pure .} = object of UObject
  UEnginePtr* {.importcpp, pure .} = ptr UEngine

  USubsystem* {.importcpp, pure .} = object of UObject
  USubsystemPtr* {.importcpp, pure .} = ptr USubsystem

  UDynamicSubsystem* {.importcpp, pure .} = object of USubsystem
  UDynamicSubsystemPtr* {.importcpp, pure .} = ptr UDynamicSubsystem

  UEngineSubsystem* {.importcpp, pure .} = object of UDynamicSubsystem
  UEngineSubsystemPtr* {.importcpp, pure .} = ptr UEngineSubsystem

  FTickFunction* {.importcpp, pure, inheritable .} = object
    bCanEverTick*, bStartWithTickEnabled*: bool

  FActorTickFunction* {.importcpp, pure, inheritable.} = object of FTickFunction


  AActor* {.importcpp, inheritable, pure .} = object of UObject
    primaryActorTick* {.importcpp:"PrimaryActorTick"}: FActorTickFunction

  AActorPtr* = ptr AActor
  AController* {.importcpp, inheritable, pure .}= object of AActor
  AControllerPtr* = ptr AController
  APlayerController* {.importcpp, inheritable, pure .}= object of AController
  APlayerControllerPtr* = ptr APlayerController
  # APawn* {.importcpp, inheritable, pure .} = object of AActor
  # APawnPtr* = ptr APawn

  AInfo* {.importcpp, inheritable, pure .}= object of AActor
  AInfoPtr* = ptr AInfo
  AGameSession* {.importcpp, inheritable, pure .}= object of AInfo
  AGameSessionPtr* = ptr AGameSession

  AWorldSettings* {.importcpp, inheritable, pure .}= object of AInfo
  AWorldSettingsPtr* = ptr AWorldSettings

  UActorComponent* {.importcpp, inheritable, pure .} = object of UObject
  UActorComponentPtr* = ptr UActorComponent
  USceneComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  USceneComponentPtr* = ptr USceneComponent
  # UPrimitiveComponent* {.importcpp, inheritable, pure .} = object of USceneComponent
  # UPrimitiveComponentPtr* = ptr UPrimitiveComponent
  # UShapeComponent* {.importcpp, inheritable, pure .} = object of UPrimitiveComponent
  # UShapeComponentPtr* = ptr UShapeComponent
  # UChildActorComponent* {.importcpp, inheritable, pure .} = object of USceneComponent
  # UChildActorComponentPtr* = ptr UChildActorComponent
  UBlueprint* {.importcpp, inheritable, pure .} = object of UObject
  UBlueprintPtr* = ptr UBlueprint


  # UBlueprintFunctionLibrary* {.importcpp, inheritable, pure .} = object of UObject
  UBlueprintGeneratedClass* {.importcpp, inheritable, pure .} = object of UClass
  UBlueprintGeneratedClassPtr* = ptr UBlueprintGeneratedClass
  UAnimBlueprintGeneratedClass* {.importcpp, inheritable, pure .} = object of UBlueprintGeneratedClass
  UAnimBlueprintGeneratedClassPtr* = ptr UAnimBlueprintGeneratedClass

  
  # UTexture* {.importcpp, inheritable, pure .} = object of UObject
  # UTexturePtr* = ptr UTexture
  # UTextureRenderTarget2D* {.importcpp, inheritable, pure .} = object of UTexture
  # UTextureRenderTarget2DPtr* = ptr UTextureRenderTarget2D

  UAsyncActionLoadPrimaryAssetBase* {.importcpp, inheritable, pure .} = object of UObject

  ASceneCapture* {.importcpp, inheritable, pure .} = object of AActor
  ASceneCapturePtr* = ptr ASceneCapture

  # UDataAsset* {.importcpp, inheritable, pure .} = object of UObject
  # UDataAssetPtr* = ptr UDataAsset

  AVolume* {.importcpp, inheritable, pure .} = object of UObject
  AVolumePtr* = ptr AVolume
  APhysicsVolume* {.importcpp, inheritable, pure .} = object of AVolume
  APhysicsVolumePtr* = ptr APhysicsVolume
  
  UAudioComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  UAudioComponentPtr* = ptr UAudioComponent
  # UGameInstanceSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  # UGameInstanceSubsystemPtr* = ptr UGameInstanceSubsystem
  UWorldSubsystem* {.importcpp, inheritable, pure .} = object of USubsystem
  UWorldSubsystemPtr* = ptr UWorldSubsystem
  UTickableWorldSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  UTickableWorldSubsystemPtr* = ptr UTickableWorldSubsystem

  # UAudioLinkSettingsAbstract* {.importcpp, inheritable, pure .} = object of UObject
  # UAudioLinkSettingsAbstractPtr* = ptr UAudioLinkSettingsAbstract

  UVectorField* {.importcpp, inheritable, pure .} = object of UObject
  UVectorFieldPtr* = ptr UVectorField



  FHitResult* {.importc, bycopy} = object
    bBlockingHit: bool

  # UDeveloperSettings* {.importcpp .} = object of UObject
  UEdGraphNode* {.importcpp .} = object of UObject

  UStreamableRenderAsset* {.importcpp, inheritable, pure .} = object of UObject
  UStreamableRenderAssetPtr* = ptr UStreamableRenderAsset

  UHandlerComponentFactory* {.importcpp .} = object of UObject
  UHandlerComponentFactoryPtr* = ptr UHandlerComponentFactory
  #Is not the type above part of CoreUObject? 
  UPackageMap* {.importcpp .} = object of UObject
  UPackageMapPtr* = ptr UPackageMap
  #Probably these are forward decls?
  UMeshDescriptionBaseBulkData* {.importcpp .} = object of UObject
  UMeshDescriptionBaseBulkDataPtr* = ptr UMeshDescriptionBaseBulkData
  ULandscapeGrassType* {.importcpp .} = object of UObject
  ULandscapeGrassTypePtr* = ptr ULandscapeGrassType

  UBlendProfile* {.importcpp, pure .} = object of UObject
  UBlendProfilePtr* = ptr UBlendProfile


  TFieldPath* {.importcpp .} = object



  UPlayer* {.importcpp, pure, inheritable .} = object of UObject
  UPlayerPtr* = ptr UPlayer
  ULocalPlayer* {.importcpp, pure, inheritable .} = object of UPlayer
  ULocalPlayerPtr* = ptr ULocalPlayer

  #This is just part of the non blueprint exposed api
  ULayer* {.importcpp, pure, inheritable .} = object of UObject
  ULayerPtr* = ptr ULayer


  FPlatformUserId* {.importc .} = object
  FInputDeviceId* {.importc .} = object
  FTopLevelAssetPath* {.importc .} = object
  FARFilter* {.importc .} = object


  EInputDeviceConnectionState* {.importc .} = enum
    Connected, Disconnected, Unknown  
  # UNetObjectPrioritizerConfig* {.importcpp .} = object of UObject
  # UReplicationBridge* {.importcpp .} = object of UObject
  # UNetBlobHandler* {.importcpp .} = object of UObject
  # UPlatformSettings* {.importcpp .} = object of UObject
    
    

#   IBlendableInterface* {.importcpp .} = object
#   IAnimationDataController* {.importcpp .} = object
#[
  UActorComponent", "APawn",
            "UPrimitiveComponent", "UPhysicalMaterial", "AController",
            "UStreamableRenderAsset", "UStaticMeshComponent", "UStaticMesh",
            "USkeletalMeshComponent", "UTexture2D", "FKey", "UInputComponent",
            "ALevelScriptActor", "FFastArraySerializer", "UPhysicalMaterialMask",
            "UHLODLayer"

]#
  # UMeshComponent* {.importcpp, inheritable, pure .} = object of UPrimitiveComponent
  # UMeshComponentPtr* = ptr UMeshComponent
  # UStaticMeshComponent* {.importcpp, inheritable, pure .} = object of UMeshComponent
  # UStaticMeshComponentPtr* = ptr UStaticMeshComponent
  # UStaticMesh* {.importcpp, inheritable, pure .} = object of UStreamableRenderAsset
  # UStaticMeshPtr* = ptr UStaticMesh
  # USkinnedMeshComponent* {.importcpp, inheritable, pure .} = object of UMeshComponent
  # USkinnedMeshComponentPtr* = ptr USkinnedMeshComponent
  # USkeletalMeshComponent* {.importcpp, inheritable, pure .} = object of USkinnedMeshComponent
  # USkeletalMeshComponentPtr* = ptr USkeletalMeshComponent
  # USkeletalMesh* {.importcpp, inheritable, pure .} = object of UStreamableRenderAsset
  # USkeletalMeshPtr* = ptr USkeletalMesh
  # UTexture2D* {.importcpp, inheritable, pure .} = object of UTexture
  # UTexture2DPtr* = ptr UTexture2D
  # UInputComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  # UInputComponentPtr* = ptr UInputComponent
  # ALevelScriptActor* {.importcpp, inheritable, pure .} = object of AActor
  # ALevelScriptActorPtr* = ptr ALevelScriptActor
  # UPhysicalMaterial* {.importcpp, inheritable, pure .} = object of UObject
  # UPhysicalMaterialPtr* = ptr UPhysicalMaterial
  # UPhysicalMaterialMask* {.importcpp, inheritable, pure .} = object of UObject
  # UPhysicalMaterialMaskPtr* = ptr UPhysicalMaterialMask
  # UHLODLayer* {.importcpp, inheritable, pure .} = object of UObject
  # UHLODLayerPtr* = ptr UHLODLayer
  # USoundBase* {.importcpp, inheritable, pure .} = object of UObject
  # USoundBasePtr* = ptr USoundBase
  # UMaterialInterface* {.importcpp, inheritable, pure .} = object of UObject
  # UMaterialInterfacePtr* = ptr UMaterialInterface
  # USubsurfaceProfile* {.importcpp, inheritable, pure .} = object of UObject
  # USubsurfaceProfilePtr* = ptr USubsurfaceProfile
  # UParticleSystem* {.importcpp, inheritable, pure .} = object of UObject
  # UParticleSystemPtr* = ptr UParticleSystem
  # UBillboardComponent* {.importcpp, inheritable, pure .} = object of UPrimitiveComponent
  # UBillboardComponentPtr* = ptr UBillboardComponent
  # UDamageType* {.importcpp, inheritable, pure .} = object of UObject
  # UDamageTypePtr* = ptr UDamageType
  # UDecalComponent* {.importcpp, inheritable, pure .} = object of USceneComponent
  # UDecalComponentPtr* = ptr UDecalComponent
  # UWorld* {.importcpp, inheritable, pure .} = object of UObject
  # UWorldPtr* = ptr UWorld
  # UCanvas* {.importcpp, inheritable, pure .} = object of UObject
  # UCanvasPtr* = ptr UCanvas
  # UDataLayer* {.importcpp, inheritable, pure .} = object of UObject
  # UDataLayerPtr* = ptr UDataLayer
  

proc makeFHitResult*(): FHitResult {.importcpp:"FHitResult()", constructor.}



# type 
#     ETeleportType* {.importcpp, size: sizeof(uint8).} = enum
#         None,
#         TeleportPhysics,
#         ResetPhysic


type
  # FSlateBrush*  = object
    
  FSlateBrush* {.importcpp, header:"Styling/SlateBrush.h".} = object
    # bIsDynamicallyLoaded*: uint8
    # imageType*: ESlateBrushImageType
    # mirroring*: ESlateBrushMirrorType
    # tiling*: ESlateBrushTileType
    # drawAs*: ESlateBrushDrawType
    # uVRegion*: FBox2f
    # resourceName*: FName
    # resourceObject*: TObjectPtr[UObject]
    # outlineSettings*: FSlateBrushOutlineSettings
    # tintColor*: FSlateColor
    # margin*: FMargin
    ImageSize*: FVector2D



#	void ForceGarbageCollection(bool bFullPurge = false);
proc forceGarbageCollection*(engine:UEnginePtr, bFullPurge: bool = false) {.importcpp: "#->ForceGarbageCollection(#)".}




proc `rootComponent=`*(obj : AActorPtr;
                       val : TObjectPtr[USceneComponent]) =
  var value : TObjectPtr[USceneComponent] = val
  let prop  = getClassByName("Actor").getFPropertyByName(
      "RootComponent")
  setPropertyValuePtr[TObjectPtr[USceneComponent]](prop, obj, value.addr)


proc `rootComponent`*(obj : AActorPtr): TObjectPtr[USceneComponent] {.
    exportcpp.} =
  let prop  = getClassByName("Actor").getFPropertyByName(
      "RootComponent")
  getPropertyValuePtr[TObjectPtr[USceneComponent]](prop, obj)[]




type EGetWorldErrorMode* {.importcpp, size: sizeof(uint8).} = enum
  ReturnNull,
  LogAndReturnNull,
  Assert
  
##ENGINE
#UWorld* UEngine::GetWorldFromContextObject(const UObject* Object, EGetWorldErrorMode ErrorMode) const
proc getEngine*() : UEnginePtr  {.importcpp: "(GEngine)".} 

proc getWorldFromContextObject*(engine:UEnginePtr, obj:UObjectPtr, errorMode:EGetWorldErrorMode) : UWorldPtr  {.importcpp: "#->GetWorldFromContextObject(#, #)".}
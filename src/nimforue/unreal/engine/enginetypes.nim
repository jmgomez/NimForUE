include ../definitions
import std/[strformat]
import ../core/math/vector
import ../coreuobject/[uobject, coreuobject, nametypes, tsoftobjectptr, scriptdelegates]
import ../core/[delegates, templates, net]
import ../core/containers/[unrealstring, array, set]

type 
  UEngine* {.importcpp, importcpp, pure .} = object of UObject
    gameViewport* {.importcpp:"GameViewport"}: UGameViewportClientPtr

  UEnginePtr* {.importcpp, pure .} = ptr UEngine
  # UGameEngine* {.importcpp, pure .} = object of UEngine
  # UGameEnginePtr* {.importcpp, pure .} = ptr UGameEngine

  USubsystem* {.importcpp, pure .} = object of UObject
  USubsystemPtr* {.importcpp, pure .} = ptr USubsystem

  UDynamicSubsystem* {.importcpp, pure .} = object of USubsystem
  UDynamicSubsystemPtr* {.importcpp, pure .} = ptr UDynamicSubsystem

  UEngineSubsystem* {.importcpp, pure .} = object of UDynamicSubsystem
  UEngineSubsystemPtr* {.importcpp, pure .} = ptr UEngineSubsystem
  FSubsystemCollectionBase* {.importcpp.} = object
    

  FTickFunction* {.importcpp, pure, inheritable .} = object
    bCanEverTick*, bStartWithTickEnabled*: bool
    tickInterval* {.importcpp:"TickInterval"}: float32

  FActorTickFunction* {.importcpp, pure, inheritable.} = object of FTickFunction
  FActorComponentTickFunction* {.importcpp, pure, inheritable.} = object of FTickFunction

  # UInputComponent* {.importcpp, inheritable, pure.} = object of UActorComponent
  # UInputComponentPtr* = ptr UInputComponent

  AActor* {.importcpp, inheritable, pure .} = object of UObject
    primaryActorTick* {.importcpp:"PrimaryActorTick"}: FActorTickFunction
    bAllowTickBeforeBeginPlay* {.importcpp.}: bool
    bOnlyRelevantToOwner* {.importcpp: "bOnlyRelevantToOwner".}: bool
    bAlwaysRelevant* {.importcpp: "bAlwaysRelevant".}: bool
    bHidden {.importcpp: "bHidden".}: bool
    bNetUseOwnerRelevancy* {.importcpp: "bNetUseOwnerRelevancy".}: bool
    bAutoDestroyWhenFinished {.importcpp: "bAutoDestroyWhenFinished".}: bool
    bCanBeDamaged {.importcpp: "bCanBeDamaged".}: bool
    bFindCameraComponentWhenViewTarget* {.
        importcpp: "bFindCameraComponentWhenViewTarget".}: bool
    bGenerateOverlapEventsDuringLevelStreaming*
        {.importcpp: "bGenerateOverlapEventsDuringLevelStreaming".}: bool
    bEnableAutoLODGeneration* {.importcpp: "bEnableAutoLODGeneration".}: bool
    bReplicates {.importcpp: "bReplicates".}: bool
    bReplicateUsingRegisteredSubObjectList
        {.importcpp: "bReplicateUsingRegisteredSubObjectList".}: bool
    initialLifeSpan* {.importcpp: "InitialLifeSpan".}: float32
    customTimeDilation* {.importcpp: "CustomTimeDilation".}: float32
    # netDormancy* {.importcpp: "NetDormancy".}: ENetDormancy
    # spawnCollisionHandlingMethod* {.importcpp: "SpawnCollisionHandlingMethod".}: ESpawnActorCollisionHandlingMethod
    netCullDistanceSquared* {.importcpp: "NetCullDistanceSquared".}: float32
    netUpdateFrequency* {.importcpp: "NetUpdateFrequency".}: float32
    minNetUpdateFrequency* {.importcpp: "MinNetUpdateFrequency".}: float32
    netPriority* {.importcpp: "NetPriority".}: float32
    instigator {.importcpp: "Instigator".}: APawnPtr
    pivotOffset {.importcpp: "PivotOffset".}: FVector
    actorGuid {.importcpp: "ActorGuid".}: FGuid
    actorInstanceGuid {.importcpp: "ActorInstanceGuid".}: FGuid
    contentBundleGuid {.importcpp: "ContentBundleGuid".}: FGuid
    spriteScale* {.importcpp: "SpriteScale".}: float32
    tags* {.importcpp: "Tags".}: TArray[FName]
    inputComponent* {.importcpp: "InputComponent".}: UObjectPtr

  AActorPtr* = ptr AActor
  AController* {.importcpp, inheritable, pure .}= object of AActor
  AControllerPtr* = ptr AController
  APlayerController* {.importcpp, inheritable, pure .}= object of AController
  APlayerControllerPtr* = ptr APlayerController
  APawn* {.importcpp, inheritable, pure .} = object of AActor
  APawnPtr* = ptr APawn
  # ACharacter* {.importcpp, inheritable, pure .} = object of APawn
  # ACharacterPtr* = ptr APawn

  AInfo* {.importcpp, inheritable, pure .}= object of AActor
  AInfoPtr* = ptr AInfo
  AGameModeBase* {.importcpp, inheritable, pure .}= object of AInfo
  AGameModeBasePtr* = ptr AGameModeBase
  AGameMode* {.importcpp, inheritable, pure .}= object of AGameModeBase
  AGameModePtr* = ptr AGameMode
  # AGameSession* {.importcpp, inheritable, pure .}= object of AInfo
  # AGameSessionPtr* = ptr AGameSession


  AWorldSettings* {.importcpp, inheritable, pure .}= object of AInfo
  AWorldSettingsPtr* = ptr AWorldSettings

  UActorComponent* {.importcpp, inheritable, pure .} = object of UObject
    primaryComponentTick* {.importcpp:"PrimaryComponentTick"}: FActorComponentTickFunction
    componentTags* {.importcpp: "ComponentTags".}: TArray[FName]
    bReplicateUsingRegisteredSubObjectList
        {.importcpp: "bReplicateUsingRegisteredSubObjectList".}: bool
    bReplicates {.importcpp: "bReplicates".}: bool
    bAutoActivate* {.importcpp: "bAutoActivate".}: bool
    bIsEditorOnly* {.importcpp: "bIsEditorOnly".}: bool
    
  ELevelTick* {.importcpp.}  = enum
    LEVELTICK_TimeOnly = 0,
    LEVELTICK_ViewportsOnly = 1,
    LEVELTICK_All = 2,
    LEVELTICK_PauseTick = 3,


  UActorComponentPtr* = ptr UActorComponent
  USceneComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  USceneComponentPtr* = ptr USceneComponent
  # FComponentBeginOverlapSignature* {.importcpp.} = object
  UPrimitiveComponent* {.importcpp, inheritable, pure.} = object of USceneComponent
    minDrawDistance* {.importcpp: "MinDrawDistance".}: float32
    lDMaxDrawDistance* {.importcpp: "LDMaxDrawDistance".}: float32
    cachedMaxDrawDistance* {.importcpp: "CachedMaxDrawDistance".}: float32
    # indirectLightingCacheQuality* {.importcpp: "IndirectLightingCacheQuality".}: EIndirectLightingCacheQuality
    # lightmapType* {.importcpp: "LightmapType".}: ELightmapType
    # hLODBatchingPolicy* {.importcpp: "HLODBatchingPolicy".}: EHLODBatchingPolicy
    bEnableAutoLODGeneration* {.importcpp: "bEnableAutoLODGeneration".}: bool
    bNeverDistanceCull* {.importcpp: "bNeverDistanceCull".}: bool
    bAlwaysCreatePhysicsState* {.importcpp: "bAlwaysCreatePhysicsState".}: bool
    bGenerateOverlapEvents {.importcpp: "bGenerateOverlapEvents".}: bool
    bMultiBodyOverlap* {.importcpp: "bMultiBodyOverlap".}: bool
    bTraceComplexOnMove* {.importcpp: "bTraceComplexOnMove".}: bool
    bReturnMaterialOnMove* {.importcpp: "bReturnMaterialOnMove".}: bool
    bAllowCullDistanceVolume* {.importcpp: "bAllowCullDistanceVolume".}: bool
    bVisibleInReflectionCaptures* {.importcpp: "bVisibleInReflectionCaptures".}: bool
    bVisibleInRealTimeSkyCaptures* {.importcpp: "bVisibleInRealTimeSkyCaptures".}: bool
    bVisibleInRayTracing* {.importcpp: "bVisibleInRayTracing".}: bool
    bRenderInMainPass* {.importcpp: "bRenderInMainPass".}: bool
    bRenderInDepthPass* {.importcpp: "bRenderInDepthPass".}: bool
    bReceivesDecals* {.importcpp: "bReceivesDecals".}: bool
    bHoldout* {.importcpp: "bHoldout".}: bool
    bOwnerNoSee* {.importcpp: "bOwnerNoSee".}: bool
    bOnlyOwnerSee* {.importcpp: "bOnlyOwnerSee".}: bool
    bTreatAsBackgroundForOcclusion* {.importcpp: "bTreatAsBackgroundForOcclusion".}: bool
    bUseAsOccluder* {.importcpp: "bUseAsOccluder".}: bool
    bForceMipStreaming* {.importcpp: "bForceMipStreaming".}: bool
    castShadow* {.importcpp: "CastShadow".}: uint8
    bEmissiveLightSource* {.importcpp: "bEmissiveLightSource".}: bool
    bAffectDynamicIndirectLighting* {.importcpp: "bAffectDynamicIndirectLighting".}: bool
    bAffectIndirectLightingWhileHidden* {.
        importcpp: "bAffectIndirectLightingWhileHidden".}: bool
    bAffectDistanceFieldLighting* {.importcpp: "bAffectDistanceFieldLighting".}: bool
    bCastDynamicShadow* {.importcpp: "bCastDynamicShadow".}: bool
    bCastStaticShadow* {.importcpp: "bCastStaticShadow".}: bool
    # shadowCacheInvalidationBehavior* {.importcpp: "ShadowCacheInvalidationBehavior".}: EShadowCacheInvalidationBehavior
    bCastVolumetricTranslucentShadow* {.importcpp: "bCastVolumetricTranslucentShadow".}: bool
    bCastContactShadow* {.importcpp: "bCastContactShadow".}: bool
    bSelfShadowOnly* {.importcpp: "bSelfShadowOnly".}: bool
    bCastFarShadow* {.importcpp: "bCastFarShadow".}: bool
    bCastInsetShadow* {.importcpp: "bCastInsetShadow".}: bool
    bCastCinematicShadow* {.importcpp: "bCastCinematicShadow".}: bool
    bCastHiddenShadow* {.importcpp: "bCastHiddenShadow".}: bool
    bCastShadowAsTwoSided* {.importcpp: "bCastShadowAsTwoSided".}: bool
    bLightAttachmentsAsGroup* {.importcpp: "bLightAttachmentsAsGroup".}: bool
    bExcludeFromLightAttachmentGroup* {.importcpp: "bExcludeFromLightAttachmentGroup".}: bool
    bReceiveMobileCSMShadows* {.importcpp: "bReceiveMobileCSMShadows".}: bool
    bSingleSampleShadowFromStationaryLights*
        {.importcpp: "bSingleSampleShadowFromStationaryLights".}: bool
    bIgnoreRadialImpulse* {.importcpp: "bIgnoreRadialImpulse".}: bool
    bIgnoreRadialForce* {.importcpp: "bIgnoreRadialForce".}: bool
    bApplyImpulseOnDamage* {.importcpp: "bApplyImpulseOnDamage".}: bool
    bReplicatePhysicsToAutonomousProxy* {.
        importcpp: "bReplicatePhysicsToAutonomousProxy".}: bool
    bRenderCustomDepth* {.importcpp: "bRenderCustomDepth".}: bool
    bVisibleInSceneCaptureOnly* {.importcpp: "bVisibleInSceneCaptureOnly".}: bool
    bHiddenInSceneCapture* {.importcpp: "bHiddenInSceneCapture".}: bool
    bStaticWhenNotMoveable {.importcpp: "bStaticWhenNotMoveable".}: bool
    # canCharacterStepUpOn* {.importcpp: "CanCharacterStepUpOn".}: ECanBeCharacterBase
    # lightingChannels* {.importcpp: "LightingChannels".}: FLightingChannels
    rayTracingGroupId* {.importcpp: "RayTracingGroupId".}: int32
    customDepthStencilValue* {.importcpp: "CustomDepthStencilValue".}: int32
    translucencySortPriority* {.importcpp: "TranslucencySortPriority".}: int32
    translucencySortDistanceOffset* {.importcpp: "TranslucencySortDistanceOffset".}: float32
    # runtimeVirtualTextures* {.importcpp: "RuntimeVirtualTextures".}: TArray[
    #     URuntimeVirtualTexturePtr]
    # virtualTextureRenderPassType* {.importcpp: "VirtualTextureRenderPassType".}: ERuntimeVirtualTextureMainPassType
    # bodyInstance* {.importcpp: "BodyInstance".}: FBodyInstance
    # onComponentHit* {.importcpp: "OnComponentHit".}: FComponentHitSignature
    # onComponentBeginOverlap* {.importcpp: "OnComponentBeginOverlap".}: FComponentBeginOverlapSignature
    # onComponentEndOverlap* {.importcpp: "OnComponentEndOverlap".}: FComponentEndOverlapSignature
    # onComponentWake* {.importcpp: "OnComponentWake".}: FComponentWakeSignature
    # onComponentSleep* {.importcpp: "OnComponentSleep".}: FComponentSleepSignature
    # onComponentPhysicsStateChanged* {.importcpp: "OnComponentPhysicsStateChanged".}: FComponentPhysicsStateChanged
    # onBeginCursorOver* {.importcpp: "OnBeginCursorOver".}: FComponentBeginCursorOverSignature
    # onEndCursorOver* {.importcpp: "OnEndCursorOver".}: FComponentEndCursorOverSignature
    # onClicked* {.importcpp: "OnClicked".}: FComponentOnClickedSignature
    # onReleased* {.importcpp: "OnReleased".}: FComponentOnReleasedSignature
    # onInputTouchBegin* {.importcpp: "OnInputTouchBegin".}: FComponentOnInputTouchBeginSignature
    # onInputTouchEnd* {.importcpp: "OnInputTouchEnd".}: FComponentOnInputTouchEndSignature
    # onInputTouchEnter* {.importcpp: "OnInputTouchEnter".}: FComponentBeginTouchOverSignature
    # onInputTouchLeave* {.importcpp: "OnInputTouchLeave".}: FComponentEndTouchOverSignature
    # rayTracingGroupCullingPriority* {.importcpp: "RayTracingGroupCullingPriority".}: ERayTracingGroupCullingPriority
    # customDepthStencilWriteMask* {.importcpp: "CustomDepthStencilWriteMask".}: ERendererStencilMask

  UPrimitiveComponentPtr* = ptr UPrimitiveComponent
  # UShapeComponent* {.importcpp, inheritable, pure .} = object of UPrimitiveComponent
  # UShapeComponentPtr* = ptr UShapeComponent
  # UChildActorComponent* {.importcpp, inheritable, pure .} = object of USceneComponent
  # UChildActorComponentPtr* = ptr UChildActorComponent
  UBlueprintCore* {.importcpp, inheritable, pure .} = object of UObject
    generatedClass* {.importcpp:"GeneratedClass"}: TSubclassOf[UBlueprintGeneratedClassPtr]
  UBlueprintCorePtr* = ptr UBlueprintCore
  UBlueprint* {.importcpp, inheritable, pure .} = object of UBlueprintCore
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
  #Jumps one level in the Class hierarchy as this Class is in inaccessible private folder now and it's the base class of multiple codegened classes.
  UAsyncActionLoadPrimaryAssetBase* {.importcpp:"UBlueprintAsyncActionBase", inheritable, pure .} = object of UObject
  UAsyncActionLoadPrimaryAssetBasePtr* = ptr UAsyncActionLoadPrimaryAssetBase

  ASceneCapture* {.importcpp, inheritable, pure .} = object of AActor
  ASceneCapturePtr* = ptr ASceneCapture



  # UAssetManager* {.importcpp, inheritable, pure .} = object of UObject
  # UAssetManagerPtr* = ptr UAssetManager
  # UDataAsset* {.importcpp, inheritable, pure .} = object of UObject
  # UDataAssetPtr* = ptr UDataAsset

  AVolume* {.importcpp, inheritable, pure .} = object of AActor
  AVolumePtr* = ptr AVolume
  # APhysicsVolume* {.importcpp, inheritable, pure .} = object of AVolume
  # APhysicsVolumePtr* = ptr APhysicsVolume
  
  # UAudioComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  # UAudioComponentPtr* = ptr UAudioComponent
  # UGameInstanceSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  # UGameInstanceSubsystemPtr* = ptr UGameInstanceSubsystem
  UWorldSubsystem* {.importcpp, inheritable, pure .} = object of USubsystem
  UWorldSubsystemPtr* = ptr UWorldSubsystem
  UTickableWorldSubsystem* {.importcpp, inheritable, pure .} = object of UObject
  UTickableWorldSubsystemPtr* = ptr UTickableWorldSubsystem

  # UAudioLinkSettingsAbstract* {.importcpp, inheritable, pure .} = object of UObject
  # UAudioLinkSettingsAbstractPtr* = ptr UAudioLinkSettingsAbstract

  # UVectorField* {.importcpp, inheritable, pure .} = object of UObject
  # UVectorFieldPtr* = ptr UVectorField

  FWorldContext* {.importcpp, pure .} = object
    gameViewport* {.importcpp: "GameViewport".}: UGameViewportClientPtr

  FWorldContextPtr* = ptr FWorldContext

  FHitResult* {.importcpp, pure.} = object
    faceIndex* {.importcpp: "FaceIndex".}: int32
    time* {.importcpp: "Time".}: float32
    distance* {.importcpp: "Distance".}: float32
    location* {.importcpp: "Location".}: FVector_NetQuantize
    impactPoint* {.importcpp: "ImpactPoint".}: FVector_NetQuantize
    normal* {.importcpp: "Normal".}: FVector_NetQuantizeNormal
    impactNormal* {.importcpp: "ImpactNormal".}: FVector_NetQuantizeNormal
    traceStart* {.importcpp: "TraceStart".}: FVector_NetQuantize
    traceEnd* {.importcpp: "TraceEnd".}: FVector_NetQuantize
    penetrationDepth* {.importcpp: "PenetrationDepth".}: float32
    myItem* {.importcpp: "MyItem".}: int32
    item* {.importcpp: "Item".}: int32
    elementIndex* {.importcpp: "ElementIndex".}: uint8
    bBlockingHit* {.importcpp: "bBlockingHit".}: bool
    bStartPenetrating* {.importcpp: "bStartPenetrating".}: bool
    physMaterial* {.importcpp: "PhysMaterial".}: TWeakObjectPtr[UPhysicalMaterial]
    # hitObjectHandle* {.importcpp: "HitObjectHandle".}: FActorInstanceHandle 
    component* {.importcpp: "Component".}: TWeakObjectPtr[UPrimitiveComponent]
    boneName* {.importcpp: "BoneName".}: FName
    myBoneName* {.importcpp: "MyBoneName".}: FName

  FLifetimeProperty* {.importcpp, pure.} = object
    repIndex* {.importcpp: "RepIndex".}: uint16
    condition* {.importcpp: "Condition".}: ELifetimeCondition
    repNotifyCondition* {.importcpp: "RepNotifyCondition".}: ELifetimeRepNotifyCondition
  FCanvas* {.importcpp, pure.} = object
  FCanvasPtr* = ptr FCanvas
  FRenderTarget* {.importcpp.} = object
  FTexture* {.importcpp, inheritable.} = object
  FTextureResource* {.importcpp.} = object of FTexture
  FGameplayTag* {.importcpp, pure.} = object
    # tagName* {.importcpp: "TagName".}: FName Field is protected look for GetTagName
  FGameplayTagContainer* {.importcpp, pure.} = object
  UDeveloperSettings* {.importcpp .} = object of UObject
  # UEdGraph* {.importcpp .} = object of UObject
  # UEdGraphPtr* = ptr UEdGraph
  # UEdGraphNode* {.importcpp .} = object of UObject
  # UEdGraphNodePtr* = ptr UEdGraphNode


  # UStreamableRenderAsset* {.importcpp, inheritable, pure .} = object of UObject
  # UStreamableRenderAssetPtr* = ptr UStreamableRenderAsset

  # UHandlerComponentFactory* {.importcpp .} = object of UObject
  # UHandlerComponentFactoryPtr* = ptr UHandlerComponentFactory
  #Is not the type above part of CoreUObject? 
  #this belogs to coreuobject
  UPackageMap* {.importcpp .} = object of UObject
  UPackageMapPtr* = ptr UPackageMap
  #Probably these are forward decls?
  # UMeshDescriptionBaseBulkData* {.importcpp .} = object of UObject
  # UMeshDescriptionBaseBulkDataPtr* = ptr UMeshDescriptionBaseBulkData
  # ULandscapeGrassType* {.importcpp .} = object of UObject
  # ULandscapeGrassTypePtr* = ptr ULandscapeGrassType

  # UBlendProfile* {.importcpp, pure .} = object of UObject
  # UBlendProfilePtr* = ptr UBlendProfile

  FLatentActionInfo* {.importcpp.} = object
    linkage* {.importcpp: "Linkage".}: int32
    uuid* {.importcpp: "UUID".}: int32
    executionFunction* {.importcpp: "ExecutionFunction".}: FName
    callbackTarget* {.importcpp: "CallbackTarget".}: UObjectPtr

  FKey* {.importcpp .} = object
  # UPlayer* {.importcpp, pure, inheritable .} = object of UObject
  # UPlayerPtr* = ptr UPlayer
  # ULocalPlayer* {.importcpp, pure, inheritable .} = object of UPlayer
  # ULocalPlayerPtr* = ptr ULocalPlayer

  #This is just part of the non blueprint exposed api
  # ULayer* {.importcpp, pure, inheritable .} = object of UObject
  # ULayerPtr* = ptr ULayer


  FPlatformUserId* {.importc .} = object
  FTopLevelAssetPath* {.importc .} = object
    packageName: FName #this props exists only in the ReflectionSystem (NoExportTypes.h). The mirror cpp type has them private. So dont use them from native Nim (there are funcitons exposed)
    assetName: FName

  FARFilter* {.importcpp .} = object
    packageNames* {.importcpp:"PackageNames".}: TArray[FName] # the filter component for package names
    packagePaths* {.importcpp:"PackagePaths".}: TArray[FString] # The filter component for package paths 
    classNames* {.importcpp:"ClassNames".}: TArray[FName] # The filter component for class names (Deprecated 5.1)
    classPaths* {.importcpp:"ClassPaths".}: TArray[FTopLevelAssetPath] # 	/** The filter component for class path names. Instances of the specified classes, but not subclasses (by default), will be included. Derived classes will be included only if bRecursiveClasses is true. */
    bRecursiveClasses* {.importcpp:"bRecursiveClasses".}: bool # Whether or not to include derived classes of those specified in ClassNames


  EInputDeviceConnectionState* {.importc, pure .} = enum
    Connected, Disconnected, Unknown 
  FTableRowBase* {.importcpp, inheritable, pure .} = object

  FObjectPreSaveContext* {.importcpp.} = object

  FViewport* {.importcpp, inheritable .} = object
  FViewportPtr* = ptr FViewport
  FSceneViewport* {.importcpp, inheritable .} = object of FViewport
  FSceneViewportPtr* = ptr FSceneViewport
  FViewportClient* {.importcpp, inheritable .} = object of UObject
  FViewportClientPtr* = ptr FViewportClient

  UGameViewportClient* {.importcpp, inheritable, pure .} = object of UObject
    viewport* {.importcpp:"Viewport"}: FViewportPtr
  UGameViewportClientPtr* = ptr UGameViewportClient

  FActorInstanceHandle* {.importcpp .} = object
    # actor* {.importcpp:"Actor".}: TWeakObjectPtr[AActor]

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
  UPhysicalMaterial* {.importcpp, inheritable, pure .} = object of UObject
  UPhysicalMaterialPtr* = ptr UPhysicalMaterial
  # UPhysicalMaterialMask* {.importcpp, inheritable, pure .} = object of UObject
  # UPhysicalMaterialMaskPtr* = ptr UPhysicalMaterialMask
  # UHLODLayer* {.importcpp, inheritable, pure .} = object of UObject
  # UHLODLayerPtr* = ptr UHLODLayer
  USoundBase* {.importcpp, inheritable, pure .} = object of UObject
  USoundBasePtr* = ptr USoundBase
  UMaterialInterface* {.importcpp, inheritable, pure .} = object of UObject
  UMaterialInterfacePtr* = ptr UMaterialInterface
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
  
  UUserDefinedStruct* {.importcpp, inheritable, pure .} = object of UScriptStruct
  UUserDefinedStructPtr* = ptr UUserDefinedStruct
  UNavigationSystemModuleConfig* {.importcpp, inheritable, pure .} = object of UObject
  UNavigationSystemModuleConfigPtr* = ptr UNavigationSystemModuleConfig
  UNavigationSystemConfig* {.importcpp, inheritable, pure .} = object of UObject
  UNavigationSystemConfigPtr* = ptr UNavigationSystemConfig


  # FNavAgentSelector* {.importcpp .} = object
  # FKConvexElem* {.importcpp .} = object

  # FRichCurve* {.importcpp .} = object
  SWidget* {.importcpp, inheritable, pure .} = object
  SWidgetPtr* = ptr SWidget
  UWidget* {.importcpp, inheritable, pure .} = object of UObject
    bOverrideAccessibleDefaults*: bool
    bCanChildrenBeAccessible*: bool

  UWidgetPtr* = ptr UWidget
  UUserWidget* {.importcpp, inheritable, pure.} = object of UWidget
  UUserWidgetPtr* = ptr UUserWidget

  FSlateBrush* {.importcpp.} = object
    # bIsDynamicallyLoaded*: uint8
    # imageType*: ESlateBrushImageType
    # mirroring*: ESlateBrushMirrorType
    # tiling*: ESlateBrushTileType
    # drawAs*: ESlateBrushDrawType
    # uVRegion*: FBox2f
    # resourceName*: FName
    # resourceObject*: TObjectPtr[UObject]
    # outlineSettings*: FSlateBrushOutlineSettings
    # tintColor*{.importcpp:"TintColor".}: FSlateColor
    # margin*: FMargin
    imageSize*{.importcpp:"ImageSize"}: FVector2D
  # FMovieSceneSequenceID* {.importcpp.} = object
  # FTextBlockStyle* {.importcpp.} = object
  UGameplayTask* {.importcpp, inheritable, pure .} = object of UObject #Needed because of force moving it to common.
  UGameplayTaskPtr* = ptr UGameplayTask
  UAbilityTask* {.importcpp, inheritable, pure .} = object of UGameplayTask
  UAbilityTaskPtr* = ptr UAbilityTask

  UGameInstance* {.importcpp, inheritable, pure.} = object of UObject
  UGameInstancePtr* = ptr UGameInstance

proc toString*(hit: FHitResult): FString {.importcpp: "#.ToString()" .}
proc `$`*(hit: FHitResult): string = hit.toString()

proc getWorld*(worldContext: FWorldContextPtr): UWorldPtr {.importcpp: "#->World()".}



#	void ForceGarbageCollection(bool bFullPurge = false);
proc forceGarbageCollection*(engine:UEnginePtr, bFullPurge: bool = false) {.importcpp: "#->ForceGarbageCollection(#)".}

# proc `rootComponent=`*(obj : AActorPtr; val : USceneComponentPtr) =
#   var value : USceneComponentPtr = val
#   let prop  = getClassByName("Actor").getFPropertyByName(
#       "RootComponent")
#   setPropertyValuePtr[USceneComponentPtr](prop, obj, value.addr)


# proc `rootComponent`*(obj : AActorPtr): USceneComponentPtr  =
#   let prop  = getClassByName("Actor").getFPropertyByName(
#       "RootComponent")
#   getPropertyValuePtr[USceneComponentPtr](prop, obj)[]
proc getCppName*(obj : UClassPtr) : FString {.ureflect.} = 
  let prefix = if obj.isChildOf(staticClass(AActor)): "A" else: "U"
  prefix & obj.getName()

proc setRootComponent*(actor : AActorPtr, newRootComponent : USceneComponentPtr): bool {.importcpp: "#->SetRootComponent(#)".}
proc getRootComponent*(actor : AActorPtr): USceneComponentPtr {.importcpp: "#->GetRootComponent()".}
proc finishAndRegisterComponent*(actor : AActorPtr, comp: UActorComponentPtr) {.importcpp: "#->FinishAndRegisterComponent(#)".}
  # void SetActorHiddenInGame(bool bNewHidden);
proc setupAttachment*(obj, inParent : USceneComponentPtr, inSocketName : FName = ENone) {.importcpp: "#->SetupAttachment(@)".}
proc registerComponent*(obj : UActorComponentPtr) {.importcpp: "#->RegisterComponent()".}
proc unRegisterComponent*(obj : UActorComponentPtr) {.importcpp: "#->UnregisterComponent()".}
proc destroyComponent*(obj : UActorComponentPtr, bPromoteChildren=false) {.importcpp: "#->DestroyComponent(#)".}


proc markRenderStateDirty*(obj : UPrimitiveComponentPtr) {.importcpp: "#->MarkRenderStateDirty()".}

type EGetWorldErrorMode* {.importcpp, size: sizeof(uint8).} = enum
  ReturnNull,
  LogAndReturnNull,
  Assert
  


#ACTOR CPP and related 
func getActor*(hitResult: FHitResult): AActorPtr {.importcpp: "#.GetActor()".}
func actor*(handle: FActorInstanceHandle): AActorPtr {.importcpp: "#.FetchActor()".}
proc isTickFunctionRegistered*(tickFn: FActorTickFunction): bool {.importcpp: "#.IsTickFunctionRegistered()".}  
proc setTickFunctionEnable*(tickFn: FActorTickFunction, bEnable: bool) {.importcpp: "#.SetTickFunctionEnable(#)".}
##ENGINE
#UWorld* UEngine::GetWorldFromContextObject(const UObject* Object, EGetWorldErrorMode ErrorMode) const
proc getEngine*() : UEnginePtr  {.importcpp: "(GEngine)", ureflect.} 
let GEngine* = getEngine()
proc getWorldFromContextObject*(engine:UEnginePtr, obj:UObjectPtr, errorMode:EGetWorldErrorMode) : UWorldPtr  {.importcpp: "#->GetWorldFromContextObject(#, #)".}
proc getWorldContextFromWorld*(engine:UEnginePtr, world:UWorldPtr) : FWorldContextPtr  {.importcpp: "#->GetWorldContextFromWorld(#)".}
proc activateExternalSubsystem*(cls:UClassPtr) {.importcpp: "FObjectSubsystemCollection<UEngineSubsystem>::ActivateExternalSubsystem(#)".}
proc createGameViewportWidget*(engine: UEnginePtr, gameViewportClient: UGameViewportClientPtr) {.importcpp: "#->CreateGameViewportWidget(#)" .}
#GameviewportClietn
proc init*(gameViewportClient: UGameViewportClientPtr, worldContext {.byref.}: FWorldContext, gameInstance:UGameInstancePtr) {.importcpp: "#->Init(@)".}

#VIEWPORT
proc getSizeXY*(viewport: FViewportPtr): FIntPoint {.importcpp: "#->GetSizeXY()".}
proc getMousePos*(viewport: FViewportPtr, mousePos: var FIntPoint, bLocalPosition: bool = true) {.importcpp: "#->GetMousePos(@)".}
proc hasFocus*(viewport: FViewportPtr): bool {.importcpp: "#->HasFocus()".}
proc getDesiredAspectRatio*(viewport: FViewportPtr): float32 {.importcpp: "#->GetDesiredAspectRatio()".}
proc keyState*(viewport: FViewportPtr, key: FKey): bool {.importcpp: "#->KeyState(#)".}#true if pressed false otherwise (lol!)
func isKeyPressed*(viewport: FViewportPtr, key: FKey): bool {.importcpp: "#->KeyState(#)".}
proc isCtrlDown*(viewport: FViewportPtr): bool {.importcpp: "IsCtrlDown(#)".}
proc isShiftDown*(viewport: FViewportPtr): bool {.importcpp: "IsShiftDown(#)".}
proc isAltDown*(viewport: FViewportPtr): bool {.importcpp: "IsAltDown(#)".}
proc getClient*(viewport: FViewportPtr): FViewportClientPtr {.importcpp: "#->GetClient()".}
# #TEMPORAL DYNAMIC DELEGATE THIS SHOULD BE BOUND FROM THE BINDINGS
# type FOnQuartzCommandEventBP* {.importcpp, pure.} = object
# type FOnQuartzMetronomeEventBP* {.importcpp, pure.} = object

#UWidget and CoreSlate stuff not bound
proc takeWidget*(widget: UWidgetPtr): TSharedRef[SWidget] {.importcpp: "#->TakeWidget()".}


#Asset should put those in uobject?
proc makeFTopLevelAssetPath*(path: FString) : FTopLevelAssetPath {.importcpp: "FTopLevelAssetPath(#)", constructor, .}
proc makeFTopLevelAssetPath*(inPacakge, inAssetName: FName) : FTopLevelAssetPath {.importcpp: "FTopLevelAssetPath(@)", constructor, .}
proc makeFTopLevelAssetPath*(inPacakge, inAssetName: FString) : FTopLevelAssetPath {. .} = makeFTopLevelAssetPath(n inPacakge, n inAssetName)
proc getClassPathName*(cls: UClassPtr): FTopLevelAssetPath {.importcpp: "#->GetClassPathName()", ureflect, .}
proc getPackageName*(assetPath: FTopLevelAssetPath): FName {.importcpp: "#.GetPackageName()", .}
proc getAssetName*(assetPath: FTopLevelAssetPath): FName {.importcpp: "#.GetAssetName()", .}
proc `$`*(assetPath: FTopLevelAssetPath): string = &"Package Name: {assetPath.getPackageName()} Asset Name: {assetPath.getAssetName()}"
# INPUT ACTION. This should live in another place.

proc getBlueprintClass*(blueprint: UBlueprintPtr): UClassPtr {.importcpp: "#->GetBlueprintClass()", ureflect, .}
proc getParentClass*(blueprint: UBlueprintPtr): TSubclassOf[UObject] {.importcpp: "#->ParentClass", ureflect, .}

type 
  ETriggerEvent* {.importcpp, size: sizeof(uint8), pure.} = enum
    None, Triggered, Started, Ongoing, Canceled, Completed, ETriggerEvent_MAX

  UInputComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  UInputComponentPtr* = ptr UInputComponent
  UEnhancedInputComponent* {. importcpp, inheritable, pure.} = object of UInputComponent
  UEnhancedInputComponentPtr* = ptr UEnhancedInputComponent
  UInputAction* {.importcpp, inheritable, pure .} = object of UObject
  UInputActionPtr* = ptr UInputAction
  UPlayerInput* {.importcpp, inheritable, pure .} = object of UObject
  UPlayerInputPtr* = ptr UPlayerInput
  UEnhancedPlayerInput* {.importcpp, inheritable, pure .} = object of UPlayerInput
  UEnhancedPlayerInputPtr* = ptr UEnhancedPlayerInput
  FEnhancedInputActionEventBinding*  {. importcpp, inheritable, pure.} = object
  FInputActionValue* {.importcpp .} = object
    #value (protected) : FVector3
    
  FKeyEvent* {.importcpp, inheritable .} = object
  FkeyEventPtr* = ptr FKeyEvent

  FInputKeyEventArgs* {.importcpp, pure .} = object
    viewport* {.importcpp:"Viewport".} : FViewportPtr
    controllerId* {.importcpp:"ControllerId".} : int32
    inputDevice* {.importcpp:"InputDevice".} : FInputDeviceId
    key* {.importcpp:"Key".} : FKey
    event* {.importcpp:"Event".} : EInputEvent
    amountDepressed* {.importcpp:"AmountDepressed".} : float32
    isTouchEvent* {.importcpp:"bIsTouchEvent".} : bool
  FInputKeyEventArgsPtr* = ptr FInputKeyEventArgs

  FInputDeviceId* {.importcpp .} = object
  EInputEvent* {. importcpp, pure.} = enum
    IE_Pressed, IE_Released, IE_Repeat, IE_DoubleClick, IE_Axis, IE_MAX
  TStatId* {.importcpp .} = object

#TODO initializer
# proc makeFInputKeyEventArgs*(viewport: FViewportPtr = nil, controllerId: int32 = 0, key: FKey = "None", event: EInputEvent = IE_Pressed) : FInputKeyEventArgs 
#   {.importcpp: "FInputKeyEventArgs(@)", constructor, .}
#INPUT
func makeFKey*(keyName: FName) : FKey {.importcpp: "FKey(#)", constructor, .}
func getFName*(key: FKey) : FName {.importcpp: "#.GetFName()", .}
func toString*(key: FKey) : FString {.importcpp: "#.ToString()", .}
func `$`*(key: FKey): string = key.toString()
func isKeyPressed*(key: FKey, name: FName): bool = key.getFName() == name

func getKey*(self: FKeyEventPtr) : FKey {.importcpp: "#->GetKey()".}
func getCharacter*(self: FKeyEventPtr) : char {.importcpp: "#->GetCharacter()".}

proc bindActionInternal*(self: UEnhancedInputComponentPtr, action: UInputActionPtr, triggerEvent: ETriggerEvent, obj: UObjectPtr, functionName: FName) : var FEnhancedInputActionEventBinding {.importcpp:"#->BindAction(@)".}
proc bindAction*(self: UEnhancedInputComponentPtr, action: UInputActionPtr, triggerEvent: ETriggerEvent, obj: UObjectPtr, functionName: FName) =
  discard bindActionInternal(self, action, triggerEvent, obj, functionName)
  

func get*[T:float32 | FVector2D | FVector](input : FInputActionValue) {.importcpp: "#.Get<'0>()".}
func axis1D*(input : FInputActionValue) : float32 {.importcpp: "#.Get<float>()".}
func axis2D*(input : FInputActionValue) : FVector2D  {.importcpp: "#.Get<FVector2D>()".}
func axis3D*(input : FInputActionValue) : FVector {.importcpp: "#.Get<FVector>()".}


type FOnInputKeySignature* = TMulticastDelegateOneParam[FInputKeyEventArgsPtr]
proc onInputKey*(viewport: UGameViewportClientPtr) : FOnInputKeySignature  {.importcpp: "#->OnInputKey()".}
type OnInputKeyEventPressedNimSignature {.exportc.} = proc (keyEventArgs:FInputKeyEventArgsPtr) : void {.cdecl.}
type OnKeyPressedNimSignature {.exportc.} = proc (keyEventArgs:FkeyEventPtr) : void {.cdecl.}

proc addInputKeyPresed*(self: UGameViewportClientPtr, fn : OnInputKeyEventPressedNimSignature) : FDelegateHandle =
  {.emit:"""
  auto constWrapper = [](const FInputKeyEventArgs& args, OnInputKeyEventPressedNimSignature fn){ 
    fn(const_cast<FInputKeyEventArgs*>(&args)) 
    };
    handle = self->OnInputKey().AddStatic(constWrapper, fn);
  """.}
  let handle {.importcpp.} : FDelegateHandle 
  handle


# Notice this is editor only 
proc addGlobalEditorKeyPressed*(fn : OnKeyPressedNimSignature) : FDelegateHandle =
  {.emit:"""
    auto constWrapper = [](const FKeyEvent& args, OnKeyPressedNimSignature fn){ 
      fn( const_cast<FKeyEvent*>(&args)); 
    };
	  handle = FSlateApplication::Get().OnApplicationPreInputKeyDownListener().AddStatic(constWrapper, fn);
  """.}
  let handle {.importcpp.} : FDelegateHandle 
  handle


proc removeGlobalEditorKeyPressed*(handle: FDelegateHandle) =
  {.emit:"""
    FSlateApplication::Get().OnApplicationPreInputKeyDownListener().Remove(handle);
  """.}


type 
  EAxisList* {.size: sizeof(uint8), importcpp:"EAxisList::Type", pure.} = enum
    None, X, Y, Z, X_Neg, Y_Neg, Z_Neg, EAxisList_MAX 
  ECollisionChannel* {.size: sizeof(uint8), importcpp, pure.} = enum
    ECC_WorldStatic, ECC_WorldDynamic, ECC_Pawn, ECC_Visibility, ECC_Camera,
    ECC_PhysicsBody, ECC_Vehicle, ECC_Destructible, ECC_EngineTraceChannel1,
    ECC_EngineTraceChannel2, ECC_EngineTraceChannel3, ECC_EngineTraceChannel4,
    ECC_EngineTraceChannel5, ECC_EngineTraceChannel6, ECC_GameTraceChannel1,
    ECC_GameTraceChannel2, ECC_GameTraceChannel3, ECC_GameTraceChannel4,
    ECC_GameTraceChannel5, ECC_GameTraceChannel6, ECC_GameTraceChannel7,
    ECC_GameTraceChannel8, ECC_GameTraceChannel9, ECC_GameTraceChannel10,
    ECC_GameTraceChannel11, ECC_GameTraceChannel12, ECC_GameTraceChannel13,
    ECC_GameTraceChannel14, ECC_GameTraceChannel15, ECC_GameTraceChannel16,
    ECC_GameTraceChannel17, ECC_GameTraceChannel18, ECC_OverlapAll_Deprecated,
    ECC_MAX

  EObjectTypeQuery* {.size: sizeof(uint8), importcpp, pure.} = enum
    ObjectTypeQuery1, ObjectTypeQuery2, ObjectTypeQuery3, ObjectTypeQuery4,
    ObjectTypeQuery5, ObjectTypeQuery6, ObjectTypeQuery7, ObjectTypeQuery8,
    ObjectTypeQuery9, ObjectTypeQuery10, ObjectTypeQuery11, ObjectTypeQuery12,
    ObjectTypeQuery13, ObjectTypeQuery14, ObjectTypeQuery15, ObjectTypeQuery16,
    ObjectTypeQuery17, ObjectTypeQuery18, ObjectTypeQuery19, ObjectTypeQuery20,
    ObjectTypeQuery21, ObjectTypeQuery22, ObjectTypeQuery23, ObjectTypeQuery24,
    ObjectTypeQuery25, ObjectTypeQuery26, ObjectTypeQuery27, ObjectTypeQuery28,
    ObjectTypeQuery29, ObjectTypeQuery30, ObjectTypeQuery31, ObjectTypeQuery32,
    ObjectTypeQuery_MAX, EObjectTypeQuery_MAX
  
  ETraceTypeQuery* {.size: sizeof(uint8), pure.} = enum
    TraceTypeQuery1, TraceTypeQuery2, TraceTypeQuery3, TraceTypeQuery4,
    TraceTypeQuery5, TraceTypeQuery6, TraceTypeQuery7, TraceTypeQuery8,
    TraceTypeQuery9, TraceTypeQuery10, TraceTypeQuery11, TraceTypeQuery12,
    TraceTypeQuery13, TraceTypeQuery14, TraceTypeQuery15, TraceTypeQuery16,
    TraceTypeQuery17, TraceTypeQuery18, TraceTypeQuery19, TraceTypeQuery20,
    TraceTypeQuery21, TraceTypeQuery22, TraceTypeQuery23, TraceTypeQuery24,
    TraceTypeQuery25, TraceTypeQuery26, TraceTypeQuery27, TraceTypeQuery28,
    TraceTypeQuery29, TraceTypeQuery30, TraceTypeQuery31, TraceTypeQuery32,
    TraceTypeQuery_MAX, ETraceTypeQuery_MAX

converter toObjectType*(collisionChannel:ECollisionChannel) : EObjectTypeQuery {.importcpp: "UEngineTypes::ConvertToObjectType(@)".}
converter toTraceType*(collisionChannel:ECollisionChannel) : ETraceTypeQuery {.importcpp: "UEngineTypes::ConvertToTraceType(@)".}

proc getTagName*(tag: FGameplayTag): FName {.importcpp: "#.GetTagName()".}
proc requestGameplayTag*(tagName: FName, errorIfNotFound = true): FGameplayTag {.importcpp:"FGameplayTag::RequestGameplayTag(@)".}
#NET
proc registerReplicatedLifetimeProperty*(prop: FPropertyPtr, outLifetimeProps {.byref.}: TArray[FLifetimeProperty], params: var FDoRepLifetimeParams) {.importcpp: "RegisterReplicatedLifetimeProperty(@)".}

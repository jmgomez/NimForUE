include ../definitions
import ../core/math/vector
import ../coreuobject/[uobject, coreuobject, nametypes]
import ../nimforue/nimforuebindings
import ../core/[delegates]
import ../core/containers/[unrealstring]


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


  # AWorldSettings* {.importcpp, inheritable, pure .}= object of AInfo
  # AWorldSettingsPtr* = ptr AWorldSettings

  UActorComponent* {.importcpp, inheritable, pure .} = object of UObject
  UActorComponentPtr* = ptr UActorComponent
  USceneComponent* {.importcpp, inheritable, pure .} = object of UActorComponent
  USceneComponentPtr* = ptr USceneComponent
  UPrimitiveComponent* {.importcpp, inheritable, pure .} = object of USceneComponent
  UPrimitiveComponentPtr* = ptr UPrimitiveComponent
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



  # UAssetManager* {.importcpp, inheritable, pure .} = object of UObject
  # UAssetManagerPtr* = ptr UAssetManager
  # UDataAsset* {.importcpp, inheritable, pure .} = object of UObject
  # UDataAssetPtr* = ptr UDataAsset

  AVolume* {.importcpp, inheritable, pure .} = object of UObject
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
  
  # FBoneReference* {.importcpp, pure .} = object
  #   boneName* {.importcpp: "BoneName".}: FName
  #   boneIndex* {.importcpp: "BoneIndex".}: int32
  #   bUseSkeletonIndex* {.importcpp.}: bool


  FWorldContextPtr* = ptr FWorldContext

  FHitResult* {.importcpp, pure.} = object
    faceIndex* {.importcpp: "FaceIndex".}: int32
    time* {.importcpp: "Time".}: float32
    distance* {.importcpp: "Distance".}: float32
    # location* {.importcpp: "Location".}: FVector_NetQuantize
    # impactPoint* {.importcpp: "ImpactPoint".}: FVector_NetQuantize
    normal* {.importcpp: "Normal".}: FVector_NetQuantizeNormal
    impactNormal* {.importcpp: "ImpactNormal".}: FVector_NetQuantizeNormal
    # traceStart* {.importcpp: "TraceStart".}: FVector_NetQuantize
    # traceEnd* {.importcpp: "TraceEnd".}: FVector_NetQuantize
    penetrationDepth* {.importcpp: "PenetrationDepth".}: float32
    myItem* {.importcpp: "MyItem".}: int32
    item* {.importcpp: "Item".}: int32
    elementIndex* {.importcpp: "ElementIndex".}: uint8
    bBlockingHit* {.importcpp: "bBlockingHit".}: bool
    bStartPenetrating* {.importcpp: "bStartPenetrating".}: bool
    # physMaterial* {.importcpp: "PhysMaterial".}: UPhysicalMaterialPtr 
    hitObjectHandle* {.importcpp: "HitObjectHandle".}: FActorInstanceHandle 
    # component* {.importcpp: "Component".}: TWeakObjectPtr[UPrimitiveComponentPtr]
    boneName* {.importcpp: "BoneName".}: FName
    myBoneName* {.importcpp: "MyBoneName".}: FName

  FLifetimeProperty* {.importcpp, pure.} = object
    repIndex* {.importcpp: "RepIndex".}: uint16
    condition* {.importcpp: "Condition".}: ELifetimeCondition
    repNotifyCondition* {.importcpp: "RepNotifyCondition".}: ELifetimeRepNotifyCondition
  
  FGameplayTag* {.importcpp, pure.} = object
    tag* {.importcpp: "Tag".}: FName
  # UDeveloperSettings* {.importcpp .} = object of UObject
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

  FARFilter* {.importc .} = object


  EInputDeviceConnectionState* {.importc, pure .} = enum
    Connected, Disconnected, Unknown 
  FTableRowBase* {.importcpp, inheritable, pure .} = object

  FViewport* {.importcpp .} = object
  FViewportPtr* = ptr FViewport

  UGameViewportClient* {.importcpp, inheritable, pure .} = object of UObject
  UGameViewportClientPtr* = ptr UGameViewportClient

  FActorInstanceHandle* {.importcpp .} = object

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
  
  # UUserDefinedStruct* {.importcpp, inheritable, pure .} = object of UScriptStruct
  # UUserDefinedStructPtr* = ptr UUserDefinedStruct
  UNavigationSystemModuleConfig* {.importcpp, inheritable, pure .} = object of UObject
  UNavigationSystemModuleConfigPtr* = ptr UNavigationSystemModuleConfig
  UNavigationSystemConfig* {.importcpp, inheritable, pure .} = object of UObject
  UNavigationSystemConfigPtr* = ptr UNavigationSystemConfig


  # FNavAgentSelector* {.importcpp .} = object
  # FKConvexElem* {.importcpp .} = object

  # FRichCurve* {.importcpp .} = object
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
  # FMovieSceneSequenceID* {.importcpp.} = object
  # FTextBlockStyle* {.importcpp.} = object

   

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


proc setRootComponent*(actor : AActorPtr, newRootComponent : USceneComponentPtr): bool {.importcpp: "#->SetRootComponent(#)".}
proc getRootComponent*(actor : AActorPtr): USceneComponentPtr {.importcpp: "#->GetRootComponent()".}
  # void SetActorHiddenInGame(bool bNewHidden);
proc setupAttachment*(obj, inParent : USceneComponentPtr, inSocketName : FName = ENone) {.importcpp: "#->SetupAttachment(@)".}
proc registerComponent*(obj : UActorComponentPtr) {.importcpp: "#->RegisterComponent()".}
proc unRegisterComponent*(obj : UActorComponentPtr) {.importcpp: "#->UnregisterComponent()".}
proc destroyComponent*(obj : UActorComponentPtr, bPromoteChildren=false) {.importcpp: "#->DestroyComponent(#)".}


type EGetWorldErrorMode* {.importcpp, size: sizeof(uint8).} = enum
  ReturnNull,
  LogAndReturnNull,
  Assert
  


#ACTOR CPP and related 
func getActor*(hitResult: FHitResult): AActorPtr {.importcpp: "#.GetActor()".}
proc isTickFunctionRegistered*(self: FActorTickFunction): bool {.importcpp: "#.IsTickFunctionRegistered()".}  
##ENGINE
#UWorld* UEngine::GetWorldFromContextObject(const UObject* Object, EGetWorldErrorMode ErrorMode) const
proc getEngine*() : UEnginePtr  {.importcpp: "(GEngine)".} 
let GEngine* = getEngine()
proc getWorldFromContextObject*(engine:UEnginePtr, obj:UObjectPtr, errorMode:EGetWorldErrorMode) : UWorldPtr  
  {.importcpp: "#->GetWorldFromContextObject(#, #)".}

proc activateExternalSubsystem*(cls:UClassPtr) {.importcpp: "FObjectSubsystemCollection<UEngineSubsystem>::ActivateExternalSubsystem(#)".}


# #TEMPORAL DYNAMIC DELEGATE THIS SHOULD BE BOUND FROM THE BINDINGS
# type FOnQuartzCommandEventBP* {.importcpp, pure.} = object
# type FOnQuartzMetronomeEventBP* {.importcpp, pure.} = object


#Asset should put those in uobject?
proc makeFTopLevelAssetPath*(path: FString) : FTopLevelAssetPath {.importcpp: "FTopLevelAssetPath(#)", constructor.}
proc getClassPathName*(self: UClassPtr): FTopLevelAssetPath {.importcpp: "#->GetClassPathName()".}

# INPUT ACTION. This should live in another place.
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
  FKeyEvent* {.importcpp .} = object
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

  FInputDeviceId* {.importc .} = object
  EInputEvent* {.size: sizeof(uint8), importcpp, pure.} = enum
    IE_Pressed, IE_Released, IE_Repeat, IE_DoubleClick, IE_Axis, IE_MAX

func getKey*(self: FKeyEventPtr) : FKey {.importcpp: "#->GetKey()".}
func getCharacter*(self: FKeyEventPtr) : char {.importcpp: "#->GetCharacter()".}

proc bindActionInteral(self: UEnhancedInputComponentPtr, action: UInputActionPtr, triggerEvent: ETriggerEvent, obj: UObjectPtr, functionName: FName) : var FEnhancedInputActionEventBinding {.importcpp:"#->BindAction(@)".}
proc bindAction*(self: UEnhancedInputComponentPtr, action: UInputActionPtr, triggerEvent: ETriggerEvent, obj: UObjectPtr, functionName: FName) =
  discard bindActionInteral(self, action, triggerEvent, obj, functionName)
  

func get*[T:float32 | FVector2D | FVector](input : FInputActionValue) {.importcpp: "#.Get<'0>()".}
func axis1D*(input : FInputActionValue) : float32 {.importcpp: "#.Get<float>()".}
func axis2D*(input : FInputActionValue) : FVector2D  {.importcpp: "#.Get<FVector2D>()".}
func axis3D*(input : FInputActionValue) : FVector {.importcpp: "#.Get<FVector>()".}


type FOnInputKeySignature* = TMulticastDelegateOneParam[FInputKeyEventArgsPtr]
proc onInputKey*(self: UGameViewportClientPtr) : FOnInputKeySignature  {.importcpp: "#->OnInputKey()".}
type OnInputKeyEventPressedNimSignature {.exportc.} = proc (keyEventArgs:FInputKeyEventArgsPtr) : void {.cdecl.}
type OnKeyPressedNimSignature {.exportc.} = proc (keyEventArgs:FkeyEventPtr) : void {.cdecl.}

proc addInputKeyPresed*(self: UGameViewportClientPtr, fn : OnInputKeyEventPressedNimSignature) : FDelegateHandle =
  {.emit:"""
  auto constWrapper = [](const FInputKeyEventArgs& args, OnInputKeyEventPressedNimSignature fn){ 
    fn(const_cast<FInputKeyEventArgs*>(&args)); 
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



type 
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



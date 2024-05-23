import ../core/containers/[array, unrealstring, map]
import nametypes
import ../core/math/vector
import ../core/[ftext]
import uobject

type

  FAssetBundleData* {.importcpp.} = object
    bundles* {.importcpp: "Bundles".}: TArray[FAssetBundleEntry]

  FAssetBundleEntry* {.importcpp.} = object
    bundleAssets* {.importcpp: "BundleAssets".}: TArray[FSoftObjectPath]
    bundleName* {.importcpp: "BundleName".}: FName

  FSoftObjectPath* {.importcpp.} = object
    subPathString* {.importcpp: "SubPathString".}: FString
    assetPathName* {.importcpp: "AssetPathName".}: FName

  FAssetData* {.importcpp.} = object
    assetClass* {.importcpp: "AssetClass".}: FName
    assetName* {.importcpp: "AssetName".}: FName
    packagePath* {.importcpp: "PackagePath".}: FName
    packageName* {.importcpp: "PackageName".}: FName
    objectPath* {.importcpp: "ObjectPath".}: FName

  FAutomationEvent* {.importcpp.} = object
    artifact* {.importcpp: "Artifact".}: FGuid
    context* {.importcpp: "Context".}: FString
    message* {.importcpp: "Message".}: FString
    `type`* {.importcpp: "Type".}: EAutomationEventType

  FGuid* {.importcpp.} = object
    d* {.importcpp: "D".}: int32
    c* {.importcpp: "C".}: int32
    b* {.importcpp: "B".}: int32
    a* {.importcpp: "A".}: int32

  EAutomationEventType* {.size: sizeof(uint8), pure.} = enum
    Info, Warning, Error, EAutomationEventType_MAX
  FAutomationExecutionEntry* {.importcpp.} = object
    timestamp* {.importcpp: "Timestamp".}: FDateTime
    lineNumber* {.importcpp: "LineNumber".}: int32
    filename* {.importcpp: "Filename".}: FString
    event* {.importcpp: "Event".}: FAutomationEvent

  FDateTime* {.importcpp.} = object

 
  FBox* {.importcpp.} = object
    isValid* {.importcpp: "IsValid".}: uint8
    max* {.importcpp: "Max".}: FVector
    min* {.importcpp: "Min".}: FVector

  FBox2D* {.importcpp.} = object
    bIsValid* {.importcpp: "bIsValid".}: uint8
    max* {.importcpp: "Max".}: FVector2D
    min* {.importcpp: "Min".}: FVector2D

  FVector2D* {.importcpp.} = object
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

  FBox2f* {.importcpp.} = object
    bIsValid* {.importcpp: "bIsValid".}: uint8
    max* {.importcpp: "Max".}: FVector2f
    min* {.importcpp: "Min".}: FVector2f

  FVector2f* {.importcpp.} = object
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

  FBox3d* {.importcpp.} = object
    isValid* {.importcpp: "IsValid".}: uint8
    max* {.importcpp: "Max".}: FVector3d
    min* {.importcpp: "Min".}: FVector3d

  FVector3d* {.importcpp, inheritable, pure .} = object
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

  FBox3f* {.importcpp.} = object
    isValid* {.importcpp: "IsValid".}: uint8
    max* {.importcpp: "Max".}: FVector3f
    min* {.importcpp: "Min".}: FVector3f

  FVector3f* {.importcpp, inheritable, pure.} = object
    z* {.importcpp: "Z".}: float32
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

  FBoxSphereBounds* {.importcpp.} = object
    sphereRadius* {.importcpp: "SphereRadius".}: float64
    boxExtent* {.importcpp: "BoxExtent".}: FVector
    origin* {.importcpp: "Origin".}: FVector

  FBoxSphereBounds3d* {.importcpp.} = object
    sphereRadius* {.importcpp: "SphereRadius".}: float64
    boxExtent* {.importcpp: "BoxExtent".}: FVector3d
    origin* {.importcpp: "Origin".}: FVector3d

  FBoxSphereBounds3f* {.importcpp.} = object
    sphereRadius* {.importcpp: "SphereRadius".}: float32
    boxExtent* {.importcpp: "BoxExtent".}: FVector3f
    origin* {.importcpp: "Origin".}: FVector3f

  FColor* {.importcpp.} = object
    a* {.importcpp: "A".}: uint8
    r* {.importcpp: "R".}: uint8
    g* {.importcpp: "G".}: uint8
    b* {.importcpp: "B".}: uint8

  FDirectoryPath* {.importcpp.} = object
    path* {.importcpp: "Path".}: FString

  FFallbackStruct* {.importcpp.} = object
  
  FFilePath* {.importcpp.} = object
    filePath* {.importcpp: "FilePath".}: FString

  FFloatInterval* {.importcpp.} = object
    max* {.importcpp: "Max".}: float32
    min* {.importcpp: "Min".}: float32

  FFloatRange* {.importcpp.} = object
    upperBound* {.importcpp: "UpperBound".}: FFloatRangeBound
    lowerBound* {.importcpp: "LowerBound".}: FFloatRangeBound

  FFloatRangeBound* {.importcpp.} = object
    value* {.importcpp: "Value".}: float32
    `type`* {.importcpp: "Type".}: ERangeBoundTypes

  ERangeBoundTypes* {.size: sizeof(uint8), pure.} = enum
    Exclusive, Inclusive, Open, ERangeBoundTypes_MAX
  FFrameNumber* {.importcpp.} = object
    value* {.importcpp: "Value".}: int32

  FFrameNumberRange* {.importcpp.} = object
    upperBound* {.importcpp: "UpperBound".}: FFrameNumberRangeBound
    lowerBound* {.importcpp: "LowerBound".}: FFrameNumberRangeBound

  FFrameNumberRangeBound* {.importcpp.} = object
    value* {.importcpp: "Value".}: FFrameNumber
    `type`* {.importcpp: "Type".}: ERangeBoundTypes

  FFrameRate* {.importcpp.} = object
    denominator* {.importcpp: "Denominator".}: int32
    numerator* {.importcpp: "Numerator".}: int32

  FFrameTime* {.importcpp.} = object
    subFrame* {.importcpp: "SubFrame".}: float32
    frameNumber* {.importcpp: "FrameNumber".}: FFrameNumber

  FInt32Interval* {.importcpp.} = object
    max* {.importcpp: "Max".}: int32
    min* {.importcpp: "Min".}: int32

  FInt32Range* {.importcpp.} = object
    upperBound* {.importcpp: "UpperBound".}: FInt32RangeBound
    lowerBound* {.importcpp: "LowerBound".}: FInt32RangeBound

  FInt32RangeBound* {.importcpp.} = object
    value* {.importcpp: "Value".}: int32
    `type`* {.importcpp: "Type".}: ERangeBoundTypes

  FInterpCurveFloat* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointFloat]

  FInterpCurvePointFloat* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: float32
    arriveTangent* {.importcpp: "ArriveTangent".}: float32
    outVal* {.importcpp: "OutVal".}: float32
    inVal* {.importcpp: "InVal".}: float32

  EInterpCurveMode* {.size: sizeof(uint8), pure.} = enum
    CIM_Linear, CIM_CurveAuto, CIM_Constant, CIM_CurveUser, CIM_CurveBreak,
    CIM_CurveAutoClamped, CIM_MAX
  FInterpCurveLinearColor* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointLinearColor]

  FInterpCurvePointLinearColor* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FLinearColor
    arriveTangent* {.importcpp: "ArriveTangent".}: FLinearColor
    outVal* {.importcpp: "OutVal".}: FLinearColor
    inVal* {.importcpp: "InVal".}: float32

  FLinearColor* {.importcpp.} = object
    a* {.importcpp: "A".}: float32
    b* {.importcpp: "B".}: float32
    g* {.importcpp: "G".}: float32
    r* {.importcpp: "R".}: float32

  FInterpCurvePointQuat* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FQuat
    arriveTangent* {.importcpp: "ArriveTangent".}: FQuat
    outVal* {.importcpp: "OutVal".}: FQuat
    inVal* {.importcpp: "InVal".}: float32

  FQuat* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

  FInterpCurvePointTwoVectors* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FTwoVectors
    arriveTangent* {.importcpp: "ArriveTangent".}: FTwoVectors
    outVal* {.importcpp: "OutVal".}: FTwoVectors
    inVal* {.importcpp: "InVal".}: float32

  FTwoVectors* {.importcpp.} = object
    v2* {.importcpp: "v2".}: FVector
    v1* {.importcpp: "v1".}: FVector

  FInterpCurvePointVector* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FVector
    arriveTangent* {.importcpp: "ArriveTangent".}: FVector
    outVal* {.importcpp: "OutVal".}: FVector
    inVal* {.importcpp: "InVal".}: float32

  FInterpCurvePointVector2D* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FVector2D
    arriveTangent* {.importcpp: "ArriveTangent".}: FVector2D
    outVal* {.importcpp: "OutVal".}: FVector2D
    inVal* {.importcpp: "InVal".}: float32

  FInterpCurveQuat* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointQuat]

  FInterpCurveTwoVectors* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointTwoVectors]

  FInterpCurveVector* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointVector]

  FInterpCurveVector2D* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointVector2D]

  FIntPoint* {.importcpp.} = object
    y* {.importcpp: "Y".}: int32
    x* {.importcpp: "X".}: int32

  FIntVector* {.importcpp.} = object
    z* {.importcpp: "Z".}: int32
    y* {.importcpp: "Y".}: int32
    x* {.importcpp: "X".}: int32

  FMatrix* {.importcpp.} = object
    wPlane* {.importcpp: "WPlane".}: FPlane
    zPlane* {.importcpp: "ZPlane".}: FPlane
    yPlane* {.importcpp: "YPlane".}: FPlane
    xPlane* {.importcpp: "XPlane".}: FPlane

  FPlane* {.importcpp.} = object of FVector
    w* {.importcpp: "W".}: float64

  FMatrix44d* {.importcpp.} = object
    wPlane* {.importcpp: "WPlane".}: FPlane4d
    zPlane* {.importcpp: "ZPlane".}: FPlane4d
    yPlane* {.importcpp: "YPlane".}: FPlane4d
    xPlane* {.importcpp: "XPlane".}: FPlane4d

  FPlane4d* {.importcpp, .} = object of FVector3d
    w* {.importcpp: "W".}: float64

  FMatrix44f* {.importcpp.} = object
    wPlane* {.importcpp: "WPlane".}: FPlane4f
    zPlane* {.importcpp: "ZPlane".}: FPlane4f
    yPlane* {.importcpp: "YPlane".}: FPlane4f
    xPlane* {.importcpp: "XPlane".}: FPlane4f

  FPlane4f* {.importcpp.} = object of FVector3f
    w* {.importcpp: "W".}: float32

  FOrientedBox* {.importcpp.} = object
    extentZ* {.importcpp: "ExtentZ".}: float64
    extentY* {.importcpp: "ExtentY".}: float64
    extentX* {.importcpp: "ExtentX".}: float64
    axisZ* {.importcpp: "AxisZ".}: FVector
    axisY* {.importcpp: "AxisY".}: FVector
    axisX* {.importcpp: "AxisX".}: FVector
    center* {.importcpp: "Center".}: FVector

  FPackedNormal* {.importcpp.} = object
    w* {.importcpp: "W".}: uint8
    z* {.importcpp: "Z".}: uint8
    y* {.importcpp: "Y".}: uint8
    x* {.importcpp: "X".}: uint8

  FPackedRGB10A2N* {.importcpp.} = object
    packed* {.importcpp: "Packed".}: int32

  FPackedRGBA16N* {.importcpp.} = object
    zW* {.importcpp: "ZW".}: int32
    xY* {.importcpp: "XY".}: int32

  FPolyglotTextData* {.importcpp.} = object
    cachedText* {.importcpp: "CachedText".}: FText
    bIsMinimalPatch* {.importcpp: "bIsMinimalPatch".}: bool
    localizedStrings* {.importcpp: "LocalizedStrings".}: TMap[FString, FString]
    nativeString* {.importcpp: "NativeString".}: FString
    key* {.importcpp: "Key".}: FString
    namespace* {.importcpp: "Namespace".}: FString
    nativeCulture* {.importcpp: "NativeCulture".}: FString
    category* {.importcpp: "Category".}: ELocalizedTextSourceCategory

  ELocalizedTextSourceCategory* {.size: sizeof(uint8), pure.} = enum
    Game, Engine, Editor, ELocalizedTextSourceCategory_MAX
  FPrimaryAssetId* {.importcpp.} = object
    primaryAssetName* {.importcpp: "PrimaryAssetName".}: FName
    primaryAssetType* {.importcpp: "PrimaryAssetType".}: FPrimaryAssetType

  FPrimaryAssetType* {.importcpp.} = object
    name* {.importcpp: "Name".}: FName

  FQualifiedFrameTime* {.importcpp.} = object
    rate* {.importcpp: "Rate".}: FFrameRate
    time* {.importcpp: "Time".}: FFrameTime

  FQuat4d* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

  FQuat4f* {.importcpp.} = object
    w* {.importcpp: "W".}: float32
    z* {.importcpp: "Z".}: float32
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

  FRandomStream* {.importcpp.} = object
    seed* {.importcpp: "Seed".}: int32
    initialSeed* {.importcpp: "InitialSeed".}: int32

  FRotator* {.importcpp.} = object
    roll* {.importcpp: "Roll".}: float64 = 0
    yaw* {.importcpp: "Yaw".}: float64 = 0
    pitch* {.importcpp: "Pitch".}: float64 = 0

  FRotator3d* {.importcpp.} = object
    roll* {.importcpp: "Roll".}: float64
    yaw* {.importcpp: "Yaw".}: float64
    pitch* {.importcpp: "Pitch".}: float64

  FRotator3f* {.importcpp.} = object
    roll* {.importcpp: "Roll".}: float32
    yaw* {.importcpp: "Yaw".}: float32
    pitch* {.importcpp: "Pitch".}: float32

  FSoftClassPath* {.importcpp.} = object
  
  FTestUninitializedScriptStructMembersTest* {.importcpp.} = object
    unusedValue* {.importcpp: "UnusedValue".}: float32
    initializedObjectReference* {.importcpp: "InitializedObjectReference".}: TObjectPtr[
        UObject]
    uninitializedObjectReference* {.importcpp: "UninitializedObjectReference".}: TObjectPtr[
        UObject]

  FTimecode* {.importcpp.} = object
    bDropFrameFormat* {.importcpp: "bDropFrameFormat".}: bool
    frames* {.importcpp: "Frames".}: int32
    seconds* {.importcpp: "Seconds".}: int32
    minutes* {.importcpp: "Minutes".}: int32
    hours* {.importcpp: "Hours".}: int32

  FTimespan* {.importcpp.} = object
  
  FTransform* {.importcpp.} = object
    scale3D* {.importcpp: "Scale3D".}: FVector
    translation* {.importcpp: "Translation".}: FVector
    rotation* {.importcpp: "Rotation".}: FQuat

  FTransform3d* {.importcpp.} = object
    scale3D* {.importcpp: "Scale3D".}: FVector3d
    translation* {.importcpp: "Translation".}: FVector3d
    rotation* {.importcpp: "Rotation".}: FQuat4d

  FTransform3f* {.importcpp.} = object
    scale3D* {.importcpp: "Scale3D".}: FVector3f
    translation* {.importcpp: "Translation".}: FVector3f
    rotation* {.importcpp: "Rotation".}: FQuat4f

  FVector4* {.importcpp.} = object
    w* {.importcpp: "W".}: float64 
    z* {.importcpp: "Z".}: float64 
    y* {.importcpp: "Y".}: float64 
    x* {.importcpp: "X".}: float64 

  FVector4d* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

  FVector4f* {.importcpp.} = object
    w* {.importcpp: "W".}: float32
    z* {.importcpp: "Z".}: float32
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

  ELifetimeCondition* {.size: sizeof(uint8), pure, importcpp.} = enum
    COND_None, COND_InitialOnly, COND_OwnerOnly, COND_SkipOwner,
    COND_SimulatedOnly, COND_AutonomousOnly, COND_SimulatedOrPhysics,
    COND_InitialOrOwner, COND_Custom, COND_ReplayOrOwner, COND_ReplayOnly,
    COND_SimulatedOnlyNoReplay, COND_SimulatedOrPhysicsNoReplay,
    COND_SkipReplay, COND_Never, COND_Max

  ELifetimeRepNotifyCondition* {.size: sizeof(uint8), pure, importcpp .} = enum
    REPNOTIFY_OnChanged,  # Only call the property's RepNotify function if it changes from the local value
    REPNOTIFY_Always,  #Always Call the property's RepNotify function when it is received from the server

  ESearchCase* {.size: sizeof(uint8), pure.} = enum
    CaseSensitive, IgnoreCase, ESearchCase_MAX
  ESearchDir* {.size: sizeof(uint8), pure.} = enum
    FromStart, FromEnd, ESearchDir_MAX
  ELogTimes* {.size: sizeof(uint8), pure.} = enum
    None, UTC, SinceGStartTime, Local, ELogTimes_MAX
  EAxis* {.size: sizeof(uint8), pure.} = enum
    None, X, Y, Z, EAxis_MAX
  EPixelFormat* {.size: sizeof(uint8), pure.} = enum
    PF_Unknown, PF_A32B32G32R32F, PF_B8G8R8A8, PF_G8, PF_G16, PF_DXT1, PF_DXT3,
    PF_DXT5, PF_UYVY, PF_FloatRGB, PF_FloatRGBA, PF_DepthStencil,
    PF_ShadowDepth, PF_R32_FLOAT, PF_G16R16, PF_G16R16F, PF_G16R16F_FILTER,
    PF_G32R32F, PF_A2B10G10R10, PF_A16B16G16R16, PF_D24, PF_R16F,
    PF_R16F_FILTER, PF_BC5, PF_V8U8, PF_A1, PF_FloatR11G11B10, PF_A8,
    PF_R32_UINT, PF_R32_SINT, PF_PVRTC2, PF_PVRTC4, PF_R16_UINT, PF_R16_SINT,
    PF_R16G16B16A16_UINT, PF_R16G16B16A16_SINT, PF_R5G6B5_UNORM, PF_R8G8B8A8,
    PF_A8R8G8B8, PF_BC4, PF_R8G8, PF_ATC_RGB, PF_ATC_RGBA_E, PF_ATC_RGBA_I,
    PF_X24_G8, PF_ETC1, PF_ETC2_RGB, PF_ETC2_RGBA, PF_R32G32B32A32_UINT,
    PF_R16G16_UINT, PF_ASTC_4x4, PF_ASTC_6x6, PF_ASTC_8x8, PF_ASTC_10x10,
    PF_ASTC_12x12, PF_BC6H, PF_BC7, PF_R8_UINT, PF_L8, PF_XGXR8,
    PF_R8G8B8A8_UINT, PF_R8G8B8A8_SNORM, PF_R16G16B16A16_UNORM,
    PF_R16G16B16A16_SNORM, PF_PLATFORM_HDR_0, PF_PLATFORM_HDR_1,
    PF_PLATFORM_HDR_2, PF_NV12, PF_R32G32_UINT, PF_ETC2_R11_EAC,
    PF_ETC2_RG11_EAC, PF_R8, PF_B5G5R5A1_UNORM, PF_G16R16_SNORM, PF_R8G8_UINT,
    PF_R32G32B32_UINT, PF_R32G32B32_SINT, PF_R32G32B32F, PF_R8_SINT,
    PF_R64_UINT, PF_MAX
  EMouseCursor* {.size: sizeof(uint8), pure.} = enum
    None, Default, TextEditBeam, ResizeLeftRight, ResizeUpDown, ResizeSouthEast,
    ResizeSouthWest, CardinalCross, Crosshairs, Hand, GrabHand, GrabHandClosed,
    SlashedCircle, EyeDropper, EMouseCursor_MAX
  EUnit* {.size: sizeof(uint8), pure.} = enum
    Micrometers, Millimeters, Centimeters, Meters, Kilometers, Inches, Feet,
    Yards, Miles, Lightyears, Degrees, Radians, CentimetersPerSecond,
    MetersPerSecond, KilometersPerHour, MilesPerHour, Celsius, Farenheit,
    Kelvin, Micrograms, Milligrams, Grams, Kilograms, MetricTons, Ounces,
    Pounds, Stones, Newtons, PoundsForce, KilogramsForce, Hertz, Kilohertz,
    Megahertz, Gigahertz, RevolutionsPerMinute, Bytes, Kilobytes, Megabytes,
    Gigabytes, Terabytes, Lumens, Milliseconds, Seconds, Minutes, Hours, Days,
    Months, Years, Multiplier, Percentage, Unspecified, EUnit_MAX
  EPropertyAccessChangeNotifyMode* {.size: sizeof(uint8), pure.} = enum
    Default, Never, Always, EPropertyAccessChangeNotifyMode_MAX
  EAppReturnType* {.size: sizeof(uint8), pure.} = enum
    No, Yes, YesAll, NoAll, Cancel, Ok, Retry, Continue, EAppReturnType_MAX
  EAppMsgType* {.size: sizeof(uint8), pure.} = enum
    Ok, YesNo, OkCancel, YesNoCancel, CancelRetryContinue, YesNoYesAllNoAll,
    YesNoYesAllNoAllCancel, YesNoYesAll, EAppMsgType_MAX
  EDataValidationResult* {.size: sizeof(uint8), pure.} = enum
    Invalid, Valid, NotValidated, EDataValidationResult_MAX

let identity* {.importcpp: "FTransform::Identity", nodecl.}: FTransform 
proc getTicks*(dt: FDateTime): int {.importcpp: "GetTicks".}

func getLocation*(tr: FTransform): FVector {.importcpp: "#.GetLocation()".}
func getTranslation*(tr: FTransform): FVector {.importcpp: "#.GetTranslation()".}
func getRotation*(tr: FTransform): FQuat {.importcpp: "#.GetRotation()".}
func getScale3D*(tr: FTransform): FVector {.importcpp: "#.GetScale3D()".}
func getUnitAxis*(tr: FTransform, axis: EAxis): FVector {.importcpp: "#.GetUnitAxis(@)".}
func toString*(tr: FTransform): FString {.importcpp: "#.ToString()".}
func `$`*(tr: FTransform): string = $tr.toString()

proc setLocation*(tr: FTransform, value: FVector) {.importcpp: "#.SetLocation(@)".}
proc setTranslation*(tr: FTransform, value: FVector) {.importcpp: "#.SetTranslation(@)".}
proc setRotation*(tr: FTransform, value: FQuat) {.importcpp: "#.SetRotation(@)".}
proc setScale3D*(tr: FTransform, value: FVector) {.importcpp: "#.SetScale3D(@)".}

func location*(tr: FTransform): FVector {.importcpp: "#.GetLocation()".}
func translation*(tr: FTransform): FVector {.importcpp: "#.GetTranslation()".}
func rotation*(tr: FTransform): FQuat {.importcpp: "#.GetRotation()".}
func scale3D*(tr: FTransform): FVector {.importcpp: "#.GetScale3D()".}

func `location=`*(tr: FTransform, value: FVector) {.importcpp: "#.SetLocation(@)".}
func `translation=`*(tr: FTransform, value: FVector) {.importcpp: "#.SetTranslation(@)".}
func `rotation=`*(tr: FTransform, value: FQuat) {.importcpp: "#.SetRotation(@)".}
func `scale3D=`*(tr: FTransform, value: FVector) {.importcpp: "#.SetScale3D(@)".}

proc normalizeRotation*(tr: FTransform) {.importcpp: "#.NormalizeRotation()".}

func makeFTransform*(location: FVector, rotation: FQuat, scale: FVector): FTransform = 
  var transform = FTransform()
  transform.setLocation(location)
  transform.setRotation(rotation)
  transform.setScale3D(scale)
  transform

func makeFTransform*(location: FVector, rotation: FQuat): FTransform = 
  #makes a transform with no rotation and scale
  {.cast(noSideEffect).}:
    var transform = identity
    transform.setLocation(location)  
    transform.setRotation(rotation)
    transform

func makeFTransform*(location: FVector): FTransform = 
  #makes a transform with no rotation and scale
  {.cast(noSideEffect).}:
    var transform = identity
    transform.setLocation(location)  
    transform.normalizeRotation()
    transform

func `*`*(a, b: FRotator): FRotator {.importcpp: "#*#".}
func `*`*(a, b: FQuat): FQuat {.importcpp: "#*#".}

func toFVector*(v: FVector4) : FVector = makeFVector(v.x, v.y, v.z)

#Asset
proc toSoftObjectPath*(assetData:FAssetData) : FSoftObjectPath {.importcpp: "#.ToSoftObjectPath()".}
proc tryLoad*(softObjectPath:FSoftObjectPath) : UObjectPtr {.importcpp: "#.TryLoad()".}

proc flip*(plane: FPlane): FPlane {.importcpp: "#.Flip()".}

#operations
func `+`*(a,b: FVector2D): FVector2D {.importcpp:"# + #".}
func `-`*(a,b: FVector2D): FVector2D {.importcpp:"# - #".}
func `*`*(a : SomeFloat | SomeNumber, b: FVector2D): FVector2D {.importcpp:"# * #".}
func `*`*(a : FVector2D, b: SomeNumber | SomeFloat): FVector2D {.importcpp:"# * #".}

func `+`*(a,b: FRotator): FRotator {.importcpp:"# + #".}

func toVector*(vec2: FVector2D, z: float32 = 0): FVector = makeFVector(vec2.x, vec2.y, z)
func getCenterAndExtents*(box: FBox, center, extends: var FVector) {.importcpp: "#.GetCenterAndExtents(@)".}
func getCenter*(box: FBox): FVector {.importcpp: "#.GetCenter()".}
func getExtent*(box: FBox): FVector {.importcpp: "#.GetExtent()".}
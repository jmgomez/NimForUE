import ../core/containers/[array, unrealstring, map]
import nametypes
import ../core/math/vector
import ../core/[ftext]
import uobject

{.experimental:"codereordering".}



type
  FAssetBundleData* {.importcpp.} = object
    bundles* {.importcpp: "Bundles".}: TArray[FAssetBundleEntry]

type
  FAssetBundleEntry* {.importcpp.} = object
    bundleAssets* {.importcpp: "BundleAssets".}: TArray[FSoftObjectPath]
    bundleName* {.importcpp: "BundleName".}: FName

type
  FSoftObjectPath* {.importcpp.} = object
    subPathString* {.importcpp: "SubPathString".}: FString
    assetPathName* {.importcpp: "AssetPathName".}: FName

type
  FAssetData* {.importcpp.} = object
    assetClass* {.importcpp: "AssetClass".}: FName
    assetName* {.importcpp: "AssetName".}: FName
    packagePath* {.importcpp: "PackagePath".}: FName
    packageName* {.importcpp: "PackageName".}: FName
    objectPath* {.importcpp: "ObjectPath".}: FName

type
  FAutomationEvent* {.importcpp.} = object
    artifact* {.importcpp: "Artifact".}: FGuid
    context* {.importcpp: "Context".}: FString
    message* {.importcpp: "Message".}: FString
    `type`* {.importcpp: "Type".}: EAutomationEventType

type
  FGuid* {.importcpp.} = object
    d* {.importcpp: "D".}: int32
    c* {.importcpp: "C".}: int32
    b* {.importcpp: "B".}: int32
    a* {.importcpp: "A".}: int32

type
  EAutomationEventType* {.size: sizeof(uint8), pure.} = enum
    Info, Warning, Error, EAutomationEventType_MAX
type
  FAutomationExecutionEntry* {.importcpp.} = object
    timestamp* {.importcpp: "Timestamp".}: FDateTime
    lineNumber* {.importcpp: "LineNumber".}: int32
    filename* {.importcpp: "Filename".}: FString
    event* {.importcpp: "Event".}: FAutomationEvent

type
  FDateTime* {.importcpp.} = object

proc getTicks*(self: FDateTime): int {.importcpp: "GetTicks".}
  
type
  FBox* {.importcpp.} = object
    isValid* {.importcpp: "IsValid".}: uint8
    max* {.importcpp: "Max".}: FVector
    min* {.importcpp: "Min".}: FVector

type
  FBox2D* {.importcpp.} = object
    bIsValid* {.importcpp: "bIsValid".}: uint8
    max* {.importcpp: "Max".}: FVector2D
    min* {.importcpp: "Min".}: FVector2D

type
  FVector2D* {.importcpp.} = object
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

type
  FBox2f* {.importcpp.} = object
    bIsValid* {.importcpp: "bIsValid".}: uint8
    max* {.importcpp: "Max".}: FVector2f
    min* {.importcpp: "Min".}: FVector2f

type
  FVector2f* {.importcpp.} = object
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

type
  FBox3d* {.importcpp.} = object
    isValid* {.importcpp: "IsValid".}: uint8
    max* {.importcpp: "Max".}: FVector3d
    min* {.importcpp: "Min".}: FVector3d

type
  FVector3d* {.importcpp, inheritable, pure .} = object
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

type
  FBox3f* {.importcpp.} = object
    isValid* {.importcpp: "IsValid".}: uint8
    max* {.importcpp: "Max".}: FVector3f
    min* {.importcpp: "Min".}: FVector3f

type
  FVector3f* {.importcpp, inheritable, pure.} = object
    z* {.importcpp: "Z".}: float32
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

type
  FBoxSphereBounds* {.importcpp.} = object
    sphereRadius* {.importcpp: "SphereRadius".}: float64
    boxExtent* {.importcpp: "BoxExtent".}: FVector
    origin* {.importcpp: "Origin".}: FVector

type
  FBoxSphereBounds3d* {.importcpp.} = object
    sphereRadius* {.importcpp: "SphereRadius".}: float64
    boxExtent* {.importcpp: "BoxExtent".}: FVector3d
    origin* {.importcpp: "Origin".}: FVector3d

type
  FBoxSphereBounds3f* {.importcpp.} = object
    sphereRadius* {.importcpp: "SphereRadius".}: float32
    boxExtent* {.importcpp: "BoxExtent".}: FVector3f
    origin* {.importcpp: "Origin".}: FVector3f

type
  FColor* {.importcpp.} = object
    a* {.importcpp: "A".}: uint8
    r* {.importcpp: "R".}: uint8
    g* {.importcpp: "G".}: uint8
    b* {.importcpp: "B".}: uint8

type
  FDirectoryPath* {.importcpp.} = object
    path* {.importcpp: "Path".}: FString

type
  FFallbackStruct* {.importcpp.} = object
  
type
  FFilePath* {.importcpp.} = object
    filePath* {.importcpp: "FilePath".}: FString

type
  FFloatInterval* {.importcpp.} = object
    max* {.importcpp: "Max".}: float32
    min* {.importcpp: "Min".}: float32

type
  FFloatRange* {.importcpp.} = object
    upperBound* {.importcpp: "UpperBound".}: FFloatRangeBound
    lowerBound* {.importcpp: "LowerBound".}: FFloatRangeBound

type
  FFloatRangeBound* {.importcpp.} = object
    value* {.importcpp: "Value".}: float32
    `type`* {.importcpp: "Type".}: ERangeBoundTypes

type
  ERangeBoundTypes* {.size: sizeof(uint8), pure.} = enum
    Exclusive, Inclusive, Open, ERangeBoundTypes_MAX
type
  FFrameNumber* {.importcpp.} = object
    value* {.importcpp: "Value".}: int32

type
  FFrameNumberRange* {.importcpp.} = object
    upperBound* {.importcpp: "UpperBound".}: FFrameNumberRangeBound
    lowerBound* {.importcpp: "LowerBound".}: FFrameNumberRangeBound

type
  FFrameNumberRangeBound* {.importcpp.} = object
    value* {.importcpp: "Value".}: FFrameNumber
    `type`* {.importcpp: "Type".}: ERangeBoundTypes

type
  FFrameRate* {.importcpp.} = object
    denominator* {.importcpp: "Denominator".}: int32
    numerator* {.importcpp: "Numerator".}: int32

type
  FFrameTime* {.importcpp.} = object
    subFrame* {.importcpp: "SubFrame".}: float32
    frameNumber* {.importcpp: "FrameNumber".}: FFrameNumber

type
  FInt32Interval* {.importcpp.} = object
    max* {.importcpp: "Max".}: int32
    min* {.importcpp: "Min".}: int32

type
  FInt32Range* {.importcpp.} = object
    upperBound* {.importcpp: "UpperBound".}: FInt32RangeBound
    lowerBound* {.importcpp: "LowerBound".}: FInt32RangeBound

type
  FInt32RangeBound* {.importcpp.} = object
    value* {.importcpp: "Value".}: int32
    `type`* {.importcpp: "Type".}: ERangeBoundTypes

type
  FInterpCurveFloat* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointFloat]

type
  FInterpCurvePointFloat* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: float32
    arriveTangent* {.importcpp: "ArriveTangent".}: float32
    outVal* {.importcpp: "OutVal".}: float32
    inVal* {.importcpp: "InVal".}: float32

type
  EInterpCurveMode* {.size: sizeof(uint8), pure.} = enum
    CIM_Linear, CIM_CurveAuto, CIM_Constant, CIM_CurveUser, CIM_CurveBreak,
    CIM_CurveAutoClamped, CIM_MAX
type
  FInterpCurveLinearColor* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointLinearColor]

type
  FInterpCurvePointLinearColor* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FLinearColor
    arriveTangent* {.importcpp: "ArriveTangent".}: FLinearColor
    outVal* {.importcpp: "OutVal".}: FLinearColor
    inVal* {.importcpp: "InVal".}: float32

type
  FLinearColor* {.importcpp.} = object
    a* {.importcpp: "A".}: float32
    b* {.importcpp: "B".}: float32
    g* {.importcpp: "G".}: float32
    r* {.importcpp: "R".}: float32

type
  FInterpCurvePointQuat* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FQuat
    arriveTangent* {.importcpp: "ArriveTangent".}: FQuat
    outVal* {.importcpp: "OutVal".}: FQuat
    inVal* {.importcpp: "InVal".}: float32

type
  FQuat* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

type
  FInterpCurvePointTwoVectors* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FTwoVectors
    arriveTangent* {.importcpp: "ArriveTangent".}: FTwoVectors
    outVal* {.importcpp: "OutVal".}: FTwoVectors
    inVal* {.importcpp: "InVal".}: float32

type
  FTwoVectors* {.importcpp.} = object
    v2* {.importcpp: "v2".}: FVector
    v1* {.importcpp: "v1".}: FVector

type
  FInterpCurvePointVector* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FVector
    arriveTangent* {.importcpp: "ArriveTangent".}: FVector
    outVal* {.importcpp: "OutVal".}: FVector
    inVal* {.importcpp: "InVal".}: float32

type
  FInterpCurvePointVector2D* {.importcpp.} = object
    interpMode* {.importcpp: "InterpMode".}: EInterpCurveMode
    leaveTangent* {.importcpp: "LeaveTangent".}: FVector2D
    arriveTangent* {.importcpp: "ArriveTangent".}: FVector2D
    outVal* {.importcpp: "OutVal".}: FVector2D
    inVal* {.importcpp: "InVal".}: float32

type
  FInterpCurveQuat* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointQuat]

type
  FInterpCurveTwoVectors* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointTwoVectors]

type
  FInterpCurveVector* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointVector]

type
  FInterpCurveVector2D* {.importcpp.} = object
    loopKeyOffset* {.importcpp: "LoopKeyOffset".}: float32
    bIsLooped* {.importcpp: "bIsLooped".}: bool
    points* {.importcpp: "Points".}: TArray[FInterpCurvePointVector2D]

type
  FIntPoint* {.importcpp.} = object
    y* {.importcpp: "Y".}: int32
    x* {.importcpp: "X".}: int32

type
  FIntVector* {.importcpp.} = object
    z* {.importcpp: "Z".}: int32
    y* {.importcpp: "Y".}: int32
    x* {.importcpp: "X".}: int32

type
  FMatrix* {.importcpp.} = object
    wPlane* {.importcpp: "WPlane".}: FPlane
    zPlane* {.importcpp: "ZPlane".}: FPlane
    yPlane* {.importcpp: "YPlane".}: FPlane
    xPlane* {.importcpp: "XPlane".}: FPlane

type
  FPlane* {.importcpp.} = object of FVector
    w* {.importcpp: "W".}: float64

type
  FMatrix44d* {.importcpp.} = object
    wPlane* {.importcpp: "WPlane".}: FPlane4d
    zPlane* {.importcpp: "ZPlane".}: FPlane4d
    yPlane* {.importcpp: "YPlane".}: FPlane4d
    xPlane* {.importcpp: "XPlane".}: FPlane4d

type
  FPlane4d* {.importcpp, .} = object of FVector3d
    w* {.importcpp: "W".}: float64

type
  FMatrix44f* {.importcpp.} = object
    wPlane* {.importcpp: "WPlane".}: FPlane4f
    zPlane* {.importcpp: "ZPlane".}: FPlane4f
    yPlane* {.importcpp: "YPlane".}: FPlane4f
    xPlane* {.importcpp: "XPlane".}: FPlane4f

type
  FPlane4f* {.importcpp.} = object of FVector3f
    w* {.importcpp: "W".}: float32

type
  FOrientedBox* {.importcpp.} = object
    extentZ* {.importcpp: "ExtentZ".}: float64
    extentY* {.importcpp: "ExtentY".}: float64
    extentX* {.importcpp: "ExtentX".}: float64
    axisZ* {.importcpp: "AxisZ".}: FVector
    axisY* {.importcpp: "AxisY".}: FVector
    axisX* {.importcpp: "AxisX".}: FVector
    center* {.importcpp: "Center".}: FVector

type
  FPackedNormal* {.importcpp.} = object
    w* {.importcpp: "W".}: uint8
    z* {.importcpp: "Z".}: uint8
    y* {.importcpp: "Y".}: uint8
    x* {.importcpp: "X".}: uint8

type
  FPackedRGB10A2N* {.importcpp.} = object
    packed* {.importcpp: "Packed".}: int32

type
  FPackedRGBA16N* {.importcpp.} = object
    zW* {.importcpp: "ZW".}: int32
    xY* {.importcpp: "XY".}: int32

type
  FPolyglotTextData* {.importcpp.} = object
    cachedText* {.importcpp: "CachedText".}: FText
    bIsMinimalPatch* {.importcpp: "bIsMinimalPatch".}: bool
    localizedStrings* {.importcpp: "LocalizedStrings".}: TMap[FString, FString]
    nativeString* {.importcpp: "NativeString".}: FString
    key* {.importcpp: "Key".}: FString
    namespace* {.importcpp: "Namespace".}: FString
    nativeCulture* {.importcpp: "NativeCulture".}: FString
    category* {.importcpp: "Category".}: ELocalizedTextSourceCategory

type
  ELocalizedTextSourceCategory* {.size: sizeof(uint8), pure.} = enum
    Game, Engine, Editor, ELocalizedTextSourceCategory_MAX
type
  FPrimaryAssetId* {.importcpp.} = object
    primaryAssetName* {.importcpp: "PrimaryAssetName".}: FName
    primaryAssetType* {.importcpp: "PrimaryAssetType".}: FPrimaryAssetType

type
  FPrimaryAssetType* {.importcpp.} = object
    name* {.importcpp: "Name".}: FName

type
  FQualifiedFrameTime* {.importcpp.} = object
    rate* {.importcpp: "Rate".}: FFrameRate
    time* {.importcpp: "Time".}: FFrameTime

type
  FQuat4d* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

type
  FQuat4f* {.importcpp.} = object
    w* {.importcpp: "W".}: float32
    z* {.importcpp: "Z".}: float32
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

type
  FRandomStream* {.importcpp.} = object
    seed* {.importcpp: "Seed".}: int32
    initialSeed* {.importcpp: "InitialSeed".}: int32

type
  FRotator* {.importcpp.} = object
    roll* {.importcpp: "Roll".}: float64
    yaw* {.importcpp: "Yaw".}: float64
    pitch* {.importcpp: "Pitch".}: float64

type
  FRotator3d* {.importcpp.} = object
    roll* {.importcpp: "Roll".}: float64
    yaw* {.importcpp: "Yaw".}: float64
    pitch* {.importcpp: "Pitch".}: float64

type
  FRotator3f* {.importcpp.} = object
    roll* {.importcpp: "Roll".}: float32
    yaw* {.importcpp: "Yaw".}: float32
    pitch* {.importcpp: "Pitch".}: float32

type
  FSoftClassPath* {.importcpp.} = object
  
type
  FTestUninitializedScriptStructMembersTest* {.importcpp.} = object
    unusedValue* {.importcpp: "UnusedValue".}: float32
    initializedObjectReference* {.importcpp: "InitializedObjectReference".}: TObjectPtr[
        UObject]
    uninitializedObjectReference* {.importcpp: "UninitializedObjectReference".}: TObjectPtr[
        UObject]

type
  FTimecode* {.importcpp.} = object
    bDropFrameFormat* {.importcpp: "bDropFrameFormat".}: bool
    frames* {.importcpp: "Frames".}: int32
    seconds* {.importcpp: "Seconds".}: int32
    minutes* {.importcpp: "Minutes".}: int32
    hours* {.importcpp: "Hours".}: int32

type
  FTimespan* {.importcpp.} = object
  
type
  FTransform* {.importcpp, bycopy.} = object
    # scale3D* {.importcpp: "Scale3D".}: FVector
    # translation* {.importcpp: "Translation".}: FVector
    # rotation* {.importcpp: "Rotation".}: FQuat

type
  FTransform3d* {.importcpp.} = object
    scale3D* {.importcpp: "Scale3D".}: FVector3d
    translation* {.importcpp: "Translation".}: FVector3d
    rotation* {.importcpp: "Rotation".}: FQuat4d

type
  FTransform3f* {.importcpp.} = object
    scale3D* {.importcpp: "Scale3D".}: FVector3f
    translation* {.importcpp: "Translation".}: FVector3f
    rotation* {.importcpp: "Rotation".}: FQuat4f

type
  FVector4* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

type
  FVector4d* {.importcpp.} = object
    w* {.importcpp: "W".}: float64
    z* {.importcpp: "Z".}: float64
    y* {.importcpp: "Y".}: float64
    x* {.importcpp: "X".}: float64

type
  FVector4f* {.importcpp.} = object
    w* {.importcpp: "W".}: float32
    z* {.importcpp: "Z".}: float32
    y* {.importcpp: "Y".}: float32
    x* {.importcpp: "X".}: float32

type
  ELifetimeCondition* {.size: sizeof(uint8), pure.} = enum
    COND_None, COND_InitialOnly, COND_OwnerOnly, COND_SkipOwner,
    COND_SimulatedOnly, COND_AutonomousOnly, COND_SimulatedOrPhysics,
    COND_InitialOrOwner, COND_Custom, COND_ReplayOrOwner, COND_ReplayOnly,
    COND_SimulatedOnlyNoReplay, COND_SimulatedOrPhysicsNoReplay,
    COND_SkipReplay, COND_Never, COND_Max

  ELifetimeRepNotifyCondition* {.size: sizeof(uint8), pure.} = enum
    REPNOTIFY_OnChanged,  # Only call the property's RepNotify function if it changes from the local value
    REPNOTIFY_Always,  #Always Call the property's RepNotify function when it is received from the server

type
  ESearchCase* {.size: sizeof(uint8), pure.} = enum
    CaseSensitive, IgnoreCase, ESearchCase_MAX
type
  ESearchDir* {.size: sizeof(uint8), pure.} = enum
    FromStart, FromEnd, ESearchDir_MAX
type
  ELogTimes* {.size: sizeof(uint8), pure.} = enum
    None, UTC, SinceGStartTime, Local, ELogTimes_MAX
type
  EAxis* {.size: sizeof(uint8), pure.} = enum
    None, X, Y, Z, EAxis_MAX
type
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
type
  EMouseCursor* {.size: sizeof(uint8), pure.} = enum
    None, Default, TextEditBeam, ResizeLeftRight, ResizeUpDown, ResizeSouthEast,
    ResizeSouthWest, CardinalCross, Crosshairs, Hand, GrabHand, GrabHandClosed,
    SlashedCircle, EyeDropper, EMouseCursor_MAX
type
  EUnit* {.size: sizeof(uint8), pure.} = enum
    Micrometers, Millimeters, Centimeters, Meters, Kilometers, Inches, Feet,
    Yards, Miles, Lightyears, Degrees, Radians, CentimetersPerSecond,
    MetersPerSecond, KilometersPerHour, MilesPerHour, Celsius, Farenheit,
    Kelvin, Micrograms, Milligrams, Grams, Kilograms, MetricTons, Ounces,
    Pounds, Stones, Newtons, PoundsForce, KilogramsForce, Hertz, Kilohertz,
    Megahertz, Gigahertz, RevolutionsPerMinute, Bytes, Kilobytes, Megabytes,
    Gigabytes, Terabytes, Lumens, Milliseconds, Seconds, Minutes, Hours, Days,
    Months, Years, Multiplier, Percentage, Unspecified, EUnit_MAX
type
  EPropertyAccessChangeNotifyMode* {.size: sizeof(uint8), pure.} = enum
    Default, Never, Always, EPropertyAccessChangeNotifyMode_MAX
type
  EAppReturnType* {.size: sizeof(uint8), pure.} = enum
    No, Yes, YesAll, NoAll, Cancel, Ok, Retry, Continue, EAppReturnType_MAX
type
  EAppMsgType* {.size: sizeof(uint8), pure.} = enum
    Ok, YesNo, OkCancel, YesNoCancel, CancelRetryContinue, YesNoYesAllNoAll,
    YesNoYesAllNoAllCancel, YesNoYesAll, EAppMsgType_MAX
type
  EDataValidationResult* {.size: sizeof(uint8), pure.} = enum
    Invalid, Valid, NotValidated, EDataValidationResult_MAX



let identity* {.importcpp: "FTransform::Identity", nodecl.}: FTransform 

func getLocation*(self: FTransform): FVector {.importcpp: "#.GetLocation()".}
func getTranslation*(self: FTransform): FVector {.importcpp: "#.GetTranslation()".}
func getRotation*(self: FTransform): FQuat {.importcpp: "#.GetRotation()".}
func getScale3D*(self: FTransform): FVector {.importcpp: "#.GetScale3D()".}
func getUnitAxis*(self: FTransform, axis: EAxis): FVector {.importcpp: "#.GetUnitAxis(@)".}
func toString*(self: FTransform): FString {.importcpp: "#.ToString()".}
func `$`*(self: FTransform): string = $self.toString()

proc setLocation*(self: FTransform, value: FVector) {.importcpp: "#.SetLocation(@)".}
proc setTranslation*(self: FTransform, value: FVector) {.importcpp: "#.SetTranslation(@)".}
proc setRotation*(self: FTransform, value: FQuat) {.importcpp: "#.SetRotation(@)".}
proc setScale3D*(self: FTransform, value: FVector) {.importcpp: "#.SetScale3D(@)".}

func location*(self: FTransform): FVector {.importcpp: "#.GetLocation()".}
func translation*(self: FTransform): FVector {.importcpp: "#.GetTranslation()".}
func rotation*(self: FTransform): FQuat {.importcpp: "#.GetRotation()".}
func scale3D*(self: FTransform): FVector {.importcpp: "#.GetScale3D()".}

func `location=`*(self: FTransform, value: FVector) {.importcpp: "#.SetLocation(@)".}
func `translation=`*(self: FTransform, value: FVector) {.importcpp: "#.SetTranslation(@)".}
func `rotation=`*(self: FTransform, value: FQuat) {.importcpp: "#.SetRotation(@)".}
func `scale3D=`*(self: FTransform, value: FVector) {.importcpp: "#.SetScale3D(@)".}

proc makeFTransform*(location: FVector, rotation: FQuat, scale: FVector): FTransform = 
  var transform = FTransform()
  transform.location = location
  transform.rotation = rotation
  transform.scale3D = scale
  transform



func `*`*(a, b: FRotator): FRotator {.importcpp: "#*#".}
func `*`*(a, b: FQuat): FQuat {.importcpp: "#*#".}

#Asset
proc toSoftObjectPath*(assetData:FAssetData) : FSoftObjectPath {.importcpp: "#.ToSoftObjectPath()".}
proc tryLoad*(softObjectPath:FSoftObjectPath) : UObjectPtr {.importcpp: "#.TryLoad()".}
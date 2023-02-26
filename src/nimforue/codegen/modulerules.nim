# import ../unreal/coreuobject/uobjectflags
import std/[sequtils, options, sugar, tables]
import ../utils/utils


const ManuallyImportedClasses* = @[ 
  #we could have this list being generated automatically by using a pragma on the imported cpp
      "AActor", "AInfo", "UReflectionHelpers", "UObject", "UEngine", "APawn",
      "UField", "UStruct", "UScriptStruct", "UPackage", "UPackageMap",
      "UClass", "UFunction", "UDelegateFunction",
      "UEnum", "AVolume", "UInterface", 
      "UActorComponent","AController","AGameMode", "AGameModeBase",
      "UBlueprint", "UBlueprintGeneratedClass",
      "APlayerController", "UAnimBlueprintGeneratedClass",
      "UEngineSubsystem", "USubsystem", "UDynamicSubsystem", "UWorldSubsystem",
      "USceneComponent", "UPrimitiveComponent",
      "UWorld",
      "UInputComponent",
      "UEnhancedInputComponent",
      "UInputAction",
      "UPlayerInput",
      "UEnhancedPlayerInput",
      "UPhysicalMaterial", 
      "UTickableWorldSubsystem",
      "UGameViewportClient",
      "UNavigationSystemConfig","UNavigationSystemModuleConfig"

]

type
     #Rules applies to UERuleTarget
    UERule* = enum
        uerNone
        uerCodeGenOnlyFields #wont generate the type. Just its fields. Only make sense in uClass. Will affect code generation (we try to do it at the import time when possible) 
        uerIgnore
        uerImportStruct
        uerImportBlueprintOnly #affects all types and all target. If set, it will only import the blueprint types.
        uerVirtualModule
        uerInnerClassDelegate #Some delegates are declared withit a class and can collide. This rule is for when both are true
        uerIgnoreHash #ignore the hash when importing a module so always imports it. 
        uerForce #Force the import of a type. This is useful for types that are not exported by default but we want to import them anyway
        uerExcludeDeps #Module deps to exclude from the module. They are in affectTypes. Module rule only
    UERuleTarget* = enum 
        uertType
        uertField
        uertModule
    #TODO Rename to UEBindRule
    UEImportRule* = object #used only to customize the codegen
        affectedTypes* : seq[string]
        target* : UERuleTarget
        case  rule* : UERule
        of uerVirtualModule:
            moduleName* : string
        of uerInnerClassDelegate: 
            onlyFor* : seq[string] #Constraints the types that the rule applies to. If empty, it applies to all types.  
        else:
            discard



# func `or`(a, b : UERule) : UERule = bitor(a.uint32, b.uint32).UERule

func makeImportedRuleType*(rule:UERule, affectedTypes:seq[string], ):UEImportRule =
    result.affectedTypes = affectedTypes
    result.rule = rule
    result.target = uertType

func makeImportedRuleField*(rule:UERule, affectedTypes:seq[string], ):UEImportRule =
    result.affectedTypes = affectedTypes
    result.rule = rule
    result.target = uertField
    
func makeImportedRuleModule*(rule:UERule) : UEImportRule = 
    result.rule = rule
    result.target = uertModule


#Notice the param restrictions on the functions below. Either you apply the rule to multiple types or you chose what types to apply in a single rule
func makeImportedDelegateRule*(affectedTypes:seq[string]) : UEImportRule = 
    result.affectedTypes = affectedTypes
    result.rule = uerInnerClassDelegate
    result.target = uertType

func makeImportedDelegateRule*(affectedType:string, onlyFor:seq[string]) : UEImportRule = 
    result.affectedTypes = @[affectedType]
    result.rule = uerInnerClassDelegate
    result.target = uertType
    result.onlyFor = onlyFor

#It's processed after the module deps are calculated
func makeVirtualModuleRule*(moduleName:string, affectedTypes:seq[string]) : UEImportRule = 
    result.rule = uerVirtualModule
    result.target = uertModule
    result.affectedTypes = affectedTypes
    result.moduleName = moduleName

func makeExcludeDepsRule*(modulesToExclude:seq[string]) : UEImportRule = 
    result.rule = uerExcludeDeps
    result.target = uertModule
    result.affectedTypes = modulesToExclude



func contains*(rules: seq[UEImportRule], rule:UERule): bool = 
    rules.any((r:UEImportRule) => r.rule == rule)

func isTypeAffectedByRule*(rules:seq[UEImportRule], name:string, rule:UERule): bool = 
    rules.any((r:UEImportRule) => r.target == uertType and r.rule == rule and r.affectedTypes.contains(name))
func getRuleAffectingType*(rules:seq[UEImportRule], name:string, rule:UERule): Option[UEImportRule] = 
    rules.first((r:UEImportRule) => r.target == uertType and r.rule == rule and r.affectedTypes.contains(name))



#Any module not picked by default.
#This could be exposed to the json file 
let extraModuleNames* = @["EnhancedInput", "Blutility", "AudioMixer", "Chaos", "AssetRegistry", "NavigationSystem", "Niagara", "NiagaraShader", 
"Constraints", "MovieSceneTools", "HoudiniEngine", "HoudiniEngineEditor", "Landscape", "Iris",
"ControlRig", "DataLayerEditor", "DataRegistry", "ActorLayerUtilities"]
#By default modules import only bp symbols because it's the safest option
#The module listed below will be an exception (alongside the ones in moduleRules that doesnt say it explicitaly)
#TODO add a hook to the user
let extraNonBpModules* = @["DeveloperSettings", "EnhancedInput", "Blutility", "AssetRegistry", "CommonUI", "CommonInput", "AudioMixer",
"NavigationSystem", "DungeonArchitectRuntime", "NiagaraCore", "GameSettings", "CommonGame",  "SignificanceManager", "Gauntlet",
"GameFeatures", "DataRegistry", "CommonConversationRuntime","BlueprintGraph", "Chaos",  "PhysicsUtilities", "AnimationCore",
"ActorLayerUtilities", "NiagaraEditor", "NiagaraShader", "DataLayerEditor", "Water", 
"GameplayAbilities", "ModularGameplay", "LyraGame"]
#CodegenOnly directly affects the Engine module but needs to be passed around
#for all modules because the one classes listed here are importc one so we dont mangle them 


const codeGenOnly* = makeImportedRuleType(uerCodeGenOnlyFields, ManuallyImportedClasses)

let moduleImportRules* = newTable[string, seq[UEImportRule]]()
moduleImportRules["Engine"] = @[
    codegenOnly, 
    makeExcludeDepsRule(@[ "UMG", "Chaos", "AudioMixer", "Landscape", "LyraGame" ]),
    makeImportedRuleType(uerIgnore, @[
    "FVector", "FSlateBrush", "FVector_NetQuantize", "FVector_NetQuantize10",
    "FVector_NetQuantize10", "FVector_NetQuantize100", "FVector_NetQuantizeNormal",
    "FHitResult","FActorInstanceHandle",
    #issue with a field name 
    "FTransformConstraint", 
    "FTableRowBase",
    "ECollisionChannel", "EObjectTypeQuery", "ETraceTypeQuery",
    "EInputEvent",
    # "UKismetMathLibrary", #issue with the funcs?,
    "FOnTemperatureChangeDelegate", #Mac gets stuck here?,
    # "UParticleSystem", #collision with a function name and Cascade is deprecated, use Niagara instead.
    "UNetFaultConfig", "FActorTickFunction",
    ]), 
    # makeImportedRuleModule(uerIgnoreHash),
    
  makeImportedRuleField(uerIgnore, @[
    "FOnTemperatureChangeDelegate",
    "FChaosPhysicsSettings",
    "PerInstanceSMCustomData", 
    "PerInstanceSMData",
    # "ObjectTypes",
    "EvaluatorMode",
    "RootComponent", #Manually imported
    # "AudioLinkSettings" #I should instead not import property of certain type
    "SetTemplate",
    "GetBlendProfile",
    
    "IsPolyglotDataValid",
    "PolyglotDataToText",
    #Engine external deps
    "SetMouseCursorWidget",
    "PlayQuantized",
    "AnimBlueprintGeneratedClass",
    "UVirtualTexture2D",
    "K2_GetRootComponent",
    "Cancel", #name collision on mac (it can be avoided by adding it as an exception on the codegen)
    #By type name
    # "UClothingSimulationInteractor",
    # "UClothingAssetBasePtr",
    "UAudioLinkSettingsAbstract",
    "TFieldPath",
    "UWorld", #cant be casted to UObject
    # "USoundWaveProcedural",
    #KismetMathLibrary funcs:
    
    "PrimaryActorTick",
   
  ]),
  
]


moduleImportRules["EnhancedInput"] = @[
  codegenOnly,
  makeImportedRuleType(uerIgnore, @[
    "ETriggerEvent",
    "FInputActionValue",
  ]),
  # makeImportedRuleModule(uerIgnoreHash)
]
moduleImportRules["UMGEditor"] = @[
  codegenOnly,
  makeImportedRuleType(uerIgnore, @[
    # "UBlueprintExtension",
    # "UEdGraphSchema_K2",
    # "UAssetEditorUISubsystem",
  ]),

]

moduleImportRules["Niagara"] = @[
  codegenOnly,
  
]
moduleImportRules["MegascansPlugin"] = @[
  codegenOnly,
  makeImportedRuleModule(uerImportBlueprintOnly)
   
  
]

moduleImportRules["DungeonArchitectRuntime"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FFlowTilemapCoord"
  ]), 
  makeImportedRuleField(uerIgnore, @[
    "FFlowTilemapCoord"
  ]),
]

moduleImportRules["AnimationLocomotionLibraryRuntime"] = @[
  makeImportedRuleField(uerIgnore, @[
    "AdvanceTimeByDistanceMatching", #need to introduce uerQualifiedName to avoid this (checkout also why the qualified is required)
  ]),
]
moduleImportRules["MovieRenderPipelineRenderPasses"] = @[
  makeImportedRuleField(uerIgnore, @[
    "ActorLayers", #need to introduce uerQualifiedName to avoid this (checkout also why the qualified is required)
  ]),
]

moduleImportRules["BlueprintGraph"] = @[ #there a triangle cycle between animgraph, blueprintgraph and unrealed (so we dont import unrel ed for the blueprint graph which is not super useful from nim)
  makeImportedRuleType(uerIgnore, @[
    "FBlueprintBreakpoint", "FPerBlueprintSettings", "UBlueprintEditorSettings"
  ]), 
  makeImportedRuleField(uerIgnore, @[
    "FBlueprintBreakpoint", "FPerBlueprintSettings"
  ]),
]

moduleImportRules["AnimGraphRuntime"] = @[
  makeImportedRuleType(uerIgnore, @[
    # "FAnimNode_ModifyBone"
  ]), 
  makeImportedRuleField(uerIgnore, @[
    "FAnimNodeFunctionRef", "FInputBlendPose", "FAnimInitializationContext", "FAnimComponentSpacePoseContext"
  ]),

  # makeImportedRuleModule(uerImportBlueprintOnly)
]
moduleImportRules["AnimGraph"] = @[
  makeImportedRuleType(uerIgnore, @[
  ]), 
  makeImportedRuleField(uerIgnore, @[
    "Class"]),

  # makeImportedRuleModule(uerImportBlueprintOnly)
]

moduleImportRules["GameplayTags"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FGameplayTag" #manually imported
  ])
]
moduleImportRules["EditorInteractiveToolsFramework"] = @[
  makeImportedRuleField(uerIgnore, @[
    "EdMode" #cycle
  ])
]

moduleImportRules["InputCore"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FKey"
  ]),
 # makeImportedRuleModule(uerImportBlueprintOnly)
]



moduleImportRules["PhysicsCore"] = @[
  codegenOnly,  
]

moduleImportRules["SequencerScripting"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  makeImportedRuleField(uerIgnore, @["UMovieSceneByteTrack"])
]

moduleImportRules["ControlRigEditor"] = @[ 
  #There a few types float, int collisioning with cpp types so we do the importBlueprintOnly for now
  makeImportedRuleModule(uerImportBlueprintOnly),
  # makeImportedRuleField(uerIgnore, @["UControlRigSnapSettings", "UMovieSceneControlRigParameterSection"])
]

# moduleImportRules["ControlRig"] = @[
#   makeImportedRuleModule(uerImportBlueprintOnly),
#   makeImportedRuleField(uerIgnore, @[
#     "FMovieSceneByteChannel"
#   ])
# ]


moduleImportRules["UMG"] = @[ 
  makeImportedRuleType(uerIgnore, @[ #MovieScene was removed as dependency for now          
    "UMovieScenePropertyTrack", "UMovieSceneNameableTrack",
    "UMovieScenePropertySystem", "UMovieScene2DTransformPropertySystem",
    "UMovieSceneMaterialTrack", 
    ]), 
  makeImportedDelegateRule(@[
    "FOnOpeningEvent", "FOnOpeningEvent", "FOnSelectionChangedEvent",

    ]),
  makeImportedDelegateRule("FGetText", @["USlateAccessibleWidgetData"]),
  makeImportedRuleField(uerIgnore, @[
    "OnIsSelectingKeyChanged",
    "SlotAsSafeBoxSlot",
    "UStackBoxSlot",
    "SetNavigationRuleCustomBoundary",
    "SetNavigationRuleCustom",

    "FMovieSceneTrackIdentifier",
    "UWidgetNavigation", 
  ])
  # makeImportedRuleModule(uerImportBlueprintOnly)
]

moduleImportRules["SlateCore"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FSlateBrush",
    "FKeyEvent", #"FInputEvent"
  ]),
   makeImportedRuleField(uerIgnore, @[
    "FComboButtonStyle",
    "FFontOutlineSettings",
    # "FTextBlockStyle"
  ]),
]
moduleImportRules["Slate"] = @[

   makeImportedRuleField(uerIgnore, @[
    "FComboButtonStyle",
    # "FTextBlockStyle"
  ]),
]
moduleImportRules["AudioMixer"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  makeExcludeDepsRule(@["LyraGame"]),

]
moduleImportRules["AudioModulationEditor"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  makeImportedRuleField(uerIgnore, @[
    "GeneratorClass",
    # "FTextBlockStyle"
  ]),
]

# moduleImportRules["DeveloperSettings"] = @[
#   makeImportedRuleType(uerCodeGenOnlyFields, @[
#     "UDeveloperSettings",
#   ])
# ]

moduleImportRules["UnrealEd"] = @[
  # makeImportedRuleModule(uerImportBlueprintOnly),
  makeExcludeDepsRule(@[ "DataLayerEditor" ]),

  makeImportedRuleField(uerIgnore, @[
    "ScriptReimportHelper", "ModeToolsContext", "PreviewInstance", "BlueprintFavorites", "CreateParams", "Bool",
  ])
]

moduleImportRules["MovieSceneTools"] = @[
  makeExcludeDepsRule(@[ "LevelSequence" ]),

  makeImportedRuleField(uerIgnore, @[
    "BurnInOptions", "EventSections"
  ])
]

moduleImportRules["MovieScene"] = @[

  makeImportedRuleField(uerIgnore, @[
    "BoolCurve",
    "FMovieSceneEvaluationFieldTrackPtr"#This type may cause issues because it ends Ptr. We could support them in F struct like, but it isnt worht it
  ]),
  makeImportedRuleType(uerIgnore, @[
    "FMovieSceneEvaluationFieldTrackPtr"#This type may cause issues because it ends Ptr. We could support them in F struct like, but it isnt worht it
  ]),
  
]

moduleImportRules["MovieSceneTracks"] = @[
  makeImportedRuleField(uerIgnore, @[
    "BurnInOptions", "FMovieSceneByteChannel"
  ])
]

moduleImportRules["LevelSequencer"] = @[
  makeImportedRuleField(uerIgnore, @[
    "FMovieSceneSequenceID"
  ])
]

moduleImportRules["AudioExtensions"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  # makeImportedRuleModule(uerIgnoreHash)
]


moduleImportRules["EditorSubsystem"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly)
]


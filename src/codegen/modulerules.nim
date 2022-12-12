import ../nimforue/unreal/coreuobject/uobjectflags
import std/[sequtils, options, sugar, tables]
import utils/utils


const ManuallyImportedClasses* = @[ 
  #we could have this list being generated automatically by using a pragma on the imported cpp
      "AActor", "UReflectionHelpers", "UObject",
      "UField", "UStruct", "UScriptStruct", "UPackage",
      "UClass", "UFunction", "UDelegateFunction",
      "UEnum", "AVolume", "UInterface", "USoundWaveProcedural",
      "UActorComponent","AController","AGameMode", "AGameModeBase",
      "UBlueprint", "UBlueprintGeneratedClass",
      "APlayerController", "UAnimBlueprintGeneratedClass",
      "UEngineSubsystem", "USubsystem", "UDynamicSubsystem", "UWorldSubsystem",
      "USceneComponent",
      "UWorld",
      "UInputComponent",
      "UEnhancedInputComponent",
      "UInputAction",
      "UPlayerInput",
      "UEnhancedPlayerInput",
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



func contains*(rules: seq[UEImportRule], rule:UERule): bool = 
    rules.any((r:UEImportRule) => r.rule == rule)

func isTypeAffectedByRule*(rules:seq[UEImportRule], name:string, rule:UERule): bool = 
    rules.any((r:UEImportRule) => r.target == uertType and r.rule == rule and r.affectedTypes.contains(name))
func getRuleAffectingType*(rules:seq[UEImportRule], name:string, rule:UERule): Option[UEImportRule] = 
    rules.first((r:UEImportRule) => r.target == uertType and r.rule == rule and r.affectedTypes.contains(name))



#Any module not picked by default.
#This could be exposed to the json file 
let extraModuleNames = @["EnhancedInput"]
#By default modules import only bp symbols because it's the safest option
#The module listed below will be an exception (alongside the ones in moduleRules that doesnt say it explicitaly)
let extraNonBpModules = @["DeveloperSettings", "EnhancedInput"]
#CodegenOnly directly affects the Engine module but needs to be passed around
#for all modules because the one classes listed here are importc one so we dont mangle them 

  #There is one main header that pulls the rest.
  #Every other header is in the module paths
  # let validCppParents = []
    # ["UObject", "AActor", "UInterface",
    #   "AVolume", "USoundWaveProcedural",
    #   # "AController",
    #   "USceneComponent",
    #   "UActorComponent",
    #   "UBlueprint",
    #   # "UBlueprintFunctionLibrary",
    #   "UBlueprintGeneratedClass",
    #   # "APlayerController",
    #   ] #TODO this should be introduced as param
const codeGenOnly* = makeImportedRuleType(uerCodeGenOnlyFields, ManuallyImportedClasses)

let moduleRules* = newTable[string, seq[UEImportRule]]()
moduleRules["Engine"] = @[
    codegenOnly, 
    makeImportedRuleType(uerIgnore, @[
    "FVector", "FSlateBrush",
    "FHitResult",
    #issue with a field name 
    "FTransformConstraint", 
    # "UKismetMathLibrary", #issue with the funcs?,
    "FOnTemperatureChangeDelegate", #Mac gets stuck here?,
    # "UParticleSystem", #collision with a function name and Cascade is deprecated, use Niagara instead.
    ]), 
    # makeImportedRuleModule(uerIgnoreHash),

    
  makeImportedRuleField(uerIgnore, @[
    "PerInstanceSMCustomData", 
    "PerInstanceSMData",
    "ObjectTypes",
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

    "Cancel", #name collision on mac (it can be avoided by adding it as an exception on the codegen)
    #By type name
    # "UClothingSimulationInteractor",
    # "UClothingAssetBasePtr",
    "UAudioLinkSettingsAbstract",
    "TFieldPath",
    "UWorld", #cant be casted to UObject

    #KismetMathLibrary funcs:
    

  ]),
  makeImportedRuleModule(uerImportBlueprintOnly),
  # makeVirtualModuleRule("gameplaystatics", @["UGameplayStatics"])
  # makeVirtualModuleRule("mathlibrary", @["UKismetMathLibrary"])
]

moduleRules["MovieScene"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FMovieSceneByteChannel"
  ]),
  makeImportedRuleModule(uerImportBlueprintOnly)
]
moduleRules["EnhancedInput"] = @[
  codegenOnly,
  makeImportedRuleType(uerIgnore, @[
    "ETriggerEvent",
    "FInputActionValue",
  ]),
  # makeImportedRuleModule(uerIgnoreHash)

]

moduleRules["InputCore"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FKey"
  ]),
  makeImportedRuleModule(uerImportBlueprintOnly)
]

moduleRules["UMG"] = @[ 
  makeImportedRuleType(uerIgnore, @[ #MovieScene was removed as dependency for now          
    "UMovieScenePropertyTrack", "UMovieSceneNameableTrack",
    "UMovieScenePropertySystem", "UMovieScene2DTransformPropertySystem",
    "UMovieSceneMaterialTrack",
    ]), 
  makeImportedDelegateRule(@[
    "FOnOpeningEvent", "FOnOpeningEvent", "FOnSelectionChangedEvent"

    ]),
  makeImportedDelegateRule("FGetText", @["USlateAccessibleWidgetData"]),
  makeImportedRuleField(uerIgnore, @[
    "OnIsSelectingKeyChanged",
    "SlotAsSafeBoxSlot",
    "UStackBoxSlot",
    "SetNavigationRuleCustomBoundary",
    "SetNavigationRuleCustom",

    "FTextBlockStyle",
    "UWidgetNavigation",

  ]),
  makeImportedRuleModule(uerImportBlueprintOnly)
]

moduleRules["SlateCore"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FSlateBrush"
  ]),
   makeImportedRuleField(uerIgnore, @[
    "FComboButtonStyle",
    "FFontOutlineSettings",
    "FTextBlockStyle"
  ]),
]
moduleRules["Slate"] = @[

   makeImportedRuleField(uerIgnore, @[
    "FComboButtonStyle",
    "FTextBlockStyle"
  ]),
]

# moduleRules["DeveloperSettings"] = @[
#   makeImportedRuleType(uerCodeGenOnlyFields, @[
#     "UDeveloperSettings",
#   ])
# ]

moduleRules["UnrealEd"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  makeImportedRuleField(uerIgnore, @[
          "ScriptReimportHelper"
  ])
]
moduleRules["AudioExtensions"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  # makeImportedRuleModule(uerIgnoreHash)
]

moduleRules["MegascansPlugin"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  makeImportedRuleField(uerIgnore, @[
      "Get"
  ])
]

moduleRules["EditorSubsystem"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly)
]

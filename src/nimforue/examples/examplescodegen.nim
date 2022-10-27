include ../unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate

let moduleRules = newTable[string, seq[UEImportRule]]()


moduleRules["Engine"] = @[
        makeImportedRuleType(uerCodeGenOnlyFields, 
          @[
            "AActor", "UReflectionHelpers", "UObject",
            "UField", "UStruct", "UScriptStruct", "UPackage",
            "UClass", "UFunction", "UDelegateFunction",
            "UEnum", "AVolume",
             "UActorComponent",
             "UBlueprint",
            #UMG Created more than once.
           

            # "UPrimitiveComponent", "UPhysicalMaterial", "AController",
            # "UStreamableRenderAsset", "UStaticMeshComponent", "UStaticMesh",
            # "USkeletalMeshComponent", "UTexture2D", "UInputComponent",
            # # "ALevelScriptActor",  "UPhysicalMaterialMask",
            # "UHLODLayer",
            # "USceneComponent",
            # "APlayerController",
            # "UTexture",
            # "USkinnedMeshComponent",
            # "USoundBase",
            # "USubsurfaceProfile",
            # "UMaterialInterface",
            # "UParticleSystem",
            # "UBillboardComponent",
            # "UChildActorComponent",
            # "UDamageType",
            # "UDecalComponent",
            "UWorld",
            # "UCanvas",
            # "UDataLayer",
            
            #"APawn",
            # "FConstraintBrokenSignature",
            # "FPlasticDeformationEventSignature",
            # "FTimerDynamicDelegate",
            # "FKey",
            # "FFastArraySerializer"
          
          ]), 
          makeImportedRuleType(uerIgnore, @[
          "FVector", "FSlateBrush",
          "FHitResult",
          #issue with a field name 
          "FTransformConstraint", 
          "UKismetMathLibrary", #issue with the funcs?,
          "FOnTemperatureChangeDelegate" #Mac gets stuck here?
          ]), 
          
        makeImportedRuleField(uerIgnore, @[
          "PerInstanceSMCustomData", 
          "PerInstanceSMData",
          "ObjectTypes",
          "EvaluatorMode",
          # "AudioLinkSettings" #I should instead not import property of certain type

          "GetBlendProfile",
          "IsPolyglotDataValid",
          "PolyglotDataToText",
          #Engine external deps
          "SetMouseCursorWidget",
          "PlayQuantized",

          "Cancel", #name collision on mac (it can be avoided by adding it as an exception on the codegen)
          #By type name
          # "UClothingSimulationInteractor",
          # "UClothingAssetBasePtr",
          "UAudioLinkSettingsAbstract",
          "TFieldPath",
          "UWorld", #cant be casted to UObject

        ]),
        makeImportedRuleModule(uerImportBlueprintOnly)#,
        # makeVirtualModuleRule("gameplaystatics", @["UGameplayStatics"])
]
moduleRules["MovieScene"] = @[
  makeImportedRuleType(uerIgnore, @[
    "FMovieSceneByteChannel"        

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

          "SetNavigationRuleCustomBoundary",
          "SetNavigationRuleCustom"
        ]),
        makeImportedRuleModule(uerImportBlueprintOnly)
]

moduleRules["SlateCore"] = @[        
          makeImportedRuleType(uerIgnore, @[
            "FSlateBrush"
          ])
]
moduleRules["DeveloperSettings"] = @[        
          makeImportedRuleType(uerCodeGenOnlyFields, @[
            "UDeveloperSettings",
          ])
]

moduleRules["UnrealEd"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly),
  makeImportedRuleField(uerIgnore, @[
          "ScriptReimportHelper"
  ])
]
moduleRules["EditorSubsystem"] = @[
  makeImportedRuleModule(uerImportBlueprintOnly)
]

#TODO Deps module needs to pull parents !!!
#Enums too?

proc getAllInstalledPlugins() : seq[string] =
  let config = getNimForUEConfig()
  try:        
    let projectJson = readFile(config.gamePath).parseJson()
    let plugins = projectJson["Plugins"]                      
                    .filterIt(it["Enabled"].jsonTo(bool))
                    .mapIt(it["Name"].jsonTo(string))
    return plugins
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to parse project json"
    return @[]
  
proc genReflectionData() = 
      let plugins = getAllInstalledPlugins()

      let deps = plugins 
                  .mapIt(getAllModuleDepsForPlugin(it).mapIt($it).toSeq())
                  .foldl(a & b, newSeq[string]()) & @["NimForUEDemo", "Engine", "UMG", "UnrealEd"]
                  
      UE_Log &"Plugins: {plugins}"
      proc getUEModuleFromModule(module:string) : seq[UEModule] =
        var excludeDeps = @["CoreUObject", "AudioMixer", "MegascansPlugin"]
        if module == "Engine":
          excludeDeps.add "UMG"
        
        # if module == "UMG":
        #   excludeDeps.add "MovieScene"
        
        var includeDeps = newSeq[string]() #MovieScene doesnt need to be bound
        if module == "MovieScene":
          includeDeps.add "Engine"
        
        let rules = if module in moduleRules: moduleRules[module] else: @[]
        tryGetPackageByName(module)
          .map((pkg:UPackagePtr) => pkg.toUEModule(rules, excludeDeps, includeDeps))
          .get(newSeq[UEModule]())
          
      
      var modCache = newTable[string, UEModule]()
      proc getDepsFromModule(modName:string, currentLevel=0) : seq[string] = 
        if currentLevel > 5: 
          UE_Warn &"Reached max level for {modName}. Breaking the cycle"
          return @[]
        UE_Log &"Getting deps for {modName}"
        let deps =
          if modName in modCache:
            modCache[modName].dependencies
          else:
            let modules = getUEModuleFromModule(modName)
            for m in modules:
              modCache[m.name] = m
            
            modules[0].dependencies #Notice No need to return virtual module dependencies.
        deps & 
          deps         
            .mapIt(getDepsFromModule(it, currentLevel+1))
            .foldl(a & b, newSeq[string]())
            .deduplicate()


      let starts = now()
      let modules = (deps.mapIt(getDepsFromModule(it))
                        .foldl(a & b, newSeq[string]()) & deps)
                        .deduplicate()

      var ends = now() - starts

      let config = getNimForUEConfig()

      let ueProject = UEProject(modules: modCache.values.toSeq())
      
      # let ueProjectAsJson = ueProject.toJson().pretty()
      # let ueProjectFilePath = config.pluginDir / ".reflectiondata" / "ueproject.json"
      # writeFile(ueProjectFilePath, ueProjectAsJson)
      #Show all deps for testing purposes
      UE_Log "All module deps:"
      for m in ueProject.modules:
        UE_Log &"{m.name}: {m.dependencies}"

      let ueProjectAsStr = $ueProject
      let codeTemplate = """
import ../nimforue/typegen/models
const project* = $1
"""
      writeFile( config.pluginDir / "src" / ".reflectiondata" / "ueproject.nim", codeTemplate % [ueProjectAsStr])


        
      ends = now() - starts
      UE_Log &"It took {ends} to gen all deps"

      UE_Warn $deps
      UE_Warn $modules


#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite):
    delTypeName : FString = "OnOpeningEvent"
  ufuncs(CallInEditor):
    proc genReflectionData() = 
      try:
        genReflectionData()
        # let rulesASJson = moduleRules.toJson().pretty()
        # UE_Log rulesASJson
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"
    
    proc genReflectionDataAndCodeGen() = 
      try:
        genReflectionData()
        let config = getNimForUEConfig()
        let cmd = &"{config.pluginDir}\\nue.exe gencppbindings"
        discard execCmd(cmd)
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"

    proc showType() = 
      let obj = getUTypeByName[UDelegateFunction]("UMG.ComboBoxKey:OnOpeningEvent"&DelegateFuncSuffix)
      let obj2 = getUTypeByName[UDelegateFunction]("OnOpeningEvent"&DelegateFuncSuffix)
      UE_Warn $obj
      UE_Warn $obj2

    proc searchDelByName() = 
      let obj = getUTypeByName[UDelegateFunction](self.delTypeName&DelegateFuncSuffix)
      if obj.isNil(): 
        UE_Error &"Error del is null"
        return

      
      UE_Warn $obj
      UE_Warn $obj.getOuter()

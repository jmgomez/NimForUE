include ../nimforue/unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../nimforue/typegen/uemeta
import ../buildscripts/[nimforueconfig, buildscripts]
import ../nimforue/macros/genmodule #not sure if it's worth to process this file just for one function? 

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
      "USceneComponent",
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
    "RootComponent", #Manually imported
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
const pluginDir {.strdefine.}: string = ""

proc getAllInstalledPlugins*(config: NimForUEConfig): seq[string] =
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

proc genReflectionData*(plugins: seq[string]): UEProject =
  let deps = plugins
              .mapIt(getAllModuleDepsForPlugin(it).mapIt($it).toSeq())
              .foldl(a & b, newSeq[string]()) & @["NimForUEDemo"] #, "Engine", "UMG", "UnrealEd"]

  UE_Log &"Plugins: {plugins}"
  #Cache with all modules so we dont have to collect the UETypes again per deps
  var modCache = newTable[string, UEModule]()

  proc getUEModuleFromModule(module: string): Option[UEModule] =
    var excludeDeps = @["CoreUObject", "AudioMixer", "MegascansPlugin"]
    if module == "Engine":
      excludeDeps.add "UMG"

    # if module == "UMG":
    #   excludeDeps.add "MovieScene"

    var includeDeps = newSeq[string]() #MovieScene doesnt need to be bound
    if module == "MovieScene":
      includeDeps.add "Engine"

    #By default all modules that are not in the list above will only export BlueprintTypes
    let bpOnlyRules = makeImportedRuleModule(uerImportBlueprintOnly)
    let rules = if module in moduleRules: moduleRules[module] else: @[bpOnlyRules]

    UE_Log &"getUEModuleFromModule {module}"

    if module notin modCache: #if it's in the cache the virtual modules are too.
      let ueMods = tryGetPackageByName(module)
            .map((pkg:UPackagePtr) => pkg.toUEModule(rules, excludeDeps, includeDeps))
            .get(newSeq[UEModule]())

      if ueMods.isEmpty():
        UE_Error &"Failed to get module {module}. Did you restart the editor already?"
        return none[UEModule]()

      for ueMod in ueMods:
        UE_Log &"Caching {ueMod.name}"
        modCache.add(ueMod.name, ueMod)

    some modCache[module] #we only return the actual uemod


  proc getDepsFromModule(modName:string, currentLevel=0) : seq[string] = 
    if currentLevel > 5: 
      UE_Warn &"Reached max level for {modName}. Breaking the cycle"
      return @[]
    UE_Log &"Getting deps for {modName}"
    let deps = getUEModuleFromModule(modName).map(x=>x.dependencies).get(newSeq[string]())
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
  createDir(config.bindingsDir)
  let bindingsPath = (modName:string) => config.bindingsDir / modName.toLower() & ".nim"

  let modulesToGen = modCache
                      .values
                      .toSeq()
                      .filterIt(it.hash != getModuleHashFromFile(bindingsPath(it.name)).get("_"))

  UE_Log &"Modules to gen: {modulesToGen.len}"
  UE_Log &"Modules in cache {modCache.len}"
  UE_Warn &"Modules to gen {modulesToGen.mapIt(it.name)}"
  let ueProject = UEProject(modules:modulesToGen)
  
  #Show all deps for testing purposes
  UE_Log "All module deps:"
  # for m in ueProject.modules:
  #   UE_Log &"{m.name}: {m.dependencies}"

  let ueProjectAsStr = $ueProject
  let codeTemplate = """
import ../nimforue/typegen/models
const project* = $1
"""

  createDir(config.reflectionDataDir)
  writeFile(config.reflectionDataFilePath, codeTemplate % [ueProjectAsStr])

  ends = now() - starts
  UE_Log &"It took {ends} to gen all deps"
  return ueProject
  # UE_Warn $deps
  # UE_Warn $ueProject


proc genUnrealBindings*(plugins: seq[string]) =
  try:
    let ueProject = genReflectionData(plugins)
    # return

    UE_Log $ueProject
    if ueProject.modules.isEmpty():
      UE_Log "No modules to generate"
      return

    # let config = getNimForUEConfig()
    # let cmd = &"{config.pluginDir}\\nue.exe gencppbindings"
    when defined(windows):
      var cmd = f &"{pluginDir}\\nue.exe"    
    else:
      var cmd = f &"{pluginDir}/nue"
    var
      args = f"gencppbindings"
      dir = f pluginDir
      stdOut : FString
      stdErr : FString

    let code = executeCmd(cmd, args, dir, stdOut, stdErr)

    # let str = execProcess(cmd, 
    #       workingDir=config.pluginDir, 
    #     #  options={poEvalCommand, poDaemon}
    # )
    UE_Log $code
    UE_Warn "output" & stdOut
    # UE_Error "error" & stdErr
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to generate reflection data"


proc NimMain() {.importc.}
proc execBindingsGenerationInAnotherThread*() {.cdecl.}= 
  # genUnrealBindings()
  # UE_Warn "Hello from another thread"
  proc ffiWraper(config:ptr NimForUEConfig) {.cdecl.} = 
    # NimMain()   
    UE_Log "Hello from another thread"
    UE_Log $config[]
    # genUnrealBindings(plugins)
    discard
  let config = getNimForUEConfig(pluginDir)

  let plugins = getAllInstalledPlugins(config)
  # executeTaskInTaskGraph[ptr NimForUEConfig](config.unsafeAddr, ffiWraper)
  genUnrealBindings(plugins)
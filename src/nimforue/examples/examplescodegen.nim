include ../unreal/prelude
import std/[strformat, tables, strutils, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate
let moduleRules = @[
        makeImportedRuleType(uerCodeGenOnlyFields, 
          @[
            "AActor", "UReflectionHelpers", "UObject",
            "UField", "UStruct", "UScriptStruct", "UPackage",
            "UClass", "UFunction", "UDelegateFunction",
            "UEnum", "UActorComponent", "AVolume",

            # "UPrimitiveComponent", "UPhysicalMaterial", "AController",
            # "UStreamableRenderAsset", "UStaticMeshComponent", "UStaticMesh",
            # "USkeletalMeshComponent", "UTexture2D", "UInputComponent",
            # "ALevelScriptActor",  "UPhysicalMaterialMask",
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
            # "UWorld",
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
          "UKismetMathLibrary" #issue with the funcs?

        
          
          ]), 
          
        makeImportedRuleField(uerIgnore, @[
          "PerInstanceSMCustomData", 
          "PerInstanceSMData",
          "ObjectTypes",
          "EvaluatorMode",
          # "AudioLinkSettings" #I should instead not import property of certain type

          #By type name
          # "UClothingSimulationInteractor",
          # "UClothingAssetBasePtr",
          "UAudioLinkSettingsAbstract",
          "TFieldPath",
          "UWorld", #cant be casted to UObject


#Functions that should not be exported (contains an UMG field)
          "SetMouseCursorWidget", "PlayQuantized", "GetBlendProfile", "PolyglotDataToText", "IsPolyglotDataValid"
          # "Tan"


          
          
          

           ]) #Enum not working because of the TEnum constructor being redefined by nim and it was already defined in UE. The solution would be to just dont work with TEnumAsByte but with the Enum itself which is more convenient. 

      ] 
proc genBindings(moduleName:string, moduleRules:seq[UEImportRule]) =
  let config = getNimForUEConfig()
  let reflectionDataPath = config.pluginDir / "src" / ".reflectiondata" #temporary
  createDir(reflectionDataPath)
  let bindingsDir = config.pluginDir / "src"/"nimforue"/"unreal"/"bindings"
  createDir(bindingsDir)
  createDir(bindingsDir / "exported")

  let nimHeadersDir = config.pluginDir / "NimHeaders" # need this to store forward decls of classes

  var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject", "UMG", "AudioMixer"])) #The last two are specifically for engine, pass them as a parameter
                      .get()
  let codegenPath = reflectionDataPath / moduleName.toLower() & ".nim"
  let exportBindingsPath = bindingsDir / "exported" / moduleName.toLower() & ".nim"
  let importBindingsPath = bindingsDir / moduleName.toLower() & ".nim"
  UE_Log &"-= The codegen module path is {codegenPath} =-"

  try:
    let codegenTemplate = codegenNimTemplate % [
      escape($module.toJson()), escape(exportBindingsPath), escape(importBindingsPath), escape(nimHeadersDir)
    ]
    #UE_Warn &"{codegenTemplate}"
    writeFile(codegenPath, codegenTemplate)
    let nueCmd = config.pluginDir/"nue.exe codegen --module:\"" & codegenPath & "\""
    let result = execProcess(nueCmd, workingDir = config.pluginDir)
    # removeFile(codegenPath)
    UE_Log &"The result is {result} "
    UE_Log &"-= Bindings for {moduleName} generated in {exportBindingsPath} =- "

    doAssert(fileExists(exportBindingsPath))
    doAssert(fileExists(importBindingsPath))
  except:
    let e : ref Exception = getCurrentException()

    UE_Log &"Error: {e.msg}"
    UE_Log &"Error: {e.getStackTrace()}"
    UE_Log &"Failed to generate {codegenPath} nim binding"




proc genBindingsWithDeps(moduleName:string, moduleRules:seq[UEImportRule], skipRoot = false, prevGeneratedMods : seq[string] = @[]) =
  var module = tryGetPackageByName(moduleName)
                .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject"]))
                .get()

  if module.dependencies.any() and moduleName notin prevGeneratedMods:
    UE_Warn &"-= Generating dependencies for {moduleName} dependencies: {module.dependencies}=-"
    for dep in module.dependencies:
      genBindingsWithDeps(dep, moduleRules, prevGeneratedMods=(prevGeneratedMods & @[dep]))
  if not skipRoot:
    genBindings(moduleName, moduleRules)


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
  



#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    #[
    proc printFBodyInstance() =
      let str = getUTypeByName[UScriptStruct]("BodyInstance")
      let ueType = str.toUEType(@[makeImportedRuleModule(uerImportBlueprintOnly)])

      # UE_Log &"UEType: {ueType}"
      # let metadata = str.getMetaDataMap()
      # let includePath = str.getMetaData("ModuleRelativePath")
      # UE_Log $cls.classFlags
      # UE_Log $includePath
      # UE_Log $metadata

    proc printModuleIncludes() = 
      var module = tryGetPackageByName("Engine")
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(@[], excludeDeps= @["CoreUObject"]))
                      .get()
      UE_Warn module.getModuleHeader().join(" \n")
    ]#

    proc genEngineBindings() = 
      genBindingsWithDeps("Engine", moduleRules, skipRoot = true)
      genBindings("Engine", moduleRules & @[makeImportedRuleModule(uerImportBlueprintOnly)])
      # genBindings("Engine", moduleRules )

      #Engine can be splited in two modules one is BP based and the other dont
      #All kismets would be in its own module -20k lines of code?

      # Hand pick classes
      # Static functions that collides can be virtual modules too. (We need to find the colliding functions)
  
    proc genSlateBindings() = 
      genBindingsWithDeps("Slate", moduleRules)
    
    proc genUnrealEdBindings() = 
      genBindingsWithDeps("UnrealEd", moduleRules)
    
    proc genMeshDescription() = 
      genBindingsWithDeps("MeshDescription", moduleRules)

    proc genNimForUEBindings() = 
      genBindings("NimForUEBindings", moduleRules)
    proc genNimForUE() = 
      genBindings("NimForUE", moduleRules)

    proc genCoreUObjectBindings() = 
      genBindings("CoreUObject", moduleRules)

    proc printEngineDeps() = 
      var module = tryGetPackageByName("Engine")
              .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject"]))
              .get()
      UE_Warn module.dependencies.join(" \n")

    proc showModuleName() = 
      let obj = getClassByName("UserWidget")
      UE_Warn obj.getModuleName()

    proc showPluginDep2() = 
      
      let plugins = getAllInstalledPlugins()



      let deps = plugins 
                  .mapIt(getAllModuleDepsForPlugin(it).mapIt($it).toSeq())
                  .foldl(a & b, newSeq[string]()) & "NimForUEDemo" & "Engine"
      UE_Log &"Plugins: {plugins}"
      proc getUEModuleFromModule(module:string) : UEModule =
          tryGetPackageByName(module)
            .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject", "UMG", "AudioMixer", "UnrealEd", "EditorSubsystem"]))
            .get()
      
      var modCache = newTable[string, UEModule]()
      proc getDepsFromModule(modName:string) : seq[string] = 
        UE_Log &"Getting deps for {modName}"
        let deps =
          if modName in modCache:
            modCache[modName].dependencies
          else:
            let module = getUEModuleFromModule(modName)
            modCache[modName] = module
            module.dependencies

        deps & 
          deps         
            .map(getDepsFromModule)
            .foldl(a & b, newSeq[string]())
            .deduplicate()

      let starts = now()
      let modules = (deps.map(getDepsFromModule)
                        .foldl(a & b, newSeq[string]()) & deps)
                        .deduplicate()

      var ends = now() - starts
      UE_Log &"It took {ends} to get all deps"
      let blueprintOnly = ["Engine"]
      for m in modules:
        let rules =  moduleRules & 
          (if m in blueprintOnly: @[makeImportedRuleModule(uerImportBlueprintOnly)]
          else: @[])
        genBindings(m, rules)#TOOD dont do this. The module is already parsed. GenBindings should just return the parameter
        UE_Log m
      ends = now() - starts
      UE_Log &"It took {ends} to gen all deps"

      UE_Warn $deps
      UE_Warn $modules

    proc showType() = 
      let obj = getUTypeByName[UDelegateFunction]("OnAssetClassLoaded"&DelegateFuncSuffix)
      UE_Warn $obj


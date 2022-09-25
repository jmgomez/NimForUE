include ../unreal/prelude
import std/[strformat, strutils, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate

proc genBindings(moduleName:string, moduleRules:seq[UEImportRule]) =
  let config = getNimForUEConfig()
  let reflectionDataPath = config.pluginDir / "src" / ".reflectiondata" #temporary
  createDir(reflectionDataPath)
  let bindingsDir = config.pluginDir / "src"/"nimforue"/"unreal"/"bindings"
  createDir(bindingsDir)
  createDir(bindingsDir / "exported")

  var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject"]))
                      .get()
  let codegenPath = reflectionDataPath / moduleName.toLower() & ".nim"
  let exportBindingsPath = bindingsDir / "exported" / moduleName.toLower() & ".nim"
  let importBindingsPath = bindingsDir / moduleName.toLower() & ".nim"
  UE_Log &"-= The codegen module path is {codegenPath} =-"

  try:
    let codegenTemplate = codegenNimTemplate % [
        $module, escape(exportBindingsPath), escape(importBindingsPath)]
    #UE_Warn &"{codegenTemplate}"
    writeFile(codegenPath, codegenTemplate)
    let nueCmd = config.pluginDir/"nue.exe codegen --module:\"" & codegenPath & "\""
    let result = execProcess(nueCmd, workingDir = config.pluginDir)
    # removeFile(codegenPath)
    # UE_Log &"The result is {result} "
    UE_Log &"-= Bindings for {moduleName} generated in {exportBindingsPath} =- "

    doAssert(fileExists(exportBindingsPath))
    doAssert(fileExists(importBindingsPath))
  except:
    let e : ref Exception = getCurrentException()

    UE_Log &"Error: {e.msg}"
    UE_Log &"Error: {e.getStackTrace()}"
    UE_Log &"Failed to generate {codegenPath} nim binding"


#TODO dont regenerate already generated deps for this pass
proc genBindingsWithDeps(moduleName:string, moduleRules:seq[UEImportRule]) =
  var module = tryGetPackageByName(moduleName)
                .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject"]))
                .get()
  if module.dependencies.any():
    UE_Warn &"-= Generating dependencies for {moduleName} dependencies: {module.dependencies}=-"
    for dep in module.dependencies:
      genBindingsWithDeps(dep, moduleRules)
  
  genBindings(moduleName, moduleRules)



#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc printFBodyInstance() =
      let str = getUTypeByName[UScriptStruct]("BodyInstance")
      let ueType = str.toUEType(@[makeImportedRuleModule(uerImportBlueprintOnly)])

      UE_Log &"UEType: {ueType}"
      # let metadata = cls.getMetaDataMap()
      # UE_Log $cls.classFlags
      # UE_Log $metadata


    proc generateUETypes() = 
      # let a = ETest.testB
      let moduleRules = @[
        makeImportedRuleType(uerCodeGenOnlyFields, 
          @[
            "AActor", "UReflectionHelpers", "UObject",
            "UField", "UStruct", "UScriptStruct", "UPackage",
            "UClass", "UFunction", "UDelegateFunction",
            "UEnum", "UActorComponent", "APawn",
            "UPrimitiveComponent", "UPhysicalMaterial", "AController",
            "UStreamableRenderAsset", "UStaticMeshComponent", "UStaticMesh",
            "USkeletalMeshComponent", "UTexture2D", "FKey", "UInputComponent",
            "ALevelScriptActor", "FFastArraySerializer", "UPhysicalMaterialMask",
            "UHLODLayer"
          
          ]), 
          makeImportedRuleType(uerIgnore, @[
          "FVector"
          
          ]), 
          
        makeImportedRuleField(uerIgnore, @[
          "PerInstanceSMCustomData", 
          "PerInstanceSMData",
          
          
          
           ]) #Enum not working because of the TEnum constructor being redefined by nim and it was already defined in UE. The solution would be to just dont work with TEnumAsByte but with the Enum itself which is more convenient. 

      ] 

      # genBindings("CoreUObject", moduleRules)

      let moduleNames = @["Engine"]

      # for moduleName in moduleNames:
      #   var engineModule = tryGetPackageByName(moduleName)
      #                 .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules, excludeDeps= @["CoreUObject"]))
      #                 .get()
        
      #   for moduleName in engineModule.dependencies:
      #     genBindings(moduleName, moduleRules)
     

      # genBindings("Chaos", moduleRules)
      # genBindingsWithDeps("Engine", moduleRules)
      genBindings("Engine", moduleRules & @[makeImportedRuleModule(uerImportBlueprintOnly)])

      #Engine can be splited in two modules one is BP based and the other dont
      #All kismets would be in its own module -20k lines of code?

      # Hand pick classes
      # Static functions that collides can be virtual modules too. (We need to find the colliding functions)
  
    proc experiments() = 
      let clsName = "Actor"
      let cls = getClassByName(clsName)
      let ueType = cls.toUEType().get()
      
      UE_Log $cls
      UE_Log $cls.getModuleName()

      UE_Warn &"UEType dependencies: {ueType.getModuleNames()}"


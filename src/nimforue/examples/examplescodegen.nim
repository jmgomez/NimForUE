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
  
  var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules))
                      .get()
  let codegenPath = reflectionDataPath / moduleName.toLower() & ".nim"
  let exportBindingsPath = bindingsDir / "exported" / moduleName.toLower() & ".nim"
  let importBindingsPath = bindingsDir / moduleName.toLower() & ".nim"
  UE_Log &"-= The codegen module path is {codegenPath} =-"

  try:
    let codegenTemplate = codegenNimTemplate % [$module, escape(exportBindingsPath), escape(importBindingsPath)]
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


#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc generateUETypes() = 
      # let a = ETest.testB
      let moduleRules = @[
        makeImportedRuleType(uerCodeGenOnlyFields, @["AActor", "UReflectionHelpers"]), 
        makeImportedRuleField(uerIgnore, @["PerInstanceSMCustomData", "PerInstanceSMData" ]) #Enum not working because of the TEnum constructor being redefined by nim and it was already defined in UE. The solution would be to just dont work with TEnumAsByte but with the Enum itself which is more convenient. 

      ] 
      let moduleNames = @["Engine"]
      for moduleName in moduleNames:
        var engineModule = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules))
                      .get()
        
        for moduleName in engineModule.dependencies:
          genBindings(moduleName, moduleRules)

        


    proc showEngineDependencies() = 
      let moduleNames = @["Engine"]
      let moduleRules = @[
          makeImportedRuleType(uerCodeGenOnlyFields, @["AActor", "UReflectionHelpers"]), 
          makeImportedRuleField(uerIgnore, @["PerInstanceSMCustomData", "PerInstanceSMData" ]) #Enum not working because of the TEnum constructor being redefined by nim and it was already defined in UE. The solution would be to just dont work with TEnumAsByte but with the Enum itself which is more convenient. 

        ]
      for moduleName in moduleNames:
        var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules))
                      .get()

        
        UE_Warn &"{module.name} Deps: {module.dependencies}"



    proc showCoreUObjectClasses() = 
      let moduleNames = @["CoreUObject"]
      let moduleRules = @[
          makeImportedRuleType(uerCodeGenOnlyFields, @["AActor", "UReflectionHelpers"]), 
          makeImportedRuleField(uerIgnore, @["PerInstanceSMCustomData", "PerInstanceSMData" ]) #Enum not working because of the TEnum constructor being redefined by nim and it was already defined in UE. The solution would be to just dont work with TEnumAsByte but with the Enum itself which is more convenient. 

        ]
      for moduleName in moduleNames:
        var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules))
                      .get()

        UE_Log $module      


    proc experiments() = 
      let clsName = "Actor"
      let cls = getClassByName(clsName)
      let ueType = cls.toUEType().get()
      
      UE_Log $cls
      UE_Log $cls.getModuleName()

      UE_Warn &"UEType dependencies: {ueType.getModuleNames()}"


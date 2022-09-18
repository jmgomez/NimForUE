include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate

#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc generateUETypes() = 
      # let a = ETest.testB
      let config = getNimForUEConfig()
      let reflectionDataPath = config.pluginDir / "src" / ".reflectiondata" #temporary
      createDir(reflectionDataPath)
      let bindingsDir = config.pluginDir / "src"/"nimforue"/"unreal"/"bindings"
      createDir(bindingsDir)
      #let moduleNames = @["NimForUEBindings", "Engine"]
      let moduleNames = @["NimForUEBindings"]
      let moduleRules = @[
          makeImportedRuleType(uerCodeGenOnlyFields, @["AActor", "UReflectionHelpers"]), 
          makeImportedRuleField(uerIgnore, @["PerInstanceSMCustomData", "PerInstanceSMData", "EnumProperty" ]) #Enum not working because of the TEnum constructor being redefined by nim and it was already defined in UE. The solution would be to just dont work with TEnumAsByte but with the Enum itself which is more convenient. 

        ]
      # let moduleNames = @["NimForUEBindings"]
      for moduleName in moduleNames:
        var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules))
                      .get()

        let codegenPath = reflectionDataPath / moduleName.toLower() & ".nim"
        let bindingsPath = bindingsDir / moduleName.toLower() & ".nim"
        let cppBindingsPath = bindingsDir / moduleName.toLower() & "cpp.nim"
        UE_Log &"-= The codegen module path is {codegenPath} =-"

        try:
          let codegenTemplate = codegenNimTemplate % [$module, escape(bindingsPath), escape(cppBindingsPath)]
          #UE_Warn &"{codegenTemplate}"
          writeFile(codegenPath, codegenTemplate)
          let nueCmd = config.pluginDir/"nue.exe codegen --module:\"" & codegenPath & "\""
          let result = execProcess(nueCmd, workingDir = config.pluginDir)
          # removeFile(codegenPath)
          UE_Log &"The result is {result} "
          UE_Log &"-= Bindings for {moduleName} generated in {bindingsPath} =- "

          doAssert(fileExists(bindingsPath))
          doAssert(fileExists(cppBindingsPath))
        except:
          let e : ref Exception = getCurrentException()

          UE_Log &"Error: {e.msg}"
          UE_Log &"Error: {e.getStackTrace()}"
          UE_Log &"Failed to generate {codegenPath} nim binding"





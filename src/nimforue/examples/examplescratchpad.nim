include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../buildscripts/codegentemplate

makeStrProc(UEMetadata)
makeStrProc(UEField)
makeStrProc(UEType)
makeStrProc(UEModule)

uClass AActorScratchpad of AActor:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    # intProp2 : int32
  
  ufuncs(CallInEditor):
    proc generateUETypes() = 
      let config = getNimForUEConfig()
      let reflectionDataPath = config.pluginDir / "src" / ".reflectiondata" #temporary
      createDir(reflectionDataPath)
      let bindingsDir = config.pluginDir / "src"/"nimforue"/"unreal"/"bindings"
      createDir(bindingsDir)
      let moduleNames = @["NimForUEBindings", "Engine"]
      for moduleName in moduleNames:
        let module = tryGetPackageByName(moduleName)
                      .flatmap(toUEModule)
        let codegenPath = reflectionDataPath / moduleName.toLower() & ".nim"
        let bindingsPath = bindingsDir / moduleName.toLower() & ".nim"
        UE_Log &"-= The codegen module path is {codegenPath} =-"

        try:
          let codegenTemplate = codegen_nim_template % [$module.get(), escape(bindingsPath)]
          #UE_Warn &"{codegenTemplate}"
          writeFile(codegenPath, codegenTemplate)
          let nueCmd = config.pluginDir/"nue.exe codegen --module:\"" & codegenPath & "\""
          let result = execProcess(nueCmd, workingDir = config.pluginDir)
          removeFile(codegenPath)
          #UE_Log &"The result is {result} "
          UE_Log &"-= Bindings for {moduleName} generated in {bindingsPath} =- "

          doAssert(fileExists(bindingsPath))
        except:
          let e : ref Exception = getCurrentException()

          UE_Log &"Error: {e.msg}"
          UE_Log &"Error: {e.getStackTrace()}"
          UE_Log &"Failed to generate {codegenPath} nim binding"

    proc showUEConfig() = 
      let config = getNimForUEConfig()
      createDir(config.pluginDir / ".reflectiondata")

    proc findEnum() = 
      let enumToFind = "EMaterialSamplerType"
      UE_Log &"looking for enum {enumToFind}"
      let uenum = someNil findObject[UEnum](anyPackage(), enumToFind)
      UE_Log &"Found {uenum}"
      let ueField = uenum.map(toUEType)
      UE_Warn &"Field {ueField}"
      let enums = uenum.get().getEnums()
      UE_Log &"Enum values: {enums}"


    
    proc showTotalEnums() = 
      let module = tryGetPackageByName("Engine")
                      .flatmap(toUEModule)
      let enums = module.get().types.filter((x:UEType)=> x.kind == uetEnum)
      UE_Log &"Total enums: {enums.len}"
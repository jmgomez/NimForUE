include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../buildscripts/codegentemplate

import ../unreal/bindings/[nimforuebindings, engine]
import ../unreal/bindings/[nimforuebindings]

# {.experimental: "codeReordering".}

# type Base = AActor #to quickly test from the bindings

makeStrProc(UEMetadata)
makeStrProc(UEField)
makeStrProc(UEType)
makeStrProc(UEImportRule)
makeStrProc(UEModule)


uEnum ETest:
  testA
  testB


type
  EComponentMobility* {.size: sizeof(uint8).} = enum
    Static, Stationary, Movable, EComponentMobility_MAX
#-------
#withEditor
#Platforms
#-------
# uClass AActorScratchpad of AActor:
uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    objTest : TObjectPtr[AActor]
    # objTestInArray : TArray[TObjectPtr[AActor]]
    beatiful: EComponentMobility
  
    # intProp2 : int32
  
  ufuncs(CallInEditor):
    proc generateUETypes() = 
      # let a = ETest.testB
      let config = getNimForUEConfig()
      let reflectionDataPath = config.pluginDir / "src" / ".reflectiondata" #temporary
      createDir(reflectionDataPath)
      let bindingsDir = config.pluginDir / "src"/"nimforue"/"unreal"/"bindings"
      createDir(bindingsDir)
      let moduleNames = @["NimForUEBindings", "Engine"]
      let moduleRules = @[
          makeImportedRuleType(uerCodeGenOnlyFields, @["AActor"]), 
          makeImportedRuleField(uerIgnore, @["PerInstanceSMCustomData", "PerInstanceSMData" ])

        ]
      # let moduleNames = @["NimForUEBindings"]
      for moduleName in moduleNames:
        var module = tryGetPackageByName(moduleName)
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(moduleRules))
                      .get()

        let codegenPath = reflectionDataPath / moduleName.toLower() & ".nim"
        let bindingsPath = bindingsDir / moduleName.toLower() & ".nim"
        UE_Log &"-= The codegen module path is {codegenPath} =-"

        try:
          let codegenTemplate = codegenNimTemplate % [$module, escape(bindingsPath)]
          #UE_Warn &"{codegenTemplate}"
          writeFile(codegenPath, codegenTemplate)
          let nueCmd = config.pluginDir/"nue.exe codegen --module:\"" & codegenPath & "\""
          let result = execProcess(nueCmd, workingDir = config.pluginDir)
          # removeFile(codegenPath)
          UE_Log &"The result is {result} "
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
      UE_Log &"-= The plugin dir is {config.pluginDir} =-"
      UE_Log &"-= The plugin dir is {config.pluginDir} =-"

    
    proc findEnum() = 
      
      let enumToFind = "EMaterialSamplerType"
      UE_Log &"looking for enum aaa{enumToFind}"
      # let uenum = someNil findObject[UEnum](anyPackage(), enumToFind)
      # UE_Log &"Found {uenum}"
      # let ueField = uenum.map(toUEType)
      # UE_Warn &"Field {ueField}"
      # let enums = uenum.get().getEnums()#.toSeq()
      # UE_Log &"Enum values: {enums}"

    
    proc showDelegates() = 
      let module = tryGetPackageByName("NimForUEBindings")
                      .flatmap((pkg:UPackagePtr) => pkg.toUEModule(@[]))
      let delegates = module.get().types.filter((x:UEType)=> x.kind == uetDelegate)
      UE_Log &"Delegates: {delegates}"

  ufuncs(BlueprintCallable):
    proc sayHello() = 
      UE_Log &"Hello from the scratchpad 5"
      UE_Log &"Hello from the scratchpad"
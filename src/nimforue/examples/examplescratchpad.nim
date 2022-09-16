include ../unreal/prelude
import std/[strformat, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../typegen/uemeta
import ../../buildscripts/nimforueconfig
import ../macros/makestrproc

import ../../codegen/codegentemplate

# import ../unreal/bindings/[nimforuebindings, testimport]
# import ../unreal/bindings/[nimforuebindings]

# {.experimental: "codeReordering".}

# type Base = AActor #to quickly test from the bindings

makeStrProc(UEMetadata)
makeStrProc(UEField)
makeStrProc(UEType)
makeStrProc(UEImportRule)
makeStrProc(UEModule)



#[
#this works
const uePropType* = UEType(name: "UMyClassToTest", parent: "UObject", kind: uetClass, 
                    fields: @[
                        makeFieldAsUFun("GetHelloWorld", @[makeFieldAsUPropParam("ReturnValue", "FString", CPF_ReturnParm or CPF_Parm)], "UMyClassToTest"),
                        ])

genType(uePropType)
]#

#[
# this works
type
  UMyClassToTest* = object of UObject
  UMyClassToTestPtr* = ptr UMyClassToTest

proc getHelloWorld*(obj: UMyClassToTestPtr): FString =
  type
    Params = object
      returnValue: FString

  var param = Params()
  var fnName: FString = "GetHelloWorld"
  callUFuncOn(obj, fnName, param.addr)
  return param.returnValue
]#


type
  UMyClassToTest {.importcpp, header:"UEGenBindings.h".} = object of UObject
  UMyClassToTestPtr = ptr UMyClassToTest

#this works I think it was failing before because of how importcpp was defined
#[
#this fails:
error C2027: use of undefined type 'UMyClassToTest'
D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\NimHeaders\UEGenBindings.h(24): note: see declaration of 'UMyClassToTest'
D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\src\nimforue\examples\examplescratchpad.nim(88): error C2660: 'amp___nimforueZunrealZ67oreZ67ontainersZunrealstring_86': function does not take 1 arguments
D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\src\nimforue\unreal\definitions.nim(43): note: see declaration of 'amp___nimforueZunrealZ67oreZ67ontainersZunrealstring_86'
#proc getHelloWorld(obj : UMyClassToTestPtr) : FString {. importcpp:"#.$1()", header:"UEGenBindings.h" .}
]#

#this works!
proc getHelloWorld(obj : UMyClassToTestPtr) : FString {. importcpp:"$1(#)", header:"UEGenBindings.h" .}


uEnum ETest:
  testA
  testB


type
  EComponentMobility* {.size: sizeof(uint8).} = enum
    Static, Stationary, Movable, EComponentMobilityMAX
#-------
#withEditor
#Platforms
#-------
uClass AActorScratchpad of AActor:
# uClass AActorScratchpad of APlayerController:
  (BlueprintType)
  uprops(EditAnywhere, BlueprintReadWrite, ExposeOnSpawn):
    stringProp : FString
    intProp : int32#
    objTest : TObjectPtr[AActor]
    objTest2 : TObjectPtr[AActor]
    # objTestInArray : TArray[TObjectPtr[AActor] g.packed[module].module
    beatiful: EComponentMobility
  
    # intProp2 : int32
  
  ufuncs(CallInEditor):
    proc testHelloWorld() =
      let obj = newUObject[UMyClassToTest]()
      UE_Log "testHelloWorld: " & obj.getHelloWorld()

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
      UE_Log &"Hello from the scratchpad doesnt  sens taskes more "
      UE_Log &"Hello from the scratchpad sa holly dasds"
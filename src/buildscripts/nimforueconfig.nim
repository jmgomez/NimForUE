import std/[json, jsonutils, os, sequtils, strformat, sugar]
import buildcommon

#[
The file is created for first time in from this file during compilation
Since UBT has to set some values on it, it does so through the FFI 
and then Saves it back to the json file. That's why we try to load it first before creating it.
]#
type NimForUEConfig* = object 
  genFilePath* : string
  nimForUELibPath* : string #due to how hot reloading on mac this now sets the last compiled filed.
  hostLibPath* : string
  engineDir* : string #Sets by UBT
  pluginDir* : string
  targetConfiguration* : TargetConfiguration #Sets by UBT (Development, Build)
  targetPlatform* : TargetPlatform #Sets by UBT
  # currentCompilation* : int 
  #WithEditor? 
  #DEBUG?

func getConfigFileName() : string = 
  when defined macosx:
    return "NimForUE.mac.json"
  when defined windows:
    return "NimForUE.win.json"

#when saving outside of nim set the path to the project
proc saveConfig*(config:NimForUEConfig, pluginDirPath="") =
  let pluginDir = if pluginDirPath == "": getCurrentDir() else: pluginDirPath
  let ueConfigPath = pluginDir / getConfigFileName()
  var json = toJson(config)
  writeFile(ueConfigPath, json.pretty())

proc getOrCreateNUEConfig(pluginDirPath="") : NimForUEConfig = 
  let pluginDir = if pluginDirPath == "": getCurrentDir() else: pluginDirPath
  let ueConfigPath = pluginDir / getConfigFileName()
  if fileExists ueConfigPath:
    let json = readFile(ueConfigPath).parseJson()
    return jsonTo(json, NimForUEConfig)
  NimForUEConfig(pluginDir:pluginDir)

proc getNimForUEConfig*(pluginDirPath="") : NimForUEConfig = 
  let pluginDir = if pluginDirPath == "": getCurrentDir() else: pluginDirPath
  #Make sure correct paths are set (Mac vs Wind)
  let ueLibsDir = pluginDir/"Binaries"/"nim"/"ue"
  #CREATE AND SAVE BEFORE RETURNING
  let genFilePath = pluginDir / "src" / "hostnimforue"/"ffigen.nim"
  var config = getOrCreateNUEConfig(pluginDirPath)
  config.nimForUELibPath = ueLibsDir / getFullLibName("nimforue")
  config.hostLibPath =  ueLibsDir / getFullLibName("hostnimforue")
  config.genFilePath = genFilePath
  config.engineDir = config.engineDir.normalizedPath().normalizePathEnd()
  config.pluginDir = config.pluginDir.normalizedPath().normalizePathEnd()
  #Rest of the fields are sets by UBT
  config.saveConfig()
  config


proc getUEHeadersIncludePaths*(conf:NimForUEConfig) : seq[string] =
  let platformDir = if conf.targetPlatform == Mac: "Mac/x86_64" else: $ conf.targetPlatform
  let confDir = $ conf.targetConfiguration
  let engineDir = conf.engineDir
  let pluginDir = conf.pluginDir

  let pluginDefinitionsPaths = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / confDir  #Notice how it uses the TargetPlatform, The Editor?, and the TargetConfiguration
  let nimForUEIntermediateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUE"
  let nimForUEBindingsHeaders =  pluginDir / "Source/NimForUEBindings/Public/"
  let nimForUEBindingsIntermediateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUEBindings"
  let nimForUEEditorHeaders =  pluginDir / "Source/NimForUEEditor/Public/"
  let nimForUEEditorIntermediateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUEEditor"

  let essentialHeaders = @[
    pluginDefinitionsPaths / "NimForUE",
    pluginDefinitionsPaths / "NimForUEBindings",
    nimForUEIntermediateHeaders,
    nimForUEBindingsHeaders,
    nimForUEBindingsIntermediateHeaders,
    #notice this shouldn't be included when target <> Editor
    nimForUEEditorHeaders,
    nimForUEEditorIntermediateHeaders,

    pluginDir / "NimHeaders",
    #engine
    engineDir / "Source/Runtime/Engine/Classes",
    engineDir / "Source/Runtime/Engine/Classes/Engine",
    engineDir / "Source/Runtime/Net/Core/Public",
    engineDir / "Source/Runtime/Net/Core/Classes",
    engineDir / "Source/Runtime/InputCore/Classes"
  ]

  proc getEngineRuntimeIncludePathFor(engineFolder, moduleName: string) : string = engineDir / "Source" / engineFolder / moduleName / "Public"
  proc getEngineIntermediateIncludePathFor(moduleName:string) : string = engineDir / "Intermediate/Build" / platformDir / "UnrealEditor/Inc" / moduleName

  let runtimeModules = @["CoreUObject", "Core", "Engine", "TraceLog", "Launch", "ApplicationCore", 
      "Projects", "Json", "PakFile", "RSA", "Engine", "RenderCore",
      "NetCore", "CoreOnline", "PhysicsCore", "Experimental/Chaos", 
      "Experimental/ChaosCore", "InputCore", "RHI", "AudioMixerCore", "AssetRegistry", "DeveloperSettings"]

  let developerModules = @["DesktopPlatform", "ToolMenus", "TargetPlatform", "SourceControl"]
  let intermediateGenModules = @["NetCore", "Engine", "PhysicsCore", "AssetRegistry", "InputCore", "DeveloperSettings"]

  let moduleHeaders = 
    runtimeModules.map(module=>getEngineRuntimeIncludePathFor("Runtime", module)) & 
    developerModules.map(module=>getEngineRuntimeIncludePathFor("Developer", module)) & 
    intermediateGenModules.map(module=>getEngineIntermediateIncludePathFor(module))

  (essentialHeaders & moduleHeaders).map(path => path.normalizedPath().normalizePathEnd())



proc getUESymbols*(conf: NimForUEConfig): seq[string] =
  let platformDir = if conf.targetPlatform == Mac: "Mac/x86_64" else: $conf.targetPlatform
  let confDir = $conf.targetConfiguration
  let engineDir = conf.engineDir
  let pluginDir = conf.pluginDir
  
  proc getEngineRuntimeSymbolPathFor(prefix, moduleName:string): string =  
    when defined windows:
      engineDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / moduleName / &"{prefix}-{moduleName}.lib"
    elif defined macosx:
      let platform = $conf.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
      engineDir / "Binaries" / platform / &"{prefix}-{moduleName}.dylib"

  proc getNimForUESymbols(): seq[string] = 
    when defined macosx:
      let libpath  = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUEBindings.dylib"
      #notice this shouldnt be included when target <> Editor
      let libPathEditor  = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUEEditor.dylib"
    elif defined windows:
      let libPath = pluginDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / "NimForUEBindings/UnrealEditor-NimForUEBindings.lib"
      let libPathEditor = pluginDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / "NimForUEEditor/UnrealEditor-NimForUEEditor.lib"

    @[libPath, libPathEditor]

  let modules = @["Core", "CoreUObject", "Engine"]
  let engineSymbolsPaths  = modules.map(modName=>getEngineRuntimeSymbolPathFor("UnrealEditor", modName))

  (engineSymbolsPaths & getNimForUESymbols()).map(path => path.normalizedPath())


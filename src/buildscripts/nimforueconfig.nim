import std/[json, jsonutils, os, strutils, genasts, sequtils, strformat, sugar, options]
import ../nimforue/utils/utils
import buildcommon

# codegen paths
const NimHeadersDir* = "NimHeaders"
const NimHeadersModulesDir* = NimHeadersDir / "Modules"
const BindingsDir* = "src"/"nimforue"/"unreal"/"bindings"
const BindingsExportedDir* = "src"/"nimforue"/"unreal"/"bindings"/"exported"
const ReflectionDataDir* = "src" / ".reflectiondata"
const ReflectionDataFilePath* = ReflectionDataDir / "ueproject.nim"




when defined(nue) and compiles(gorgeEx("")):
  const ex  = gorgeEx("powershell.exe pwd") 
  const output = $ex[0]
  const PluginDir* = output.split("----")[1].strip().replace("\\src\\buildscripts", "")
else:
  const PluginDir* {.strdefine.} = ""#Defined in switches. Available for all targets (Hots, Guest..)

#[
The file is created for first time in from this file during compilation
Since UBT has to set some values on it, it does so through the FFI 
and then Saves it back to the json file. That's why we try to load it first before creating it.
]#


type NimForUEConfig* = object 
  engineDir* : string #Set by UBT
  gameDir* : string
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
proc saveConfig*(config:NimForUEConfig) =
  let ueConfigPath = PluginDir / getConfigFileName()
  var json = toJson(config)
  writeFile(ueConfigPath, json.pretty())



proc getOrCreateNUEConfig() : NimForUEConfig = 
  let ueConfigPath = PluginDir / getConfigFileName()
  if fileExists ueConfigPath:
    let json = parseFile(ueConfigPath)
    return json.to(NimForUEConfig)

  NimForUEConfig()


proc getNimForUEConfig*() : NimForUEConfig = 
  var config = getOrCreateNUEConfig()

  let configErrMsg = "Please check " & getConfigFileName() & " for missing: "
  doAssert(config.engineDir.dirExists(), configErrMsg & " engineDir")
  doAssert(config.gameDir.dirExists(), configErrMsg & " gameDir")
  config.engineDir = config.engineDir.normalizedPath().normalizePathEnd()
  config.gameDir = config.gameDir.normalizedPath().normalizePathEnd()

  #Rest of the fields are sets by UBT
  config.saveConfig()
  config


#PATHS. The can be set at compile time

#Make sure correct paths are set (Mac vs Wind)
#CREATE AND SAVE BEFORE RETURNING

# when defined(nue):
  # let config = getOrCreateNUEConfig("G:\\NimForUEDemov2\\NimForUEDemov2\\Plugins\\NimForUE")
# else:
#   const PluginDir* {.strdefine.} = ""#Defined in switches. Available for all targets (Hots, Guest..)

let config = getOrCreateNUEConfig()

let 
  ueLibsDir = PluginDir/"Binaries"/"nim"/"ue" #THIS WILL CHANGE BASED ON THE CURRENT CONF
  NimForUELibDir* = ueLibsDir.normalizePathEnd()
  HostLibPath* =  ueLibsDir / getFullLibName("hostnimforue")
  GenFilePath* = PluginDir / "src" / "hostnimforue"/"ffigen.nim"
  NimGameDir* = config.gameDir / "NimForUE"
  GamePath* = (config.gameDir / "*.uproject").walkFiles.toSeq().head().get("Couldnt find the uproject file")



template codegenDir(fname, constName: untyped): untyped =
  proc fname*(config: NimForUEConfig): string =
    PluginDir / constName

codegenDir(nimHeadersDir, NimHeadersDir)
codegenDir(nimHeadersModulesDir, NimHeadersModulesDir)
codegenDir(bindingsDir, BindingsDir)
codegenDir(bindingsExportedDir, BindingsExportedDir)
codegenDir(reflectionDataDir, ReflectionDataDir)
codegenDir(reflectionDataFilePath, ReflectionDataFilePath)




proc getUEHeadersIncludePaths*(conf:NimForUEConfig) : seq[string] =
  let platformDir = if conf.targetPlatform == Mac: "Mac/x86_64" else: $ conf.targetPlatform
  let confDir = $ conf.targetConfiguration
  let engineDir = conf.engineDir
  let pluginDir = PluginDir

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
    engineDir / "Shaders",
    engineDir / "Shaders/Shared",
    engineDir / "Source",
    engineDir / "Source/Runtime",
    engineDir / "Source/Runtime/Engine",
    engineDir / "Source/Runtime/Engine/Public",
    engineDir / "Source/Runtime/Engine/Public/Rendering",
    engineDir / "Source/Runtime/Engine/Classes",
    engineDir / "Source/Runtime/Engine/Classes/Engine",
    engineDir / "Source/Runtime/Net/Core/Public",
    engineDir / "Source/Runtime/Net/Core/Classes",
    engineDir / "Source/Runtime/InputCore/Classes"
  ]

  let editorHeaders = @[
    engineDir / "Source/Editor",
    engineDir / "Source/Editor/UnrealEd",
    engineDir / "Source/Editor/UnrealEd/Classes",
    engineDir / "Source/Editor/UnrealEd/Classes/Settings"
    
  ]

  proc getEngineRuntimeIncludePathFor(engineFolder, moduleName: string) : string = engineDir / "Source" / engineFolder / moduleName / "Public"
  proc getEngineRuntimeIncludeClassesPathFor(engineFolder, moduleName: string) : string = engineDir / "Source" / engineFolder / moduleName / "Classes"
  proc getEngineIntermediateIncludePathFor(moduleName:string) : string = engineDir / "Intermediate/Build" / platformDir / "UnrealEditor/Inc" / moduleName

  let runtimeModules = @["CoreUObject", "Core", "TraceLog", "Launch", "ApplicationCore", 
      "Projects", "Json", "PakFile", "RSA", "RenderCore",
      "NetCore", "CoreOnline", "PhysicsCore", "Experimental/Chaos", 
      "SlateCore", "Slate", "TypedElementFramework", "Renderer", "AnimationCore",
      "ClothingSystemRuntimeInterface", "SandboxFile", "NetworkFileSystem",
      "Experimental/Interchange/Core",
      "Experimental/ChaosCore", "InputCore", "RHI", "AudioMixerCore", "AssetRegistry", "DeveloperSettings"]

  let developerModules = @["DesktopPlatform", 
  "ToolMenus", "TargetPlatform", "SourceControl", 
  "DeveloperToolSettings",
  "Localization"]
  let intermediateGenModules = @["NetCore", "Engine", "PhysicsCore", "AssetRegistry", 
    "UnrealEd", "ClothingSystemRuntimeInterface",  "EditorSubsystem", "InterchangeCore",
    "TypedElementFramework","Chaos", "ChaosCore", "EditorStyle", "EditorFramework",
    "Localization", "DeveloperToolSettings", "Slate",
    "InputCore", "DeveloperSettings", "SlateCore", "ToolMenus"]
  let editorModules = @["UnrealEd", "PropertyEditor", 
  "EditorStyle", "EditorSubsystem","EditorFramework",
  
  ]
  let moduleHeaders = 
    runtimeModules.map(module=>getEngineRuntimeIncludePathFor("Runtime", module)) & 
    developerModules.map(module=>getEngineRuntimeIncludePathFor("Developer", module)) & 
    developerModules.map(module=>getEngineRuntimeIncludeClassesPathFor("Developer", module)) & #if it starts to complain about the lengh of the cmd line. Optimize here
    editorModules.map(module=>getEngineRuntimeIncludePathFor("Editor", module)) & 
    intermediateGenModules.map(module=>getEngineIntermediateIncludePathFor(module)) 

  (essentialHeaders & moduleHeaders & editorHeaders).map(path => path.normalizedPath().normalizePathEnd())



proc getUESymbols*(conf: NimForUEConfig): seq[string] =
  let platformDir = if conf.targetPlatform == Mac: "Mac/x86_64" else: $conf.targetPlatform
  let confDir = $conf.targetConfiguration
  let engineDir = conf.engineDir
  let pluginDir = PluginDir
  #We only support Debug and Development for now and Debug is Windows only
  let suffix = if conf.targetConfiguration == Debug : "-Win64-Debug" else: "" 
  proc getEngineRuntimeSymbolPathFor(prefix, moduleName:string): string =  
    when defined windows:
      engineDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / moduleName / &"{prefix}-{moduleName}{suffix}.lib"
    elif defined macosx:
      let platform = $conf.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
      engineDir / "Binaries" / platform / &"{prefix}-{moduleName}.dylib"

  proc getNimForUESymbols(): seq[string] = 
    when defined macosx:
      let libpath = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUE.dylib"
      let libpathBindings  = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUEBindings.dylib"
      #notice this shouldnt be included when target <> Editor
      let libPathEditor  = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUEEditor.dylib"
    elif defined windows:
      let libPath = pluginDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / &"NimForUE/UnrealEditor-NimForUE{suffix}.lib"
      let libPathBindings = pluginDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / &"NimForUEBindings/UnrealEditor-NimForUEBindings{suffix}.lib"
      let libPathEditor = pluginDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / &"NimForUEEditor/UnrealEditor-NimForUEEditor{suffix}.lib"

    @[libPath,libpathBindings, libPathEditor]

  let modules = @["Core", "CoreUObject", "Engine", "SlateCore", "UnrealEd", "InputCore"]
  let engineSymbolsPaths  = modules.map(modName=>getEngineRuntimeSymbolPathFor("UnrealEditor", modName))

  (engineSymbolsPaths & getNimForUESymbols()).map(path => path.normalizedPath())


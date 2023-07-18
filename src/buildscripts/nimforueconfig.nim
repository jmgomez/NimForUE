import std/[json, jsonutils, os, strutils, genasts, sequtils, strformat, sugar, options]
import ../nimforue/utils/utils
import buildcommon

#[
TODO this file does too many things and it's imported from too many places
  It should be split in three files:
    - nimforuedefines.nim
    - nimforueconfig.nim
    - nimforuecppsymbols.nim
]#

# codegen paths
const NimHeadersDir* = "NimHeaders"
const NimHeadersModulesDir* = NimHeadersDir / "Modules"
const BindingsDir* = "src"/"nimforue"/"unreal"/"bindings"
const BindingsImportedDir* = "src"/"nimforue"/"unreal"/"bindings"/"imported"
const BindingsExportedDir* = "src"/"nimforue"/"unreal"/"bindings"/"exported"
const BindingsVMDir* = "src"/"nimforue"/"unreal"/"bindings"/"vm"
const ReflectionDataDir* = "src" / ".reflectiondata"
const ReflectionDataFilePath* = ReflectionDataDir / "ueproject.nim"

const GamePathError* = "Could not find the uproject file."

const MacOsARM* = true #Change this if you want to target x86_64 on mac (TODO autodetect)



when defined(nue) and compiles(gorgeEx("")):

  when defined(windows):
    const ex  = gorgeEx("powershell.exe pwd") 
    const output = $ex[0]
    const PluginDir* = output.split("----")[1].strip().replace("\\src\\buildscripts", "")
  else:
    const ex  = gorgeEx("pwd") 
    const output = $ex[0]
    const PluginDir* = output.strip().replace("/src/buildscripts", "")

else:
  const PluginDir* {.strdefine.} = ""#Defined in switches. Available for all targets (Hots, Guest..)


proc getGamePathFromGameDir*() : string =
  let gameDir = absolutePath(PluginDir/".."/"..", PluginDir)
  walkDir(gameDir)
    .toSeq    
    .filterIt(it[1].endsWith(".uproject"))
    .mapIt(it[1])
    .head()
    .get(GamePathError)
  # (gameDir / "*.uproject").walkFiles.toSeq().head().get(GamePathError)



proc UEVersion*() : float = #defers the execution until it's needed  
  when defined(nimsuggest) or defined(nimcheck): return 5.2 #Does really matter as it doesnt include anything

  let uprojectFile = getGamePathFromGameDir()
  let engineAssociation = readFile(uprojectFile).parseJson()["EngineAssociation"].getStr()
  parseFloat(engineAssociation)  
  


when MacOsARM and UEVersion() >= 5.2:
  const MacPlatformDir* = "Mac/arm64"
else:
  const MacPlatformDir* = "Mac/x86_64"


when UEVersion() >= 5.2: #Seems they introduced ARM win support in 5.2
  const WinPlatformDir* = "Win64"/"x64"
else:
  const WinPlatformDir* = "Win64"
  

when defined windows:
  import std/registry
  proc getEnginePathFromRegistry*(association:string) : string =
    let registryPath = "SOFTWARE\\EpicGames\\Unreal Engine\\" & association
    getUnicodeValue(registryPath, "InstalledDirectory", HKEY_LOCAL_MACHINE)
  
  proc tryGetEngineAndGameDir*() : Option[(string, string)] =
    try:
      #We assume we are inside the game plugin folder when no json is available
      let gameDir = absolutePath(PluginDir/".."/"..")
      let uprojectFile = getGamePathFromGameDir()
      let engineAssociation = readFile(uprojectFile).parseJson()["EngineAssociation"].getStr()
      let engineDir = getEnginePathFromRegistry(engineAssociation)
      some (engineDir / "Engine", gameDir)
    except:
      log "Could not find the game path. Please set the game path in the json file."
      log getCurrentExceptionMsg()
      none[(string, string)]()
else:
  proc tryGetEngineAndGameDir*() : Option[(string, string)] = 
     let gameDir = absolutePath(PluginDir/".."/"..")
     some ("", gameDir)

#Dll output paths for the uclasses the user generates
const OutputHeader* {.strdefine.} = ""
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
  withEditor* : bool
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

proc createConfigFromDirs(engineDir, gameDir:string) : NimForUEConfig = 
  let defaultPlatform = when defined(windows): Win64 else: Mac
  NimForUEConfig(engineDir: engineDir, gameDir: gameDir, withEditor:true, targetConfiguration: Development, targetPlatform: defaultPlatform)

proc getOrCreateNUEConfig() : NimForUEConfig = 
  let ueConfigPath = PluginDir / getConfigFileName()
  if fileExists ueConfigPath:
    let json = readFile(ueConfigPath).parseJson()
    return json.to(NimForUEConfig)
  let conf = 
    tryGetEngineAndGameDir()
      .map(d=>createConfigFromDirs(d[0], d[1]))
  
  if conf.isSome():
    conf.get().saveConfig()
    return conf.get()

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



let
  ueLibsDir = PluginDir/"Binaries"/"nim"/"ue" #THIS WILL CHANGE BASED ON THE CURRENT CONF
  NimForUELibDir* = ueLibsDir.normalizePathEnd()
  HostLibPath* =  ueLibsDir / getFullLibName("hostnimforue")
  GameLibPath* =  ueLibsDir / getFullLibName("game")
  GenFilePath* = PluginDir / "src" / "hostnimforue"/"ffigen.nim"
proc NimGameDir*() :string = getOrCreateNUEConfig().gameDir / "NimForUE" #notice this is a proc so it's lazy loaded
proc GamePath*() : string = getGamePathFromGameDir()
proc GameName*() : string = GamePath().split(PathSeparator)[^1].split(".")[0]
#TODO we need to make it accesible from game/guest at compile time
when defined(nue):
  let WithEditor* = getOrCreateNUEConfig().withEditor 
  doAssert(GamePath() != GamePathError, &"Config file error: The uproject file could not be found in {getOrCreateNUEConfig().gameDir}. Please check that 'gameDir' points to the directory containing your uproject in '{PluginDir / getConfigFileName()}'.")

else:
  const WithEditor* {.booldefine.} = true


template codegenDir(fname, constName: untyped): untyped =
  proc fname*(config: NimForUEConfig): string =
    PluginDir / constName

codegenDir(nimHeadersDir, NimHeadersDir)
codegenDir(nimHeadersModulesDir, NimHeadersModulesDir)
codegenDir(bindingsDir, BindingsDir)
codegenDir(bindingsImportedDir, BindingsImportedDir)
codegenDir(bindingsExportedDir, BindingsExportedDir)
codegenDir(reflectionDataDir, ReflectionDataDir)
codegenDir(reflectionDataFilePath, ReflectionDataFilePath)


proc getUEHeadersIncludePaths*(conf:NimForUEConfig) : seq[string] =
  let platformDir = if conf.targetPlatform == Mac: MacPlatformDir else:  WinPlatformDir
  let confDir = $ conf.targetConfiguration
  let engineDir = conf.engineDir
  let pluginDir = PluginDir
  let enginePluginDir = engineDir/"Plugins"#\EnhancedInput\Source\EnhancedInput\Public\EnhancedPlayerInput.h

  let unrealFolder = if conf.withEditor: "UnrealEditor" else: "UnrealGame"

  let pluginDefinitionsPaths = pluginDir / "Intermediate" / "Build" / platformDir / unrealFolder / confDir  #Notice how it uses the TargetPlatform, The Editor?, and the TargetConfiguration
  let nimForUEIntermediateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / unrealFolder / "Inc" / "NimForUE"
  let nimForUEBindingsHeaders =  pluginDir / "Source/NimForUEBindings/Public/"
  let nimForUEBindingsIntermediateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / unrealFolder / "Inc" / "NimForUEBindings"
  let nimForUEEditorHeaders =  pluginDir / "Source/NimForUEEditor/Public/"
  let nimForUEEditorIntermediateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / unrealFolder / "Inc" / "NimForUEEditor"

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
  proc getEngineIntermediateIncludePathFor(moduleName:string) : string = engineDir / "Intermediate/Build" / platformDir / unrealFolder / "Inc" / moduleName
  proc getEnginePluginModule(moduleName:string) : string = enginePluginDir / moduleName / "Source" / moduleName / "Public"
  proc getEngineRuntimePluginModule(moduleName:string) : string = enginePluginDir / "Runtime" / moduleName / "Source" / moduleName / "Public"
  proc getEngineExperimentalPluginModule(moduleName:string) : string = enginePluginDir / "Experimental" / moduleName / "Source" / moduleName / "Public"


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


  let enginePlugins = @["EnhancedInput"]
  let engineExperimentalPlugins = @["PCG"]
  let engineRuntimePlugins = @["GameplayAbilities"]

#Notice the header are not need for compiling the dll. We use a PCH. They will be needed to traverse the C++
  let moduleHeaders = 
    runtimeModules.map(module=>getEngineRuntimeIncludePathFor("Runtime", module)) & 
    developerModules.map(module=>getEngineRuntimeIncludePathFor("Developer", module)) & 
    developerModules.map(module=>getEngineRuntimeIncludeClassesPathFor("Developer", module)) & #if it starts to complain about the lengh of the cmd line. Optimize here
    editorModules.map(module=>getEngineRuntimeIncludePathFor("Editor", module)) & 
    intermediateGenModules.map(module=>getEngineIntermediateIncludePathFor(module)) &
    enginePlugins.map(module=>getEnginePluginModule(module)) & 
    engineRuntimePlugins.map(module=>getEngineRuntimePluginModule(module)) &
    engineExperimentalPlugins.map(module=>getEngineExperimentalPluginModule(module))

  (essentialHeaders & moduleHeaders & editorHeaders).map(path => path.normalizedPath().normalizePathEnd())



proc getUESymbols*(conf: NimForUEConfig): seq[string] =
  let platformDir = if conf.targetPlatform == Mac: MacPlatformDir else: WinPlatformDir
  let confDir = $conf.targetConfiguration
  let engineDir = conf.engineDir
  let pluginDir = PluginDir
  let unrealFolder = if conf.withEditor: "UnrealEditor" else: "UnrealGame"
  proc getObjFiles(dir: string, moduleName:string) : seq[string] = 
    #useful for non editor builds. Some modules are split
    # let objFiles = walkFiles(dir/ &"Module.{moduleName}*.cpp.obj").toSeq()
    # let objFiles = walkFiles(dir/ &"*.obj").toSeq()
    # echo &"objFiles for {moduleName} in {dir}: {objFiles}"
    
    # objFiles
    @[]

  #We only support Debug and Development for now and Debug is Windows only
  let suffix = if conf.targetConfiguration == Debug : "-Win64-Debug" else: "" 
  proc getEngineRuntimeSymbolPathFor(prefix, moduleName:string): seq[string] =  
    
    when defined windows:
      let dir =  engineDir / "Intermediate/Build" / platformDir / unrealFolder / confDir / moduleName 
      if conf.withEditor:
        @[dir / &"{prefix}-{moduleName}{suffix}.lib"]
      else:
        getObjFiles(dir, moduleName)
       
    elif defined macosx:
      let platform = $conf.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
      @[engineDir / "Binaries" / platform / &"{prefix}-{moduleName}.dylib"]
#E:\unreal_sources\5.1Launcher\UE_5.1\Engine\Plugins\EnhancedInput\Intermediate\Build\Win64\UnrealEditor\Development\EnhancedInput
  proc getEnginePluginSymbolsPathFor(prefix,  moduleName:string): seq[string] =  
      when defined windows:
        let dir = engineDir / "Plugins" / moduleName / "Intermediate/Build" / platformDir / unrealFolder / confDir / moduleName 
        if conf.withEditor:
          @[dir / &"{prefix}-{moduleName}{suffix}.lib"]
        else:
          getObjFiles(dir, moduleName)

      elif defined macosx:
        let platform = $conf.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
        @[engineDir / "Plugins" / moduleName / "Binaries" / platform / &"{prefix}-{moduleName}.dylib"]

  #engineFolder is Runtime, Experimental etc.
  proc getEnginePluginSymbolsPathFor(prefix,  engineFolder, moduleName:string): seq[string] =  
      when defined windows:
        let dir = engineDir / "Plugins" / engineFolder / moduleName / "Intermediate/Build" / platformDir / unrealFolder / confDir / moduleName 
        if conf.withEditor:
          @[dir / &"{prefix}-{moduleName}{suffix}.lib"]
        else:
          getObjFiles(dir, moduleName)

      elif defined macosx:
        let platform = $conf.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
        @[engineDir / "Plugins" / engineFolder  / moduleName / "Binaries" / platform / &"{prefix}-{moduleName}.dylib"]


  proc getNimForUESymbols(): seq[string] = 
    when defined macosx:
      let libpath = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUE.dylib"
      let libpathBindings  = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUEBindings.dylib"
      #notice this shouldnt be included when target <> Editor
      let libPathEditor  = pluginDir / "Binaries" / $conf.targetPlatform / "UnrealEditor-NimForUEEditor.dylib"
      return @[libPath,libpathBindings, libPathEditor]

    elif defined windows:

      if conf.withEditor:
        #seems like the plugin is still win64?
        let libPath = pluginDir / "Intermediate/Build" / platformDir / unrealFolder / confDir / &"NimForUE/UnrealEditor-NimForUE{suffix}.lib"
        let libPathBindings = pluginDir / "Intermediate/Build" / platformDir / unrealFolder / confDir / &"NimForUEBindings/UnrealEditor-NimForUEBindings{suffix}.lib"
        let libPathEditor = pluginDir / "Intermediate/Build" / platformDir / unrealFolder / confDir / &"NimForUEEditor/UnrealEditor-NimForUEEditor{suffix}.lib"
        @[libPath,libpathBindings, libPathEditor]
      else:
        let dir = pluginDir / "Intermediate/Build" / platformDir / unrealFolder / confDir 
        let libPath = getObjFiles(dir / "NimForUE", "NimForUE")
        let libPathBindings = getObjFiles(dir / "NimForUEBindings", "NimForUEBindings")
        libPath & libPathBindings

  let modules = @["Core", "CoreUObject", "PhysicsCore", "Engine", "SlateCore","Slate", "UnrealEd", "InputCore", "GameplayTags", "GameplayTasks", "NetCore", "UMG"]
  let engineSymbolsPaths  = modules.map(modName=>getEngineRuntimeSymbolPathFor("UnrealEditor", modName)).flatten()
  let enginePluginSymbolsPaths = @["EnhancedInput"].map(modName=>getEnginePluginSymbolsPathFor("UnrealEditor", modName)).flatten()
  let engineRuntimePluginSymbolsPaths = @["GameplayAbilities"].map(modName=>getEnginePluginSymbolsPathFor("UnrealEditor", "Runtime", modName)).flatten()
  let engineExperimentalPluginSymbolsPaths = @["PCG"].map(modName=>getEnginePluginSymbolsPathFor("UnrealEditor", "Experimental", modName)).flatten()

  (engineSymbolsPaths & enginePluginSymbolsPaths &  engineRuntimePluginSymbolsPaths & engineExperimentalPluginSymbolsPaths & getNimForUESymbols()).map(path => path.normalizedPath())



#TODO ADD RUNTIME TO THE PATH
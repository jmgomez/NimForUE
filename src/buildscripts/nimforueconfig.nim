import std/[strutils,sequtils, sugar, strformat, os, json, jsonutils]

func getFullLibName(baseLibName:string) :string  = 
    when defined macosx:
        return "lib" & baseLibName & ".dylib"
    elif defined windows:
        return  baseLibName & ".dll"
    elif defined linux:
        return ""



type TargetPlatform* = enum
    Mac = "Mac"
    Win64 = "Win64"
    #TODO Fill the rest

type TargetConfiguration* = enum
    Debug = "Debug"
    Development = "Development"
    Shipping = "Shipping"
    #TODO Fill the rest

proc fromJsonHook*(self: var TargetPlatform, jsonNode:JsonNode) =
    self = parseEnum[TargetPlatform](jsonNode.getStr())

proc fromJsonHook*(self: var TargetConfiguration, jsonNode:JsonNode) =
    self = parseEnum[TargetConfiguration](jsonNode.getStr())


proc toJsonHook*(self:TargetPlatform) : JsonNode = newJString($self)
proc toJsonHook*(self:TargetConfiguration) : JsonNode = newJString($self)

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
    #Rest of the fields are sets by UBT
    config.saveConfig()
    config



        
#Epics adds a space in the installation directory (Epic Games) on Windows so it has to be quoted. Maybe we should do this for all user paths?
proc addQuotes*(fullPath: string) : string = "\"" & fullPath & "\""

proc getUEHeadersIncludePaths*(conf:NimForUEConfig) : seq[string] =
    let platformDir = if conf.targetPlatform == Mac: "Mac/x86_64" else: $ conf.targetPlatform
    let confDir = $ conf.targetConfiguration
    let engineDir = conf.engineDir
    let pluginDir = conf.pluginDir

    let pluginDefinitionsPaths = "./Intermediate"/"Build"/ platformDir / "UnrealEditor"/confDir  #Notice how it uses the TargetPlatform, The Editor?, and the TargetConfiguration
    let nimForUEBindingsHeaders =  pluginDir/ "Source/NimForUEBindings/Public/"
    let nimForUEBindingsIntermidateHeaders = pluginDir/ "Intermediate"/ "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUEBindings"
    let nimForUEEditorHeaders =  pluginDir/ "Source/NimForUEEditor/Public/"
    let nimForUEEditorIntermidateHeaders = pluginDir/ "Intermediate"/ "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUEEditor"

    proc getEngineRuntimeIncludePathFor(engineFolder, moduleName:string) : string = addQuotes(engineDir / "Source"/engineFolder/moduleName/"Public")
    proc getEngineIntermediateIncludePathFor(moduleName:string) : string = addQuotes(engineDir / "Intermediate"/"Build"/platformDir/"UnrealEditor"/"Inc"/moduleName)
    
    let essentialHeaders = @[
        pluginDefinitionsPaths /  "NimForUE",
        pluginDefinitionsPaths /  "NimForUEBindings",
        nimForUEBindingsHeaders,
        nimForUEBindingsIntermidateHeaders,
    #notice this shouldnt be included when target <> Editor
        nimForUEEditorHeaders,
        nimForUEEditorIntermidateHeaders,

        pluginDir/"NimHeaders",
        #engine
        addQuotes(engineDir/"Source"/"Runtime"/"Engine"/"Classes"),
        addQuotes(engineDir/"Source"/"Runtime"/"Engine"/"Classes"/"Engine"),
        addQuotes(engineDir/"Source"/"Runtime"/"Net"/"Core"/"Public"),
        addQuotes(engineDir/"Source"/"Runtime"/"Net"/"Core"/"Classes")
    ]
    let runtimeModules = @["CoreUObject", "Core", "Engine", "TraceLog", "Launch", "ApplicationCore", 
        "Projects", "Json", "PakFile", "RSA", "Engine", "RenderCore",
        "NetCore", "CoreOnline", "PhysicsCore", "Experimental/Chaos", 
        "Experimental/ChaosCore", "InputCore", "RHI", "AudioMixerCore", "AssetRegistry"]

    let developerModules = @["DesktopPlatform", "ToolMenus", "TargetPlatform", "SourceControl"]
    let intermediateGenModules = @["NetCore", "Engine", "PhysicsCore", "AssetRegistry"]

    let moduleHeaders = 
        runtimeModules.map(module=>getEngineRuntimeIncludePathFor("Runtime", module)) & 
        developerModules.map(module=>getEngineRuntimeIncludePathFor("Developer", module)) & 
        intermediateGenModules.map(module=>getEngineIntermediateIncludePathFor(module))

    return essentialHeaders & moduleHeaders
        

proc getUESymbols*(conf:NimForUEConfig) : seq[string] =
    let platformDir = if conf.targetPlatform == Mac: "Mac/x86_64" else: $ conf.targetPlatform
    let confDir = $ conf.targetConfiguration
    let engineDir = conf.engineDir
    let pluginDir = conf.pluginDir
    
    proc getEngineRuntimeSymbolPathFor(prefix, moduleName:string) : string =  
        when defined windows:
            let libName = fmt "{prefix}-{moduleName}.lib" 
            return addQuotes(engineDir / "Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir / moduleName / libName)
        elif defined macosx:
            let platform = $conf.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)

            let libName = fmt "{prefix}-{moduleName}.dylib"
            return  engineDir / "Binaries" / platform / libName

    
    

    proc getNimForUESymbols() : seq[string] = 
        when defined macosx:
            let libpath  = pluginDir / "Binaries"/ $conf.targetPlatform/"UnrealEditor-NimForUEBindings.dylib"
            #notice this shouldnt be included when target <> Editor
            let libPathEditor  = pluginDir / "Binaries"/ $conf.targetPlatform/"UnrealEditor-NimForUEEditor.dylib"
          
        elif defined windows:
            let libName = fmt "UnrealEditor-NimForUEBindings.lib" 
            let libPath = addQuotes(pluginDir / "Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir / "NimForUEBindings" / libName)
            let libPathEditor = addQuotes(pluginDir / "Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir / "NimForUEEditor" / libName)
           
        @[libPath, libPathEditor]

    
    let modules = @["Core", "CoreUObject", "Engine"]
    let engineSymbolsPaths  = modules.map(modName=>getEngineRuntimeSymbolPathFor("UnrealEditor", modName))
    
    return engineSymbolsPaths & getNimForUESymbols()


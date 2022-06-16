import std/[os, strutils, json, jsonUtils]

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
    let str = jsonNode.getStr()
    self = parseEnum[TargetPlatform](str)

proc fromJsonHook*(self: var TargetConfiguration, jsonNode:JsonNode) =
    let str = jsonNode.getStr()
    self = parseEnum[TargetConfiguration](str)


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

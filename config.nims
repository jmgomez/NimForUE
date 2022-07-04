import src/buildscripts/[buildscripts, nimForUEConfig]
import std/[strutils,sequtils, sugar, os, strformat]
# let compiledFileName = projectPath().split("/")[^1].split(".")[0]
# switch("nimcache", "./Binaries/nim/nimcache/" & compiledFileName)

when defined host:
    switch("header", "NimForUEFFI.h")
    switch("threads") #needed to watch
    switch("tlsEmulation", "off")

switch("outdir", "./Binaries/nim/")
switch("backend", "cpp")
# switch("mm", "orc") 
switch("exceptions", "cpp") #need to investigate further how to get Unreal exceptions and nim exceptions to work together so UE doesn't crash when generating an exception in cpp
switch("define", "useMalloc")



when not defined copylib:
    # switch("listcmd")
    # switch("f")
    let nueConfig = getNimForUEConfig()
    switch("define", "genFilePath:"& nueConfig.genFilePath)
    switch("define", "pluginDir:"& nueConfig.pluginDir)
    #todo get from NueConfig?
    let withPCH = true and not defined host
    let withDebug = true
    

    let platformDir = if nueConfig.targetPlatform == Mac: "Mac/x86_64" else: $ nueConfig.targetPlatform
    #Im pretty sure theere will moref specific handles for the other platforms
    let confDir = $ nueConfig.targetConfiguration
    let engineDir = nueConfig.engineDir
    let pluginDir = nueConfig.pluginDir
    #/Volumes/Store/Dropbox/GameDev/UnrealProjects/NimForUEDemo/MacOs/Plugins/NimForUE/Intermediate/Build/Mac/x86_64/UnrealEditor/Development/NimForUE/PCH.NimForUE.h.gch
    let pchPath = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / confDir / "NimForUE" / "PCH.NimForUE.h.gch"

    case nueConfig.targetConfiguration:
        of Debug, Development:
            if withDebug:
                switch("debugger", "native")
                switch("stacktrace", "on")
            
            switch("opt", "none")

        of Shipping: 
            #TODO Maybe for shipping we need to get rid of the FFI dll and to use only NimForUE.dll
            switch("d", "release")

    when defined windows:
        switch("cc", "vcc")
        #switch("passC", "/MP") # build with multiple processes, enables /FS force synchronous writes
        switch("passC", "/FS") # build with multiple processes, enables /FS force synchronous writes
        switch("passC", "/std:c++17")

    when defined macosx: #Doesn't compile with ORC. TODO Investigate why
        switch("passC", "-x objective-c++")
        switch("passC", "-stdlib=libc++")
        switch("passC", "-fno-unsigned-char")
        switch("passC", "-std=c++17")
        switch("passC", "-fno-rtti")   
        switch("passC", "-fasm-blocks")   
        switch("passC", "-fvisibility-ms-compat")   
        switch("passC", "-fvisibility-inlines-hidden")   
        switch("passC", "-fno-delete-null-pointer-checks")   
        switch("passC", "-pipe")   
        switch("passC", "-fmessage-length=0")   
        
        if withPCH:
            switch("passC", "-include-pch " & pchPath)
        switch("cc", "clang")
        putEnv("MACOSX_DEPLOYMENT_TARGET", "10.15") #sets compatibility with the same macos version as ue5 was build to. Update: it can be passed as compiler option
        switch("passC", "-mincremental-linker-compatible")
        #(DYLD_LIBRARY_PATH cant be set without modifiying macosx permissions)
        #TODO try again passing the compiler --rpath
        #Uncomment the line above to being able to use executables that uses the engine libraries 
        # exec(fmt("ln -s {nueConfig.engineDir}/Binaries/Mac/*.dylib /usr/local/lib/"))



when defined withue:
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
        

    #EDITOR VS GAME is just switching UnrealEditor with UnrealGame?
    for headerPath in getUEHeadersIncludePaths(nueConfig):
        switch("passC", "-I" & headerPath)
    for symbolPath in getUESymbols(nueConfig):
        switch("passL", symbolPath)

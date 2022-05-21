import src/buildscripts/[buildscripts, nimForUEConfig]
import std/[strutils, sequtils, strformat]
import sugar
import std/os


# let compiledFileName = projectPath().split("/")[^1].split(".")[0]
# switch("nimcache", "./Binaries/nim/nimcache/" & compiledFileName)

when defined host:
    switch("header", "NimForUEFFI.h")
    switch("threads") #needed to watch
   
# switch("mm", "orc") #Doest compile with ORC. TODO Investigate why
switch("outdir", "./Binaries/nim/")
switch("backend", "cpp")

let nueConfig = getNimForUEConfig()
switch("define", "genFilePath:"& nueConfig.genFilePath)
switch("define", "pluginDir:"& nueConfig.pluginDir)


case nueConfig.targetConfiguration:
    of Debug, Development:
        switch("debugger", "native")
        switch("stacktrace", "on")
    of Shipping: 
        #TODO Maybe for shipping we need to get rid of the FFI dll and to use only NimForUE.dll
        switch("d", "release")  
      

when defined windows:
    switch("cc", "vcc")
    switch("passC", "/FS")
    switch("passC", "/std:c++17")

when defined macosx:
    switch("passC", "-x objective-c++")
    switch("passC", "-stdlib=libc++")
    switch("passC", "-fno-unsigned-char")
    switch("passC", "-std=c++17")
    switch("cc", "clang")
    putEnv("MACOSX_DEPLOYMENT_TARGET", "10.15") #sets compatibility with the same macos version as ue5 was build to
    
    #(DYLD_LIBRARY_PATH cant be set without modifiying macosx permissions)
    #TODO try again passing the compiler --rpath
    #Uncomment the line above to being able to use executables that uses the engine libraries 
    # exec(fmt("ln -s {nueConfig.engineDir}/Binaries/Mac/*.dylib /usr/local/lib/"))

when defined withue:   
   
    let platformDir = if nueConfig.targetPlatform == Mac: "Mac/x86_64" else: $ nueConfig.targetPlatform
    #Im pretty sure theere will moref specific handles for the other platforms
    let confDir = $ nueConfig.targetConfiguration
    let engineDir = nueConfig.engineDir
    let pluginDir = nueConfig.pluginDir
    

    proc addHeaders() = 
        let pluginDefinitionsPaths = "./Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir  #Notice how it uses the TargetPlatform, The Editor?, and the TargetConfiguration
        let nimForUEBindingsHeaders =  pluginDir/ "Source/NimForUEBindings/Public/"
        let nimForUEBindingsGeneratedHeaders =  pluginDir/ "Intermediate/Build/Mac/x86_64/UnrealEditor/Inc/NimForUEBindings"

        proc getEngineRuntimeIncludePathFor( moduleName, engineFolder:string) : string = "\"" & engineDir / "Source" / engineFolder / moduleName / "Public" & "\""
        proc setEngineRuntimeIncludeForModules(modules:seq[string], engineFolder:string) =
            for moduleName in modules:
                switch("passC", "-I" & getEngineRuntimeIncludePathFor(moduleName, engineFolder))

        switch("passC", "-I" & pluginDefinitionsPaths /  "NimForUE")
        switch("passC", "-I" & pluginDefinitionsPaths /  "NimForUEBindings")
        switch("passC", "-I" & nimForUEBindingsHeaders)
        switch("passC", "-I" & nimForUEBindingsGeneratedHeaders)
        switch("passC", "-I" & engineDir/"Source")
        switch("passC", "-I" & engineDir/"Public")


        switch("passC", "-I" & engineDir/"/Source/Runtime/InputCore/Classes")


        
        setEngineRuntimeIncludeForModules(@["CoreUObject", "Core", "TraceLog"], "Runtime")

        when defined test:

            let runtimeTestModules = @["Launch", "ApplicationCore", 
            "Projects", "Json", "PakFile", "RSA", "Engine", "RenderCore",
            "NetCore", "CoreOnline", "PhysicsCore", "Experimental/Chaos", 
            "Experimental/ChaosCore", "InputCore", "RHI", "AudioMixerCore", 
            #EDITOR 
            "DeveloperSettings", "SlateCore", "Slate", "AssetRegistry", "TypedElementFramework", 
            "Renderer", "MeshDescription", "Experimental/Interchange/Core"

            ]
            #/Volumes/Store/UnrealSources/UE_5.0/Engine/Source/Runtime/Experimental/Interchange/Core/Public
            let developerTestModules = @["DesktopPlatform", "ToolMenus", "TargetPlatform", "SourceControl"]
            switch("passC", "-I" & "/Volumes/Store/UnrealSources/UE_5.0/")

            setEngineRuntimeIncludeForModules(runtimeTestModules, "Runtime")
            setEngineRuntimeIncludeForModules(developerTestModules, "Developer")
            switch("passC", "-I" & engineDir/"Source/Runtime/Engine/Classes/")
            switch("passC", "-I" & engineDir/"Source"/"Runtime/Net/Core/Public/")
            switch("passC", "-I" & engineDir/"Source"/"Runtime/Net/Core/Classes/")
            switch("passC", "-I" & engineDir/"Source/Runtime/")
            switch("passC", "-I" & engineDir/"Source/Editor/UnrealEd/Classes")
            switch("passC", "-I" & engineDir/"Source/Editor/UnrealEd/Public")
            switch("passC", "-I" & engineDir/"Shaders/Shared")
          
            let editorModules = @["EditorStyle", "PropertyEditor", "EditorSubsystem", "PIEPreviewDeviceProfileSelector", "AudioEditor"]
            setEngineRuntimeIncludeForModules(editorModules, "Editor")

            #/Volumes/Store/UnrealSources/UE_5.0/Engine/Source/Editor/PropertyEditor/Public          
            proc setIntermediateEngine(moduleName:string) = #TODO change
                switch("passC", "-I" & fmt("/Volumes/Store/UnrealSources/UE_5.0/Engine/Intermediate/Build/Mac/x86_64/UnrealEditor/Inc/{moduleName}/"))
    
            setIntermediateEngine("NetCore")
            setIntermediateEngine("Engine")
            setIntermediateEngine("PhysicsCore")
            setIntermediateEngine("InputCore")
            setIntermediateEngine("DeveloperSettings")
            setIntermediateEngine("SlateCore")
            setIntermediateEngine("Slate")
            setIntermediateEngine("UnrealEd")
            setIntermediateEngine("ToolMenus")
            setIntermediateEngine("TypedElementFramework")
            setIntermediateEngine("Chaos")
            setIntermediateEngine("EditorSubsystem")
            setIntermediateEngine("MeshDescription")
            setIntermediateEngine("InterchangeCore")

            




            #HAD TO MODIFY THE NETINE FOR TICKABLE ON WorldSubsystem.h

    proc addSymbols() =
        proc getEngineRuntimeIncludePathFor(moduleName:string) : string =  
            when defined windows:
                let libName = fmt "UnrealEditor-{moduleName}.lib" 
                return "\"" & engineDir / "Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir / moduleName / libName & "\""
            when defined macosx:
                let platform = $nueConfig.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
                let libName = fmt "UnrealEditor-{moduleName}.dylib"
                return  engineDir / "Binaries" / platform / libName

        proc setEngineWeakSymbolsForModules(modules:seq[string]) =
            for module in modules:
                switch("passL",  getEngineRuntimeIncludePathFor(module))
        
        
        let nimForUEBindingsLib =  "/Volumes/Store/Dropbox/GameDev/UnrealProjects/NimForUEDemo/Plugins/NimForUE/Binaries/Mac/UnrealEditor-NimForUEBindings.dylib"
        switch("passL",  nimForUEBindingsLib)
        # switch("passC", "--rpath "&nimForUEBindingsLib)
        exec("rm  /usr/local/lib/UnrealEditor-NimForUEBindings.dylib")
        exec(fmt("ln -s {nimForUEBindingsLib} /usr/local/lib/"))


        let libs = readFile("./libs.txt").split("\n")
        let libToSkip = @["CrashDebugHelper", "AGXRHI"]
        for libname in libs:
            var name = libname
            if libToSkip.any(skipLib => skipLib in name):
                continue
            switch("passL", libname)

        # setEngineWeakSymbolsForModules(@["CoreUObject", "Core"])

        # when defined test:
        #     let runtimeTestModules = @["Launch", "ApplicationCore", "Projects", "Json", "PakFile", "RSA"]
        #     let developerTestModules = @["DesktopPlatform"]
        #     #  setEngineWeakSymbolsForModules(@["ApplicationCore"])
        #     switch("passL", "/Volumes/Store/UnrealSources/UE_5.0/Engine/Binaries/Mac/UnrealEditor-ApplicationCore.dylib")
        #     switch("passL", "/Volumes/Store/UnrealSources/UE_5.0/Engine/Binaries/Mac/UnrealEditor-Projects.dylib")

        #     switch("passL", "/Volumes/Store/UnrealSources/UE_5.0/Engine/Binaries/Mac/UnrealEditor-Core.dylib")
        #     switch("passL", "/Volumes/Store/UnrealSources/UE_5.0/Engine/Binaries/Mac/UnrealEditor-Engine.dylib")
        #     switch("passL", "/Volumes/Store/UnrealSources/UE_5.0/Engine/Binaries/Mac/UnrealEditor-BuildSettings.dylib")
        #     # setEngineWeakSymbolsForModules(runtimeTestModules)
    

    addHeaders()
    addSymbols()
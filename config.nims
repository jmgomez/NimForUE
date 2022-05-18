import src/buildscripts/[buildscripts, nimForUEConfig]
import std/[strutils, strformat]

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
        
        proc getEngineRuntimeIncludePathFor(moduleName:string) : string = "\"" & engineDir / "Source"/"Runtime"/moduleName/"Public" & "\""
        proc setEngineRuntimeIncludeForModules(modules:seq[string]) =
            for module in modules:
                switch("passC", "-I" & getEngineRuntimeIncludePathFor(module))

        switch("passC", "-I" & pluginDefinitionsPaths /  "NimForUE")
        switch("passC", "-I" & pluginDefinitionsPaths /  "NimForUEBindings")
        switch("passC", "-I" & nimForUEBindingsHeaders)
        setEngineRuntimeIncludeForModules(@["CoreUObject", "Core", "TraceLog"])
        

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
        
        # switch("passL",  nimForUEBindingsLib)
              
        
        setEngineWeakSymbolsForModules(@["CoreUObject", "Core"])
    

    addHeaders()
    addSymbols()
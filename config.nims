import src/buildscripts/[buildscripts, nimForUEConfig]
import std/[strutils,sequtils, sugar, strformat]

import std / [os]

# let compiledFileName = projectPath().split("/")[^1].split(".")[0]
# switch("nimcache", "./Binaries/nim/nimcache/" & compiledFileName)

when defined host:
    switch("header", "NimForUEFFI.h")
    switch("threads") #needed to watch
    switch("tlsEmulation", "off")

switch("outdir", "./Binaries/nim/")
switch("backend", "cpp")
switch("mm", "orc") 

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
    #switch("passC", "/MP") # build with multiple processes, enables /FS force synchronous writes
    switch("passC", "/FS") # build with multiple processes, enables /FS force synchronous writes
    switch("passC", "/std:c++17")

when defined macosx: #Doesn't compile with ORC. TODO Investigate why
    switch("cc", "clang")
    let clangCompilerOptions = @[
        "-x objective-c++",
        "-stdlib=libc++",
        "-fno-unsigned-char",
        "-std=c++17",
        "-fno-rtti",
        "-v",
        "-mincremental-linker-compatible"
    ]
    for compilerOption in clangCompilerOptions:
        switch("passC", compilerOption)
   
   
    putEnv("MACOSX_DEPLOYMENT_TARGET", "10.15") #sets compatibility with the same macos version as ue5 was build to
    #(DYLD_LIBRARY_PATH cant be set without modifiying macosx permissions)
    #TODO try again passing the compiler --rpath
    #Uncomment the line above to being able to use executables that uses the engine libraries 
    # exec(fmt("ln -s {nueConfig.engineDir}/Binaries/Mac/*.dylib /usr/local/lib/"))




when defined withue:   
    #EDITOR VS GAME is just switching UnrealEditor with UnrealGame?

    let platformDir = if nueConfig.targetPlatform == Mac: "Mac/x86_64" else: $ nueConfig.targetPlatform
    #Im pretty sure theere will moref specific handles for the other platforms
    let confDir = $ nueConfig.targetConfiguration
    let engineDir = nueConfig.engineDir
    let pluginDir = nueConfig.pluginDir
    
    
    #Epics adds a space in the installation directory (Epic Games) on Windows so it has to be quoted. Maybe we should do this for all user paths?
    proc addQuotes(fullPath: string) : string = "\"" & fullPath & "\""

    proc getHeadersIncludePaths() : seq[string] = 
        let pluginDefinitionsPaths = "./Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir  #Notice how it uses the TargetPlatform, The Editor?, and the TargetConfiguration
        let nimForUEBindingsHeaders =  pluginDir/ "Source/NimForUEBindings/Public/"
        let nimForUEBindingsIntermidateHeaders = pluginDir/ "Intermediate"/ "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUEBindings"

        proc getEngineRuntimeIncludePathFor(engineFolder, moduleName:string) : string = addQuotes(engineDir / "Source"/engineFolder/moduleName/"Public")
        proc getEngineIntermediateIncludePathFor(moduleName:string) : string = addQuotes(engineDir / "Intermediate"/"Build"/platformDir/"UnrealEditor"/"Inc"/moduleName)

        let essentialHeaders = @[
            pluginDefinitionsPaths /  "NimForUE",
            pluginDefinitionsPaths /  "NimForUEBindings",
            nimForUEBindingsHeaders,
            nimForUEBindingsIntermidateHeaders,
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
            "Experimental/ChaosCore", "InputCore", "RHI", "AudioMixerCore"]

        let developerModules = @["DesktopPlatform", "ToolMenus", "TargetPlatform", "SourceControl"]
        let intermediateGenModules = @["NetCore", "Engine", "PhysicsCore"]

        let moduleHeaders = 
            runtimeModules.map(module=>getEngineRuntimeIncludePathFor("Runtime", module)) & 
            developerModules.map(module=>getEngineRuntimeIncludePathFor("Developer", module)) & 
            intermediateGenModules.map(module=>getEngineIntermediateIncludePathFor(module))

        essentialHeaders & moduleHeaders

    proc addHeaders() = 
        let headers = getHeadersIncludePaths()
        for headerPath in headers:
            switch("passC", "-I" & headerPath)
        

    proc addSymbols() =

        proc getEngineRuntimeSymbolPathFor(prefix, moduleName:string) : string =  
            when defined windows:
                let libName = fmt "{prefix}-{moduleName}.lib" 
                return addQuotes(engineDir / "Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir / moduleName / libName)
            elif defined macosx:
                let platform = $nueConfig.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)

                let libName = fmt "{prefix}-{moduleName}.dylib"
                return  engineDir / "Binaries" / platform / libName
 
        proc setEngineWeakSymbolsForModules(prefix:string, modules:seq[string]) =
            for module in modules:
                switch("passL",  getEngineRuntimeSymbolPathFor(prefix, module))
        

        proc addNewForUEBindings() = 

            when defined macosx:
                let libpath  = pluginDir / "Binaries"/ $nueConfig.targetPlatform/"UnrealEditor-NimForUEBindings.dylib"
                switch("passL", libPath )
            elif defined windows:
                let libName = fmt "UnrealEditor-NimForUEBindings.lib" 
                let libPath = addQuotes(pluginDir / "Intermediate"/"Build"/ platformDir / "UnrealEditor"/ confDir / "NimForUEBindings" / libName)
                switch("passL", libPath)

        setEngineWeakSymbolsForModules("UnrealEditor", @["Core", "CoreUObject", "Engine"]) 
        addNewForUEBindings()

    proc emitPCH() = 
        #Will it require the same compiler options?
        #For sure it will require the include paths
        let sdkRoot = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
        #-x objective-c++-header -std=c++17 -stdlib=libc++
        let clangOptions = @[
            "-x objective-c++-header",
            "-stdlib=libc++",
            "-std=c++17",
            # "-fno-rtti",
            # "-flto", #this is in nim config file,
            # # "-framework Foundation",
            "-F Foundation",
            # "-framework Cocoa",
            # # "-framework Carbon",
            # # "-framework IOKit",
            # # "-framework Security",
            # "-isysroot " & sdkRoot,
            # "-cc1 ",
            # "-triple x86_64-apple-macosx10.15.0",
            # "-Wundef-prefix=TARGET_OS_",
            # "-Wdeprecated-objc-isa-usage",
            # "-emit-obj",
            # "-mincremental-linker-compatible",
            # "-mrelax-relocations",
            # "-disable-free",
            # "-disable-llvm-verifier",
            # "-discard-value-names",
            # "-target-linker-version 763",
            # "-resource-dir /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/13.1.6",
            # "-mrelocation-model pic",
            # "-pic-level 2",
            # "-mllvm -extra-vectorizer-passes",
            # "-fno-strict-return",
            # "-fno-rounding-math",
            # "-munwind-tables",
            # "-target-sdk-version=12.3",
            # "-fvisibility-inlines-hidden-static-local-var",


        



            # "-fblocks", #advice from an error (delete once everything work)
        ]
        
        #Notice: this can be built with "xcode-select", "--print-path" & hardcoded parth & 
        # let sdkRoot = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk"
        let exportSdKRootCmd = "export SDKROOT=" & sdkRoot
        let exportMacOsDeployment = "export MACOSX_DEPLOYMENT_TARGET=10.15"

        #/Applications/Xcode.app/Contents/Developer
        let headers = getHeadersIncludePaths() & 
            @[
                sdkRoot / "usr/include/c++/v1/",
                sdkRoot / "usr/include/",
                sdkRoot / "usr/include/",
                sdkRoot / "/System/Library/Frameworks/Kernel.framework/Versions/A/Headers/",
                "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/13.1.6/include/"
            ]
        let headerIncludePathCompilerOption = headers.map(h=> "-I" & h).foldl(a & " " & b, "")
        let compilerOptions = clangOptions.foldl(a & " " & b, "")


        #unreal
        #-fmessage-length=0 -pipe -fpascal-strings -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fasm-blocks -fvisibility-ms-compat -fvisibility-inlines-hidden -Wall -Werror -Wdelete-non-virtual-dtor -Wno-range-loop-analysis  -fno-delete-null-pointer-checks -Wshadow -Wundef -c -arch x86_64 -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk" -mmacosx-version-min=10.15 -O3 -gdwarf-2
        # let args = """-fmessage-length=0 -pipe -fpascal-strings -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fasm-blocks -fvisibility-ms-compat -fvisibility-inlines-hidden -Wall -Werror -Wdelete-non-virtual-dtor -Wno-range-loop-analysis  -fno-delete-null-pointer-checks -Wshadow -Wundef -c -arch x86_64 -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk" -mmacosx-version-min=10.15 -O3 -gdwarf-2"""
        let args = """-fmessage-length=0 -fpascal-strings -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fasm-blocks  -fvisibility-inlines-hidden -Wall -Werror -Wdelete-non-virtual-dtor -Wno-range-loop-analysis  -fno-delete-null-pointer-checks -Wshadow -Wundef -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk"  -O3 """

        # let compileCmd = "clang  -cc1 NimHeaders/UEDeps.h -emit-pch -o NimHeaders/UEDeps.h.pch  -x objective-c++-header -framework Foundation " & compilerOptions & headerIncludePathCompilerOption
        let compileCmd = fmt"clang -cc1 {compilerOptions} {args} NimHeaders/UEDeps.h -emit-pch -o NimHeaders/UEDeps.h.pch " & headerIncludePathCompilerOption
        # let compileCmd = "clang  -x objective-c++-header -framework Foundation  NimHeaders/UEDeps.h -emit-pch " & headerIncludePathCompilerOption
        # let compileCmd = fmt"clang {compilerOptions} NimHeaders/UEDeps.h --relocatable-pch " & headerIncludePathCompilerOption
        # let compileCmd = fmt"clang {compilerOptions} -emit-pch  ./NimHeaders/UEDeps.h -o ./NimHeaders/UEDeps.h.pch " & headerIncludePathCompilerOption 
          # clang -x c-header --relocatable-pch -isysroot /path/to/build /path/to/build/mylib.h mylib.h.pch

        let printSDKRootCMD = exportSdKRootCmd & " && " & "echo $SDKROOT"
        let cmd = exportSdKRootCmd & " && " & exportMacOsDeployment & " && " & compileCmd
        # echo "******************************** EXECUTING " & printSDKRootCMD & " ********************************"
        exec(cmd)

    emitPCH()   

    addHeaders()
    addSymbols()
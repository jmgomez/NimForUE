import src/buildscripts/[buildscripts, nimforueconfig]
# Package

version       = "0.1.0"
author        = "jmgomez"
description   = "A plugin for UnrealEngine 5"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.4"

backend = "cpp"
#bin = @["nue"]

task nue, "Build the NimForUE tool":
    exec "nim cpp --mm:arc --threads --tlsEmulation:off src/nue.nim" # output to the plugin folder instead of Binaries/nim

template callTask(name: untyped) =
    ## Invokes the nimble task with the given name
    exec "nimble " & astToStr(name)

task nimforue, "Builds the main lib. The one that makes sense to hot reload.":
    generateFFIGenFile()
    exec("nim cpp --app:lib --warning:UnusedImport:off --warning:HoleEnumConv:off --warning:Spacing:off --hint:XDeclaredButNotUsed:off --nomain -d:withue -d:genffi --nimcache:.nimcache/nimforue src/nimforue.nim")
    exec("nim c -d:release --warning:UnusedImport:off --run --d:copylib src/buildscripts/copyLib.nim")
    

task watch, "Watchs the main lib and rebuilds it when something changes.":
    when defined macosx:
        exec("""echo nimble nimforue > nueMac.sh""")
    exec("./nue watch") # use nimble to call the watcher. Typically the user will call `nue watch` since nue will be installed in `.nimble/bin`.

task host, "Builds the library that's hooked to unreal":
    if not fileExists(getNimForUEConfig().genFilePath):
        generateFFIGenFile() #makes sure FFI gen file exists (not tracked) so it can be imported from hostnimforue but only if it doesnt exists so it doesnt override its content
    exec("nim cpp --app:lib --nomain --d:host --nimcache:.nimcache/host src/hostnimforue/hostnimforue.nim")
    
    #TODO using a custom cache dir would be better
    copyFileFromNimCachetoLib("NimForUEFFI.h", "./NimHeaders/NimForUEFFI.h", "host") #temp hack to copy the header. 
    copyLibToUE4("hostnimforue")
    when defined macosx:
        #needed for dllimport in ubt mac only
        let src = "./Binaries/nim/libhostnimforue.dylib"
        let dst = "/usr/local/lib/libhostnimforue.dylib"
        cpFile src, dst
        echo "Copied " & src & " to " & dst
    generateUBTScriptFile() #move to generateProject whe it exists
 
task buildlibs, "Builds the sdk and the ffi which generates the headers":
    callTask nimforue
    callTask host


task clean, "deletes all files generated by the project":
    exec("rm -rf ./Binaries/nim/")
    exec("rm /usr/local/lib/libhostnimforue.dylib")
    exec("rm NimForUE.mac.json")

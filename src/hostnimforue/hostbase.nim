import ../buildscripts/nimforueconfig
import std/[dynlib, strutils]
import locks

const pluginDir* {.strdefine.} : string = ""


var libLock* : Lock
initLock(libLock)
var lib* {.guard:libLock.} : LibHandle


type 
    OnReloadSingature* = proc(msg:cstring):void  {. cdecl, gcsafe .}

var onReload : OnReloadSingature; #callback called to notify UE when NimForUE changed

proc notifyOnReloaded*(msg:string) = 
    if not onReload.isnil():
        onReload(msg)

proc subscribeToReload*(inOnReload: OnReloadSingature) : void {.exportc, cdecl, dynlib.}= 
    onReload = inOnReload

proc reloadlib*(path:cstring) : void {.exportc, cdecl, dynlib.} = 
    withLock libLock:
        unloadLib(lib)
        lib = loadLib($path)
        if lib.isNil():
            echo "Failed to load lib: " & $path

proc reloadWithHandle*(path:cstring, lib: var LibHandle) : void =
    withLock libLock:
        unloadLib(lib)
        lib = loadLib($path)
        #Not sure if I have to do this from the main thread
        

        

#UBT Helpers.
#Since UBT doesnt seem to have package support, we expose a few function to interact with it.
proc setNimForUEConfig(pluginDir, engineDir, targetPlatform, targetConfig:cstring) {.exportc, cdecl, dynlib.} = 
    var nueConfig = getNimForUEConfig($pluginDir)
    nueConfig.engineDir = $engineDir
    nueConfig.pluginDir = $pluginDir
    nueConfig.targetPlatform = parseEnum[TargetPlatform]($targetPlatform)
    nueConfig.targetConfiguration = parseEnum[TargetConfiguration]($targetConfig)
    nueConfig.saveConfig($pluginDir)


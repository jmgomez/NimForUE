import ../buildscripts/nimforueconfig
import std/[dynlib, strutils]
import locks

const pluginDir* {.strdefine.} : string = ""


var libLock* : Lock
initLock(libLock)
var lib* {.guard:libLock.} : LibHandle


type 
    OnReloadSingature* = proc(msg:cstring):void  {. cdecl, gcsafe .}
    LoggerSignature* = proc(msg:cstring):void  {. cdecl, gcsafe .}


var onReload : OnReloadSingature; #callback called to notify UE when NimForUE changed
var logger : LoggerSignature

{.pragma: ex, exportc, cdecl, dynlib.}

# call to initialize gc for guest dll, or Nim will crash on memory (re)alloc
# must be called on thread (usually main thread) which is calling guest dll functions
proc initNimForUE*() {.ex.} =
    discard

#    withLock libLock:
#        (cast[proc(){.cdecl.}](lib.symAddr("NimMain")))()

proc notifyOnReloaded*(msg:string) = 
    if not onReload.isnil():
        onReload(msg)

proc subscribeToReload*(inOnReload: OnReloadSingature) : void {.ex.}= 
    onReload = inOnReload

proc registerLogger*(inLogger: LoggerSignature) : void {.ex.}= 
    logger = inLogger

proc reloadlib*(path:cstring) : void {.ex.} = 
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
proc setNimForUEConfig(pluginDir, engineDir, targetPlatform, targetConfig:cstring) {.ex.} = 
    var nueConfig = getNimForUEConfig($pluginDir)
    nueConfig.engineDir = $engineDir
    nueConfig.pluginDir = $pluginDir
    nueConfig.targetPlatform = parseEnum[TargetPlatform]($targetPlatform)
    nueConfig.targetConfiguration = parseEnum[TargetConfiguration]($targetConfig)
    nueConfig.saveConfig($pluginDir)



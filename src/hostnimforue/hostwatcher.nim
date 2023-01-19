import std/[times, os, dynlib, tables, strutils, sequtils, algorithm, locks, sugar, options]
import pure/asyncdispatch
import ../buildscripts/[buildscripts]
import ffigen

import hostbase

type LoggerSignature* = proc(msg:cstring) {.cdecl, gcsafe.}
    



var logger : LoggerSignature

{.pragma: ex, exportc, cdecl, dynlib.}


proc registerLogger*(inLogger: LoggerSignature) {.ex.} =
    logger = inLogger

proc ensureGuestIsCompiled*() : void {.ex.} =
    ensureGuestIsCompiledImpl()

proc setSdkVersion(version:cstring) {.ex.} =
    writeFile(PluginDir/"sdk_version.txt", $version)

proc setUEConfig(engineDir, conf, platform : cstring, withEditor:bool) {.ex.} =
    #TODO add witheditor
    let targetConf = parseEnum[TargetConfiguration]($conf)
    let targetPlatform = parseEnum[TargetPlatform]($platform)
    let (_,gameDir) = tryGetEngineAndGameDir().get()
    let conf = 
        NimForUEConfig(engineDir: $engineDir, gameDir: $gameDir, 
            targetConfiguration: targetConf, targetPlatform: targetPlatform)
    conf.saveConfig()

proc loadNueLib*(libName, nextPath: string) =
  var nueLib = libMap[libName]
  if nueLib.lastLoadedPath != nextPath or not nueLib.isInit:
    nueLib.lib = loadLib(nextPath)
    inc nueLib.timesReloaded
    nueLib.lastLoadedPath = nextPath
    libMap[libName] = nueLib
    onLibLoaded(libName.cstring, nextPath.cstring, (nueLib.timesReloaded - 1).cint)

#This could be done internally by exposing epol
proc checkReload*() {.ex.} = #only for nimforue (plugin)
    let plugin = "nimforue"
    # logger("Checking reload")
    for currentLib in libMap.keys:
        let isPlugin = plugin == currentLib
        let mbNext = getLastLibPath(NimForUELibDir, currentLib)
        if mbNext.isSome():
            let nextLibName = mbNext.get()
            try:
                loadNueLib(currentLib, nextLibName)
            except:
                logger("There was a problem trying to load the library: " & nextLibName)
                logger(getCurrentExceptionMsg())
            
           
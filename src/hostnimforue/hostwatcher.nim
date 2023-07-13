import std/[times, os, dynlib, tables, strutils, sequtils, algorithm, locks, sugar, options, compilesettings]
import pure/asyncdispatch
import ../buildscripts/[buildscripts]
import ffigen

import hostbase

type LoggerSignature* = proc(msg:cstring) {.cdecl, gcsafe.}
    



var logger : LoggerSignature


proc loadNueLib*(libName, nextPath: string, loadedFrom:NueLoadedFrom) =
  var nueLib = libMap[libName]
  if nueLib.lastLoadedPath != nextPath or not nueLib.isInit:
    nueLib.lib = loadLib(nextPath)
    inc nueLib.timesReloaded
    nueLib.lastLoadedPath = nextPath
    libMap[libName] = nueLib
    onLibLoaded(libName.cstring, nextPath.cstring, (nueLib.timesReloaded - 1).cint, loadedFrom)

{.push  exportc, cdecl, dynlib.}

proc registerLogger*(inLogger: LoggerSignature)  =
    logger = inLogger

proc ensureGuestIsCompiled*() : void =
    ensureGuestIsCompiledImpl()

proc setWinCompilerSettings(sdkVersion, compilerVersion, toolchainDir:cstring) =
    #TODO unify it in one file
    writeFile(PluginDir/"sdk_version.txt", $sdkVersion)
    writeFile(PluginDir/"compiler_version.txt", $compilerVersion)
    writeFile(PluginDir/"toolchain_dir.txt", $toolchainDir)

proc getNimBaseHeaderPath(): cstring = querySetting(libPath).cstring

proc setUEConfig(engineDir, conf, platform : cstring, withEditor:bool)=
    #TODO add witheditor
    let targetConf = parseEnum[TargetConfiguration]($conf)
    let targetPlatform = parseEnum[TargetPlatform]($platform)
    let (_,gameDir) = tryGetEngineAndGameDir().get()
    let conf = 
        NimForUEConfig(engineDir: $engineDir, gameDir: $gameDir, 
            targetConfiguration: targetConf, targetPlatform: targetPlatform)
    conf.saveConfig()

var currentLoadPhase = nlfPreEngine #First time check reload is called is preengine
#In the future Consider removing Host and using the plugin directly? 
proc checkReload*(loadedFrom:NueLoadedFrom)  = #only for nimforue (plugin)
    let plugin = "nimforue"
    # logger("Checking reload")
    for currentLib in libMap.keys:
        let mbNext = getLastLibPath(NimForUELibDir, currentLib)
        if mbNext.isSome():
            let nextLibName = mbNext.get()
            try:
                loadNueLib(currentLib, nextLibName, loadedFrom)                 
            except:
                logger("There was a problem trying to load the library: " & nextLibName)
                logger(getCurrentExceptionMsg())
    
    #TEST currentLoadPhase changed AND we are in Plugin so we can trigger the emission
    if currentLoadPhase != loadedFrom:
        if plugin in libMap:
            let pluginLib = libMap[plugin]
            if pluginLib.lib != nil:
                onLoadingPhaseChanged(currentLoadPhase, loadedFrom)
    let pluginLib = libMap[plugin]
    if pluginLib.lib != nil:
      if fileExists(scriptPath) and currentLoadPhase >= NueLoadedFrom.nlfEditor and
        scriptLastModified < getLastModificationTime(scriptPath).toUnix():
        reloadScriptGuest()
        scriptLastModified = getLastModificationTime(scriptPath).toUnix()

    currentLoadPhase = loadedFrom

{.pop.}     
           
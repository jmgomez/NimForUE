import std/[times, os, dynlib, tables, strutils, sequtils, algorithm, locks, sugar, options]
import pure/asyncdispatch
import ../buildscripts/[buildscripts]
import ffigen

import hostbase

type
    WatcherMessage = enum
        Stop
    ReloadCallback* = proc(msg:cstring) {.cdecl, gcsafe.}
    LoggerSignature* = proc(msg:cstring) {.cdecl, gcsafe.}
    

const pluginDir* {.strdefine.} : string = ""




var onPreReload : ReloadCallback; #callback called to notify UE when NimForUE changed
var onPostReload : ReloadCallback; #callback called to notify UE when NimForUE changed

var logger : LoggerSignature

{.pragma: ex, exportc, cdecl, dynlib.}

proc subscribeToReload*(preReloadCb:ReloadCallback, postReloadCb: ReloadCallback) {.ex.} =
    onPreReload = preReloadCb
    onPostReload = postReloadCb

proc registerLogger*(inLogger: LoggerSignature) {.ex.} =
    logger = inLogger


proc NimMain() {.importc.} # needed to initialize the gc

proc initializeHost() {.ex.} =
    once:
        NimMain()



proc loadNueLib*(libName, nextPath: string) =
  var nueLib = libMap[libName]
  if nueLib.lastLoadedPath != nextPath or not nueLib.isInit:
    nueLib.lib = loadLib(nextPath)
    nueLib.isInit = true
    nueLib.lastLoadedPath = nextPath
    libMap[libName] = nueLib
    onLibLoaded(libName.cstring, nextPath.cstring)


proc checkReload*() {.ex.} = #only for nimforue (plugin)
    let plugin = "nimforue"
    for currentLib in libMap.keys:
        let isPlugin = plugin == currentLib
        let mbNext = getLastLibPath(libDir, currentLib)
        if mbNext.isSome():
            let nextLibName = mbNext.get()
            try:
                loadNueLib(currentLib, nextLibName)
                
            except:
                logger("There was a problem trying to load the library: " & nextLibName)
                logger(getCurrentExceptionMsg())
            
           
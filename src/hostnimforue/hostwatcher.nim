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


proc loadNueLib*(libName, nextPath: string) =
  var nueLib = libMap[libName]
  if nueLib.lastLoadedPath != nextPath or not nueLib.isInit:
    nueLib.lib = loadLib(nextPath)
    inc nueLib.timesReloaded
    nueLib.lastLoadedPath = nextPath
    libMap[libName] = nueLib
    onLibLoaded(libName.cstring, nextPath.cstring, (nueLib.timesReloaded - 1).cint)


proc checkReload*() {.ex.} = #only for nimforue (plugin)
    let plugin = "nimforue"
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
            
           
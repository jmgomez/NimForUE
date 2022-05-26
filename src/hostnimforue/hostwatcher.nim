import std/[times, os, dynlib, strutils, sequtils, algorithm, locks, sugar, options]
import system/io
import pure/asyncdispatch
import ../buildscripts/[nimforueconfig, copyLib]

import hostbase
initLock(libLock)

type
    WatcherMessage = enum
        Stop
    ReloadCallback* = proc(msg:cstring) {.cdecl, gcsafe.}
    LoggerSignature* = proc(msg:cstring) {.cdecl, gcsafe.}


const pluginDir* {.strdefine.} : string = ""

var thread : Thread[void]
var chan : Channel[WatcherMessage]
var lastLoaded {.threadvar.} : string

var onReload : ReloadCallback; #callback called to notify UE when NimForUE changed
var logger : LoggerSignature

{.pragma: ex, exportc, cdecl, dynlib.}

proc subscribeToReload*(cb: ReloadCallback) {.ex.} =
    onReload = cb

proc registerLogger*(inLogger: LoggerSignature) {.ex.} =
    logger = inLogger


# call to initialize gc for guest dll, or Nim will crash on memory (re)alloc
# must be called on thread (usually main thread) which is calling guest dll functions
proc initNimForUE*() {.ex.} =
    (cast[proc(){.cdecl.}](lib.symAddr("NimMain")))()

proc checkAndReload*(libPath:string) = 
    let mbNext = getLastLibPath(libPath)
    if mbNext.isSome() and mbNext.get() != lastLoaded:
        let nextLibName = mbNext.get()
        lastLoaded = nextLibName
        withLock libLock:
            unloadLib(lib)
            lib = loadLib(nextLibName)
            doAssert(not lib.isNil())
            if not onReload.isnil():
                onReload(nextLibName)

proc watchChangesInLib*() {.thread.}  =
    let libPath = getNimForUEConfig(pluginDir).nimForUELibPath
    while true:
        checkAndReload(libPath)
        let recv = chan.tryRecv()
        if recv.dataAvailable:
            #since only Stop available 
            return

        sleep(1000)

proc NimMain() {.importc.} # needed to initialize the gc in startWatch

proc startWatch*() {.ex.} = 
    once:
        NimMain()
    chan.open()
    createThread(thread, watchChangesInLib)

proc stopWatch*() {.ex} =
    discard chan.trySend(Stop)

#[
#UBT Helpers.
#Since UBT doesnt seem to have package support, we expose a few function to interact with it.
proc setNimForUEConfig(pluginDir, engineDir, targetPlatform, targetConfig:cstring) {.ex.} = 
    var nueConfig = getNimForUEConfig($pluginDir)
    nueConfig.engineDir = $engineDir
    nueConfig.pluginDir = $pluginDir
    nueConfig.targetPlatform = parseEnum[TargetPlatform]($targetPlatform)
    nueConfig.targetConfiguration = parseEnum[TargetConfiguration]($targetConfig)
    nueConfig.saveConfig($pluginDir)
]#
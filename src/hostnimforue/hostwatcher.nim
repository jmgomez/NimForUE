import std/[times, os, dynlib, strutils, sequtils, algorithm]
import system/io
import hostbase
import pure/asyncdispatch
import locks
import sugar
import options
import ../buildscripts/[nimforueconfig, copyLib]

type WatcherMessage = enum  
    Stop 

var thread : Thread[void]
var chan : Channel[WatcherMessage]
var lastLoaded {.threadvar.} : string

proc checkAndReload*(libPath:string) = 
    let mbNext = getLastLibPath(libPath)
    if mbNext.isSome() and mbNext.get() != lastLoaded:
        let nextLibName = mbNext.get()
        echo "Reloading " & nextLibName
        reloadlib(nextLibName.cstring)
        notifyOnReloaded(nextLibName)
        lastLoaded = nextLibName

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

{.pragma: ex, exportc, cdecl, dynlib.} # defined, so we can use the `once` pragma in startWatch for NimMain

var watchStarted = false # startWatch and stopWatch are called in pairs
proc startWatch*() {.ex.} = 
    once:
        NimMain()
    watchStarted = true
    chan.open()
    withLock libLock:   
        createThread(thread, watchChangesInLib)

proc stopWatch*() {.ex} =
    if watchStarted:
        discard chan.trySend(Stop)
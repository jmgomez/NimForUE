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

proc checkAndReload*(lastLoaded:var string, libPath:string) = 
    let mbNext = getLastLibPath(libPath)
    if mbNext.isSome() and mbNext.get() != lastLoaded:
        let nextLibName = mbNext.get()
        echo "Reloading " & nextLibName
        reloadlib(nextLibName)
        notifyOnReloaded(nextLibName)
        lastLoaded = nextLibName
    
    
proc watchChangesInLib*() {.thread.}  =
    let libPath = getNimForUEConfig(pluginDir).nimForUELibPath
    var nextLibName = libPath
    while true:
        checkAndReload(nextLibName, libPath)
        let recv = chan.tryRecv()
        if recv.dataAvailable:
            #since only Stop available 
            return

        sleep(1000)

{.push exportc, cdecl, dynlib.}


proc startWatch*() = 
    chan.open()
    withLock libLock:   
        createThread(thread, watchChangesInLib)

proc stopWatch*() = 
    discard chan.trySend(Stop)
    
{.pop.}


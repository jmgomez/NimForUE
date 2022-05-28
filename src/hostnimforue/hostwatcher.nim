import std/[times, os, dynlib, strutils, sequtils, algorithm, locks, sugar, options]
import system/io
import pure/asyncdispatch
import ../buildscripts/[nimforueconfig, copyLib]

import hostbase

type
    WatcherMessage = enum
        Stop
    ReloadCallback* = proc(msg:cstring) {.cdecl, gcsafe.}
    LoggerSignature* = proc(msg:cstring) {.cdecl, gcsafe.}


const pluginDir* {.strdefine.} : string = ""

var libPath:string
var lastLoaded : string

var onReload : ReloadCallback; #callback called to notify UE when NimForUE changed
var logger : LoggerSignature

{.pragma: ex, exportc, cdecl, dynlib.}

proc subscribeToReload*(cb: ReloadCallback) {.ex.} =
    onReload = cb

proc registerLogger*(inLogger: LoggerSignature) {.ex.} =
    logger = inLogger


proc NimMain() {.importc.} # needed to initialize the gc

proc initializeHost() {.ex.} =
    once:
        NimMain()
        libPath = getNimForUEConfig(pluginDir).nimForUELibPath

proc checkReload*() {.ex.} =
    let mbNext = getLastLibPath(libPath)
    if mbNext.isSome() and mbNext.get() != lastLoaded:
        let nextLibName = mbNext.get()
        lastLoaded = nextLibName
        if lib != nil:
            unloadLib(lib)
        lib = loadLib(nextLibName)
        doAssert(not lib.isNil())
        # call to initialize gc for guest dll, or Nim will crash on memory (re)alloc
        # must be called on the game thread which is calling guest dll functions
        (cast[proc(){.cdecl.}](lib.symAddr("NimMain")))()
        if not onReload.isnil():
            onReload(nextLibName)
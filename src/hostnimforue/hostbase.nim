import std/[locks, dynlib, options, tables]
import ../buildscripts/[buildscripts]

var libLock* : Lock
initLock(libLock)



type 
  NueLib* = object
    lastLoadedPath* : string
    lib* : LibHandle
    timesReloaded* : int

func isInit*(lib : NueLib) : bool = lib.lib != nil

var libMap* : Table[string, NueLib] = {
  "nimforue" : NueLib(lastLoadedPath: getLastLibPath(NimForUELibDir, "nimforue").get())
}.toTable()

#Game must be compiled at least once. 
let gameLibPath = getLastLibPath(NimForUELibDir, "game")
if gameLibPath.isSome():
  libMap["game"] = NueLib(lastLoadedPath: gameLibPath.get())



proc lib*() : LibHandle = libMap["nimforue"].lib
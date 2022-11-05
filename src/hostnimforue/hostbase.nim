import std/[locks, dynlib, options, tables]
import ../buildscripts/[buildscripts]

var libLock* : Lock
initLock(libLock)

const pluginDir* {.strdefine.} : string = ""

let libDir* = getNimForUEConfig(pluginDir).nimForUELibDir


type 
  NueLib* = object
    lastLoadedPath* : string
    lib* : LibHandle
    isInit* : bool



var libMap* : Table[string, NueLib] = {
  "nimforue" : NueLib(lastLoadedPath: getLastLibPath(libDir, "nimforue").get()),
  "game" : NueLib(lastLoadedPath: getLastLibPath(libDir, "game").get()),
}.toTable()





proc lib*() : LibHandle = libMap["nimforue"].lib
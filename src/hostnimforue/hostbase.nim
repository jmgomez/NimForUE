import std/[locks, dynlib, options, tables, strformat, os, osproc]
import ../buildscripts/[buildscripts]

var libLock* : Lock
initLock(libLock)

type LoggerSignature* = proc(msg:cstring) {.cdecl, gcsafe.}
var logger* : LoggerSignature

proc log(str:string) = 
  if logger != nil:
    logger(str.cstring)
  else:
    echo str

type 
  NueLib* = object
    lastLoadedPath* : string
    lib* : LibHandle
    timesReloaded* : int

func isInit*(lib : NueLib) : bool = lib.lib != nil
var libMap* : Table[string, NueLib]
var scriptPath*: string
var scriptLastModified*: int

proc start() = 
  libMap = {
    "nimforue" : NueLib(lastLoadedPath: getLastLibPath(NimForUELibDir, "nimforue").get())
  }.toTable()
  scriptPath = NimGameDir() / "vm" / "script.nim"

  #Adds all game libs including game 
  let allGameLibs = getAllGameLibs()
  for libName in allGameLibs:
    let libPath = getLastLibPath(NimForUELibDir, libName)
    if libPath.isSome():
      libMap[libName] = NueLib(lastLoadedPath: libPath.get())

proc ensureGuestIsCompiledImpl*()  = 
  let guestLibPath = getLastLibPath(NimForUELibDir, "nimforue")
  if guestLibPath.isNone():
    log "NimForUE lib not found. Will compile it now..."
    let output = compileGuestSyncFromPlugin()
    log output
  start()




proc lib*() : LibHandle = libMap["nimforue"].lib
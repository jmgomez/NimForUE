

include unreal/prelude
import macros/[ffi]
import std/[options, strformat, dynlib]
import ../buildscripts/[nimforueconfig, buildscripts]

const genFilePath* {.strdefine.} : string = ""




proc getEmitterFromGame(libPath:string) : UEEmitterPtr = 
  type 
    GetUEEmitterFn = proc (): UEEmitterPtr {.gcsafe, stdcall.}

  let lib = loadLib(libPath)
  let getEmitter = cast[GetUEEmitterFn](lib.symAddr("getUEEmitter"))
  UE_Log "The emitter is " & $getEmitter()
  getEmitter()



#entry point for the game. but it will also be for other libs in the future
#even the next guest/nimforue?
proc onLibLoaded(libName:cstring, libPath:cstring) : void {.ffi:genFilePath} = 
    case $libName:
    of "nimforue": 
        emitNueTypes(getGlobalEmitter()[], "Nim")
    of "game":
        emitNueTypes(getEmitterFromGame($libPath)[], "GameNim")
    
    UE_Log &"lib loaded: {libName}"


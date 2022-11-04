include ../unreal/prelude
import ../../buildscripts/[buildscripts, nimforueconfig]

import std/[os, dynlib, strformat, options]

type 
  GameExposedFn = proc (): cint {.gcsafe, stdcall.}
  GetUEEmitterFn = proc (): UEEmitterPtr {.gcsafe, stdcall.}

let config = getNimForUEConfig()
let dllDir = config.pluginDir / "Binaries" / "nim" / "ue"

#Need to add the dir to the library


proc emitTypesInGame(emitter: UEEmitterPtr) =
  
  let gameNimHotReload = emitUStructsForPackage(emitter[], "GameNim")
  UE_Log &"GameNim HotReload {gameNimHotReload}" #Notice hot reload wont work because the types doenst exists.

proc getEmitterFromGame() : UEEmitterPtr = 
  let gameDllPath = getLastLibPath(dllDir, "game").get()
  let lib = loadLib(gameDllPath)
  let getEmitter = cast[GetUEEmitterFn](lib.symAddr("getUEEmitter"))
  UE_Log "The emitter is " & $getEmitter()
  getEmitter()


uClass AGameDllTest of AActor:
  (BlueprintType)
  ufuncs(CallInEditor):
    proc loadGameDll() = 
      try:
        let emitter = getEmitterFromGame()
        emitTypesInGame(emitter)
      except:
        UE_Error getCurrentExceptionMsg()
    proc justAnotherTest2() = 
      UE_Log "Just another test"
        
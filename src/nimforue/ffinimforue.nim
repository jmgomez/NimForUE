

include unreal/prelude
import unreal/editor/editor
import macros/[ffi]
import std/[options, strformat, dynlib]
import ../buildscripts/[nimforueconfig, buildscripts]
import ../codegen/genreflectiondata
import typegen/emitter

const genFilePath* {.strdefine.} : string = ""




proc getEmitterFromGame(libPath:string) : UEEmitterPtr = 
  type 
    GetUEEmitterFn = proc (): UEEmitterPtr {.gcsafe, stdcall.}

  let lib = loadLib(libPath)
  let getEmitter = cast[GetUEEmitterFn](lib.symAddr("getUEEmitter"))
  
  assert not getEmitter.isNil()

  let emitterPtr = getEmitter()
  assert not emitterPtr.isNil()
  emitterPtr



proc onPIEStart(isSimulating:bool) {.cdecl.} = 
  UE_Warn "Heyyyy! PIE STARTED"

proc onPIEEnd(isSimulating:bool) {.cdecl.} = 
  UE_Warn "Goodbye! PIE End!"



#entry point for the game. but it will also be for other libs in the future
#even the next guest/nimforue?
proc onLibLoaded(libName:cstring, libPath:cstring, timesReloaded:cint) : void {.ffi:genFilePath} = 
  try:
    case $libName:
    of "nimforue": 
        onBeginPIEEvent.addLambda(onPIEStart)
        onEndPIEEvent.addLambda(onPIEEnd)
        
        # let v = onBeginPIEEvent()
        emitNueTypes(getGlobalEmitter()[], "Nim")
        if timesReloaded == 0: #Generate bindings. The collected part is single threaded ATM, that's one we only do it once. It takes around 2-3 seconds.
          execBindingsGenerationInAnotherThread()
    of "game":
        emitNueTypes(getEmitterFromGame($libPath)[], "GameNim")
    
    UE_Log &"lib loaded: {libName}"
  except:
    UE_Error &"Error in onLibLoaded: {getCurrentExceptionMsg()}"


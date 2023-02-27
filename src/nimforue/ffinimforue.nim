

include unreal/prelude
import unreal/editor/editor
import unreal/core/containers/containers
import ../nimforue/codegen/[ffi,emitter, genreflectiondatav2, models, uemeta, ueemit]
import std/[options, strformat, dynlib, os, osproc]
import ../buildscripts/[nimforueconfig, buildscripts]

const genFilePath* {.strdefine.} : string = ""

var prevGameLib : Option[string]

#Useful to free del handles in the game/lib
proc unloadPrevLib(nextLib:string) = 
  type OnNewLibLoadedFn = proc(): void {.gcsafe, stdcall.} 
  if prevGameLib.isSome():
    let lib = loadLib(prevGameLib.get())
    let onLibUnloaded = cast[OnNewLibLoadedFn](lib.symAddr("onUnloadLib"))
    onLibUnloaded()
  
  prevGameLib = some nextLib

proc getEmitterFromGame(libPath:string) : UEEmitterPtr = 
  type 
    GetUEEmitterFn = proc (): UEEmitterPtr {.gcsafe, stdcall.}

  let lib = loadLib(libPath)
  let getEmitter = cast[GetUEEmitterFn](lib.symAddr("getUEEmitter"))
  
  assert getEmitter.isNotNil()

  let emitterPtr = getEmitter()
  assert not emitterPtr.isNil()

  unloadPrevLib(libPath) 

  emitterPtr

proc startNue(libPath:string)  = 
  type 
    StartNueFN = proc ():void {.gcsafe, stdcall.}

  let lib = loadLib(libPath)
  let startNueFn = cast[StartNueFN](lib.symAddr("startNue"))
  
  assert startNueFn.isNotNil()

  startNueFn()

#Will be called from the commandlet that generates the bindigns
proc genBindingsEntryPoint() : void {.ffi:genFilePath} = 
  UE_LOG "Running genBindingsEntryPoint"
  # execBindingGeneration(true)  
  try:
    generateProject()       
  except:
    UE_Error &"Error in genBindingsEntryPoint: {getCurrentExceptionMsg()}"
    sleep(3000)
     


proc emitNueTypes*(emitter: UEEmitterRaw, packageName:string) = 
    try:
        let nimHotReload = emitUStructsForPackage(emitter, packageName)
        
        #For now we assume is fine to EmitUStructs even in PIE. IF this is not the case, we need to extract the logic from the FnNativePtrs and constructor so we can update them anyways
        if GEditor.isNotNil() and not GEditor.isInPIE():#Not sure if we should do it only for non guest targets
          reinstanceNueTypes(packageName, nimHotReload, "")
          return;
       
        proc onPIEEndCallback(isSimulating:bool, packageName:string, hotReload:FNimHotReloadPtr, handle:FDelegateHandlePtr) {.cdecl.} = 
          reinstanceNueTypes(packageName, hotReload, "")
          onEndPIEEvent.remove(handle[])
          deleteCpp(handle)
          UE_LOG(&"NimUE: PIE ended, reinstanciated nue types {packageName}")
          
        let onPIEEndHandle = newCpp[FDelegateHandle]()
        (onPIEEndHandle[]) = onEndPIEEvent.addStatic(onPIEEndCallback, packageName, nimHotReload, onPIEEndHandle)
        UE_Log "Deffered reinstance of NueTypes for package: " & packageName & " after PIE ended"

       
    except Exception as e:
        #TODO here we could send a message to the user
        UE_Error "Nim CRASHED "
        UE_Error e.msg
        UE_Error e.getStackTrace()




#entry point for the game. but it will also be for other libs in the future
#even the next guest/nimforue?
proc onLibLoaded(libName:cstring, libPath:cstring, timesReloaded:cint) : void {.ffi:genFilePath} = 
  UE_Log &"lib loaded: {libName}"

  try:
    case $libName:
    of "nimforue": 
        emitNueTypes(getGlobalEmitter()[], "Nim")
        # if isRunningCommandlet(): return
        # # if timesReloaded == 0: #Generate bindings. The collected part is single threaded ATM, that's one we only do it once. It takes around 2-3 seconds.
        #   #Base the condition on if Game needs to be compiled or not.
        # let doesTheGameExists = fileExists(GameLibPath)    
        # UE_Log &"Game lib exists: {doesTheGameExists}"   
        # execBindingGeneration(shouldRunSync=not doesTheGameExists)                
        # if not doesTheGameExists:
        #   UE_Log "Game lib doesnt exists, compiling it now:"
        #   let output = compileGameSyncFromPlugin()
        #   UE_Log output
        if not isRunningCommandlet() and timesReloaded == 0: 
          genBindingsCMD()

    of "game":      
        emitNueTypes(getEmitterFromGame($libPath)[], "GameNim")
    
  except:
    UE_Error &"Error in onLibLoaded: {getCurrentExceptionMsg()}"




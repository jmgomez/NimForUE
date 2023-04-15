

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
    if isRunningCommandlet(): #TODO test not cooking
      generateProject()       
  except:
    UE_Error &"Error in genBindingsEntryPoint: {getCurrentExceptionMsg()}"
    sleep(3000)
     


proc emitNueTypes*(emitter: UEEmitterRaw, packageName:string, emitEarlyLoadTypesOnly, reuseHotReload:bool) = 
    try:
        let nimHotReload = emitUStructsForPackage(emitter, packageName, emitEarlyLoadTypesOnly)
        
        #For now we assume is fine to EmitUStructs even in PIE. IF this is not the case, we need to extract the logic from the FnNativePtrs and constructor so we can update them anyways
        if GEditor.isNotNil() and not GEditor.isInPIE():#Not sure if we should do it only for non guest targets
          reinstanceNueTypes(packageName, nimHotReload, "", reuseHotReload)
          return;
       
        proc onPIEEndCallback(isSimulating:bool, packageName:string, hotReload:FNimHotReloadPtr, handle:FDelegateHandlePtr) {.cdecl.} = 
          reinstanceNueTypes(packageName, hotReload, "", false)
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





proc emitTypeFor(libName, libPath:string, timesReloaded:int, loadedFrom : NueLoadedFrom) = 
  try:
    case libName:
    of "nimforue": 
        emitNueTypes(getGlobalEmitter()[], "Nim", loadedFrom == nlfPreEngine, false)
        if not isRunningCommandlet() and timesReloaded == 0: 
          # genBindingsCMD()
          discard
    else:
        emitNueTypes(getEmitterFromGame(libPath)[], "GameNim",  loadedFrom == nlfPreEngine, false)
  except CatchableError as e:
    UE_Error &"Error in onLibLoaded: {e.msg} {e.getStackTrace}"


#only GameNim types
proc emitTypesExternal(emitter : UEEmitterPtr, loadedFrom:NueLoadedFrom, reuseHotReload: bool) {.cdecl, exportc, dynlib.} = 
  UE_Log "Emitting types from external lib"
  emitNueTypes(emitter[], "GameNim",  loadedFrom == nlfPreEngine, reuseHotReload)




#entry point for the game. but it will also be for other libs in the future
#even the next guest/nimforue?
var libsToEmmit : seq[(string, string, int)] 
proc onLibLoaded(libName:cstring, libPath:cstring, timesReloaded:cint, loadedFrom:NueLoadedFrom) : void {.ffi:genFilePath} = 
  UE_Log &"lib loaded: {libName} loaded from {loadedFrom}" 
  case loadedFrom
  of nlfPreEngine:
    UE_Log "Too early"
    libsToEmmit.add ($libName, $libPath, int timesReloaded)
    emitTypeFor($libName, $libPath, timesReloaded, loadedFrom)

  else: #Safe to emit types here
    emitTypeFor($libName, $libPath, timesReloaded, loadedFrom)
    # if $libName == "nimforue" and not isRunningCommandlet():
    #   registerVmTests() 





#TODO should something like this be handled by the game too? 
  #1. Works as it worked before
  #2. Make it fail by initializing everything in start
  #3. Only emmit types when no in preInit 
proc onLoadingPhaseChanged(prev : NueLoadedFrom, next:NueLoadedFrom) : void {.ffi:genFilePath} = 
  UE_Log &"Loading phase changed: {prev} -> {next}"
  if prev == nlfPreEngine and next == nlfPostDefault:
    for (libName, libPath, timesReloaded) in libsToEmmit:
      UE_Log &"Emitting types for {libName}"
      emitTypeFor(libName, libPath, timesReloaded, next)
  
 


include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter]
import ../codegen/[gencppclass]


import engine/common
import engine/gameframework
import engine/engine
import enhancedinput
import std/[typetraits, options, asyncdispatch, strformat]

proc getSubsystem*[T : UEngineSubsystem]() : Option[ptr T] = 
    tryUECast[T](getEngineSubsystem(makeTSubclassOf[UEngineSubsystem](staticClass[T]())))

proc  getSubsystem*[T : USubsystem](objContext : UObjectPtr) : Option[ptr T] =
    let cls = staticClass[T]()
    if cls.isChildOf(staticClass[UGameInstanceSubsystem]()):
      tryUECast[T](getGameInstanceSubsystem(objContext, makeTSubclassOf[UGameInstanceSubsystem](cls)))
    elif cls.isChildOf(staticClass[ULocalPlayerSubsystem]()):
      tryUECast[T](getLocalPlayerSubsystem(objContext, makeTSubclassOf[ULocalPlayerSubsystem](cls)))
    elif cls.isChildOf(staticClass[UWorldSubsystem]()):
      tryUECast[T](getWorldSubsystem(objContext, makeTSubclassOf[UWorldSubsystem](cls)))
    else:
      none[ptr T]()



type 
  onGameUnloadedCallback* = proc()


proc tickPoll(deltaTime:float32) : bool {.cdecl.} =
  try:
    let p = getGlobalDispatcher()
    poll(0)
  except: 
    discard
  true


proc subscribeToTick() : FTickerDelegateHandle = 
  UE_Log "Subscribed to tick"
  let tickerDel : FTickerDelegate = createStatic[bool, float32](tickPoll)
  let handle = (getCoreTicker()[]).addTicker(tickerDel, 0)
  handle

let tickHandle = subscribeToTick()

var onGameUnloaded* : onGameUnloadedCallback

when WithEditor:
  proc onUnloadLib() {.exportc, dynlib, cdecl.} =
    if onGameUnloaded.isNotNil():
      onGameUnloaded()
    removeTicker(tickHandle)
  #This function is requested by the plugin when it load this dll
  #The UEEmitter should also have the package name where it supposed to push
  proc getUEEmitter() : UEEmitter {.cdecl, dynlib, exportc.} =   cast[UEEmitter](addr ueEmitter)


# import unreal/editor/editor

# proc emitNueTypes*(emitter: UEEmitterRaw, packageName:string, emitEarlyLoadTypesOnly, reuseHotReload:bool) = 
#     try:
#         let nimHotReload = emitUStructsForPackage(emitter, packageName, emitEarlyLoadTypesOnly)

#         #For now we assume is fine to EmitUStructs even in PIE. IF this is not the case, we need to extract the logic from the FnNativePtrs and constructor so we can update them anyways
#         if GEditor.isNotNil() and not GEditor.isInPIE():#Not sure if we should do it only for non guest targets
#           UE_Warn "Reinstanciating NueTypes "
#           reinstanceNueTypes(packageName, nimHotReload, "", reuseHotReload)
#           return;
       
#         proc onPIEEndCallback(isSimulating:bool, packageName:string, hotReload:FNimHotReloadPtr, handle:FDelegateHandlePtr) {.cdecl.} = 
#           reinstanceNueTypes(packageName, hotReload, "", false)#TODO change this
#           onEndPIEEvent.remove(handle[])
#           deleteCpp(handle)
#           UE_LOG(&"NimUE: PIE ended, reinstanciated nue types {packageName}")
          
#         let onPIEEndHandle = newCpp[FDelegateHandle]()
#         (onPIEEndHandle[]) = onEndPIEEvent.addStatic(onPIEEndCallback, packageName, nimHotReload, onPIEEndHandle)
#         UE_Log "Deffered reinstance of NueTypes for package: " & packageName & " after PIE ended"

       
#     except Exception as e:
#         #TODO here we could send a message to the user
#         UE_Error "Nim CRASHED "
#         UE_Error e.msg
#         UE_Error e.getStackTrace()

import ../buildscripts/buildscripts
import std/[dynlib, os]
proc emitTypesInGuest(calledFrom:NueLoadedFrom) = 
  type 
    EmitTypesExternal = proc (emitter : UEEmitterPtr, loadedFrom:NueLoadedFrom, reuseHotReload: bool) {.gcsafe, cdecl.}
  let libDir = PluginDir / "Binaries"/"nim"/"ue"
  let guestPath = getLastLibPath(libDir, "nimforue")
  if guestPath.isNone():
    UE_Error "Could not find guest lib"
    UE_Warn "Looked at: ???" & PluginDir
    return
  let lib = loadLib(guestPath.get())
  let emitTypesExternal = cast[EmitTypesExternal](lib.symAddr("emitTypesExternal"))
  if emitTypesExternal.isNotNil():
    emitTypesExternal(cast[UEEmitterPtr](getGlobalEmitter()), calledFrom, reuseHotReload=true)
  
#Called from NimForUE module as entry point when we are in a non editor build
proc startNue*(calledFrom:NueLoadedFrom) {.cdecl, exportc.} =
  UE_Log "Reinstanciating NueTypes startNue! aqui"
  case calledFrom:
  of nlfPostDefault:  
    discard emitUStructsForPackage(getGlobalEmitter()[], "GameNim", emitEarlyLoadTypesOnly = false)
  of nlfEditor:
    
    #so here it should somehow notify guest to do the reinstance
    # emitNueTypes(getGlobalEmitter()[], "GameNim", emitEarlyLoadTypesOnly =false, reuseHotReload = false)
    emitTypesInGuest(calledFrom)
  else:
    #TODO hook early load
    discard
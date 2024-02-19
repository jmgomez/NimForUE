include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter, nuemacrocache]
import unreal/nimforue/nimforuebindings

import engine/common
import engine/gameframework
import engine/engine
import enhancedinput/enhancedinput
import std/[typetraits, options, asyncdispatch, strformat, tables]

proc tryGetSubsystem*[T : UEngineSubsystem]() : Option[ptr T] = 
    tryUECast[T](getEngineSubsystem(makeTSubclassOf[UEngineSubsystem](staticClass[T]())))

proc tryGetSubsystem*[T : USubsystem](objContext: UObjectPtr) : Option[ptr T] =
  let cls = staticClass[T]()
  if cls.isChildOf(staticClass[UGameInstanceSubsystem]()):
    tryUECast[T](getGameInstanceSubsystem(objContext, makeTSubclassOf[UGameInstanceSubsystem](cls)))
  elif cls.isChildOf(staticClass[ULocalPlayerSubsystem]()):
    tryUECast[T](getLocalPlayerSubsystem(objContext, makeTSubclassOf[ULocalPlayerSubsystem](cls)))
  elif cls.isChildOf(staticClass[UWorldSubsystem]()):
    tryUECast[T](getWorldSubsystem(objContext, makeTSubclassOf[UWorldSubsystem](cls)))
  else:
    none[ptr T]()

proc getSubsystem*[T: UEngineSubsystem](): ptr T = tryGetSubsystem[T]().get(nil)
proc getSubsystem*[T: UEngineSubsystem](objContext: UObjectPtr): ptr T = tryGetSubsystem[T](objContext).get(nil)

type 
  onGameUnloadedCallback* = proc()


proc tickPoll(deltaTime:float32) : bool {.cdecl.} =
  try:      
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
    removeTicker(tickHandle)
    if onGameUnloaded.isNotNil():
      onGameUnloaded()


# import unreal/editor/editor


when WithEditor:
  import ../../buildscripts/buildscripts
  import std/[os, sequtils, sugar, dynlib]
  # import unreal/editor/editor

  # proc GameNimMain() {.importcpp.}
proc reinstanceFromGloabalEmitter*(globalEmitter:UEEmitterPtr) {.cdecl, exportc.} = 
  when WithEditor:
    proc emitTypesInGuest(calledFrom:NueLoadedFrom, globalEmitter:UEEmitterPtr) = 
          type 
            EmitTypesExternal = proc (emitter : UEEmitterPtr, loadedFrom:NueLoadedFrom, reuseHotReload: bool) {.gcsafe, cdecl.}
          let libDir = PluginDir / "Binaries"/"nim"/"ue"
          let guestPath = getLastLibPath(libDir, "nimforue")
          if guestPath.isNone():
            UE_Error "Could not find guest lib"
            return
          UE_Log "emit types in guest"
          let lib = loadLib(guestPath.get())
          let emitTypesExternal = cast[EmitTypesExternal](lib.symAddr("emitTypesExternal"))
          if emitTypesExternal.isNotNil():
            emitTypesExternal(globalEmitter, calledFrom, reuseHotReload=true)
    emitTypesInGuest(nlfEditor, globalEmitter)

proc emitTypes() {.cdecl, exportc, dynlib.} =  
  discard  emitUStructsForPackage(getGlobalEmitter(), "GameNim", emitEarlyLoadTypesOnly = false)     

proc isThereAnyNimClass(): bool = 
  var objIter = makeFRawObjectIterator()
  for objIter in objIter:
    if objIter.isValid:
      let cls = objIter.get.ueCast(UClass)      
      if cls.isNotNil and cls.isNimClass():
        return true
  return false

proc emitInNextFrame(): Future[void] {.async.} = 
    log "NimForUE will emit in next frame."
    await sleepAsync(0)
    emitTypes()
    
proc reinstanceNextFrame() {.cdecl, exportc.} = 
  when WithEditor:
    sleepAsync(100).callback= () => reinstanceFromGloabalEmitter(getGlobalEmitter())
  


#Called from NimForUE module as entry point when we are in a non editor build
proc startNue*() {.cdecl, exportc.} =
    log "NimForUE entra en Extras."
    #Notice this could also be a HotReload, in that case we should emit the types again but handle it later. 
    #TODO Hook the Early Types here. 

    #Test if there is any NimClass emitted and it doesnt have the meta EarlyLoadMetadataKey. If so, we are in PostDefault.
    #NEED to find a way to know when it ends
    if isThereAnyNimClass():      
      asyncCheck emitInNextFrame()
    else:
      #TODO Hook the Early Types here. 
      let handle = onAllModuleLoadingPhasesComplete.addStatic(emitTypes)      

once:
  startNue() 

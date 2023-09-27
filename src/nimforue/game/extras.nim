include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter]
import ../codegen/[gencppclass]


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
  import std/[dynlib, os, sequtils, sugar]
  # import unreal/editor/editor

  # proc GameNimMain() {.importcpp.}

proc reinstanceFromGloabalEmitter*(globalEmitter:UEEmitterPtr) {.cdecl, exportc.} = 
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
  
#Called from NimForUE module as entry point when we are in a non editor build
proc startNue*(calledFrom:NueLoadedFrom) {.cdecl, exportc.} =
  UE_Log "Reinstanciating NueTypes startNue! aqui"
  case calledFrom:
  of nlfPostDefault:  #TODO do hook early on the module's constructor.
    discard emitUStructsForPackage(getGlobalEmitter(), "GameNim", emitEarlyLoadTypesOnly = false)     
  else:    
    #TODO hook early load
    discard


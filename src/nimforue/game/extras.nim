include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter]
# import ../codegen/[gencppclass]

import engine/common
import engine/gameframework
import engine/engine
import enhancedinput
import std/[typetraits, options, asyncdispatch]

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


#This function is requested by the plugin when it load this dll
#The UEEmitter should also have the package name where it supposed to push
proc getUEEmitter() : UEEmitter {.cdecl, dynlib, exportc.} =   cast[UEEmitter](addr ueEmitter)

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

proc onUnloadLib() {.exportc, dynlib, cdecl.} =
  if onGameUnloaded.isNotNil():
    removeTicker(tickHandle)
    onGameUnloaded()




#Called from NimForUE module as entry point when we are in a non editor build
proc startNue*() {.cdecl, exportc, dynlib.} =
  UE_Log "Start Nue CALLED"
  let nimHotReload = emitUStructsForPackage(getGlobalEmitter()[], "GameNim")
  
 

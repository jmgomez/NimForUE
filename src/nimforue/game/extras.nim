include ../unreal/prelude
import ../codegen/[ueemit, emitter]
# import ../codegen/[gencppclass]

import ../bindings/[engine, enhancedinput]
import std/[typetraits, options]

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
proc getUEEmitter() : UEEmitter {.cdecl, dynlib, exportc.} =   ueEmitter

type 
  onGameUnloadedCallback* = proc()

var onGameUnloaded* : onGameUnloadedCallback

proc onUnloadLib() {.exportc, dynlib, cdecl.} =
  if onGameUnloaded.isNotNil():
    onGameUnloaded()




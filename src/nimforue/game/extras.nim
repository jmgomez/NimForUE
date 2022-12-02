include ../unreal/prelude

import ../bindings/[engine, enhancedinput]
import std/[typetraits, options]

proc getSubsystem*[T : UDynamicSubsystem]() : Option[ptr T] = 
    tryUECast[T](getEngineSubsystem(makeTSubclassOf[UEngineSubsystem](staticClass[T]())))

proc getSubsystem*[T : USubsystem](objContext : UObjectPtr) : Option[ptr T] =
    let cls = staticClass[T]()
    if cls.isChildOf(staticClass[UGameInstanceSubsystem]()):
      tryUECast[T](getGameInstanceSubsystem(objContext, makeTSubclassOf[UGameInstanceSubsystem](cls)))
    elif cls.isChildOf(staticClass[ULocalPlayerSubsystem]()):
      tryUECast[T](getLocalPlayerSubsystem(objContext, makeTSubclassOf[ULocalPlayerSubsystem](cls)))
    elif cls.isChildOf(staticClass[UWorldSubsystem]()):
      tryUECast[T](getWorldSubsystem(objContext, makeTSubclassOf[UWorldSubsystem](cls)))
    else:
      none[ptr T]()


# #enhanced input
# proc bindAction*(self: UEnhancedInputComponentPtr, action: UInputActionPtr, triggerEvent: ETriggerEvent, obj: UObjectPtr, functionName: FName) : var FEnhancedInputActionEventBinding

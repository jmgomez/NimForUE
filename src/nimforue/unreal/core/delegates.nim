#This file will contain everything related with delegates.

import ../coreuobject/uobject


# type FWeakObjectPtr* {.importcpp.} = object


# proc makeWeakObjectPtr*[T : UObjectPtr] (obj : T) : FWeakObjectPtr {.importcpp: "FWeakObjectPtr(#)", constructor.} 


# type TBaseDynamicMulticastDelegate* {.importcpp, inheritable, pure.} = object

# type TDynamicMulticastDelegateOneParam*[T] = object of TBaseDynamicMulticastDelegate


# proc broadcast*[T](del: TDynamicMulticastDelegateOneParam[T], val : T) {.importcpp: "#.Broadcast(@)"}

#This file will contain everything related with delegates.

import ../coreuobject/uobject


type FWeakObjectPtr* {.importcpp.} = object


# proc makeWeakObjectPtr*[T : UObjectPtr] (obj : T) : FWeakObjectPtr {.importcpp: "FWeakObjectPtr(#)", constructor.} 


# type TBaseDynamicMulticastDelegate* {.importcpp, inheritable, pure.} = object

# type TDynamicMulticastDelegateOneParam*[T] = object of TBaseDynamicMulticastDelegate


# proc broadcast*[T](del: TDynamicMulticastDelegateOneParam[T], val : T) {.importcpp: "#.Broadcast(@)"}


type FDelegateHandle* {.importcpp, pure, byref.} = object
proc isValid*(del : FDelegateHandle) : bool {.importcpp: "#.IsValid()", discardable.}
proc reset*(del : var FDelegateHandle) {.importcpp: "#.Reset()"}

#Delegates a variadic, for now we can just return the type adhoc
type TMulticastDelegateOneParam*[T] {.importc:"TMulticastDelegate<void('0)>", nodecl.} = object
proc addStatic*[T](del: TMulticastDelegateOneParam[T], fn : proc(v:T) {.cdecl.}) : FDelegateHandle {.importcpp:"#.AddStatic(#)".}
proc remove*[T](del: TMulticastDelegateOneParam[T], handle : FDelegateHandle) {.importcpp:"#.Remove(#)"}
#This file will contain everything related with delegates.

import ../coreuobject/uobject


type FWeakObjectPtr* {.importcpp.} = object


# proc makeWeakObjectPtr*[T : UObjectPtr] (obj : T) : FWeakObjectPtr {.importcpp: "FWeakObjectPtr(#)", constructor.} 


# type TBaseDynamicMulticastDelegate* {.importcpp, inheritable, pure.} = object

# type TDynamicMulticastDelegateOneParam*[T] = object of TBaseDynamicMulticastDelegate


# proc broadcast*[T](del: TDynamicMulticastDelegateOneParam[T], val : T) {.importcpp: "#.Broadcast(@)"}


type 
  FDelegateHandle* {.importcpp, pure.} = object
  FDelegateHandlePtr* = ptr FDelegateHandle
proc isValid*(del : FDelegateHandle) : bool {.importcpp: "#.IsValid()", discardable.}
proc reset*(del : var FDelegateHandle) {.importcpp: "#.Reset()"}

#Delegates a variadic, for now we can just return the type adhoc
type TMulticastDelegateOneParam*[T] {.importc:"TMulticastDelegate<void('0)>", nodecl.} = object
#TODO add macro that binds all delegates with all params
proc addStatic*[T](del: TMulticastDelegateOneParam[T], fn : proc(v:T) {.cdecl.}) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P) {.cdecl.}, v2:P) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P, P2](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P, v3:P2) {.cdecl.}, v2:P, v3:P2) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P, P2, P4](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P, v3:P2, v4:P4) {.cdecl.}, v2:P, v3:P2, v:P4) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}

proc remove*[T](del: TMulticastDelegateOneParam[T], handle : FDelegateHandle) {.importcpp:"#.Remove(#)"}
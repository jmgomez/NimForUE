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
type 
  TMulticastDelegateOneParam*[T] {.importc:"TMulticastDelegate<void('0)>", nodecl.} = object
  TDelegateRetOneParam*[R, T] {.importcpp:"TDelegate<'0('1)>", nodecl.} = object

#TODO add macro that binds all delegates with all params
proc addStatic*[T](del: TMulticastDelegateOneParam[T], fn : proc(v:T) {.cdecl.}) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P) {.cdecl.}, v2:P) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P, P2](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P, v3:P2) {.cdecl.}, v2:P, v3:P2) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P, P2, P4](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P, v3:P2, v4:P4) {.cdecl.}, v2:P, v3:P2, v:P4) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[T, P, P2, P4, P5](del: TMulticastDelegateOneParam[T], fn : proc(v:T, v2:P, v3:P2, v4:P4, v5:P5) {.cdecl.}, v2:P, v3:P2, v:P4, v5:P5) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}

proc remove*[T](del: TMulticastDelegateOneParam[T], handle : FDelegateHandle) {.importcpp:"#.Remove(#)"}

proc addStatic*[R, T](del: TDelegateRetOneParam[R, T], fn : proc(v:T) : bool {.cdecl.}) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}
proc addStatic*[R, T, P](del: TDelegateRetOneParam[R, T], fn : proc(v:T, p:P) : bool {.cdecl.}, p:P) : FDelegateHandle {.importcpp:"#.AddStatic(@)".}

proc createStatic*[R, T](fn : proc(v:T) : bool {.cdecl.}) : TDelegateRetOneParam[R, T] {.importcpp:"TDelegate<bool(float)>::CreateStatic(@)".}
proc createStatic*[R, T, P](fn : proc(v:T, p:P) : bool {.cdecl.}, p:P) : TDelegateRetOneParam[R, T] {.importcpp:"TDelegate<bool(float)>::CreateStatic(@)".}

#Notice this is needed because we cant express the signature of some delegates without hacks (mostly due to const) in Nim
#So you bind the delegate as a regular type and then you pass over a functor to this function and voila!
proc createLambda*[T](functor: object): T {.importcpp:"'0::CreateLambda(#)" .}


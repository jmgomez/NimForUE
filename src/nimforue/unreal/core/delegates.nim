#This file will contain everything related with delegates.

import ../coreuobject/uobject


type FWeakObjectPtr* {.importcpp.} = object


# proc makeWeakObjectPtr*[T : UObjectPtr] (obj : T) : FWeakObjectPtr {.importcpp: "FWeakObjectPtr(#)", constructor.} 


# type TBaseDynamicMulticastDelegate* {.importcpp, inheritable, pure.} = object

# type TDynamicMulticastDelegateOneParam*[T] = object of TBaseDynamicMulticastDelegate


# proc broadcast*[T](del: TDynamicMulticastDelegateOneParam[T], val : T) {.importcpp: "#.Broadcast(@)"}


#Delegates a variadic, for now we can just return the type adhoc

#They can be generalized later but doing a macro or something.
#This is just the minimum to get the event working
# type TMulticastDelegateOneParam*[bool] {.importc:"TMulticastDelegate<void(bool)>", nodecl .} = object

# proc addLambda*(del: TMulticastDelegateOneParam[bool], lambda : proc (val : bool)) {.importcpp: "#.AddLambda(@)"}

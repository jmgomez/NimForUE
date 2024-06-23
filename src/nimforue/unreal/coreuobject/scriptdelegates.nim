include ../definitions

import uobject
import nametypes
import std/strformat
import ../nimforue/bindingdeps


type
    FMulticastScriptDelegate* {.importcpp, inheritable, pure.} = object 
    FScriptDelegate* {.importcpp, inheritable, pure.} = object
    

proc getMulticastDelegate*(prop: FMulticastDelegatePropertyPtr, propValue: pointer): ptr FMulticastScriptDelegate {.importcpp:"const_cast<FMulticastScriptDelegate*>(#->GetMulticastDelegate(#))".}
proc setMulticastDelegate*(prop: FMulticastDelegatePropertyPtr, propValue: pointer, scriptDel: FMulticastScriptDelegate) : void {.importcpp:"#->SetMulticastDelegate(#, #)".}
proc addDelegate*(prop: FMulticastDelegatePropertyPtr, del: FScriptDelegate, obj: UObjectPtr): void {.importcpp:"#->AddDelegate(@)".}
proc clearDelegate*(prop: FMulticastDelegatePropertyPtr, parent: UObjectPtr): void {.importcpp:"#->ClearDelegate(@)".}

proc makeScriptDelegate*() : FScriptDelegate {. importcpp:"FScriptDelegate()", constructor .}
# proc makeMulticastScriptDelegate() : FMulticastScriptDelegate {. importcpp:"FScriptDelegate()", constructor .}


proc bindUFunction*(dynDel: var FScriptDelegate, obj:UObjectPtr, name:FName) : void {.importcpp: "#.BindUFunction(@)".}
# proc bindUFunction*(dynDel: var FScriptDelegate, obj:UObjectPtr, name:FName) : void = bindUFunction(dynDel[], obj, name)

#Should use add unique?
proc addUnique*(dynDel: var FMulticastScriptDelegate, scriptDel : FScriptDelegate) : void {.importcpp: "#.AddUnique(#)".}
proc add*(dynDel: var FMulticastScriptDelegate, scriptDel : FScriptDelegate) : void {.importcpp: "#.Add(#)".}

# #Notice this function doesnt exists in cpp
# We reserve AddDynamic for the future.
proc bindUFunc*(ownerProp: (UObjectPtr, FMulticastDelegatePropertyPtr), obj: UObjectPtr, name: FName) = 
#This overloads deals with the bindings. Fixes #46 where in some delegates the addr is nil if not bp inherit from it
  let (owner, prop) = ownerProp
  var scriptDel = makeScriptDelegate()
  scriptDel.bindUFunction obj, name    
  prop.addDelegate(scriptDel, owner)

proc bindUFunc*(dynDel: var FMulticastScriptDelegate, obj: UObjectPtr, name: FName) = 
  var scriptDel = makeScriptDelegate()
  scriptDel.bindUFunction obj, name
  if dynDel.addr.isNil:
    UE_Error &"Coudlnt bind {name.toFString()} to {obj.getName()} because the delegate is null"
  else:
    dynDel.addUnique(scriptDel)

proc removeAll*(dynDel: var FMulticastScriptDelegate, obj: UObjectPtr) : void {. importcpp: "#.RemoveAll(#)" .}
proc removeAll*(dynDel: ptr FMulticastScriptDelegate, obj: UObjectPtr) : void {. importcpp: "#->RemoveAll(#)" .}

proc removeAll*(ownerProp: (UObjectPtr, FMulticastDelegatePropertyPtr), obj: UObjectPtr) = 
  let (owner, prop) = ownerProp
  let del = getMulticastDelegate(prop, getPropertyValuePtr[FMulticastScriptDelegate](prop, owner))
  del.removeAll(obj)

#this is the same thing as processEvent (onFunctionCall)
#params should be a struct

proc processMulticastDelegateInternal(dynDel: var FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}

proc processMulticastDelegate*(dynDel: var FMulticastScriptDelegate, params:pointer) {.inline.} = 
    dynDel.processMulticastDelegateInternal(params)

proc isBound*(dynDel:var FScriptDelegate) : bool {.importcpp: "#.IsBound()" .}

proc processDelegateInternal(dynDel:var FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}

proc processDelegate*(dynDel:var FScriptDelegate, params:pointer) : void = 
    if dynDel.isBound():
        dynDel.processDelegateInternal(params)





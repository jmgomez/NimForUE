include ../definitions

import uobject
import nametypes



type
    FMulticastScriptDelegate* {.importcpp, inheritable, pure.} = object 
    FScriptDelegate* {.importcpp, inheritable, pure.} = object


proc makeScriptDelegate() : FScriptDelegate {. importcpp:"FScriptDelegate()", constructor .}


proc bindUFunction*(dynDel:FScriptDelegate, obj:UObjectPtr, name:FName) : void {.importcpp: "#.BindUFunction(@)".}

#Should use add unique?
proc addUnique(dynDel: FMulticastScriptDelegate, scriptDel : FScriptDelegate) : void {.importcpp: "#.AddUnique(#)".}

#Notice this function doesnt exists in cpp
proc bindUFunction*(dynDel: FMulticastScriptDelegate, obj:UObjectPtr, name:FName) = 
    let scriptDel = makeScriptDelegate()
    scriptDel.bindUFunction obj, name
    dynDel.addUnique(scriptDel)

proc removeAll*(dynDel: FMulticastScriptDelegate, obj:UObjectPtr) : void {. importcpp: "#.RemoveAll(#)" .}




#this is the same thing as processEvent (onFunctionCall)
#params should be a struct

proc processMulticastDelegate*(dynDel:FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}
proc isBound*(dynDel:FScriptDelegate) : bool {.importcpp: "#.IsBound()" .}
proc processDelegateInternal(dynDel:FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}
proc processDelegate*(dynDel:FScriptDelegate, params:pointer) : void = 
    if dynDel.isBound():
        dynDel.processDelegateInternal(params)





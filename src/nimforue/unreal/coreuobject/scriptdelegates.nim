include ../definitions

import uobject
import nametypes



type
    FMulticastScriptDelegate* {.importcpp.} = object 
    FScriptDelegate* {.importcpp, inheritable, pure.} = object


proc makeScriptDelegate() : FScriptDelegate {. importcpp:"TScriptDelegate<>()", constructor .}


proc bindUFunction*(dynDel:FScriptDelegate, obj:UObjectPtr, name:FName) : void {.importcpp: "#.BindUFunction(@)".}

#Should use add unique?
proc add(dynDel:ptr FMulticastScriptDelegate, scriptDel : FScriptDelegate) : void {.importcpp: "#.Add(#)".}

#Notice this function doesnt exists in cpp
proc bindUFunction*(dynDel:ptr FMulticastScriptDelegate, obj:UObjectPtr, name:FName) = 
    let scriptDel = makeScriptDelegate()
    scriptDel.bindUFunction obj, name
    dynDel.add(scriptDel)
    




#this is the same thing as processEvent (onFunctionCall)
#params should be a struct

proc processMulticastDelegate*(dynDel:FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}
proc isBound*(dynDel:FScriptDelegate) : bool {.importcpp: "#.IsBound()" .}
proc processDelegate*(dynDel:FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}






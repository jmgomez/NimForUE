include ../definitions

import uobject
import nametypes



type
    FMulticastScriptDelegate* {.importcpp, inheritable, pure.} = object 
    FScriptDelegate* {.importcpp, inheritable, pure.} = object
    

proc getMulticastDelegate*(prop: FMulticastDelegatePropertyPtr, propValue: pointer): ptr FMulticastScriptDelegate {.importcpp:"const_cast<FMulticastScriptDelegate*>(#->GetMulticastDelegate(#))".}

proc makeScriptDelegate() : FScriptDelegate {. importcpp:"FScriptDelegate()", constructor .}
# proc makeMulticastScriptDelegate() : FMulticastScriptDelegate {. importcpp:"FScriptDelegate()", constructor .}


proc bindUFunction*(dynDel: var FScriptDelegate, obj:UObjectPtr, name:FName) : void {.importcpp: "#.BindUFunction(@)".}
# proc bindUFunction*(dynDel: var FScriptDelegate, obj:UObjectPtr, name:FName) : void = bindUFunction(dynDel[], obj, name)

#Should use add unique?
proc addUnique(dynDel: var FMulticastScriptDelegate, scriptDel : FScriptDelegate) : void {.importcpp: "#.AddUnique(#)".}

# #Notice this function doesnt exists in cpp
proc bindUFunc*(dynDel: var FMulticastScriptDelegate, obj:UObjectPtr, name:FName) = 
    var scriptDel = makeScriptDelegate()
    scriptDel.bindUFunction obj, name
    dynDel.addUnique(scriptDel)

# template bindUFunction*(dynDel: var FMulticastScriptDelegate, obj:UObjectPtr, name:FName) = 
#     var scriptDel = makeScriptDelegate()
#     scriptDel.bindUFunction obj, name
#     {.emit: [
#         """(reinterpret_cast<FMulticastScriptDelegate*>(""",
#         dynDel.addr,
#         "))->AddUnique(",
#         scriptDel,
#         ");"
#     ].}

proc removeAll*(dynDel:var FMulticastScriptDelegate, obj:UObjectPtr) : void {. importcpp: "#.RemoveAll(#)" .}




#this is the same thing as processEvent (onFunctionCall)
#params should be a struct

proc processMulticastDelegateInternal(dynDel:var FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}
proc processMulticastDelegate*(dynDel:var FMulticastScriptDelegate, params:pointer) {.inline.} = 
    dynDel.processMulticastDelegateInternal(params)
proc isBound*(dynDel:var FScriptDelegate) : bool {.importcpp: "#.IsBound()" .}
proc processDelegateInternal(dynDel:var FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}
proc processDelegate*(dynDel:var FScriptDelegate, params:pointer) : void = 
    if dynDel.isBound():
        dynDel.processDelegateInternal(params)






import uobject
import nametypes



type
    FMulticastScriptDelegate* {.importcpp.} = object 
    FScriptDelegate* {.importcpp.} = object




proc bindUFunction*(dynDel:FScriptDelegate, obj:UObjectPtr, name:FName) : void {.importcpp: "#.BindUFunction(@)".}

#this is the same thing as processEvent (onFunctionCall)
#params should be a struct



proc processMulticastDelegate*(dynDel:FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}


proc internalProcessDelegate*(dynDel:FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}
proc isBound*(dynDel:FScriptDelegate) : bool {.importcpp: "#.IsBound()" .}


proc processDelegate*(dynDel:FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}






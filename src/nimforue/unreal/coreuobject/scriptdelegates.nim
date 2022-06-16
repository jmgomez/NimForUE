
import uobject
import nametypes



type
    FMulticastScriptDelegate* {.importcpp.} = object 
    FScriptDelegate* {.importcpp.} = object


#this is the same thing as processEvent (onFunctionCall)
#params should be a struct

proc processMulticastDelegate*(dynDel:FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}
proc processDelegate*(dynDel:FScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessDelegate<UObject>(@)" .}





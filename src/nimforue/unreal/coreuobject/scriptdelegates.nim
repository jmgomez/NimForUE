

type
    FMulticastScriptDelegate* {.importcpp.} = object 


#this is the same thing as processEvent (onFunctionCall)
#params should be a struct

proc processDelegate*(dynDel:FMulticastScriptDelegate, params:pointer) : void {.importcpp: "#.ProcessMulticastDelegate<UObject>(@)" .}



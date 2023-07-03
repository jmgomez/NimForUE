



let GPlayInEditorID* {.importcpp, nodecl .} : int32
# /** Whether GWorld points to the play in editor world */
let GIsPlayInEditorWorld* {.importcpp, nodecl.} : bool



proc isRunningCommandlet*() : bool {.importcpp:"(IsRunningCommandlet)" .}


#Misc types that lives inside core
import delegates

type FArchive* {.importcpp .} = object


proc makeFArchive*(): FArchive {.importcpp: "'0()", constructor.}

type
  FSimpleMulticastDelegate* = TMulticastDelegate
  EReloadCompleteReason* {.importcpp, size:sizeof(uint8).} = enum
    None, HotReloadAutomatic, HotReloadManual
  # FReloadCompleteDelegate* = TMulticastDelegateOneParam[EReloadCompleteReason]

let onAllModuleLoadingPhasesComplete* {.importcpp:"FCoreDelegates::OnAllModuleLoadingPhasesComplete", nodecl.}: FSimpleMulticastDelegate
let reloadCompleteDelegate* {.importcpp:"FCoreUObjectDelegates::ReloadCompleteDelegate", nodecl.}: TMulticastDelegateOneParam[EReloadCompleteReason]
let onPostEngineInit* {.importcpp:"FCoreDelegates::OnPostEngineInit", nodecl.}: FSimpleMulticastDelegate

proc `<<`*(ar: var FArchive, n: SomeNumber | bool) {.importcpp:"(#<<#)".}


#Misc types that lives inside core
import delegates

type FArchive* {.importcpp .} = object


proc makeFArchive*(): FArchive {.importcpp: "'0()", constructor.}

type
  FSimpleMulticastDelegate* = TMulticastDelegate

let onAllModuleLoadingPhasesComplete* {.importcpp:"FCoreDelegates::OnAllModuleLoadingPhasesComplete", nodecl.}: FSimpleMulticastDelegate

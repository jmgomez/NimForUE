import ../core/delegates
import std/typetraits


type FOnPIEEvent* = TMulticastDelegateOneParam[bool]
# proc onBeginPIEEvent*() : FOnPIEEvent  {.importcpp:"(FEditorDelegates::BeginPIE)".}



let onBeginPIEEvent* {.importcpp:"(FEditorDelegates::BeginPIE)", nodecl.}  : FOnPIEEvent
let onEndPIEEvent* {.importcpp:"(FEditorDelegates::EndPIE)", nodecl.}  : FOnPIEEvent


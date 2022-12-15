include  ../prelude
import std/typetraits



type 
  UEditorEngine* {.importcpp.} = object of UEngine
    playWorld* {.importcpp: "PlayWorld".} : UWorldPtr
    editorWorld* {.importcpp: "EditorWorld".} : UWorldPtr
  UEditorEnginePtr* = ptr UEditorEngine

let GEditor* {.importcpp:"GEditor", nodecl.} : UEditorEnginePtr

type FOnPIEEvent* = TMulticastDelegateOneParam[bool]
# proc onBeginPIEEvent*() : FOnPIEEvent  {.importcpp:"(FEditorDelegates::BeginPIE)".}

func isInPIE*(editor:UEditorEnginePtr) : bool = editor.playWorld.isNotNil

let onBeginPIEEvent* {.importcpp:"FEditorDelegates::BeginPIE", nodecl.}  : FOnPIEEvent
let onEndPIEEvent* {.importcpp:"FEditorDelegates::EndPIE", nodecl.}  : FOnPIEEvent


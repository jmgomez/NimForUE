include  ../prelude
import std/[options,sugar, typetraits]



type 
  UEditorEngine* {.importcpp.} = object of UEngine
    playWorld* {.importcpp: "PlayWorld".} : UWorldPtr
    editorWorld* {.importcpp: "EditorWorld".} : UWorldPtr
  UEditorEnginePtr* = ptr UEditorEngine
  FEditorViewportClient* {.importcpp.} = object
  FEditorViewportClientPtr* = ptr FEditorViewportClient

let GEditor* {.importcpp, nodecl.} : UEditorEnginePtr

type FOnPIEEvent* = TMulticastDelegateOneParam[bool]
# proc onBeginPIEEvent*() : FOnPIEEvent  {.importcpp:"(FEditorDelegates::BeginPIE)".}

func isInPIE*(editor:UEditorEnginePtr) : bool = editor.playWorld.isNotNil

let onBeginPIEEvent* {.importcpp:"FEditorDelegates::BeginPIE", nodecl.}  : FOnPIEEvent
let onEndPIEEvent* {.importcpp:"FEditorDelegates::EndPIE", nodecl.}  : FOnPIEEvent

proc getPieWorldContext*(editor:UEditorEnginePtr, worldPIEInstance:int32 = 0) : FWorldContextPtr {.importcpp: "#->GetPIEWorldContext(#)".}

proc getAllViewportClients*(editor:UEditorEnginePtr) : TArray[FEditorViewportClientPtr] {.importcpp: "#->GetAllViewportClients()".}

proc getWorld*(viewportClient:FEditorViewportClientPtr) : UWorldPtr {.importcpp: "#->GetWorld()".}

proc getGameViewPort*(uworld:UWorldPtr) : UGameViewportClientPtr {. importcpp:"#->GetGameViewport()" .}

proc getEditorWorld*() : UWorldPtr =
  #notice this wont give you the appropiated world when there are multiple viewports
  if GPlayInEditorID < 0:
    let worldContext = GEditor.getPieWorldContext(1)
    if worldContext.isNil:
      if GEngine.gameViewport.isNotNil:
        return GEngine.gameViewport.getWorld()
    else:
      return worldContext.getWorld()
  else:
    let worldContext = GEditor.getPieWorldContext(GPlayInEditorID)
    if worldContext.isNotNil:
      return worldContext.getWorld()
  #At this point we try to return an editor one
  return GEditor
          .getAllViewportClients()
          .toSeq()
          .head()
          .map(x=>x.getWorld())
          .get(nil)
    
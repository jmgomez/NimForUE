include  ../prelude
import std/typetraits



type 
  UEditorEngine* {.importcpp.} = object of UEngine
    playWorld* {.importcpp: "PlayWorld".} : UWorldPtr
    editorWorld* {.importcpp: "EditorWorld".} : UWorldPtr
  UEditorEnginePtr* = ptr UEditorEngine

let GEditor* {.importcpp, nodecl.} : UEditorEnginePtr

type FOnPIEEvent* = TMulticastDelegateOneParam[bool]
# proc onBeginPIEEvent*() : FOnPIEEvent  {.importcpp:"(FEditorDelegates::BeginPIE)".}

func isInPIE*(editor:UEditorEnginePtr) : bool = editor.playWorld.isNotNil

let onBeginPIEEvent* {.importcpp:"FEditorDelegates::BeginPIE", nodecl.}  : FOnPIEEvent
let onEndPIEEvent* {.importcpp:"FEditorDelegates::EndPIE", nodecl.}  : FOnPIEEvent

proc getPieWorldContext*(editor:UEditorEnginePtr, worldPIEInstance:int32 = 0) : FWorldContextPtr {.importcpp: "#->GetPIEWorldContext(#)".}


proc getEditorWorld*() : UWorldPtr =
  #notice this wont give you the appriate world when there is multiple viewports
  if GPlayInEditorID < 0:
    var worldContext = GEditor.getPieWorldContext(1)
    if worldContext.isNil:
      if GEngine.gameViewport.isNotNil:
        return GEngine.gameViewport.getWorld()
    else:
      return worldContext.getWorld()
  else:
    let worldContext = GEditor.getPieWorldContext(GPlayInEditorID)
    if worldContext.isNotNil:
      return worldContext.getWorld()
  return nil
    

# /*static*/
# UWorld* UWorldStatics::GetActiveWorld()
# {
# 	UWorld* world = nullptr;
# #if WITH_EDITOR
# 	if (GIsEditor)
# 	{
# 		if (GPlayInEditorID == -1)
# 		{
# 			FWorldContext* worldContext = GEditor->GetPIEWorldContext(1);
# 			if (worldContext == nullptr)
# 			{
# 				if (UGameViewportClient* viewport = GEngine->GameViewport)
# 				{
# 					world = viewport->GetWorld();
# 				}
# 			}
# 			else
# 			{
# 				world = worldContext->World();
# 			}
# 		}
# 		else
# 		{
# 			FWorldContext* worldContext = GEditor->GetPIEWorldContext(GPlayInEditorID);
# 			if (worldContext == nullptr)
# 			{
# 				return nullptr;
# 			}
# 			world = worldContext->World();
# 		}
# 	}
# 	else
# 	{
# 		world = GEngine->GetCurrentPlayWorld(nullptr);
# 	}
# #else
# 	world = GEngine->GetCurrentPlayWorld(nullptr);
# #endif
# 	return world;
# }
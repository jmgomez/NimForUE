when not defined(nimsuggest):
  include  ../prelude
import std/[options,sugar, typetraits, sequtils]



type 
  UEditorEngine* {.importcpp.} = object of UEngine
    playWorld* {.importcpp: "PlayWorld".} : UWorldPtr
    editorWorld* {.importcpp: "EditorWorld".} : UWorldPtr
  UEditorEnginePtr* = ptr UEditorEngine
  FEditorViewportClient* {.importcpp, inheritable.} = object of FViewportClient
    viewport* {.importcpp: "Viewport".} : FViewportPtr
  FEditorViewportClientPtr* = ptr FEditorViewportClient
  FLevelEditorViewportClient* {.importcpp.} = object of FEditorViewportClient
  FLevelEditorViewportClientPtr* = ptr FLevelEditorViewportClient

  FViewportCursorLocation* {.importcpp.} = object
  EReloadCompleteReason* {.importcpp, size:sizeof(uint8).} = enum
    None, HotReloadAutomatic, HotReloadManual
  FReloadCompleteDelegate* = TMulticastDelegateOneParam[EReloadCompleteReason]
  FOnPIEEvent* = TMulticastDelegateOneParam[bool]

  #Probably this belongs to enginetypes
  FSceneView* {.importcpp.} = object
  FSceneViewPtr* = ptr FSceneView
  FSceneViewProjectionData* {.importcpp} = object

  FAssetTypeActions_Base* {.importcpp, inheritable.} = object
  FAssetTypeActions_BasePtr* = ptr FAssetTypeActions_Base
  IAssetTools* {.importcpp.} = object
  IAssetToolsPtr* = ptr IAssetTools  
  

  EAssetTypeCategories* = enum
    None, Basic, Animation, Materials, Sounds, Physics, UI, Misc = 64, Gameplay, Blueprint, Media, Textures



let GEditor* {.importcpp, nodecl.} : UEditorEnginePtr

# proc onBeginPIEEvent*() : FOnPIEEvent  {.importcpp:"(FEditorDelegates::BeginPIE)".}

func isInPIE*(editor:UEditorEnginePtr) : bool = 
  editor.playWorld.isNotNil

func getActiveViewport*(editor:UEditorEnginePtr) : FViewportPtr {.importcpp: "#->GetActiveViewport()".}
#	void DeprojectFVector2D(const FVector2D& ScreenPos, FVector& out_WorldOrigin, FVector& out_WorldDirection) const;


let onBeginPIEEvent* {.importcpp:"FEditorDelegates::BeginPIE", nodecl.}  : FOnPIEEvent
let onEndPIEEvent* {.importcpp:"FEditorDelegates::EndPIE", nodecl.}  : FOnPIEEvent
let onReloadCompleteEvent* {.importcpp:"FCoreUObjectDelegates::ReloadCompleteDelegate", nodecl.}  : FReloadCompleteDelegate

proc getPieWorldContext*(editor:UEditorEnginePtr, worldPIEInstance:int32 = 0) : FWorldContextPtr {.importcpp: "#->GetPIEWorldContext(#)".}

proc getAllViewportClients*(editor:UEditorEnginePtr) : TArray[FEditorViewportClientPtr] {.importcpp: "#->GetAllViewportClients()".}
proc getLevelViewportClients*(editor:UEditorEnginePtr) : TArray[FLevelEditorViewportClientPtr] {.importcpp: "#->GetLevelViewportClients()".}

proc getWorld*(viewportClient:FEditorViewportClientPtr) : UWorldPtr {.importcpp: "#->GetWorld()".}
proc getClientAsEditorViewportClient*(viewport: FViewportPtr): FEditorViewportClientPtr = 
  cast[FEditorViewportClientPtr](viewport.getClient())

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
    
proc getEditorViewportClient*(editorWorld:UWorldPtr) : FEditorViewportClientPtr = GEditor.getAllViewportClients().toSeq().filterIt(it.getWorld()==editorWorld).head().get(nil)

# proc getMouseX*(viewportClient:FEditorViewportClientPtr) : int32 {.importcpp: "#->GetMouseX()".}
proc getViewLocation*(viewportClient:FEditorViewportClientPtr) : FVector {.importcpp: "#->GetViewLocation()".}


proc getCursorWorldLocation*(viewportClient:FEditorViewportClientPtr) : FViewportCursorLocation {.importcpp: "#->GetCursorWorldLocationFromMousePos()".}


proc getOrigin*(cursorLocation:FViewportCursorLocation) : FVector {.importcpp: "#.GetOrigin()".}
proc getDirection*(cursorLocation:FViewportCursorLocation) : FVector {.importcpp: "#.GetDirection()".}
proc getCursorPos*(cursorLocation:FViewportCursorLocation) : FIntPoint {.importcpp: "#.GetCursorPos()".}

proc `$`*(cursorLocation:FViewportCursorLocation) : string =
  "Origin: " & $cursorLocation.getOrigin() & " Direction: " & $cursorLocation.getDirection() & " CursorPos: " & $cursorLocation.getCursorPos()

#Not in PCH, wont work in 5.3 either add it to the pch or dont use it.
# proc compileBlueprint*(bp: UBlueprintPtr) {.importcpp: "FKismetEditorUtilities::CompileBlueprint(#)", header:"Kismet2/KismetEditorUtilities.h".}


  #[
     UToolMenu* AssetsToolBar = UToolMenus::Get()->ExtendMenu("LevelEditor.LevelEditorToolBar.AssetsToolBar");
        if (AssetsToolBar) {
            FToolMenuSection& Section = AssetsToolBar->AddSection("Content");
            FToolMenuEntry LaunchPadEntry = FToolMenuEntry::InitToolBarButton("DA", FUIAction(FExecuteAction::CreateStatic(&FLaunchPadSystem::Launch)),        //FDALevelToolbarCommands::Get().OpenLaunchPad,
                                                                                    LOCTEXT("DAToolbarButtonText_1", "Dungeon Architect"),
                                                                                    LOCTEXT("DAToolbarButtonTooltip", "Dungeon Architect Launch Pad"),
                                                                                    FSlateIcon(FDungeonArchitectStyle::GetStyleSetName(), TEXT("DungeonArchitect.Toolbar.IconMain")));
            LaunchPadEntry.StyleNameOverride = "CalloutToolbar";
            Section.AddEntry(LaunchPadEntry);
        }
  ]#


proc loadModulePtr*[T](name: FName): ptr T {.importcpp:"FModuleManager::LoadModulePtr<'*0>(#)".} #This should be part of EngineTypes
proc loadAssetTools*() : IAssetToolsPtr {.importcpp: "&FModuleManager::LoadModuleChecked<FAssetToolsModule>(\"AssetTools\").Get()".}

proc registerAssetTypeActions*(assetTools:IAssetToolsPtr, newActions:TSharedRef[FAssetTypeActions_Base]) {.importcpp: "#->RegisterAssetTypeActions(#)".}
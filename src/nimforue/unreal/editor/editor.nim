when not defined(nimsuggest):
  include  ../prelude
import std/[options,sugar, typetraits, sequtils]

when defined(game): #TODO remove this
  import ../../game/extras/ui
else:
  type 
    SCompoundWidget* {.importcpp, inheritable.} = object of SWidget
    SCompoundWidgetPtr* = ptr SCompoundWidget
    SBorder* {.importcpp, inheritable.} = object of SCompoundWidget
    SBorderPtr* = ptr SBorder
    SDockTab* {.importcpp, inheritable.} = object of SBorder
    SDockTabPtr* = ptr SDockTab
    SDockableTab * {.importcpp, inheritable.} = object of SDockTab
    SDockableTabPtr* = ptr SDockableTab

    EToolkitMode* {.importcpp:"EToolkitMode::Type".} = enum
      Standalone
      WorldCentric

type 
  UEditorEngine* {.importcpp.} = object of UEngine
    playWorld* {.importcpp: "PlayWorld".} : UWorldPtr
    editorWorld* {.importcpp: "EditorWorld".} : UWorldPtr
  UEditorEnginePtr* = ptr UEditorEngine
  FEditorViewportClient* {.importcpp, inheritable.} = object of FViewportClient
    # viewport* {.importcpp: "Viewport".} : FViewportPtr
    previewScene* {.importcpp: "PreviewScene".} : FPreviewScenePtr
  FEditorViewportClientPtr* = ptr FEditorViewportClient
  FLevelEditorViewportClient* {.importcpp.} = object of FEditorViewportClient
  FLevelEditorViewportClientPtr* = ptr FLevelEditorViewportClient
  FEditorModeTools* {.importcpp.} = object
  FEditorModeToolsPtr* = ptr FEditorModeTools
  FAdvancedPreviewSceneModule* {.importcpp.} = object
  FAdvancedPreviewSceneModulePtr* = ptr FAdvancedPreviewSceneModule

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

  FWorkflowTabFactory* {.importcpp, inheritable.} = object 
    tabLabel {.importcpp:"TabLabel".} : FText
  FWorkflowTabFactoryPtr* = ptr FWorkflowTabFactory
  FWorkflowTabSpawnInfo* {.importcpp, bycopy, inheritable.} = object
  FWorkflowTabSpawnInfoPtr* = ptr FWorkflowTabSpawnInfo
  FTabManager* {.importcpp, inheritable.} = object
  FTabManagerPtr* = ptr FTabManager
  FTabManagerLayout* {.importcpp:"FTabManager::FLayout", inheritable.} = object #what is the base class?
  FTabManagerLayoutNode* {.importcpp:"FTabManager::FLayoutNode", inheritable.} = object
  FTabManagerArea* {.importcpp:"FTabManager::FArea", inheritable.} = object of FTabManagerLayoutNode
  FTabManagerStack* {.importcpp:"FTabManager::FStack", inheritable.} = object of FTabManagerLayoutNode
  FTabManagerSplitter* {.importcpp:"FTabManager::FSplitter", inheritable.} = object 
  FSpawnTabArgs* {.importcpp, inheritable, bycopy.} = object
  FTabSpawnerEntry* {.importcpp, inheritable.} = object
    # tabId {.importcpp:"TabId".} : FName
    discard


  ETabState* {.importcpp:"ETabState::Type".} = enum
    OpenedTab, ClosedTab, SidebarTab

  IToolkitHost* {.importcpp, inheritable.} = object
  IToolkitHostPtr* = ptr IToolkitHost
  IDetailsView* {.importcpp, inheritable.} = object of SCompoundWidget
  IDetailsViewPtr* = ptr IDetailsView
  FPropertyEditorModule* {.importcpp, inheritable.} = object
  FPropertyEditorModulePtr* = ptr FPropertyEditorModule
  FDetailsViewArgs* {.importcpp, inheritable.} = object
    bAllowSearch* {.importcpp:"bAllowSearch".} : bool
    bHideSelectionTip* {.importcpp:"bHideSelectionTip".} : bool
    bLockable* {.importcpp:"bLockable".} : bool

  FPreviewScene* {.importcpp, inheritable.} = object
  FPreviewScenePtr* = ptr FPreviewScene
  FAdvancedPreviewScene* {.importcpp, inheritable.} = object of FPreviewScene
  FAdvancedPreviewScenePtr* = ptr FAdvancedPreviewScene
  ConstructionValues* {.importcpp:"FPreviewScene::$1", inheritable.} = object
    lightRotation* {.importcpp:"LightRotation".} : FRotator
    lightBrightness* {.importcpp:"LightBrightness".} : float32

  SEditorViewport* {.importcpp, inheritable.} = object of SCompoundWidget
  SEditorViewportPtr* = ptr SEditorViewport
  SAssetEditorViewport* {.importcpp, inheritable.} = object of SEditorViewport
    sceneViewport {.importcpp:"SceneViewport".} : TSharedPtr[FSceneViewport]
  SAssetEditorViewportPtr* = ptr SAssetEditorViewport
  SAssetEditorViewportFArguments* {.importcpp:"SAssetEditorViewport::FArguments", inheritable.} = object
  FAssetEditorViewportLayout* {.importcpp, inheritable.} = object #of FEditorViewportLayout
  FAssetEditorViewportConstructionArgs* {.importcpp.} = object
    parentLayout* {.importcpp:"ParentLayout".} : TSharedRef[FAssetEditorViewportLayout]

  SAdvancedPreviewDetailsTab* {.importcpp.} = object of SCompoundWidget

  ICommonEditorViewportToolbarInfoProvider* {.importcpp, inheritable.} = object 

  FAssetEditorToolkit* {.importcpp, inheritable.} = object
  FAssetEditorToolkitPtr* = ptr FAssetEditorToolkit
  #this should be in EngineTypes I guess
  

  FOnSpawnTab* {.importcpp.} = object# TDelegateRetOneParam[TSharedRef[SDockTab], FSpawnTabArgs]
  
  FExtender* {.importcpp.} = object
#TODO before moving on make the parser work with the enums!
  EOrientation* {.size: sizeof(uint8), importcpp, pure.} = enum
    Orient_Horizontal, Orient_Vertical, Orient_MAX


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
proc setRealtime*(viewportClient:FEditorViewportClientPtr, val: bool) {.importcpp: "#->SetRealtime(#)".}
proc setViewLocation*(viewportClient:FEditorViewportClientPtr, loc: FVector) {.importcpp: "#->SetViewLocation(#)".}
proc setViewRotation*(viewportClient:FEditorViewportClientPtr, rot: FRotator) {.importcpp: "#->SetViewRotation(#)".}
proc setLookAtLocation*(viewportClient:FEditorViewportClientPtr, loc: FVector, bRecalculateView = false) {.importcpp: "#->SetLookAtLocation(@)".}
proc getClientAsEditorViewportClient*(viewport: FViewportPtr): FEditorViewportClientPtr = 
  cast[FEditorViewportClientPtr](viewport.getClient())

proc getEditorWorld*(): UWorldPtr {.deprecated: "Use the playWorld from GEditor".} =
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
proc isAltPressed*(vpClint: FEditorViewportClientPtr): bool {.importcpp: "#->IsAltPressed()".}
proc isCtrlPressed*(vpClint: FEditorViewportClientPtr): bool {.importcpp: "#->IsCtrlPressed()".}
proc isShiftPressed*(vpClint: FEditorViewportClientPtr): bool {.importcpp: "#->IsShiftPressed()".}
proc getViewportDimensions*(vpClint: FEditorViewportClientPtr, outOrigin, outSize: var FIntPoint) {.importcpp:"#->(@)".}

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



proc initAssetEditor*(self:FAssetEditorToolkitPtr, mode: EToolkitMode, initToolkitHost {.byref.}: TSharedPtr[IToolkitHost], appIdentifier: FName,
                     standaloneDefaultLayout: TSharedRef[FTabManagerLayout], bCreateDefaultStandaloneMenu: bool,
                      bCreateDefaultToolbar: bool, objToEdit: UObjectPtr, bInIsToolbarFocusable = false,
                      bInUseSmallToolbarIcons = false) {.importcpp:"#->InitAssetEditor(@)".}

proc createDetailView*(self: FPropertyEditorModulePtr, args: FDetailsViewArgs): TSharedPtr[IDetailsView] {.importcpp:"#->CreateDetailView(#)" .}
proc setObject*(self: TSharedPtr[IDetailsView], obj: UObjectPtr) {.importcpp:"#->SetObject(#)" .}

#Need to find a generic way to deal with attributes but this should work for now
proc label*(self: TSharedRef[SDockTab], text: FText): TSharedRef[SDockTab] {.importcpp:"#.Label(#)" .} #TODO this is wrong

proc addArea*(self: TSharedRef[FTabManagerLayout], area: TSharedRef[FTabManagerArea]): TSharedRef[FTabManagerLayout] {.importcpp:"#->AddArea(#)" .}
proc newPrimaryArea*(): TSharedRef[FTabManagerArea] {.importcpp:"FTabManager::NewPrimaryArea()" .}
proc setOrientation*(self: TSharedRef[FTabManagerArea], orientation: EOrientation): TSharedRef[FTabManagerArea] {.importcpp:"#->SetOrientation(#)" .}
proc split*(self: TSharedRef[FTabManagerArea], node: TSharedRef[FTabManagerLayoutNode]): TSharedRef[FTabManagerArea] {.importcpp:"#->Split(#)" .}
proc newSplitter*(orientation: EOrientation): TSharedRef[FTabManagerSplitter] {.importcpp:"FTabManager::NewSplitter(#)" .}
proc split*(self: TSharedRef[FTabManagerSplitter], node: TSharedRef[FTabManagerLayoutNode]): TSharedRef[FTabManagerSplitter] {.importcpp:"#->Split(#)" .}
proc newTabManagerStack*(): TSharedRef[FTabManagerStack] {.importcpp:"FTabManager::NewStack()" .}
proc newTabManagerLayout*(name: FName): TSharedRef[FTabManagerLayout] {.importcpp:"FTabManager::NewLayout(#)".}
proc nullTabManagerLayout*(): TSharedRef[FTabManagerLayout] {.importcpp:"(FTabManager::FLayout::NullLayout)".}
proc addTab*(self: TSharedRef[FTabManagerStack], tabId: FName, tabState: ETabState): TSharedRef[FTabManagerStack] {.importcpp:"#->AddTab(@)" .}

proc registerTabSpawner*(self: TSharedRef[FTabManager], tabId: FName, tabSpawner {.byref.}: FOnSpawnTab): FTabSpawnerEntry {.importcpp:"#->RegisterTabSpawner(#, #)" .}
proc unregisterTabSpawner*(self: TSharedRef[FTabManager], tabId: FName): bool {.importcpp:"#->UnregisterTabSpawner(#)" .}


proc construct*(arg: SAssetEditorViewportFArguments, ctorArg: FAssetEditorViewportConstructionArgs) {.importcpp:"SAssetEditorViewport::Construct(@)".}
proc setEditorViewportClient*(self: SAssetEditorViewportFArguments, viewportClient: TSharedPtr[FEditorViewportClient]) {.importcpp:"#.EditorViewportClient(#)".}

proc createAdvancedPreviewSceneSettingsWidget*(prevSceneModule: FAdvancedPreviewSceneModulePtr, prevScene: TSharedRef[FAdvancedPreviewScene]): TSharedRef[SWidget] {.importcpp:"#->CreateAdvancedPreviewSceneSettingsWidget(#)".}
func getWorld*(prevScene: FPreviewScenePtr): UWorldPtr {.importcpp:"#->GetWorld()".}
proc setEnvironmentVisibility*(prevScene: FAdvancedPreviewScenePtr, bVisible: bool, bDirect = false) {.importcpp:"#->SetEnvironmentVisibility(@)" .}
proc setFloorVisibility*(prevScene: FAdvancedPreviewScenePtr, bVisible: bool, bDirect = false) {.importcpp:"#->SetFloorVisibility(@)" .}

template withCallInEditor*(body: untyped) =
  block:
    {.emit:"FEditorScriptExecutionGuard Guard; ".}
    body
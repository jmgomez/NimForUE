#[
  UMG and Slate extra manually binds
]#

include unrealprelude
import umg/[umg, blueprint, components, enums]
import slatecore
import codegen/uebind
export umg, blueprint, components, enums
export slatecore

type 
  SCompoundWidget* {.importcpp, inheritable.} = object of SWidget
  SCompoundWidgetPtr* = ptr SCompoundWidget
  SBorder* {.importcpp, inheritable.} = object of SCompoundWidget
  SBorderPtr* = ptr SBorder
  SDockTab* {.importcpp, inheritable.} = object of SBorder
  SDockTabPtr* = ptr SDockTab
  SDockableTab * {.importcpp, inheritable.} = object of SDockTab
  SDockableTabPtr* = ptr SDockableTab
  SPanel* {.importcpp, inheritable.} = object of SWidget
  SPanelPtr* = ptr SPanel
  SOverlay* {.importcpp, inheritable.} = object of SPanel
  SOverlayPtr* = ptr SOverlay
  SLeafWidget* {.importcpp, inheritable.} = object of SWidget
  SLeafWidgetPtr* = ptr SLeafWidget
  STextBlock* {.importcpp, inheritable.} = object of SLeafWidget
  STextBlockPtr* = ptr STextBlock



  EToolkitMode* {.importcpp:"EToolkitMode::Type".} = enum
    Standalone
    WorldCentric

type ArrowPtr[T] = ptr T | TSharedRef[out T] | TSharedPtr[T]  | TSharedRef[T]
#SLATE
proc sNew*[T:SWidget](): TSharedRef[T]{.importcpp:"SNew('*0)" .}
proc sNew*(T: typedesc[SWidget]): TSharedRef[T]{.importcpp:"SNew('*0)" .}
proc sNew*[T:SWidget, P](_: typedesc[T], arg:P): TSharedRef[T]{.importcpp:"#SNew('*1, #)" .}
proc getParentWidget*[T: SWidget](self: ArrowPtr[T]): TSharedPtr[SWidget] {.importcpp:"#->GetParentWidget()" .}

proc sAssignNew*[T:SWidget](widget: TSharedPtr[T]){.importcpp:"SAssignNew(#, '*1)" .}
# proc sNew[T: typedesc[SWidget]](_: T): TSharedRef[T] = sNew[T]()
#SBorder
proc setContent*[T: SBorder](self: ArrowPtr[T], content: TSharedRef[SWidget]): TSharedRef[T] {.importcpp:"#->SetContent(#)" .}
proc getContent*[T: SBorder](self: ArrowPtr[T]): TSharedRef[SWidget] {.importcpp:"#->GetContent()" .}


proc `accessibleBehavior`*(obj : UWidgetPtr): ESlateAccessibleBehavior =
  let prop = obj
  .getClass.getFPropertyByName(
      "AccessibleBehavior")
  getPropertyValuePtr[ESlateAccessibleBehavior](prop, obj)[]

proc `accessibleBehavior=`*(obj : UWidgetPtr;
                                 val : ESlateAccessibleBehavior) =
  var value : ESlateAccessibleBehavior = val
  let prop  = obj.getClass.getFPropertyByName(
      "AccessibleBehavior")
  setPropertyValuePtr[ESlateAccessibleBehavior](prop, obj, value.addr)

ueBindProp(FSlateBrush, TintColor, FSlateColor)
proc makeSlateColor*(color: FLinearColor): FSlateColor {.constructor, importcpp.}

proc setViewportOverlayWidget*(gameViewportClient: UGameViewportClientPtr, overlayWidget: TSharedRef[SOverlay]) {.importcpp: "#->SetViewportOverlayWidget(nullptr, #)".}


#Slots
type 
  FSlotBase* {.importcpp, inheritable.} = object
  FOverlaySlot* {.importcpp : "SOverlay::FOverlaySlot".} = object of FSlotBase
  FOverlaySlotArguments* {.importcpp:"FOverlaySlot::FSlotArguments".} = object
  FScopeWidgetSlotArguments* {.importcpp:"TPanelChildren<FOverlaySlot>::FScopedWidgetSlotArguments".} = object

#This can be made "generic"
# proc `+`*(slot: ArrowPtr[SOverlay], argument: FOverlaySlotArguments): TSharedRef[SOverlay]  {.importcpp: "#->operator+(#)" .}
# proc `+`*(slot: ArrowPtr[SOverlay], argument: FOverlaySlotArguments): TSharedRef[SOverlay]  {.importcpp: "(*#).operator+(#)" .}

# proc add*(slot: FOverlaySlot, )
proc addSlot*(overlay: ArrowPtr[SOverlay], zIndex: int32 = -1):FScopeWidgetSlotArguments {.importcpp: "#->AddSlot(#)" .}
proc `[]`*(arg: FScopeWidgetSlotArguments, widget: ArrowPtr[SWidget]) {.importcpp: "#[@]" .}
proc add*(arg: FScopeWidgetSlotArguments, widget: ArrowPtr[SWidget]) {.importcpp: "#[@]" .}
proc removeSlot*(overlay: ArrowPtr[SOverlay], zIndex: int32) {.importcpp: "#->RemoveSlot(#)" .}
proc clearChildren*(overlay: ArrowPtr[SOverlay]) {.importcpp: "#->ClearChildren()" .}
proc slot*(overlay: typedesc[SOverlay]): FOverlaySlotArguments {.importcpp: "'1::Slot()" .}
proc getNumberWidgets*(overlay: ArrowPtr[SOverlay]): int32 {.importcpp: "#->GetNumWidgets()" .}
proc len*(overlay: ArrowPtr[SOverlay]): int32  = getNumberWidgets(overlay)


proc setText*(textBlock: ArrowPtr[STextBlock], text: FText) {.importcpp: "#->SetText(#)" .}

#For some reason this is not being bound. TODO research why
import codegen/uebind
 
proc setVisibility*(widget: UWidget, visibility: ESlateVisibility) {.uebind.}
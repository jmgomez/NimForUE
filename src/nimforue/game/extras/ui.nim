#[
  UMG and Slate extra manually binds
]#

include unrealprelude
import umg/[umg, blueprint, components, enums]
import slatecore
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

  EToolkitMode* {.importcpp:"EToolkitMode::Type".} = enum
    Standalone
    WorldCentric

#SLATE
proc sNew*[T:SWidget](): TSharedRef[T]{.importcpp:"SNew('*0)" .}
proc sNew*[P](T: typedesc[SWidget], arg:P): TSharedRef[T]{.importcpp:"#SNew('*1, #)" .}

proc sAssignNew*[T:SWidget](widget: TSharedPtr[T]){.importcpp:"SAssignNew(#, '*1)" .}
# proc sNew[T: typedesc[SWidget]](_: T): TSharedRef[T] = sNew[T]()
#SBorder
proc setContent*[T: SBorder](self: TSharedRef[T], content: TSharedRef[SWidget]): TSharedRef[T] {.importcpp:"#->SetContent(#)" .}


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
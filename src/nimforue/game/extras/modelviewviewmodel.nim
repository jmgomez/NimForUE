include unrealprelude
#TODO This will need to be changed to exported when deploying, review others extras
import ../../unreal/bindings/imported/modelviewviewmodel

#[
  This assumes you have in your game.json   "gameModules": ["ModelViewViewModel"]
  and in your nuegame.h #include "MVVMViewModelBase.h"

]#

type 
  FFieldNotificationId* {.importcpp.} = object
  FFieldId* {.importcpp:"UE::FieldNotification::FFieldId".} = object

proc makeFFieldNotificationId*(name: FName): FFieldNotificationId {.importcpp: "FFieldNotificationId(#)", constructor.}
proc getFieldId*(vm: UMVVMViewModelBasePtr, cls: UClassPtr, name: FName): FFieldId {.importcpp: "#->GetFieldNotificationDescriptor().GetField(#, #)" .}
proc getFieldId*(vm: UMVVMViewModelBasePtr, name: FName): FFieldId = getFieldId(vm, vm.getClass(), name)
proc broadcastFieldValueChanged*(vm: UMVVMViewModelBasePtr, fieldId: FFieldId): void {.importcpp: "#->BroadcastFieldValueChanged(#)" .}
proc broadcastFieldValueChanged*(vm: UMVVMViewModelBasePtr, name: FName): void = 
  let fieldId = getFieldId(vm, name)
  broadcastFieldValueChanged(vm, fieldId)
include unrealprelude
#TODO This will need to be changed to exported when deploying, review others extras
when WithEditor:
  import ../../unreal/bindings/imported/modelviewviewmodel
else:
  import ../../unreal/bindings/exported/modelviewviewmodel

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

#[
These includes should be in nuegame.h in order to make the following work:
#include "MVVMViewModelBase.h"
#include "Types/MVVMViewModelContext.h"

]#
proc getViewModelCollectionWithContextFor(T: typedesc, worldContext: UObjectPtr): (UMVVMViewModelCollectionObjectPtr, FMVVMViewModelContext)   =
  let vmSubsystem = tryGetSubsystem[UMVVMGameSubsystem](worldContext).get(nil)
  if vmSubsystem.isNil:
    # printString "ViewModel Subsystem not found"
    return (nil, FMVVMViewModelContext())
  let vmContext = FMVVMViewModelContext(
    contextClass: makeTSubclassOf[UMVVMViewModelBase](T.staticClass),
    contextName: T.staticClass.getFName()
  )
  let col = vmSubsystem.get.getViewModelCollection()
  (col, vmContext)

proc addViewModelToCollection*(T: typedesc, worldContext: UObjectPtr): ptr T  =
  let (collection, vmContext) = getViewModelCollectionWithContextFor(T, worldContext)
  if collection.isNil: return nil
  let instance = newUObject[T]()
  discard collection.addViewModelInstance(vmContext, instance)
  instance

proc getViewModelFromCollection*(T: typedesc, worldContext: UObjectPtr): ptr T  = 
  let (collection, vmContext) = getViewModelCollectionWithContextFor(T, worldContext)
  if collection.isNil: return nil
  let instance = collection.findViewModelInstance(vmContext).ueCast(T)
  if instance.isNil:
    addViewModelToCollection(T, worldContext)
  else:
    instance
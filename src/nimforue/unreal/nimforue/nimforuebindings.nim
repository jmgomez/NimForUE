include ../definitions
import ../coreuobject/[uobject, uobjectglobals, package, unrealtype, nametypes]
import ../core/containers/[unrealstring, array, map]
import std/[typetraits, strutils, options, strformat]
import ../../codegen/models
import ../../utils/utils
type 
    UFunctionCaller* {.importc, inheritable, pure .} = object
    FNativeFuncPtr* {.importcpp.} = object
    
    UNimScriptStruct* {.importcpp.} = object of UScriptStruct
    # UNimScriptStruct* = UScriptStruct
        

    UNimScriptStructPtr* = ptr UNimScriptStruct

    UNimEnum* {.importcpp.} = object of UEnum

    UNimEnumPtr* = ptr UNimEnum

    UNimFunction* {.importcpp.} = object of UFunction
        sourceHash* {.importcpp: "SourceHash".} : FString
    UNimFunctionPtr* = ptr UNimFunction




    UReflectionHelpers* {.importcpp.} = object of UObject
    UReflectionHelpersPtr* = ptr UReflectionHelpers

proc setCppStructOpFor*[T](scriptStruct:UNimScriptStructPtr, fakeType:ptr T) : void {.importcpp:"#->SetCppStructOpFor<'*2>(#)".}




#UNimEnum
func getEnums*(uenum:UEnumPtr) : TArray[FString] {.importcpp:"UReflectionHelpers::GetEnums(#)".}
proc markNewVersionExists*(uenum:UNimEnumPtr) : void {.importcpp:"#->MarkNewVersionExists()".}

#UNimClassBase
proc setClassConstructor*(cls:UClassPtr, classConstructor:UClassConstructor) : void {.importcpp:"UReflectionHelpers::SetClassConstructor(@)".}
# proc prepareNimClass*(cls:UNimClassBasePtr) : void {.importcpp:"#->PrepareNimClass()".}
proc constructFromVTable*(clsVTableHelperCtor:VTableConstructor) : UObjectPtr {.importcpp:"UReflectionHelpers::ConstructFromVTable(@)".}


# proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:openarray[pointer]) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc invoke*(functionCaller: UFunctionCaller, executor:ptr UObject, returnResult:pointer) : void {.importcpp: "#.Invoke(@)".}

proc callUFuncOn*(executor:UObjectPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}
proc callUFuncOn*(class:UClassPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOnClass(@)".}



proc UE_LogInternal(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUELog(@)".}
proc UE_WarnInternal(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUEWarn(@)".}
proc UE_ErrorInteral(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUEError(@)".}


template UE_Log*(msg: FString): untyped =
  let pos = instantiationInfo()
  let meta = "[$1:$2]: " % [pos.filename, $pos.line]
  UE_LogInternal(meta & msg)


template UE_Warn*(msg: FString): untyped =
  let pos = instantiationInfo()
  let meta = "[$1:$2]: " % [pos.filename, $pos.line]
  UE_WarnInternal(meta & msg)


template UE_Error*(msg: FString): untyped =
  let pos = instantiationInfo()
  let meta = "[$1:$2]: " % [pos.filename, $pos.line]
  UE_ErrorInteral(meta & msg)



proc getPropertyValuePtr*[T](property:FPropertyPtr, container : pointer) : ptr T {.importcpp: "GetPropertyValuePtr<'*0>(@)", header:"UPropertyCaller.h".}
proc setPropertyValuePtr*[T](property:FPropertyPtr, container : pointer, value : ptr T) : void {.importcpp: "SetPropertyValuePtr<'*3>(@)", header:"UPropertyCaller.h".}
proc setPropertyValue*[T](property:FPropertyPtr, container : pointer, value : T) : void {.importcpp: "SetPropertyValue<'3>(@)", header:"UPropertyCaller.h".}


proc getValueFromBoolProp*(prop:FPropertyPtr, obj:UObjectPtr): bool {.inline.} =
  castField[FBoolProperty](prop).getPropertyValue(prop.containerPtrToValuePtr(obj))
proc setValueInBoolProp*(prop:FPropertyPtr, obj:UObjectPtr, val: bool) {.inline.} =
  castField[FBoolProperty](prop).setPropertyValue(prop.containerPtrToValuePtr(obj), val)



proc containsStrongReference*(prop:FPropertyPtr) : bool {.importcpp:"UReflectionHelpers::ContainsStrongReference(@)".}

# static TNativeType& StepCompiledInRef(FFrame* Frame, void*const TemporaryBuffer, TProperty* Ignore) {

proc stepCompiledInRef*[T, TProperty ](stack:ptr FFrame, tempBuffer:pointer, ignore:ptr FProperty) : var T {. importcpp: "UReflectionHelpers::StepCompiledInRef<'*3, '*0>(@)" .}


type 
    FNimTestBase* {.importcpp, inheritable, pure.} = object
        ActualTest* : proc (test:var FNimTestBase) : void {.cdecl.}


proc makeFNimTestBase*(testName:FString): FNimTestBase {.importcpp:"FNimTestBase(#)", constructor.}
proc reloadTest*(test:FNimTestBase, isOnly:bool):void {.importcpp:"#.ReloadTest(@)".}
proc testTrue*(test:FNimTestBase, msg:FString, value:bool):void {.importcpp:"#.TestTrue(@)".}


#TODO This should throw if the property is not found!
proc getFPropertyByName*(struct:UStructPtr, propName:FString) : FPropertyPtr {.importcpp: "UReflectionHelpers::GetFPropetyByName(@)"}
proc getFPropertiesFrom*(struct:UStructPtr) : TArray[FPropertyPtr] {.importcpp: "UReflectionHelpers::GetFPropertiesFrom(@)"}

proc getUTypeByName*[T :UObject](typeName:FString) : ptr T {.importcpp:"UReflectionHelpers::GetUTypeByName<'*0>(@)".}
proc tryGetUTypeByName*[T :UObject](typeName:FString) : Option[ptr T] = someNil getUTypeByName[T](typeName)

proc getAllClassesFromModule*(moduleName:FString) : TArray[UClassPtr] {.importcpp:"UReflectionHelpers::GetAllClassesFromModule(@)" .}

#nil here and in newUObject is equivalent to GetTransient() (like ue does). Once GetTrasientPackage is bind, use that instead since 
#it's better design
proc newObjectFromClass*(owner:UObjectPtr, cls:UClassPtr, name:FName) : UObjectPtr {.importcpp:"UReflectionHelpers::NewObjectFromClass(@)".}
proc newObjectFromClass*(cls:UClassPtr) : UObjectPtr = newObjectFromClass(nil, cls, ENone)
proc newObjectFromClass(params:FStaticConstructObjectParameters) : UObjectPtr {.importcpp:"UReflectionHelpers::NewObjectFromClass(@)".}


 
proc getAllModuleDepsForPlugin*(pluginName:FString) : TArray[FString] {.importcpp:"UReflectionHelpers::GetAllModuleDepsForPlugin(@)".}


#TODO This can be (and should be optmized in multiple ways. 
#1. Define package when possible, 
#2. Do not pass copy of FStrings around.
#3. Cache
proc getClassByName*(className:FString) : UClassPtr {.exportcpp.} = getUTypeByName[UClass](className)
proc tryGetClassByName*(className:FString) : Option[UClassPtr] = someNil(getClassByName(className))

proc getScriptStructByName*(structName:FString) : UScriptStructPtr = getUTypeByName[UScriptStruct](structName)
proc getUStructByName*(structName:FString) : UStructPtr = getUTypeByName[UStruct](structName)

proc newUObject*[T:UObject](owner:UObjectPtr, name:FName) : ptr T = 
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)
    return cast[ptr T](newObjectFromClass(owner, cls, name)) 

proc newUObject*[T:UObject](owner:UObjectPtr) : ptr T = newUObject[T](owner, ENone)
proc newUObject*[T:UObject]() : ptr T = newUObject[T](nil, ENone)
proc newUObject*[T:UObject](outer:UObjectPtr, name:FName, flags: EObjectFlags) : ptr T = 
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)

    var params = makeFStaticConstructObjectParameters(cls)
    params.Outer = outer
    params.Name = name
    params.SetFlags = flags
    cast[ptr T](newObjectFromClass(params))

proc newUObject*[T:UObject](outer:UObjectPtr, subcls : TSubClassOf[T]) : ptr T = 
    let cls = subcls.get()
    var params = makeFStaticConstructObjectParameters(cls)
    params.Outer = outer
    cast[ptr T](newObjectFromClass(params))




proc toClass*[T : UObject ](val: TSubclassOf[T]): UClassPtr =
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)
    return cls

proc staticClass*[T:UObject]() : UClassPtr = 
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className) #TODO stop doing this and use fname instead
    return cls
proc staticClass*(T:typedesc) : UClassPtr = staticClass[T]()
proc isChildOf*(str:UStructPtr, someBase:UStructPtr) : bool {.importcpp:"#->IsChildOf(@)".}


proc isChildOf*[T:UObject](cls: UClassPtr) : bool =
    let someBase = staticClass[T]()
    isChildOf(cls, someBase)

proc isChildOf*[C:UStruct, P:UStruct] : bool = isChildOf(staticClass[C](), staticClass[P]())
proc staticSubclass*[T]() : TSubclassOf[T] = makeTSubClassOf[T](staticClass[T]())
proc staticSubclass*(T:typedesc) : TSubclassOf[T] = makeTSubClassOf[T](staticClass[T]())

proc getDefaultObject*[T:UObject]() : ptr T =
    let cls = staticClass[T]()
    ueCast[T](cls.getDefaultObject())

proc createDefaultSubobject*[T:UObject](initializer:var FObjectInitializer, name:FName) : ptr T = 
    let cls = staticClass[T]()
    let subObj = initializer.createDefaultSubobject(initializer.getObj(), name, cls, cls, true, false)
    ueCast[T](subObj)

proc addClassFlag*(cls:UClassPtr, flag:EClassFlags) : void {.importcpp:"UReflectionHelpers::AddClassFlag(@)".}    
proc addScriptStructFlag*(cls:UScriptStructPtr, flag:EStructFlags) : void {.importcpp:"UReflectionHelpers::AddScriptStructFlag(@)".}    
    
proc makeFNativeFuncPtr*(fun:proc (context:ptr UObject, stack:var FFrame,  result: pointer):void {. cdecl .}) : FNativeFuncPtr {.importcpp: "UReflectionHelpers::MakeFNativeFuncPtr(@)" .}

proc setNativeFunc*(ufunc: ptr UFunction, funcPtr: FNativeFuncPtr) : void {.importcpp: "#->SetNativeFunc(#)" .}

proc increaseStack*(stack: var FFrame) : void {.importcpp: "UReflectionHelpers::IncreaseStack(#)" .}
proc stepCompiledIn*[T : FProperty](frame:var FFrame, result:pointer, prop:ptr T) : void {.importcpp:"UReflectionHelpers::StepCompiledIn<'*3>(@)".}

 
#UPACKAGE
func getAllObjectsFromPackage*[T](package:UPackagePtr) : TArray[ptr T] {.importcpp:"UReflectionHelpers::GetAllObjectsFromPackage<'**0>(@)".}
proc createNimPackage*(packageShortName:FString) : UPackagePtr {.importcpp:"UReflectionHelpers::CreateNimPackage(@)".}

##EDITOR
proc broadcastAsset*(asset:UObjectPtr) : void {.importcpp: "UFakeFactory::BroadcastAsset(#)" .}

type
    FNimHotReload* {.importcpp, inheritable, pure.} = object
        structsToReinstance* {.importcpp: "StructsToReinstance" .} : TMap[UScriptStructPtr, UScriptStructPtr]
        classesToReinstance* {.importcpp: "ClassesToReinstance" .} : TMap[UClassPtr, UClassPtr]
        delegatesToReinstance* {.importcpp: "DelegatesToReinstance" .} : TMap[UDelegateFunctionPtr, UDelegateFunctionPtr]
        enumsToReinstance* {.importcpp: "EnumsToReinstance" .} : TMap[UEnumPtr, UEnumPtr]
        nativeFunctionsToReinstance* {.importcpp: "NativeFunctionsToReinstance" .} : TArray[TPair[FNativeFuncPtr, FNativeFuncPtr]]
        newStructs* {.importcpp: "NewStructs" .} : TArray[UScriptStructPtr]
        newClasses* {.importcpp: "NewClasses" .} : TArray[UClassPtr]
        newDelegatesFunctions* {.importcpp: "NewDelegateFunctions" .} : TArray[UDelegateFunctionPtr]
        newEnums* {.importcpp: "NewEnums" .} : TArray[UEnumPtr]
        deletedStructs* {.importcpp: "DeletedStructs" .} : TArray[UScriptStructPtr]
        deletedClasses* {.importcpp: "DeletedClasses" .} : TArray[UClassPtr]
        deletedDelegatesFunctions* {.importcpp: "DeletedDelegateFunctions" .} : TArray[UDelegateFunctionPtr]
        deletedEnums* {.importcpp: "DeletedEnums" .} : TArray[UEnumPtr]

        bShouldHotReload* {.importcpp: "bShouldHotReload" .} : bool
    FNimHotReloadPtr* = ptr FNimHotReload

proc getNumber*(hotReloadInfo: ptr FNimHotReload) : int {.importcpp: "#->GetNumber()".}

proc newNimHotReload*() : FNimHotReloadPtr {.importcpp: "new '*0()".}
proc setShouldHotReload*(hotReloadInfo: ptr FNimHotReload) = 
    hotReloadInfo.bShouldHotReload = 
        hotReloadInfo.classesToReinstance.keys().len() +
        hotReloadInfo.structsToReinstance.keys().len() +
        hotReloadInfo.enumsToReinstance.keys().len() +
        hotReloadInfo.delegatesToReinstance.keys().len() > 0

proc `$`(cls:UClassPtr) : string = cls.getName()

proc `$`*(hr:FNimHotReloadPtr) : string = 
    &"""
        StructsToReinstance: {hr.structsToReinstance}  
        ClassesToReinstance: {hr.classesToReinstance} 
        DelegatesToReinstance: {hr.delegatesToReinstance} 
        EnumsToReinstance: {hr.enumsToReinstance} 
        NewStructs: {hr.newStructs} 
        NewClasses: {hr.newClasses} 
        NewDelegateFunctions: {hr.newDelegatesFunctions} 
        NewEnums: {hr.newEnums} 
        DeletedStructs: {hr.deletedStructs} 
        DeletedClasses: {hr.deletedClasses} 
        DeletedDelegateFunctions: {hr.deletedDelegatesFunctions} 
        DeletedEnums: {hr.deletedEnums} 
        bShouldHotReload: {hr.bShouldHotReload} 
    
    """





proc executeTaskInTaskGraph*[T](param: T, taskFn: proc(param:T){.cdecl.}) {.importcpp: "UReflectionHelpers::ExecuteTaskInTaskGraph<'1>(#, #)".}

#static int ExecuteCmd(FString& Cmd, FString& Args, FString& WorkingDir, FString& StdOut, FString& StdError);
proc executeCmd*(cmd, args, workingDir, stdOut, stdError: var FString) : int {.importcpp: "UReflectionHelpers::ExecuteCmd(@)".}

#ReinstanceNueTypes(FString NueModule, FNimHotReload* NimHotReload, FString NimError);
proc reinstanceNueTypes*(nueModule:FString, nimHotReload:FNimHotReloadPtr, nimError:FString) : void {.importcpp: "ReinstanceBindings::ReinstanceNueTypes(@)".}
include ../definitions
import ../coreuobject/[uobject, uobjectglobals, package, unrealtype, templates/subclassof, nametypes, uobjectglobals]
import ../core/containers/[unrealstring, array, map]
import std/[typetraits, strutils]


type 
    UFunctionCaller* {.importc, inheritable, pure .} = object
    FNativeFuncPtr* {.importcpp.} = object
    
    UNimClassBase* {.importcpp, inheritable, pure .} = object of UClass
    UNimClassBasePtr* = ptr UNimClassBase

    UNimScriptStruct* {.importcpp.} = object of UScriptStruct
    UNimScriptStructPtr* = ptr UNimScriptStruct

    UNimEnum* {.importcpp.} = object of UEnum
    UNimEnumPtr* = ptr UNimEnum

    UNimFunction* {.importcpp.} = object of UFunction
        sourceHash* {.importcpp: "SourceHash".} : FString
    UNimFunctionPtr* = ptr UNimFunction


proc setCppStructOpFor*[T](scriptStruct:UNimScriptStructPtr, fakeType:ptr T) : void {.importcpp:"#->SetCppStructOpFor<'*2>(#)".}




#UNimEnum
func getEnums*(uenum:UNimEnumPtr) : TArray[TPair[FName, int64]] {.importcpp:"#->GetEnums()".}
proc markNewVersionExists*(uenum:UNimEnumPtr) : void {.importcpp:"#->MarkNewVersionExists()".}

# proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:openarray[pointer]) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc makeFunctionCaller*(class : UClassPtr, functionName:var FString, InParams:pointer) : UFunctionCaller {.importcpp: "UFunctionCaller(@)".}
proc invoke*(functionCaller: UFunctionCaller, executor:ptr UObject, returnResult:pointer) : void {.importcpp: "#.Invoke(@)".}

proc callUFuncOn*(executor:UObjectPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}
proc callUFuncOn*(class:UClassPtr, funcName : var FString, InParams : pointer) : void {.importcpp: "UFunctionCaller::CallUFunctionOn(@)".}



proc UE_Log*(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUELog(@)".}
proc UE_Warn*(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUEWarn(@)".}
proc UE_Error*(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUEError(@)".}


proc getPropertyValuePtr*[T](property:FPropertyPtr, container : pointer) : ptr T {.importcpp: "GetPropertyValuePtr<'*0>(@)", header:"UPropertyCaller.h".}
proc setPropertyValuePtr*[T](property:FPropertyPtr, container : pointer, value : ptr T) : void {.importcpp: "SetPropertyValuePtr<'*3>(@)", header:"UPropertyCaller.h".}
proc setPropertyValue*[T](property:FPropertyPtr, container : pointer, value : T) : void {.importcpp: "SetPropertyValue<'3>(@)", header:"UPropertyCaller.h".}

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

proc getUTypeByName*[T :UField](typeName:FString) : ptr T {.importcpp:"UReflectionHelpers::GetUTypeByName<'*0>(@)".}

proc getAllClassesFromModule*(moduleName:FString) : TArray[UClassPtr] {.importcpp:"UReflectionHelpers::GetAllClassesFromModule(@)" .}

proc getAllObjectsFromPackage*[T](package:UPackagePtr) : TArray[ptr T] {.importcpp:"UReflectionHelpers::GetAllObjectsFromPackage<'**0>(@)".}
#nil here and in newUObject is equivalent to GetTransient() (like ue does). Once GetTrasientPackage is bind, use that instead since 
#it's better design
proc newObjectFromClass*(owner:UObjectPtr, cls:UClassPtr, name:FName) : UObjectPtr {.importcpp:"UReflectionHelpers::NewObjectFromClass(@)".}
proc newObjectFromClass*(cls:UClassPtr) : UObjectPtr = newObjectFromClass(nil, cls, ENone)
proc newObjectFromClass(params:FStaticConstructObjectParameters) : UObjectPtr {.importcpp:"UReflectionHelpers::NewObjectFromClass(@)".}


#TODO This can be (and should be optmized in multiple ways. 
#1. Define package when possible, 
#2. Do not pass copy of FStrings around.
#3. Cache
proc getClassByName*(className:FString) : UClassPtr = getUTypeByName[UClass](className)

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




proc toClass*[T : UObject ](val: TSubclassOf[T]): UClassPtr =
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)
    return cls

proc addClassFlag*(cls:UClassPtr, flag:EClassFlags) : void {.importcpp:"UReflectionHelpers::AddClassFlag(@)".}    
proc addScriptStructFlag*(cls:UScriptStructPtr, flag:EStructFlags) : void {.importcpp:"UReflectionHelpers::AddScriptStructFlag(@)".}    
    
proc makeFNativeFuncPtr*(fun:proc (context:ptr UObject, stack:var FFrame,  result: pointer):void {. cdecl .}) : FNativeFuncPtr {.importcpp: "UReflectionHelpers::MakeFNativeFuncPtr(@)" .}

proc setNativeFunc*(ufunc: ptr UFunction, funcPtr: FNativeFuncPtr) : void {.importcpp: "#->SetNativeFunc(#)" .}

proc increaseStack*(stack: var FFrame) : void {.importcpp: "UReflectionHelpers::IncreaseStack(#)" .}
proc stepCompiledIn*[T : FProperty](frame:var FFrame, result:pointer, prop:ptr T) : void {.importcpp:"UReflectionHelpers::StepCompiledIn<'*3>(@)".}

 
 
#UPACKAGE
func getPackageByName*(packageName:FString) : UPackagePtr = 
        findObject[UPackage](nil, convertToLongScriptPackageName(packageName))
let nimPackage* = getPackageByName("Nim")

##EDITOR
proc broadcastAsset*(asset:UObjectPtr) : void {.importcpp: "UFakeFactory::BroadcastAsset(#)" .}

type
    FNimHotReload* {.importcpp.} = object
        structsToReinstance* {.importcpp: "StructsToReinstance" .} : TMap[UScriptStructPtr, UScriptStructPtr]
        classesToReinstance* {.importcpp: "ClassesToReinstance" .} : TMap[UClassPtr, UClassPtr]
        delegatesToReinstance* {.importcpp: "DelegatesToReinstance" .} : TMap[UDelegateFunctionPtr, UDelegateFunctionPtr]
        enumsToReinstance* {.importcpp: "EnumsToReinstance" .} : TMap[UEnumPtr, UEnumPtr]
        nativeFunctionsToReinstance* {.importcpp: "NativeFunctionsToReinstance" .} : TArray[TPair[FNativeFuncPtr, FNativeFuncPtr]]
        bShouldHotReload* {.importcpp: "bShouldHotReload" .} : bool
    FNimHotReloadPtr* = ptr FNimHotReload

proc newNimHotReload*() : FNimHotReloadPtr {.importcpp: "new '*0()".}
proc setShouldHotReload*(hotReloadInfo: ptr FNimHotReload) = 
    hotReloadInfo.bShouldHotReload = 
        hotReloadInfo.classesToReinstance.keys().len() +
        hotReloadInfo.structsToReinstance.keys().len() +
        hotReloadInfo.enumsToReinstance.keys().len() +
        hotReloadInfo.delegatesToReinstance.keys().len() > 0



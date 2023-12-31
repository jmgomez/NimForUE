include ../definitions
import ../coreuobject/[uobject, uobjectglobals, package, unrealtype, nametypes]
import ../core/containers/[unrealstring, array, map]
import std/[typetraits, strutils, options, strformat, sequtils, sugar, tables]
import ../../codegen/[models]
import ../../utils/[utils, ueutils]
import bindingdeps

type 
    FNativeFuncPtr* {.importcpp.} = object #recreate in Nim
    UNimScriptStruct* {.importcpp.} = object of UScriptStruct #HARD: recreate in Nim (the last one)
    UNimScriptStructPtr* = ptr UNimScriptStruct

#Manual uClasses (copied from generating one with the macro. The metadata is in emitter)
const clsTemplate = "struct $1 : public $3 {\n  \n  $1(FVTableHelper& Helper) : $3(Helper) {}\n  $2  \n};\n"
type
  #Notice you cant export types here or they will collide with the ones in the headers when linking the bindings.
  UNimFunction* {.inheritable, codegenDecl: clsTemplate .} = object of UFunction
    sourceHash*: FString
  UNimFunctionPtr* = ptr UNimFunction
  UNimEnum* {.inheritable, codegenDecl: clsTemplate .} = object of UEnum #recreate in Nim
  UNimEnumPtr* = ptr UNimEnum

proc makeNimEnum*(init: var FObjectInitializer): UNimEnum {.constructor:"UNimEnum(const '1 #1) : UEnum(#1)".} = discard
#HACK ahead, this probably would crash at runtime if called. TODO add suport for noDecl in the compiler
when (NimMajor, NimMinor) <= (2, 0):    
  proc makeNimEnum*(): UNimEnum {.constructor: "UNimEnum() : UEnum(*(new FObjectInitializer()))".} = discard
else:
  proc makeNimEnum*(): UNimEnum {.constructor, nodecl .} = discard

proc makeNimFunction*(): UNimFunction {.constructor.} = discard
#UNimEnum
proc markNewVersionExistsInternal(uenum:UNimEnumPtr) : void {.importcpp:"#->SetEnumFlags(EEnumFlags::NewerVersionExists)".}
proc markNewVersionExists*(uenum:UNimEnumPtr) {.member.} = uenum.markNewVersionExistsInternal()

proc setCppStructOpFor*[T](scriptStruct:UNimScriptStructPtr, fakeType:ptr T) : void {.importcpp:"#->SetCppStructOpFor<'*2>(#)".}

func getEnums*(uenum:UEnumPtr) : TArray[FString] = 
  let values = uenum.numEnums()
  result = makeTArray[FString]()
  for i in 0 ..< values:
    result.add uenum.getNameStringByIndex(i)

#UNimClassBase
proc setClassConstructor*(cls:UClassPtr, classConstructor:UClassConstructor) : void {.importcpp:"(#->ClassConstructor = reinterpret_cast<void(*)(const FObjectInitializer&)>(#))".}
proc constructFromVTable*(clsVTableHelperCtor:VTableConstructor) : UObjectPtr {.importcpp:"UReflectionHelpers::ConstructFromVTable(@)".}
# proc constructFromVTable*(clsVTableHelperCtor: VTableConstructor) : UObjectPtr = 
#   var clsVTableHelperCtor {.exportc.} = clsVTableHelperCtor
#   #we emit here so we dont bind unnecesary functions
#   {.emit:"""
#     {
#       TGuardValue<bool> Guard(GIsRetrievingVTablePtr, true);

#       // Mark we're in the constructor now.
#       FUObjectThreadContext& ThreadContext = FUObjectThreadContext::Get();
#       TScopeCounter<int32> InConstructor(ThreadContext.IsInConstructor);

#       FVTableHelper Helper;
#       result = clsVTableHelperCtor(Helper);
#       result->AtomicallyClearInternalFlags(EInternalObjectFlags::PendingConstruction);
#     }

#     if( !result->IsRooted() ) {
#       result->MarkAsGarbage();
#     }
#     return result;
#   """.}




proc getFPropertiesFrom*(struct:UStructPtr) : TArray[FPropertyPtr] = 
  var xs : TArray[FPropertyPtr]
  var fieldIterator = makeTFieldIterator[FProperty](struct, IncludeSuper)
  for it in fieldIterator: 
    xs.add it.get() 
  xs


proc getAllClassesFromModule*(moduleName:FString) : TArray[UClassPtr] {.importcpp:"UReflectionHelpers::GetAllClassesFromModule(@)" .}

#nil here and in newUObject is equivalent to GetTransient() (like ue does). Once GetTrasientPackage is bind, use that instead since 
#it's better design
proc staticConstructObject_Internal(params:FStaticConstructObjectParameters): UObjectPtr {.importcpp:"StaticConstructObject_Internal(#)".}
proc newObjectFromClass*(owner:UObjectPtr, cls:UClassPtr, name:FName) : UObjectPtr = 
  var params = makeFStaticConstructObjectParameters(cls)
  params.outer = if owner.isNil(): getTransientPackage() else: owner
  params.name = name
  params.setFlags = RF_NoFlags
  staticConstructObject_Internal(params)

proc newObjectFromClass*(cls:UClassPtr) : UObjectPtr = newObjectFromClass(nil, cls, ENone)
proc newObjectFromClass(params:FStaticConstructObjectParameters): UObjectPtr = staticConstructObject_Internal(params)



 
proc getAllModuleDepsForPlugin*(pluginName:FString) : TArray[FString] {.importcpp:"UReflectionHelpers::GetAllModuleDepsForPlugin(@)".}


#TODO This can be (and should be optmized in multiple ways. 
#1. Define package when possible, 
#2. Do not pass copy of FStrings around.
#3. Cache
proc tryGetClassByName*(className:FString) : Option[UClassPtr] = someNil(getClassByName(className))

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
    params.outer = outer
    params.name = name
    params.setFlags = flags
    cast[ptr T](newObjectFromClass(params))

proc newUObject*[T:UObject](outer:UObjectPtr, subcls : TSubClassOf[T]) : ptr T = 
    let cls = subcls.get()
    var params = makeFStaticConstructObjectParameters(cls)
    params.outer = outer
    cast[ptr T](newObjectFromClass(params))





proc toClass*[T : UObject ](val: TSubclassOf[T]): UClassPtr =
    let className : FString = typeof(T).name.substr(1) #Removes the prefix of the class name (i.e U, A etc.)
    let cls = getClassByName(className)
    return cls


proc staticSubclass*[T]() : TSubclassOf[T] = makeTSubClassOf[T](staticClass[T]())
proc staticSubclass*(T:typedesc) : TSubclassOf[T] = makeTSubClassOf[T](staticClass[T]())
proc Subclass*[T : typedesc](t:T) : TSubclassOf[t] = makeTSubClassOf[t](staticClass[t]())


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
proc getNativeFunc*(ufunc: UFunctionPtr) : pointer {.importcpp: "#->GetNativeFunc()" .} #TODO FNativeFuncPtr is wrongly bound

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

# proc getNumber*(hotReloadInfo: ptr FNimHotReload) : int {.importcpp: "#->GetNumber()".}

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


proc executeTaskInTaskGraph*[T](param: T, taskFn: proc(param:T){.cdecl.}, nimMain:proc(){.cdecl.}) {.importcpp: "UReflectionHelpers::ExecuteTaskInTaskGraph<'1>(#, #)".}
#[
    The task to run in another thread
    The callback when it completes in the mainthread
]#
proc executeTaskInBackgroundThread*(taskFn: proc(){.cdecl.}, callback: proc(){.cdecl.}) {.importcpp: "UReflectionHelpers::ExecuteTaskInBackgroundThread(@)".}

#static int ExecuteCmd(FString& Cmd, FString& Args, FString& WorkingDir, FString& StdOut, FString& StdError);
proc executeCmd*(cmd, args, workingDir, stdOut, stdError: var FString) : int {.importcpp: "UReflectionHelpers::ExecuteCmd(@)".}

#ReinstanceNueTypes(FString NueModule, FNimHotReload* NimHotReload, FString NimError);
proc reinstanceNueTypes*(nueModule:FString, nimHotReload:FNimHotReloadPtr, nimError:FString, reuseHotReload:bool) : void {.importcpp: "ReinstanceBindings::ReinstanceNueTypes(@)".}



#This file contains logic on top of ue types that it isnt necessarily bind 



func isNimClass*(cls:UClassPtr) : bool = cls.hasMetadata(NimClassMetadataKey)

proc markAsNimClass*(cls:UClassPtr) = cls.setMetadata(NimClassMetadataKey, "true")

#not sure if I should make a specific file for object extensions that are outside of the bindings


proc removeFunctionFromClass*(cls:UClassPtr, fn:UFunctionPtr) =
    cls.removeFunctionFromFunctionMap(fn)
    cls.Children = fn.Next 

proc getFPropsFromUStruct*(ustr:UStructPtr, flags=EFieldIterationFlags.None) : seq[FPropertyPtr] = 
    var xs : seq[FPropertyPtr] = @[]
    var fieldIterator = makeTFieldIterator[FProperty](ustr, flags)
    for it in fieldIterator:
        let prop = it.get()
        xs.add prop
    xs
#This should be an iterator    
proc getFuncsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[UFunctionPtr] = 
    var xs : seq[UFunctionPtr] = @[]
    var fieldIterator = makeTFieldIterator[UFunction](cls, flags)
    for it in fieldIterator:
        let fn = it.get()
        xs.add fn
    xs


proc getFuncsParamsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[FPropertyPtr] = 
    cls 
    .getFuncsFromClass(flags)
    .mapIt(it.getFPropsFromUStruct(flags))
    .foldl(a & b, newSeq[FPropertyPtr]())

proc findFunctionByNameIncludingSuper*(cls : UClassPtr, name:FName) : UFunctionPtr = 
  cls.getFuncsFromClass(EFieldIterationFlags.IncludeSuper)
    .filterIt(it.getFName() == name)
    .head()
    .get(nil)
#bound directly so we dont have to compile this with the bindings
# func findFuncByName*(cls : UClassPtr, name:FName) : UFunctionPtr = 
#   cls.getFuncsFromClass()
#     .filterIt(it.getFName() == name)
#     .head()
#     .get(nil)

proc getAllPropsOf*[T : FProperty](ustr:UStructPtr) : seq[ptr T] = 
    ustr.getFPropsFromUStruct()
        .filterIt(castField[T](it).isNotNil())
        .mapIt(castField[T](it))

   
proc getAllPropsWithMetaData*[T : FProperty](ustr:UStructPtr, metadataKey:string) : seq[ptr T] = 
    ustr.getAllPropsOf[:T]()
        .filterIt(it.hasMetaData(metadataKey))

func getModuleRelativePath*(str:UStructPtr) : Option[string] = 
  str
    .getAllPropsWithMetaData[:FProperty]("ModuleRelativePath")
    .head()
    .flatMap((p:FPropertyPtr) => p.getMetaData("ModuleRelativePath").map(m => $m))
  

#it will call super until UObject is reached
iterator getClassHierarchy*(cls:UClassPtr) : UClassPtr = 
    var super = cls
    let uObjCls = staticClass[UObject]()
    while super != uObjCls:
        super = super.getSuperClass()
        yield super

func isBPClass*(cls:UClassPtr) : bool =    
    result = (CLASS_CompiledFromBlueprint.uint32 and cls.classFlags.uint32) != 0
    # UE_Warn &"isBpClass called for {cls.getName() } and result is {result}"
    

func getFirstCppClass*(cls:UClassPtr) : UClassPtr =
    for super in getClassHierarchy(cls):
        if super.isNimClass() or super.isBPClass():
            continue
        return super

proc getPropsWithFlags*(fn:UFunctionPtr, flag:EPropertyFlags) : TArray[FPropertyPtr] = 
    let isIn = (p:FPropertyPtr) => flag in p.getPropertyFlags()
    getFPropertiesFrom(fn).filter(isIn)

proc isOutParam*(prop:FPropertyPtr) : bool = CPF_OutParm in prop.getPropertyFlags()


proc callStaticUFunction*(clsName, fnName: string, args:pointer): bool = 
  #dynamically calls a ufunction
  #args is Params. See exported for an example  
  let fnName = n fnName
  let self {.inject.} = getDefaultObjectFromClassName(clsName)
  if self.isNil():
     false
  else:
    let fn {.inject, used.} = ueCast[UObject](self).getClass().findFuncByName(fnName)
    if fn.isNil():
      false
    else:
      self.processEvent(fn, args)
      true



#this shouldnt be needed when having out in TArray
func asUObjectArray*[T : UObject](arr:TArray[ptr T]): TArray[UObjectPtr] = 
  var xs = makeTArray[UObjectPtr]()
  for x in arr:
    xs.add x
  xs


#Probably these should be repr

func `$`*(prop:FPropertyPtr):string= 

  if prop.isNil(): 
    return "nil"
  let meta = prop.getMetadataMap()
  &"Prop: {prop.getName()} CppType: {prop.getCppType()} Offset: {prop.getOffset()} Flags: {prop.getPropertyFlags()} Metadata: {meta}"


    

func `$`*(fn:UFunctionPtr):string = 
  if fn.isNil(): 
    return "nil"
  
  let metadataMap = fn.getMetadataMap()
  if metadataMap.len() > 0:
    metadataMap.remove(n"Comment")
    metadataMap.remove(n"ToolTip")
  let params = getFPropsFromUStruct(fn).mapIt($it).join("\n\t")
    #PROPS?
  &"""Func: {fn.getName()} Class: {fn.getOuter()} Flags: {fn.functionFlags} Metadata: {metadataMap}
  
  Params: 
    {params}
  """


proc isA[T:FProperty](prop:FPropertyPtr) : bool = tryCastField[T](prop).isSome()
proc asA[T:FProperty](prop:FPropertyPtr) : ptr T = castField[T](prop)
# when WithEditor:
  
proc `$`*(str:UScriptStructPtr) : string = 
  # "hola"
  result = &"ScriptStruct: {str.getName()} \n\t Parent: \n\t Module:{str.getPackage().getModuleName()} \n\t Package:{str.getPackage().getName()} \n\t Struct Flags: {str.structFlags} \n\t Object Flags: {str.getFlags}"
  # result = &"{str} \n\t Metas:"
  # let metas = str.getMetadataMap().toTable()
  # for key, value in metas:
  #   result = &"{str}\n\t\t {key} : {value}"

  # result = &"{str} \n\t Props:"
  # for p in str.getFPropsFromUStruct():
  #   result = &"{str}\n\t\t {p}"
  

proc dump*(cls:UClassPtr) : string = 
  var str = &"Class: {cls.getName()} \n\t Parent: {cls.getSuperClass().getName()}\n\t Module:{cls.getPackage().getModuleName()} \n\t Package:{cls.getPackage().getName()} \n\t Class Flags: {cls.classFlags} \n\t Object Flags: {cls.getFlags}"
  # str = &"{str} \n\t Interfaces:"
  # for i in cls.interfaces:
  #   str = &"{str}\n\t\t {i}"
  # str = &"{str} \n\t Metas:"
  # let metas = cls.getMetadataMap().toTable()
  # for key, value in metas:
  #   str = &"{str}\n\t\t {key} : {value}"

  str = &"{str} \n\t Props:"
  for p in cls.getFPropsFromUStruct():
    str = &"{str}\n\t\t {p}"
    
  str = &"{str} \n\t Funcs:"
  let funcs = cls.getFuncsFromClass()
  for f in funcs:
    str = &"{str}\n\t\t {f}"
  str

proc `$`*(obj:UObjectPtr) : string = 
  if obj.isNil(): return "nil"
  # UE_Warn getStackTrace()
  obj.getName()
  
proc repr*(obj:UObjectPtr) : string = 
    if obj.isNil(): return "nil"
    var str = &"\n {obj.getName()}:\n\t"
    let props = obj.getClass().getFPropsFromUStruct(IncludeSuper)
    for p in props:
        #Only UObjects vals for now:
        
        if p.isA[:FObjectPtrProperty]():
            let valPtr = someNil getPropertyValuePtr[UObjectPtr](p, obj)
            let val = valPtr.map(p=>tryUECast[UObject](p[])).flatten()
            if val.isSome():
                str = str & &"{p.getName()}: \n\t {val.get().getName()}\n\t"
        elif p.isA[:FBoolProperty]():
            let val = getValueFromBoolProp(p, obj)
            str = str & &"{p.getName()}: {val}\n\t"
        elif p.isA[:FStrProperty]():
            let val = getPropertyValuePtr[FString](p, obj)[]
            str = str & &"{p.getName()}: {val}\n\t"
        elif p.isA[:FNameProperty]():
            let val = getPropertyValuePtr[FName](p, obj)[]
            str = str & &"{p.getName()}: {val}\n\t"
        elif p.isA[:FClassProperty]():
            let val = getPropertyValuePtr[UClassPtr](p, obj)[]
            str = str & &"{p.getName()}: {val.getName()}\n\t"
        # elif p.isA[FUinProperty]():
    str

func makeUEMetadata*(name:FName, value:FString) : UEMetadata = 
    makeUEMetadata($n, value)
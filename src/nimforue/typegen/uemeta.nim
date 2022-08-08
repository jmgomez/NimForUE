include ../unreal/prelude
import std/[times,strformat,tables, strutils, options, sugar, algorithm, sequtils, hashes]
import fproperty
import models
export models


const fnPrefixes = @["", "Receive", "K2_"]


#UE META CONSTRUCTORS. Noticuee they are here because they pull type definitions from Cpp which cant be loaded in the ScriptVM
func makeFieldAsUProp*(name, uPropType: string, flags=CPF_None, metas:seq[UEMetadata] = @[]) : UEField = 
    UEField(kind:uefProp, name: name, uePropType: uPropType, propFlags:EPropertyFlagsVal(flags), metadata:metas)       

func makeFieldAsUPropMulDel*(name, uPropType: string, flags=CPF_None, metas:seq[UEMetadata] = @[]) : UEField = 
    UEField(kind:uefProp, name: name, uePropType: uPropType, propFlags:EPropertyFlagsVal(flags), metadata: @[makeUEMetadata(MulticastDelegateMetadataKey)]&metas)       

func makeFieldAsUPropDel*(name, uPropType: string, flags=CPF_None, metas:seq[UEMetadata] = @[]) : UEField = 
    UEField(kind:uefProp, name: name, uePropType: uPropType, propFlags:EPropertyFlagsVal(flags), metadata: @[makeUEMetadata(DelegateMetadataKey)]&metas)       


func makeFieldAsUFun*(name:string, signature:seq[UEField], className:string, flags=FUNC_None, metadata: seq[UEMetadata] = @[]) : UEField = 
    UEField(kind:uefFunction, name:name, signature:signature, className:className, fnFlags:EFunctionFlagsVal(flags), metadata:metadata)

func makeFieldAsUPropParam*(name, uPropType: string, flags=CPF_Parm) : UEField = 
    UEField(kind:uefProp, name: name, uePropType: uPropType, propFlags:EPropertyFlagsVal(flags))       

func makeFieldASUEnum*(name:string) :UEField = UEField(name:name, kind:uefEnumVal)

func makeUEClass*(name, parent:string, clsFlags:EClassFlags, fields:seq[UEField], metadata : seq[UEMetadata] = @[]) : UEType = 
    UEType(kind:uetClass, name:name, parent:parent, clsFlags: EClassFlagsVal(clsFlags), fields:fields)

func makeUEStruct*(name:string, fields:seq[UEField], superStruct="", metadata : seq[UEMetadata] = @[], flags = STRUCT_NoFlags) : UEType = 
    UEType(kind:uetStruct, name:name, fields:fields, superStruct:superStruct, metadata: metadata, structFlags: flags)

func makeUEMulDelegate*(name:string, fields:seq[UEField]) : UEType = 
    UEType(kind:uetDelegate, delKind:uedelMulticastDynScriptDelegate, name:name, fields:fields)

func makeUEEnum*(name:string, fields:seq[UEField], metadata : seq[UEMetadata] = @[]) : UEType = 
    UEType(kind:uetEnum, name:name, fields:fields, metadata: metadata)



func isTArray(prop:FPropertyPtr) : bool = not castField[FArrayProperty](prop).isNil()
func isTMap(prop:FPropertyPtr) : bool = not castField[FMapProperty](prop).isNil()
func isTEnum(prop:FPropertyPtr) : bool = "TEnumAsByte" in prop.getName()
func isDynDel(prop:FPropertyPtr) : bool = not castField[FDelegateProperty](prop).isNil()
func isMulticastDel(prop:FPropertyPtr) : bool = not castField[FMulticastDelegateProperty](prop).isNil()
#TODO Dels

func getNimTypeAsStr(prop:FPropertyPtr, outer:UObjectPtr) : string = #The expected type is something that UEField can understand
    if prop.isTArray(): 
        let innerType = castField[FArrayProperty](prop).getInnerProp().getCPPType()
        return fmt"TArray[{innerType}]"

    if prop.isTMap(): #better pattern here, i.e. option chain
        let mapProp = castField[FMapProperty](prop)
        let keyType = mapProp.getKeyProp().getCPPType()
        let valueType = mapProp.getValueProp().getCPPType()
        return fmt"TMap[{keyType}, {valueType}]"
    
    try:
        UE_Log &"Will get cpp type for prop {prop.getName()} NameCpp: {prop.getNameCPP()} and outer {outer.getName()}"

        let cppType = prop.getCPPType() #TODO review this. Hiphothesis it should not reach this point in the hotreload if the struct has the pointer to the prev ue type and therefore it shouldnt crash

        if prop.isTEnum(): #Not sure if it would be better to just support it on the macro
            return cppType.replace("TEnumAsByte<","")
                        .replace(">", "")


        let nimType = cppType.replace("<", "[")
                            .replace(">", "]")
                            .replace("*", "Ptr")
        

        # UE_Warn prop.getTypeName() #private?
        return nimType
    except:
        raise newException(Exception, fmt"Unsupported type {prop.getName()}")

#Function that receives a FProperty and returns a Type as string
func toUEField*(prop:FPropertyPtr, outer:UObjectPtr) : UEField = #The expected type is something that UEField can understand
    let name = prop.getName()
    let nimType = prop.getNimTypeAsStr(outer)
    return makeFieldAsUProp(prop.getName(), nimType, prop.getPropertyFlags())

    
# func toUEField(udel:UDelegateFunctionPtr) : UEField = 
#     let params = getFPropsFromUStruct(udel).map(toUEField).map(x=>x.uePropType)
#     makeFieldAsMulDel(udel.getName(), params)



func toUEField*(ufun:UFunctionPtr) : UEField = 
    # let asDel = ueCast[UDelegateFunction](ufun)
    # if not asDel.isNil(): return toUEField asDel
    let params = getFPropsFromUStruct(ufun).map(x=>toUEField(x, ufun))
    # UE_Warn(fmt"{ufun.getName()}")
    let class = ueCast[UClass](ufun.getOuter())
    let className = class.getPrefixCpp() & class.getName()
    let actualName : string = uFun.getName()
    let fnNameNim = actualName.removePrefixes(fnPrefixes)
    var fnField = makeFieldAsUFun(ufun.getName(), params, className, ufun.functionFlags)
    fnField.actualFunctionName = actualName
    fnField


func toUEType*(cls:UClassPtr) : UEType =
    #First it tries to see if it is a UNimClassBase and if it has a UEType stored.
    #Otherwise tries to parse the UEType from the Runtime information.
    let storedUEType = tryUECast[UNimClassBase](cls)
                        .flatMap((cls:UNimClassBasePtr)=>tryCast[ptr UEType](cls.ueTypePtr))
                        
    if storedUEType.isSome(): return storedUEType.get()[]

 
    let fields = getFuncsFromClass(cls)
                    .map(toUEField) & 
                 getFPropsFromUStruct(cls)
                    .map(x=>toUEField(x, cls))
    let name = cls.getPrefixCpp() & cls.getName()
    let parent = cls.getSuperClass()
    let parentName = parent.getPrefixCpp() & parent.getName()

    UEType(name:name, kind:uetClass, parent:parentName, fields:fields.reversed())

func toUEType*(str:UStructPtr) : UEType =
    
    #same as above 
    let storedUEType = tryUECast[UNimScriptStruct](str)
                        .flatMap((str:UNimScriptStructPtr)=>tryCast[ptr UEType](str.ueTypePtr))

    if storedUEType.isSome(): return storedUEType.get()[]  

    let name = str.getPrefixCpp() & str.getName()

    let fields = getFPropsFromUStruct(str)
                    .map(x=>toUEField(x, str))

    # let parent = str.getSuperClass()
    # let parentName = parent.getPrefixCpp() & parent.getName()

    UEType(name:name, kind:uetStruct, fields:fields.reversed())

func toUEType*(uenum:UNimEnumPtr) : UEType = #notice we have to specify the type because we use specific functions here. All types are Nim base types
    # let fields = getFPropsFromUStruct(enum).map(toUEField)
    let storedUEType = tryUECast[UNimEnum](uenum)
                        .flatMap((uenum:UNimEnumPtr)=>tryCast[ptr UEType](uenum.ueTypePtr))
                        
    if storedUEType.isSome(): return storedUEType.get()[]

    let name = uenum.getName()
    let fields = uenum.getEnums()
                      .map((x)=>makeFieldASUEnum(x.key.toFString()))
                      .toSeq()
    UEType(name:name, kind:uetEnum, fields: fields) #TODO

proc emitFProperty*(propField:UEField, outer : UStructPtr) : FPropertyPtr = 
    assert propField.kind == uefProp

    let prop : FPropertyPtr = newFProperty(outer, propField)
    prop.setPropertyFlags(propField.propFlags or prop.getPropertyFlags())
    for metadata in propField.metadata:
        prop.setMetadata(metadata.name, $metadata.value)
    outer.addCppProperty(prop)
    prop


#this functions should only being use when trying to resolve
#the nim name in unreal on the emit, when the actual name is not set already. 
#it is also taking into consideration when converting from ue to nim via UClass->UEType
func findFunctionByNameWithPrefixes*(cls: UClassPtr, name:string) : Option[UFunctionPtr] = 
    for prefix in fnPrefixes:
        let fnName = prefix & name
        # assert not cls.isNil()
        if cls.isNil():
            UE_Error "WTF the CLASS is None for " & name
            return none[UFunctionPtr]()
        let fun = cls.findFunctionByName(makeFName(fnName))
        if not fun.isNil(): 
            return some fun
    
    none[UFunctionPtr]()

#note at some point class can be resolved from the UEField?
proc emitUFunction*(fnField : UEField, cls:UClassPtr, fnImpl:Option[UFunctionNativeSignature]) : UFunctionPtr = 
    let superCls = someNil(cls.getSuperClass())
    let superFn  = superCls.flatmap((scls:UClassPtr)=>scls.findFunctionByNameWithPrefixes(fnField.name))
    #the only 


    #if we are overriden a function we use the name with the prefix
    #notice this only works with BlueprintEvent so check that too. 
    let fnName = superFn.map(fn=>fn.getName().makeFName()).get(fnField.name.makeFName())

    UE_Warn "Emitting function " & fnField.name

    const objFlags = RF_Public | RF_Standalone | RF_MarkAsRootSet
    var fn = newUObject[UNimFunction](cls, fnName, objFlags)
    fn.functionFlags = EFunctionFlags(fnField.fnFlags) 

    if superFn.isSome():
        let sFn = superFn.get()
        UE_Log "Overrides the function " & fnName.toFString()
        fn.functionFlags = fn.functionFlags  | (sFn.functionFlags & (FUNC_FuncInherit | FUNC_Public | FUNC_Protected | FUNC_Private | FUNC_BlueprintPure | FUNC_HasOutParms))        
        copyMetadata(sFn, fn)
        setSuperStruct(fn, sFn)

    fn.Next = cls.Children 
    cls.Children = fn

    for field in fnField.signature.reversed():
        let fprop =  field.emitFProperty(fn)
   
    for metadata in fnField.metadata:
        UE_Error metadata.name
        fn.setMetadata(metadata.name, $metadata.value)

    cls.addFunctionToFunctionMap(fn, fnName)
    if fnImpl.isSome(): #blueprint implementable events doesnt have a function implementation 
        fn.setNativeFunc(makeFNativeFuncPtr(fnImpl.get()))
    fn.staticLink(true)
    fn.sourceHash = $hash(fnField.sourceHash) 
    # fn.parmsSize = uprops.foldl(a + b.getSize(), 0) doesnt seem this is necessary 
    fn


# UNimClassBase* GetFirstNimBase(UObject* Object) {
# 	UClass* Parent = Object->GetClass();
# 	while (Parent != nullptr)
# 	{
# 		if (Cast<UNimClassBase>(Parent) != nullptr)
# 			return (UNimClassBase*)Parent;
# 		Parent = Parent->GetSuperClass();
# 	}
# 	return nullptr;
# } 

proc isNotNil[T](x:ptr T) : bool = not x.isNil()
# template isNotNil(x:typed) = (not x.isNil())
proc isNimClassBase(cls:UClassPtr) : bool = ueCast[UNimClassBase](cls) != nil


#here for reference
proc defaultClassConstructor(initializer: var FObjectInitializer) {.cdecl.}= 
    var obj = initializer.getObj()
    obj.getClass().getSuperClass().classConstructor(initializer)    
    UE_Warn "Class Constructor Called from Nim!!" & obj.getName()


type CtorInfo* = object #stores the constuctor information for a class. 
        fn* : UClassConstructor
        hash* : string

proc emitUClass*(ueType : UEType, package:UPackagePtr, fnTable : Table[string, Option[UFunctionNativeSignature]], clsConstructor : Option[CtorInfo] ) : UFieldPtr =
    const objClsFlags  =  (RF_Public | RF_Standalone | RF_Transactional | RF_WasLoaded) # RF_LoadCompleted deprecated per the ObjectMacros.h comments

    let
        newCls = newUObject[UNimClassBase](package, makeFName(ueType.name.removeFirstLetter()), cast[EObjectFlags](objClsFlags))
        parentCls = someNil(getClassByName(ueType.parent.removeFirstLetter()))
    
    let parent = parentCls
                    .getOrRaise(fmt "Parent class {ueType.parent} not found for {ueType.name}")
    
        
    assetCreated(newCls)

    newCls.propertyLink = parent.propertyLink
    newCls.classWithin = parent.classWithin
    newCls.classConfigName = parent.classConfigName

    newCls.setSuperStruct(parent)

    # use explicit casting between uint32 and enum to avoid range checking bug https://github.com/nim-lang/Nim/issues/20024
    newCls.classFlags = cast[EClassFlags](ueType.clsFlags.uint32 and parent.classFlags.uint32)

    newCls.classCastFlags = parent.classCastFlags
    
    copyMetadata(parent, newCls)
    newCls.setMetadata("IsBlueprintBase", "true") #todo move to ueType. BlueprintType should be producing this
    newCls.setMetadata("BlueprintType", "true") #todo move to ueType
    for metadata in ueType.metadata:
        newCls.setMetadata(metadata.name, $metadata.value)


    for field in ueType.fields: 
        case field.kind:
        of uefProp: discard field.emitFProperty(newCls) 
        of uefFunction: 
            UE_Log fmt"Emitting function {field.name} in class {newCls.getName()}"
            discard emitUFunction(field, newCls, fnTable[field.name]) 
        else:
            UE_Error("Unsupported field kind: " & $field.kind)
        #should gather the functions here?


    newCls.bindType()
    newCls.staticLink(true)
    clsConstructor.run(proc (cons:CtorInfo) = 
        newCls.setClassConstructor(cons.fn)
        newCls.constructorSourceHash = cons.hash
    )
    # newCls.addConstructorToActor()

    newCls.assembleReferenceTokenStream()

    newCls.ueTypePtr = newUETypeWith ueType 


    # discard newCls.getDefaultObject() #forces the creation of the cdo
    # broadcastAsset(newCls) Dont think this is needed since the notification will be done in the boundary of the plugin
    newCls

 
proc emitUStruct*[T](ueType : UEType, package:UPackagePtr) : UFieldPtr =
      
    const objClsFlags  =  (RF_Public | RF_Standalone | RF_MarkAsRootSet)
    let scriptStruct = newUObject[UNimScriptStruct](package, makeFName(ueType.name.removeFirstLetter()), objClsFlags)
        
    # scriptStruct.setMetadata("BlueprintType", "true") #todo move to ueType
    for metadata in ueType.metadata:
        scriptStruct.setMetadata(metadata.name, $metadata.value)

    scriptStruct.assetCreated()
    
    for field in ueType.fields:
        discard field.emitFProperty(scriptStruct) 

    setCppStructOpFor[T](scriptStruct, nil)
    scriptStruct.bindType()
    scriptStruct.staticLink(true)
    scriptStruct.ueTypePtr = newUETypeWith ueType 
    scriptStruct




proc emitUStruct*[T](ueType : UEType, package:string) : UFieldPtr =
    let package = getPackageByName(package)
    if package.isnil():
        raise newException(Exception, "Package not found!")
    emitUStruct[T](ueType, package)
    
proc emitUEnum*(enumType:UEType, package:UPackagePtr) : UFieldPtr = 
    let name = enumType.name.makeFName()
    const objFlags = RF_Public | RF_Standalone | RF_MarkAsRootSet
    let uenum = newUObject[UNimEnum](package, name, objFlags)
    for metadata in enumType.metadata:
        uenum.setMetadata(metadata.name, $metadata.value)
    let enumFields = makeTArray[TPair[FName, int64]]()
    for field in enumType.fields.pairs:
        let fieldName = field.val.name.makeFName()
        enumFields.add(makeTPair(fieldName,  field.key.int64))
        # uenum.setMetadata("DisplayName", "Whatever"&field.val.name)) TODO the display name seems to be stored into a metadata prop that isnt the one we usually use
    discard uenum.setEnums(enumFields)
    uenum.ueTypePtr = newUETypeWith enumType 
    uenum

proc emitUDelegate*(delType : UEType, package:UPackagePtr) : UFieldPtr = 
    let fnName = (delType.name.removeFirstLetter() & DelegateFuncSuffix).makeFName()
    const objFlags = RF_Public | RF_Standalone | RF_MarkAsRootSet
    var fn = newUObject[UNimDelegateFunction](package, fnName, objFlags)
    fn.functionFlags = FUNC_MulticastDelegate or FUNC_Delegate
    for field in delType.fields.reversed():
        let fprop =  field.emitFProperty(fn)
        # UE_Warn "Has Return " & $ (CPF_ReturnParm in fprop.getPropertyFlags())
    fn.staticLink(true)
    fn


proc createUFunctionInClass*(cls:UClassPtr, fnField : UEField, fnImpl:UFunctionNativeSignature) : UFunctionPtr {.deprecated: "use emitUFunction instead".}= 
    fnField.emitUFunction(cls, some fnImpl)




include ../unreal/prelude
import std/[times,strformat,tables, json, jsonUtils, strutils, options, sugar, algorithm, sequtils, hashes]
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

func makeUEModule*(name:string, types:seq[UEType], rules: seq[UEImportRule] = @[], dependencies:seq[UEModule]= @[]) : UEModule = 
    UEModule(name: name, types: types, dependencies: dependencies, rules: rules)


func isTArray(prop:FPropertyPtr) : bool = not castField[FArrayProperty](prop).isNil()
func isTMap(prop:FPropertyPtr) : bool = not castField[FMapProperty](prop).isNil()
func isTEnum(prop:FPropertyPtr) : bool = "TEnumAsByte" in prop.getName()
func isDynDel(prop:FPropertyPtr) : bool = not castField[FDelegateProperty](prop).isNil()
func isMulticastDel(prop:FPropertyPtr) : bool = not castField[FMulticastDelegateProperty](prop).isNil()
#TODO Dels


func getNimTypeAsStr(prop:FPropertyPtr, outer:UObjectPtr) : string = #The expected type is something that UEField can understand
    func cleanCppType(cppType:string) : string = 
         cppType.replace("<", "[").replace(">", "]").replace("*", "Ptr")

    if prop.isTArray(): 
        let innerType = castField[FArrayProperty](prop).getInnerProp().getCPPType()
        return fmt"TArray[{innerType.cleanCppType()}]"

    if prop.isTMap(): #better pattern here, i.e. option chain
        let mapProp = castField[FMapProperty](prop)
        let keyType = mapProp.getKeyProp().getCPPType()
        let valueType = mapProp.getValueProp().getCPPType()
        return fmt"TMap[{keyType}, {valueType}]"
    
    try:
        # UE_Log &"Will get cpp type for prop {prop.getName()} NameCpp: {prop.getNameCPP()} and outer {outer.getName()}"

        let cppType = prop.getCPPType() #TODO review this. Hiphothesis it should not reach this point in the hotreload if the struct has the pointer to the prev ue type and therefore it shouldnt crash

        if prop.isTEnum(): #Not sure if it would be better to just support it on the macro
            return cppType.replace("TEnumAsByte<","")
                        .replace(">", "")


        let nimType = cppType.cleanCppType()
        

        # UE_Warn prop.getTypeName() #private?
        return nimType
    except:
        raise newException(Exception, fmt"Unsupported type {prop.getName()}")



func isBPExposed(prop:FPropertyPtr) : bool = true #CPF_BlueprintVisible in prop.getPropertyFlags() 

# func isBPExposed(ufun:UFunctionPtr) : bool = FUNC_BlueprintCallable in ufun.functionFlags

func isBPExposed(str:UFieldPtr) : bool = true #str.hasMetadata("BlueprintType")

# func isBPExposed(cls:UClassPtr) : bool = true
#      cls.hasMetadata("BlueprintType") or 
#      cls.getFuncsFromClass()
#         .filter(isBPExposed)
#         .any()
        
# func isBPExposed(uenum:UEnumPtr) : bool = true
#     # uenum.hasMetadata("BlueprintType")
  
#Function that receives a FProperty and returns a Type as string
func toUEField*(prop:FPropertyPtr, outer:UObjectPtr, rules: seq[UEImportRule] = @[]) : Option[UEField] = #The expected type is something that UEField can understand
    let name = prop.getName()

    var nimType = prop.getNimTypeAsStr(outer)
    if "TEnumAsByte" in nimType:   
        nimType = nimType.extractTypeFromGenericInNimFormat("TEnumAsByte")

    for rule in rules:
        if name in rule.affectedTypes and rule.target == uerTField and rule.rule == uerIgnore: #TODO extract
            return none(UEField)
    if prop.isBPExposed():
        some makeFieldAsUProp(prop.getName(), nimType, prop.getPropertyFlags())
    else:
        none(UEField)

    
# func toUEField(udel:UDelegateFunctionPtr) : UEField = 
#     let params = getFPropsFromUStruct(udel).map(toUEField).map(x=>x.uePropType)
#     makeFieldAsMulDel(udel.getName(), params)



func toUEField*(ufun:UFunctionPtr) : Option[UEField] = 
    # let asDel = ueCast[UDelegateFunction](ufun)
    # if not asDel.isNil(): return toUEField asDel
    let params = getFPropsFromUStruct(ufun).map(x=>toUEField(x, ufun)).sequence()
    # UE_Warn(fmt"{ufun.getName()}")
    let class = ueCast[UClass](ufun.getOuter())
    let className = class.getPrefixCpp() & class.getName()
    let actualName : string = uFun.getName()
    let fnNameNim = actualName.removePrefixes(fnPrefixes)
    var fnField = makeFieldAsUFun(ufun.getName(), params, className, ufun.functionFlags)
    fnField.actualFunctionName = actualName
    if ufun.isBPExposed():
        some fnField
    else:
        none(UEField)

func tryParseJson[T](jsonStr : string) : Option[T] = 
    {.cast(noSideEffect).}:
        try:
            some parseJson(jsonStr).jsonTo(T)
        except:
            UE_Error &"Crashed parsing json for with json {jsonStr}" 
            none[T]()

func toUEType*(cls:UClassPtr, rules: seq[UEImportRule] = @[]) : Option[UEType] =
    #First it tries to see if it is a UNimClassBase and if it has a UEType stored.
    #Otherwise tries to parse the UEType from the Runtime information.
    let storedUEType = tryUECast[UNimClassBase](cls)
                        .flatMap((cls:UNimClassBasePtr)=>tryParseJson[UEType](cls.ueType))
                        
    if storedUEType.isSome(): return storedUEType

 
    let fields = getFuncsFromClass(cls)
                    .map(toUEField).sequence() & 
                 getFPropsFromUStruct(cls)
                    .map(x=>toUEField(x, cls, rules))
                    .sequence()
    let name = cls.getPrefixCpp() & cls.getName()
    let parent = someNil cls.getSuperClass()

    
    let parentName = parent.map(p=>p.getPrefixCpp() & p.getName()).get("")
    if cls.isBpExposed():
        some UEType(name:name, kind:uetClass, parent:parentName, fields:fields.reversed())
    else:
        # UE_Warn &"Class {name} is not exposed to BP"
        none(UEType)

func toUEType*(str:UStructPtr, rules: seq[UEImportRule] = @[]) : Option[UEType] =
    
    #same as above 
    let storedUEType = tryUECast[UNimScriptStruct](str)
                        .flatMap((str:UNimScriptStructPtr)=>tryParseJson[UEType](str.ueType))

    if storedUEType.isSome(): return storedUEType

    let name = str.getPrefixCpp() & str.getName()

    let fields = getFPropsFromUStruct(str)
                    .map(x=>toUEField(x, str))
                    .sequence()

    # let parent = str.getSuperClass()
    # let parentName = parent.getPrefixCpp() & parent.getName()
    if str.isBpExposed():
        some UEType(name:name, kind:uetStruct, fields:fields.reversed())
    else:
        # UE_Warn &"Struct {name} is not exposed to BP"
        none(UEType)



func toUEType*(del:UDelegateFunctionPtr, rules: seq[UEImportRule] = @[]) : Option[UEType] =
    
    #same as above 
    let storedUEType = tryUECast[UNimDelegateFunction](del)
                        .flatMap((del:UNimDelegateFunctionPtr)=>tryParseJson[UEType](del.ueType))

    if storedUEType.isSome(): return storedUEType

    let name = del.getPrefixCpp() & del.getName()


    let fields = getFPropsFromUStruct(del)
                    .map(x=>toUEField(x, del))
                    .sequence()
    
    #TODO is defaulting to MulticastDelegate this may be wrong when trying to autogen the types 
    
    some UEType(name:name, kind:uetDelegate, delKind:uedelMulticastDynScriptDelegate, fields:fields.reversed())





func toUEType*(uenum:UEnumPtr, rules: seq[UEImportRule] = @[]) : Option[UEType] = #notice we have to specify the type because we use specific functions here. All types are Nim base types
    # let fields = getFPropsFromUStruct(enum).map(toUEField)
    let storedUEType = tryUECast[UNimEnum](uenum)
                        .flatMap((uenum:UNimEnumPtr)=>tryParseJson[UEType](uenum.ueType))
                        
    if storedUEType.isSome(): return storedUEType

    let name = uenum.getName()
    var fields = newSeq[UEField]()
    for fieldName in uenum.getEnums():
        fields.add(makeFieldASUEnum(fieldName))


    if uenum.isBpExposed():
        some UEType(name:name, kind:uetEnum, fields:fields)
    else:
        UE_Warn &"Enum {name} is not exposed to BP"
        none(UEType)
   


func convertToUEType[T](obj:UObjectPtr, rules: seq[UEImportRule] = @[]) : Option[UEType] = 
  tryUECast[T](obj).flatMap((val:ptr T)=>toUEType(val, rules))


func getUETypeFrom(obj:UObjectPtr, rules: seq[UEImportRule] = @[]) : Option[UEType] = 
  if obj.getFlags() & RF_ClassDefaultObject == RF_ClassDefaultObject: 
    return none[UEType]()
  
  convertToUEType[UClass](obj, rules)
    .chainNone(()=>convertToUEType[UScriptStruct](obj, rules))
    .chainNone(()=>convertToUEType[UEnum](obj, rules))
    .chainNone(()=>convertToUEType[UDelegateFunction](obj, rules))
  
func toUEModule*(pkg:UPackagePtr, rules:seq[UEImportRule]) : Option[UEModule] = 
  let allObjs = pkg.getAllObjectsFromPackage[:UObject]()
  let types = allObjs.toSeq()
                .map((obj:UObjectPtr) => getUETypeFrom(obj, rules))
                .sequence()
                # .filter((x:UEType)=>x.kind != uetDelegate)
               

  some makeUEModule(pkg.getShortName(), types, rules)

#returns all modules neccesary to reference the UEType 
func getModuleNames*(ueType:UEType) : seq[string] = 
    #only uStructs based for now
    let outer : UStructPtr = getUTypeByName[UStruct](ueType.name.removeFirstLetter())
    let modName = outer.getModuleName()
    let fprops = outer.getFPropsFromUStruct()
    #Print them for now but eventually I will need to get the Cls/ScriptStruct name.
    @[$modName] & fprops.mapIt(&"{it.getName()}: {it.getCppType()}")

# func getAllModuleDependentNames(module:UEModule) : seq[string] =
#     #Iterate over all fields of uclass
  
  


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


    const objFlags = RF_Public | RF_Transient | RF_MarkAsRootSet | RF_MarkAsNative
    var fn = newUObject[UNimFunction](cls, fnName, objFlags)
    fn.functionFlags = EFunctionFlags(fnField.fnFlags) 

    if superFn.isSome():
        let sFn = superFn.get()
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


proc isNotNil[T](x:ptr T) : bool = not x.isNil()
# template isNotNil(x:typed) = (not x.isNil())
proc isNimClassBase(cls:UClassPtr) : bool = ueCast[UNimClassBase](cls) != nil


proc defaultClassConstructor*(initializer: var FObjectInitializer) {.cdecl.}= 
    var obj = initializer.getObj()
    obj.getClass().getFirstCppClass().classConstructor(initializer)
    UE_Warn "Class Default Constructor Called from Nim!!" & obj.getName()


type CtorInfo* = object #stores the constuctor information for a class. 
        fn* : UClassConstructor
        hash* : string
        className* : string

proc emitUClass*(ueType : UEType, package:UPackagePtr, fnTable : Table[string, Option[UFunctionNativeSignature]], clsConstructor : Option[CtorInfo] ) : UFieldPtr =
    const objClsFlags  =  (RF_Public | RF_Transient | RF_Transactional | RF_WasLoaded | RF_MarkAsNative) 

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
            # UE_Log fmt"Emitting function {field.name} in class {newCls.getName()}"
            discard emitUFunction(field, newCls, fnTable[field.name]) 
        else:
            UE_Error("Unsupported field kind: " & $field.kind)
        #should gather the functions here?


    # newCls.bindType()
    newCls.staticLink(true)
    newCls.setClassConstructor(clsConstructor.map(ctor=>ctor.fn).get(defaultClassConstructor))
    clsConstructor.run(proc (cons:CtorInfo) = 
        newCls.constructorSourceHash = cons.hash
    )
    # assert not parent.addReferencedObjects.isNil()
    # newCls.addReferencedObjects = parent.addReferencedObjects
    newCls.setAddClassReferencedObjectFn(parent.addReferencedObjects)

    # newCls.addConstructorToActor()

    newCls.assembleReferenceTokenStream()

    newCls.ueType =  $ueType.toJson() 



    discard newCls.getDefaultObject() #forces the creation of the cdo. the LC reinstancer needs it created before the object gets nulled out
    # broadcastAsset(newCls) Dont think this is needed since the notification will be done in the boundary of the plugin
    newCls

 
proc emitUStruct*[T](ueType : UEType, package:UPackagePtr) : UFieldPtr =
      
    const objClsFlags  =  (RF_Public | RF_Transient | RF_MarkAsNative)
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
    scriptStruct.ueType =  $ueType.toJson() 
    scriptStruct


proc emitUStruct*[T](ueType : UEType, package:string) : UFieldPtr =
    let package = getPackageByName(package)
    if package.isnil():
        raise newException(Exception, "Package not found!")
    emitUStruct[T](ueType, package)
    
proc emitUEnum*(enumType:UEType, package:UPackagePtr) : UFieldPtr = 
    let name = enumType.name.makeFName()
    const objFlags = RF_Public | RF_Transient | RF_MarkAsNative
    let uenum = newUObject[UNimEnum](package, name, objFlags)
    for metadata in enumType.metadata:
        uenum.setMetadata(metadata.name, $metadata.value)
    let enumFields = makeTArray[TPair[FName, int64]]()
    for field in enumType.fields.pairs:
        let fieldName = field.val.name.makeFName()
        enumFields.add(makeTPair(fieldName,  field.key.int64))
        # uenum.setMetadata("DisplayName", "Whatever"&field.val.name)) TODO the display name seems to be stored into a metadata prop that isnt the one we usually use
    discard uenum.setEnums(enumFields)
    uenum.ueType =  $enumType.toJson() 
    uenum

proc emitUDelegate*(delType : UEType, package:UPackagePtr) : UFieldPtr = 
    let fnName = (delType.name.removeFirstLetter() & DelegateFuncSuffix).makeFName()
    const objFlags = RF_Public | RF_Transient | RF_MarkAsNative
    var fn = newUObject[UNimDelegateFunction](package, fnName, objFlags)
    fn.functionFlags = FUNC_MulticastDelegate or FUNC_Delegate
    for field in delType.fields.reversed():
        let fprop =  field.emitFProperty(fn)
        # UE_Warn "Has Return " & $ (CPF_ReturnParm in fprop.getPropertyFlags())
    fn.staticLink(true)
  
    fn.ueType =  $delType.toJson() 


    fn
    


proc createUFunctionInClass*(cls:UClassPtr, fnField : UEField, fnImpl:UFunctionNativeSignature) : UFunctionPtr {.deprecated: "use emitUFunction instead".}= 
    fnField.emitUFunction(cls, some fnImpl)




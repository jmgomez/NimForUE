when defined codegen:
    type FString = string

import std/[strformat,json, strutils, options, sugar, sequtils, tables]
import ../utils/utils

import ../codegen/[makestrproc]
import ../codegen/modulerules

#Note not all supported metas are here. Only the ones we reference in code and generally outside of the macros
const UETypeMetadataKey* = "UEType"
const ClassConstructorMetadataKey* = "ClassConstructor"
const NimClassMetadataKey* = "NimClass"
const CategoryMetadataKey* = "Category"
const AttachMetadataKey* = "Attach"
const SocketMetadataKey* = "Socket"
const DefaultComponentMetadataKey* = "DefaultComponent"
const DefaultMetadataKey* = "Default"
const RootComponentMetadataKey* = "RootComponent"
const CPP_Default_MetadataKeyPrefix* = "CPP_Default_"
const AutoCreateRefTermMetadataKey* = "AutoCreateRefTerm"
const ScriptMethodMetadataKey* = "ScriptMethod"
const InstancedMetadataKey* = "Instanced"
const BlueprintImplementableEventMetadataKey* = "BlueprintImplementableEvent"
const FieldNotifyMetadataKey* = "FieldNotify" 

#UEType metadata
const NoDeclMetadataKey* = "NoDecl"
const EarlyLoadMetadataKey* = "EarlyLoad"
const ReinstanceMetadataKey* = "Reinstance" #force the reinstantiation of a UEType
const CompileBPMetadataKey* = "CompileBP" #recompile all childs even if nothing changes
const NeedsObjectInitializerCtorMetadataKey* = "NeedsObjectInitializerCtor" #recompile all childs even if nothing changes


type #TODO get rid of this (this was used before Nim supported virtual)
  CppModifiers* = enum
    cmNone, cmConst
    
  CppParam* = object #TODO take const, refs, etc. into account
    name*: string
    typ*: string
    modifiers*: CppModifiers #convert this into a set when there are more or just support bitset operations?


  CppAccesSpecifier* = enum 
    caPublic, caPrivate, caProtected


  CppFunction* = object #visibility?
    name*: string
    returnType*: string
    accessSpecifier* : CppAccesSpecifier
    params*: seq[CppParam] #this is not expressed as param
    modifiers*: CppModifiers #convert this into a set when there are more or just support bitset operations?
  CppClassKind* = enum #TODO add more
    cckClass, cckStruct
  CppClassType* = object
    name*, parent*: string
    functions*: seq[CppFunction]
    kind*: CppClassKind
    isUObjectBased* : bool #TODO add to kind class only
  CppHeader* = object
    name*: string
    includes*: seq[string]
    classes*: OrderedTable[string, CppClassType] #name, class

type
    EPropertyFlagsVal* = distinct(uint64)
    EFunctionFlagsVal* = distinct(uint32)
    EClassFlagsVal* = (uint32)
    EStructFlagsVal* = distinct(uint32)
    EClassCastFlagsVal* = distinct(uint64)
    
    
    UEExposure* = enum
        uexDsl, uexImport, uexExport

    UETypeKind* = enum
        uetClass
        uetStruct
        uetDelegate
        uetEnum
        uetInterface

    UEFieldKind* = enum
        uefProp, #this covers FString, int, TArray, etc. 
        uefFunction
        uefEnumVal

    UEDelegateKind* = enum
        uedelDynScriptDelegate,
        uedelMulticastDynScriptDelegate
    UEMetadata* = object 
        name* : string
        value* : string

    UEField* = object
        name* : string
        typeName* : string
        metadata* : seq[UEMetadata] #Notice we are using a custom metadata field to indicate if the field is delegate or not. It has to be anotated from the dsl somewhoe to (infer it from the flags or do something else? )

        case kind*: UEFieldKind
            of uefProp:
                uePropType* : string #Do a close set of types? No, just do a close set on the MetaType. i.e Struct, TArray, Delegates (they complicate things)
                propFlags*:EPropertyFlagsVal
                size*: int32
                offset*: int32
                defaultParamValue*:string #Only valid for params. It has the UE Format
                isReturn*: bool #needed for reliability. CPF_ReturnParam doesnt seem to work well in the vm
            of uefFunction:
                # className*:string #use typeName
                actualFunctionName*:string #some functions are called differently on unreal (receivve, k2_ etc.)
                #note cant use option type. If it has a returnParm it will be the first param that has CPF_ReturnParm
                signature* : seq[UEField]
                fnFlags* : EFunctionFlagsVal
                sourceHash* : string 

            of uefEnumVal:
                discard

    UEType* = object        
        name* : string
        fields* : seq[UEField] #it isnt called field because there is a collision with a nim type
        metadata* : seq[UEMetadata]
        isInPCH* : bool #if the type is in the PCH at the time of generting the bindings. Means we can do importc directly (only for structs and classes for now. Need to figure out enums, not sure about if delegate worth the trouble, probably not)
        moduleRelativePath* : string 
        size*: int32
        parentSize*: int32
        alignment*: int32        
        isEditorOnly*: bool

        case kind*: UETypeKind
            of uetClass:
                isInCommon* : bool #the type is part of the common module (if it's the actual type in common it also has forwardDeclareOnly set to false)
                parent* : string
                clsFlags*: EClassFlagsVal
                ctorSourceHash*: string
                interfaces* : seq[string] #the names of the interfaces implemented by this class. If starts with I is a cpp interface otherwise (U) it's a reflected interface. The cpp version generates the actual required cpp code
                fnOverrides* : seq[CppFunction] #the names of theTODO Delete
                isParentInPCH* : bool
                forwardDeclareOnly* : bool #if the class is forward declared only. This means we dont define the class in the current module, it maybe defined (func emmited) in another module or in the PCH
                hasObjInitCtor* : bool #if the class has a constructor that takes an object initializer. This is used to generate the constructor in the nim side
                hasDefaultCtor* : bool #if the class has a default constructor, usually implies the above. Only used for bindings so far
            of uetStruct:
                superStruct* : string
                structFlags*: EStructFlagsVal
                isSuperStructInPCH* : bool
            of uetEnum:
                cppEnumName*: string
            of uetDelegate:
                #the signature is just the fields
                # delegateSignature*: seq[string] #this could be set as FScriptDelegate[String,..] but it's probably clearer this way
                delKind*: UEDelegateKind
                outerClassName*: string #the name of the class that contains the delegate (if any)
            of uetInterface:
                discard

    UEModule* = object
        name* : string #i.e. gamefrawework inside engine. 
        types* : seq[UEType]
        rules* : seq[UEImportRule]
        dependencies* : seq[string]   
        hash* : string
        isVirtual* : bool #A fake module that's only a module in the Nim side of things. It basically means that a set of classes get included into its own file to avoid name collisions and also to speed up compilation times.
        isEditorOnly*: bool
    UEProject* = object
        modules* : seq[UEModule]

const CommonModule* = "Engine/Common"
const ManuallyImportedModule* = "ManuallyImportedModule"
func isCommon*(module: UEModule): bool = module.name == CommonModule

func `$`*(a : EPropertyFlagsVal) : string {.borrow.}
func `$`*(a : EFunctionFlagsVal) : string {.borrow.}
func `$`*(a : EStructFlagsVal) : string {.borrow.}

when not defined(nuevm): #TODO this doesnt belong here
    makeStrProc(UEMetadata)
    makeStrProc(UEField)
    makeStrProc(UEType)
    makeStrProc(UEImportRule)
    makeStrProc(UEModule)
    makeStrProc(UEProject)




# #ONLY FOR Delagates that matches the rule innerClassDelegate
func getFuncDelegateNimName*(name, outerClassName:string) : string = 
    if outerClassName == "": name
    else: &"{outerClassName}_{name}"

func getFuncDelegateNimName*(ueType:UEType) : string = 
    assert ueType.kind == uetDelegate
    getFuncDelegateNimName(ueType.name, ueType.outerClassName)

func countMembers*(uet : UEType) : int = 
    #Notice a member only makes sense for classes since ufields props are defined as functions and the functs itself
    case uet.kind:
    of uetClass:
        uet.fields.filter(f=>f.kind == uefFunction).len + 
        uet.fields.filter(f=>f.kind == uefProp).len * 2
    else: 1


# func getAllMatchingTypes*(module:UEModule, rule:UERule) : seq[UEType] =
#    module.types
#          .filter(ueType:UEType => ueType in rule.affectedTypes)   
func getAllMatchingRulesForType*(module:UEModule, ueType:UEType) : UERule =
    let rules = module.rules
                .filter(func (rule:UEImportRule):bool = 
                        rule.affectedTypes.any(name=>name==ueType.name) or 
                        rule.target == uertModule)
                .map((rule:UEImportRule) => rule.rule)
    if rules.any(): rules[0]#.foldl(a or b, uerNone)
    else: uerNone

proc `[]`*(metadata:seq[UEMetadata], key:string) : Option[string] = 
    metadata.first(x=>x.name==key).map(x=>x.value)


const MulticastDelegateMetadataKey* = "MulticastDelegate"
const DelegateMetadataKey* = "Delegate"
    
func makeUEMetadata*(name:string) : UEMetadata = 
    UEMetadata(name:name, value:"true" ) #todo check if the name is valid. Also they can be more than simple names

func makeUEMetadata*(name:string, value:string) : UEMetadata = 
    UEMetadata(name:name, value:value ) #todo check if the name is valid. Also they can be more than simple names

func contains*(metas:seq[UEMetadata], name:string): bool =     
  for meta in metas:
    if meta.name.toLower() == name.toLower():
      return true

func hasUEMetadata*(val: UEField, name: string): bool = val.metadata.any(m => m.name.toLower == name.toLower)
func hasUEMetadata*(val: UEType, name: string): bool = val.metadata.any(m => m.name.toLower == name.toLower)
func hasUEMetadataDefaultValue*(val: UEField): bool = val.metadata.any(m => m.name.toLower.contains(CPP_Default_MetadataKeyPrefix.toLower))
func shouldBeLoadedEarly*(uet: UEType): bool = uet.hasUEMetadata(EarlyLoadMetadataKey)

func getAllParametersWithDefaultValuesFromFunc*(fnField:UEField) : seq[UEField] =
    assert fnField.kind == uefFunction
    let names = 
        fnField
            .metadata
            .filterIt(it.name.contains(CPP_Default_MetadataKeyPrefix))
            .mapIt(it.name.replace(CPP_Default_MetadataKeyPrefix, "").firstToLow())
    fnField
    .signature
    .filterIt(it.name in names)


#The name is in nim format. It's transformed here.
func getMetadataValueFromFunc*[T](fnField : UEField, name:string) : T =
    assert fnField.kind == uefFunction
    var name = name
    if name[0] != 'b':
        name = name.firstToUpper()
    let val = fnField.metadata[CPP_Default_MetadataKeyPrefix & name]
    #TODO the val can come in a lot of different shapes. See PrintString
    when T is bool:
        return parseBool(val.get()) #TODO uint 
    #Get the parameter with the name. 
    #inspect the type of the parameter
    #convert it to the type T which should be known before calling this function?
    # return T()
    

func getFieldByName*(ueType:UEType, name:string) : Option[UEField] = ueType.fields.first(f=>f.name == name)
func getFieldByName*(ueTypes:seq[UEType], name:string) : Option[UEField] = 
    ueTypes
        .map(ueType=>ueType.fields)
        .foldl(a & b)
        .first(f=>f.name == name)

func getUETypeByName*(ueTypes:seq[UEType], name:string) : Option[UEType] = ueTypes.first(ueType=>ueType.name == name)
func isMulticastDelegate*(field:UEField) : bool = hasUEMetadata(field, MulticastDelegateMetadataKey)
func isDelegate*(field:UEField) : bool = hasUEMetadata(field, DelegateMetadataKey)
func isGeneric*(field:UEField) : bool = field.kind == uefProp and field.uePropType.contains("[")

func shouldBeReturnedAsVar*(field:UEField) : bool =
    let typesReturnedAsVar = ["TMap", "TArray", "TSet"]
    result = field.kind == uefProp and typesReturnedAsVar.any(tp => tp in field.uePropType) or
            field.isMulticastDelegate() or 
            field.isDelegate() or
            field.uePropType.startsWith("F") and field.uePropType != "FString" #FStruct always starts with F. We need to enforce it in our types too.

type ValFlags = EPropertyFlagsVal | EFunctionFlagsVal | EClassFlagsVal | EStructFlagsVal

  

func `==`*(a, b : EPropertyFlagsVal) : bool {.borrow.}
func `==`*(a, b : EFunctionFlagsVal) : bool {.borrow.}
# func `==`*(a, b : EClassFlagsVal) : bool {.borrow.}
func `==`*(a, b : EStructFlagsVal) : bool {.borrow.}


func compareUEPropTypes(a, b:string) : bool = 
    #maps the type difference between ue and nim (this is relevant because we want to compare a runtime generated type with ours)
    let typeMap = { 
        "int" : "int64", 
        "bool" : "uint8", 
        "TArray[bool]" : "TArray[uint8]", 
        "TArray[float]" : "TArray[double]", 
        "float64":"double",
        "float32":"double", #WHy?
        "float":"double",
        "TSubclassOf[AActor]" : "UClassPtr"
        }.toTable()
    var a = a
    var b = b
    if a in typeMap:
        a = typeMap[a]
    if b in typeMap:
        b = typeMap[b]
    result = a == b


func `==`*(a, b : UEField) : bool = 
    result = a.name == b.name and
        # a.metadata == b.metadata and
        a.kind == b.kind and
        (case a.kind:
        of uefProp: 
            compareUEPropTypes(a.uePropType, b.uePropType) and
            a.propFlags == b.propFlags #Flags are modified in UE so the test here will fail if the type was recreated from UE. 
        of uefFunction: 
            a.signature == b.signature  and  #two functions from the point of view of a class are equals if they have the same signature 
            a.fnFlags == b.fnFlags
        of uefEnumVal: true)

func `==`*(a, b:UEType) : bool = 
    # UE_Error2 $a
    # UE_Error2 $b
    #  
    result = 
        (a.name == b.name and

        a.fields == b.fields and
        # a.metadata == b.metadata and
        a.kind == b.kind and
        (case a.kind:
        of uetClass:
            a.parent == b.parent
            # a.clsFlags == b.clsFlags
        of uetStruct:
            a.superStruct == b.superStruct #and
            # a.structFlags == b.structFlags
        of uetEnum: true
        of uetInterface: true
        of uetDelegate: true))

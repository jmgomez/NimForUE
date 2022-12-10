when defined codegen:
    type FString = string
else:
    include ../unreal/definitions

import ../utils/utils
import std/[times,strformat,json, strutils, options, sugar, sequtils, bitops, tables]

import ../macros/makestrproc


const UETypeMetadataKey* = "UEType"
const ClassConstructorMetadataKey* = "ClassConstructor"
const NimClassMetadataKey* = "NimClass"
const CategoryMetadataKey* = "Category"
const AttachMetadataKey* = "Attach"
const SocketMetadataKey* = "Socket"
const DefaultComponentMetadataKey* = "DefaultComponent"
const RootComponentMetadataKey* = "RootComponent"
const CPP_Default_MetadataKeyPrefix* = "CPP_Default_"
const AutoCreateRefTermMetadataKey* = "AutoCreateRefTerm"


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
        metadata* : seq[UEMetadata] #Notice we are using a custom metadata field to indicate if the field is delegate or not. It has to be anotated from the dsl somewhoe to (infer it from the flags or do something else? )

        case kind*: UEFieldKind
            of uefProp:
                uePropType* : string #Do a close set of types? No, just do a close set on the MetaType. i.e Struct, TArray, Delegates (they complicate things)
                propFlags*:EPropertyFlagsVal
                size*: int32
                offset*: int32
                defaultParamValue*:string #Only valid for params. It has the UE Format

            of uefFunction:
                className*:string
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

        case kind*: UETypeKind
            of uetClass:
                parent* : string
                clsFlags*: EClassFlagsVal
                ctorSourceHash*: string
                interfaces* : seq[string]
            of uetStruct:
                superStruct* : string
                structFlags*: EStructFlagsVal
                size*: int32
                alignment*: int32
            of uetEnum:
                discard
            of uetDelegate:
                #the signature is just the fields
                # delegateSignature*: seq[string] #this could be set as FScriptDelegate[String,..] but it's probably clearer this way
                delKind*: UEDelegateKind
                outerClassName*: string #the name of the class that contains the delegate (if any)

    #Rules applies to UERuleTarget
    UERule* = enum
        uerNone
        uerCodeGenOnlyFields #wont generate the type. Just its fields. Only make sense in uClass. Will affect code generation (we try to do it at the import time when possible) 
        uerIgnore
        uerImportStruct
        uerImportBlueprintOnly #affects all types and all target. If set, it will only import the blueprint types.
        uerVirtualModule
        uerInnerClassDelegate #Some delegates are declared withit a class and can collide. This rule is for when both are true
        uerIgnoreHash #ignore the hash when importing a module so always imports it. 

    UERuleTarget* = enum 
        uertType
        uertField
        uertModule
    #TODO Rename to UEBindRule
    UEImportRule* = object #used only to customize the codegen
        affectedTypes* : seq[string]
        target* : UERuleTarget
        case  rule* : UERule
        of uerVirtualModule:
            moduleName* : string
        of uerInnerClassDelegate: 
            onlyFor* : seq[string] #Constraints the types that the rule applies to. If empty, it applies to all types.  
        else:
            discard


    UEModule* = object
        name* : string
        types* : seq[UEType]
        rules* : seq[UEImportRule]
        dependencies* : seq[string]   
        hash* : string
        isVirtual* : bool #A fake module that's only a module in the Nim side of things. It basically means that a set of classes get included into its own file to avoid name collisions and also to speed up compilation times.
        
    UEProject* = object
        modules* : seq[UEModule]

func `$`*(a : EPropertyFlagsVal) : string {.borrow.}
func `$`*(a : EFunctionFlagsVal) : string {.borrow.}
func `$`*(a : EStructFlagsVal) : string {.borrow.}

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




# func `or`(a, b : UERule) : UERule = bitor(a.uint32, b.uint32).UERule

func makeImportedRuleType*(rule:UERule, affectedTypes:seq[string], ):UEImportRule =
    result.affectedTypes = affectedTypes
    result.rule = rule
    result.target = uertType

func makeImportedRuleField*(rule:UERule, affectedTypes:seq[string], ):UEImportRule =
    result.affectedTypes = affectedTypes
    result.rule = rule
    result.target = uertField
    
func makeImportedRuleModule*(rule:UERule) : UEImportRule = 
    result.rule = rule
    result.target = uertModule


#Notice the param restrictions on the functions below. Either you apply the rule to multiple types or you chose what types to apply in a single rule
func makeImportedDelegateRule*(affectedTypes:seq[string]) : UEImportRule = 
    result.affectedTypes = affectedTypes
    result.rule = uerInnerClassDelegate
    result.target = uertType

func makeImportedDelegateRule*(affectedType:string, onlyFor:seq[string]) : UEImportRule = 
    result.affectedTypes = @[affectedType]
    result.rule = uerInnerClassDelegate
    result.target = uertType
    result.onlyFor = onlyFor

#It's processed after the module deps are calculated
func makeVirtualModuleRule*(moduleName:string, affectedTypes:seq[string]) : UEImportRule = 
    result.rule = uerVirtualModule
    result.target = uertModule
    result.affectedTypes = affectedTypes
    result.moduleName = moduleName



func contains*(rules: seq[UEImportRule], rule:UERule): bool = 
    rules.any((r:UEImportRule) => r.rule == rule)

func isTypeAffectedByRule*(rules:seq[UEImportRule], name:string, rule:UERule): bool = 
    rules.any((r:UEImportRule) => r.target == uertType and r.rule == rule and r.affectedTypes.contains(name))
func getRuleAffectingType*(rules:seq[UEImportRule], name:string, rule:UERule): Option[UEImportRule] = 
    rules.first((r:UEImportRule) => r.target == uertType and r.rule == rule and r.affectedTypes.contains(name))

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



#allocates a newUEType based on an UEType value.
#the allocated version will be stored in the NimBase class/struct in UE so we can 
#check what changes have been made to the type.
proc newUETypeWith*(ueType:UEType) : ptr UEType = 
    result = create(UEType)
    if result.isNil():
        raise newException(Exception, &"Failed to allocate UEType {ueType.name}")
    result[] = ueType
    
proc `[]`*(metadata:seq[UEMetadata], key:string) : Option[string] = 
    metadata.first(x=>x.name==key).map(x=>x.value)


const MulticastDelegateMetadataKey* = "MulticastDelegate"
const DelegateMetadataKey* = "Delegate"
    
func makeUEMetadata*(name:string) : UEMetadata = 
    UEMetadata(name:name, value:"true" ) #todo check if the name is valid. Also they can be more than simple names
func makeUEMetadata*(name:string, value:string) : UEMetadata = 
    UEMetadata(name:name, value:value ) #todo check if the name is valid. Also they can be more than simple names



func hasUEMetadata*[T:UEField|UEType](val:T, name:string) : bool = val.metadata.any(m => m.name == name)
func hasUEMetadataDefaultValue*(val:UEField) : bool = val.metadata.any(m => m.name.contains(CPP_Default_MetadataKeyPrefix))

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

func getUETypeByName*(ueTypes:seq[UEType], name:string) : Option[UEType] = ueTypes.first(ueType=>ueType.name)
func isMulticastDelegate*(field:UEField) : bool = hasUEMetadata(field, MulticastDelegateMetadataKey)
func isDelegate*(field:UEField) : bool = hasUEMetadata(field, DelegateMetadataKey)
func isGeneric*(field:UEField) : bool = field.kind == uefProp and field.uePropType.contains("[")

func shouldBeReturnedAsVar*(field:UEField) : bool =
    let typesReturnedAsVar = ["TMap", "TArray"]
    result = field.kind == uefProp and typesReturnedAsVar.any(tp => tp in field.uePropType) or
               field.isMulticastDelegate() or 
               field.isDelegate() or
               field.uePropType.startsWith("F") and field.uePropType != "FString" #FStruct always starts with F. We need to enforce it in our types too.

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
            a.parent == b.parent and
            a.ctorSourceHash == b.ctorSourceHash 
            # a.clsFlags == b.clsFlags
        of uetStruct:
            a.superStruct == b.superStruct #and
            # a.structFlags == b.structFlags
        of uetEnum: true
        of uetDelegate: true))


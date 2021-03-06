include ../unreal/definitions
import ../utils/utils
import std/[times,strformat,json, strutils, options, sugar, sequtils, tables]
import ../unreal/core/containers/unrealstring


type
    EPropertyFlagsVal* = distinct(uint64)
    EFunctionFlagsVal* = distinct(uint32)
    EClassFlagsVal* = (uint32)
    EStructFlagsVal* = distinct(uint32)
    EClassCastFlagsVal* = distinct(uint64)


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
        value* : bool

    UEField* = object
        name* : string
        metadata* : seq[UEMetadata] #Notice we are using a custom metadata field to indicate if the field is delegate or not. It has to be anotated from the dsl somewhoe to (infer it from the flags or do something else? )

        case kind*: UEFieldKind
            of uefProp:
                uePropType* : string #Do a close set of types? No, just do a close set on the MetaType. i.e Struct, TArray, Delegates (they complicate things)
                propFlags*:EPropertyFlagsVal

            of uefFunction:
                className*:string
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
            of uetStruct:
                superStruct* : string
                structFlags*: EStructFlagsVal
            of uetEnum:
                discard
            of uetDelegate:
                #the signature is just the fields
                # delegateSignature*: seq[string] #this could be set as FScriptDelegate[String,..] but it's probably clearer this way
                delKind*: UEDelegateKind

    UEModule* = object
        name* : string
        types* : seq[UEType]
        dependencies* : seq[UEModule]   



const MulticastDelegateMetadataKey* = "MulticastDelegate"
const DelegateMetadataKey* = "Delegate"
    
func makeUEMetadata*(name:string) : UEMetadata = 
    UEMetadata(name:name, value:true ) #todo check if the name is valid. Also they can be more than simple names

func hasUEMetadata*[T:UEField|UEType](val:T, name:string) : bool = val.metadata.any(m => m.name == name)

func isMulticastDelegate*(field:UEField) : bool = hasUEMetadata(field, MulticastDelegateMetadataKey)
func isDelegate*(field:UEField) : bool = hasUEMetadata(field, DelegateMetadataKey)

func isGeneric*(field:UEField) : bool = field.kind == uefProp and field.uePropType.contains("[")

func getFieldByName*(ueType:UEType, name:string) : Option[UEField] = ueType.fields.first(f=>f.name == name)
func getFieldByName*(ueTypes:seq[UEType], name:string) : Option[UEField] = 
    ueTypes
        .map(ueType=>ueType.fields)
        .foldl(a & b)
        .first(f=>f.name == name)

func shouldBeReturnedAsVar*(field:UEField) : bool = 
    let typesReturnedAsVar = ["TMap"]
    field.kind == uefProp and 
    typesReturnedAsVar.any(tp => tp in field.uePropType) or
    field.isMulticastDelegate() or 
    field.isDelegate()
 

func `==`*(a, b : EPropertyFlagsVal) : bool {.borrow.}
func `==`*(a, b : EFunctionFlagsVal) : bool {.borrow.}
# func `==`*(a, b : EClassFlagsVal) : bool {.borrow.}
func `==`*(a, b : EStructFlagsVal) : bool {.borrow.}


proc UE_Error2*(msg: FString) : void {.importcpp: "UReflectionHelpers::NimForUEError(@)".}

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
    if not result: #This is just for debugging types. This functions has to be moved from here so there is no unreal symbols in this file
        UE_Error2 a & " " & b


func `==`*(a, b : UEField) : bool = 
    result = a.name == b.name and
        # a.metadata == b.metadata and
        a.kind == b.kind and
        (case a.kind:
        of uefProp: 
            compareUEPropTypes(a.uePropType, b.uePropType) #and
            # a.propFlags == b.propFlags
        of uefFunction: false
            # a.signature == b.signature  #and  
            # a.fnFlags == b.fnFlags
        of uefEnumVal: true)
    if not result: #This is just for debugging types. This functions has to be moved from here so there is no unreal symbols in this file
        UE_Error2 $a 
        UE_Error2 $b

func `==`*(a, b:UEType) : bool = 
    # UE_Error2 $a
    # UE_Error2 $b
    # 
    a.name == b.name and
    a.fields == b.fields and
    # a.metadata == b.metadata and
    a.kind == b.kind and
    (case a.kind:
    of uetClass:
        a.parent == b.parent #and
        # a.clsFlags == b.clsFlags
    of uetStruct:
        a.superStruct == b.superStruct #and
        # a.structFlags == b.structFlags
    of uetEnum: true
    of uetDelegate: true) 
        



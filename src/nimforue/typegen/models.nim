
import ../unreal/coreuobject/[uobject,  unrealtype, templates/subclassof, tsoftobjectptr, nametypes, scriptdelegates]
import ../utils/utils
import std/[times,strformat,json, strutils, options, sugar, sequtils]


type
    UETypeKind* = enum
        uClass
        uStruct
        uEnum

    UEFieldKind* = enum
        uefProp, #this covers FString, int, TArray, etc. 
        uefDelegate,
        uefFunction
        uefEnumVal

    UEDelegateKind* = enum
        uedelDynScriptDelegate,
        uedelMulticastDynScriptDelegate

    UEField* = object
        name* : string

        case kind*: UEFieldKind
            of uefProp:
                uePropType* : string #Do a close set of types? No, just do a close set on the MetaType. i.e Struct, TArray, Delegates (they complicate things)
                propFlags*:EPropertyFlags

            of uefDelegate:
                delegateSignature*: seq[string] #this could be set as FScriptDelegate[String,..] but it's probably clearer this way
                delKind*: UEDelegateKind
                delFlags*: EPropertyFlags

            of uefFunction:
                #note cant use option type. If it has a returnParm it will be the first param that has CPF_ReturnParm
                signature* : seq[UEField]
                fnFlags* : EFunctionFlags
            
            of uefEnumVal:
                discard


# #JSON
              
func makeFieldAsUProp*(name, uPropType: string, flags=CPF_None) : UEField = 
    UEField(kind:uefProp, name: name, uePropType: uPropType, propFlags:flags)       

func makeFieldAsDel*(name:string, delKind: UEDelegateKind, signature:seq[string], flags=CPF_None) : UEField = 
    UEField(kind:uefDelegate, name: name, delKind: delKind, delegateSignature:signature, delFlags:flags)

func makeFieldAsUFun*(name:string, signature:seq[UEField], flags=FUNC_None) : UEField = 
    UEField(kind:uefFunction, name:name, signature:signature, fnFlags:flags)

func makeFieldAsUPropParam*(name, uPropType: string, flags=CPF_Parm) : UEField = 
    UEField(kind:uefProp, name: name, uePropType: uPropType, propFlags:flags)       


func isGeneric*(field:UEField) : bool = field.kind == uefProp and field.uePropType.contains("[")
func shouldBeReturnedAsVar*(field:UEField) : bool = 
    let typesReturnedAsVar = ["TMap"]
    field.kind == uefProp and typesReturnedAsVar.filter(tp => tp in field.uePropType ).head().isSome()

type
    UEType* = object 
        name* : string
        fields* : seq[UEField] #it isnt called field because there is a collision with a nim type
        #class flags?
        case kind*: UETypeKind
            of uClass:
                parent* : string
                clsFlags*: EClassFlags
            of uStruct:
                discard
            of uEnum:
                discard



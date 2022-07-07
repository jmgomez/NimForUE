include ../unreal/definitions
import ../utils/utils
import std/[times,strformat,json, strutils, options, sugar, sequtils, tables]


type
    EPropertyFlagsVal* = distinct(uint64)
    EFunctionFlagsVal* = distinct(uint32)
    EClassFlagsVal* = distinct(uint32)
    EClassCastFlagsVal* = distinct(uint64)




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
        # metatadata* : Table[string, bool]

        case kind*: UEFieldKind
            of uefProp:
                uePropType* : string #Do a close set of types? No, just do a close set on the MetaType. i.e Struct, TArray, Delegates (they complicate things)
                propFlags*:EPropertyFlagsVal

            of uefDelegate:
                delegateSignature*: seq[string] #this could be set as FScriptDelegate[String,..] but it's probably clearer this way
                delKind*: UEDelegateKind
                delFlags*: EPropertyFlagsVal

            of uefFunction:
                #note cant use option type. If it has a returnParm it will be the first param that has CPF_ReturnParm
                signature* : seq[UEField]
                fnFlags* : EFunctionFlagsVal
            
            of uefEnumVal:
                discard

func isGeneric*(field:UEField) : bool = field.kind == uefProp and field.uePropType.contains("[")

func shouldBeReturnedAsVar*(field:UEField) : bool = 
    let typesReturnedAsVar = ["TMap"]
    field.kind == uefProp and typesReturnedAsVar.filter(tp => tp in field.uePropType ).head().isSome()

type
    UEType* = object 
        name* : string
        fields* : seq[UEField] #it isnt called field because there is a collision with a nim type
        # metadata* : Table[string, bool]
        # metadata* : seq[Metadata]
        #class flags?
        case kind*: UETypeKind
            of uClass:
                parent* : string
                clsFlags*: EClassFlagsVal
            of uStruct:
                discard
            of uEnum:
                discard

    UEModule* = object
        name* : string
        types* : seq[UEType]
        dependencies* : seq[UEModule]        
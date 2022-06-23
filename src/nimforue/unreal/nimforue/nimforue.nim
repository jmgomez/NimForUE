import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/[unrealstring, array]
import nimforuebindings
import ../../macros/uebind
import std/strformat
include ../definitions

import std/[typetraits, strutils, sequtils, sugar]
#This file contains logic on top of ue types that it isnt necessarily bind 



proc createProperty*(outer : UObjectPtr, field:UEField) : FPropertyPtr = 
    let flags = RF_NoFlags
    let name = field.name.makeFName()


    let prop : FPropertyPtr =   
                if field.uePropType == "FString": 
                    makeFStrProperty(makeFieldVariant(outer), name, flags)
                elif field.uePropType == "int32":
                    makeFIntProperty(makeFieldVariant(outer), name, flags)
                else:
                    raise newException(Exception, "FProperty not covered in the types for " & field.uePropType)
    
    prop.setPropertyFlags(CPF_Parm)
    prop
 

type UFunctionNativeSignature* = proc (context:UObjectPtr, stack:var FFrame,  result: pointer) : void {. cdecl .}

proc createUFunctionInClass*(fnName : FName, cls:UClassPtr, flags: EFunctionFlags, fnImpl:UFunctionNativeSignature, props:seq[UEField]) : UFunctionPtr = 
    var fn = newUObject[UFunction](cls, fnName)
    fn.functionFlags = flags
    fn.Next = cls.Children 
    cls.Children = fn

    let uprops = props.map(p=>createProperty(fn, p))
    for prop in uprops:
        fn.addCppProperty(prop)

    fn.setNativeFunc(makeFNativeFuncPtr(fnImpl))
    fn.staticLink(true)

    fn.parmsSize = uprops.foldl(a + b.getSize(), 0)
    # if uprops.len() > 0:
    #         #// Parameter size is the byte count after the last argument
    #     fn.parmsSize = 32# ( uprops[^1].getOffsetForUFunction() +  uprops[^1].getSize()).uint16
    let msg = fmt"Param size is {fn.parmsSize}"
    UE_Log(msg)
    fn

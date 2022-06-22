import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/[unrealstring, array]
import nimforuebindings
import ../../macros/uebind
include ../definitions

import std/[typetraits, strutils, sequtils, sugar]
#This file contains logic on top of ue types that it isnt necessarily bind 


proc createProperty*(outer : UObjectPtr, name : FName, flags : EObjectFlags) : FPropertyPtr = 
    let fieldVariant = makeFieldVariant(outer)
    let prop = makeFStringProperty(fieldVariant, name, flags)
    prop.setPropertyFlags(CPF_Parm)
    prop
 


type UFunctionNativeSignature* = proc (context:UObjectPtr, stack:var FFrame,  result: pointer) : void {. cdecl .}

proc createUFunctionInClass*(fnName : FName, cls:UClassPtr, flags: EFunctionFlags, fnImpl:UFunctionNativeSignature, props:seq[UEField]) : UFunctionPtr = 
    var fn = newUObject[UFunction](cls, fnName)
    fn.functionFlags = flags
    fn.Next = cls.Children 
    cls.Children = fn

    let uprops = props.map(p=>createProperty(fn, makeFName(p.name), RF_NoFlags))
    for prop in uprops:
        fn.addCppProperty(prop)

    fn.setNativeFunc(makeFNativeFuncPtr(fnImpl))
    fn.staticLink(true)

    if uprops.len() > 0:
            #			// Parameter size is the byte count after the last argument
        fn.parmsSize = ( uprops[^1].getOffsetForUFunction() +  uprops[^1].getSize()).uint16
    fn
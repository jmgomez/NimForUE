import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/unrealstring 
import std/[typetraits, strutils]
import nimforuebindings
include ../definitions

#This file contains logic on top of ue types that it isnt necessarily bind 

type UFunctionNativeSignature* = proc (context:UObjectPtr, stack:var FFrame,  result: pointer) : void {. cdecl .}

proc createUFunctionInClass*(fnName : FName, cls:UClassPtr, flags: EFunctionFlag, fnImpl:UFunctionNativeSignature) : UFunctionPtr = 
    var fn = newUObject[UFunction](cls, fnName)
    fn.functionFlags = flags
    fn.Next = cls.Children 
    cls.Children = fn
    fn.setNativeFunc(makeFNativeFuncPtr(fnImpl))
    fn.staticLink(true)
    fn
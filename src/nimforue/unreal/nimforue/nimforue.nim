import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/[unrealstring, array]
import nimforuebindings
import ../../macros/uebind
import std/strformat
include ../definitions

import std/[typetraits, strutils, sequtils, sugar]
#This file contains logic on top of ue types that it isnt necessarily bind 



proc createProperty*(outer : UStructPtr, propField:UEField) : FPropertyPtr = 
    let flags = RF_NoFlags #OBJECT FLAGS
    let name = propField.name.makeFName()
    let prop : FPropertyPtr =   
                if propField.uePropType == "FString": 
                    makeFStrProperty(makeFieldVariant(outer), name, flags)
                elif propField.uePropType == "int32":
                    makeFIntProperty(makeFieldVariant(outer), name, flags)
                else:
                    raise newException(Exception, "FProperty not covered in the types for " & propField.uePropType)
    
    prop.setPropertyFlags(propField.propFlags)
    outer.addCppProperty(prop)
    prop
 

type UFunctionNativeSignature* = proc (context:UObjectPtr, stack:var FFrame,  result: pointer) : void {. cdecl .}

#note at some point class can be resolved from the UEField?
proc createUFunctionInClass*(cls:UClassPtr, fnField : UEField, fnImpl:UFunctionNativeSignature) : UFunctionPtr = 
    let fnName = fnField.name.makeFName()
    var fn = newUObject[UFunction](cls, fnName)
    fn.functionFlags = fnField.fnFlags
    #There should be a cpp method that does this for us (try with fn.addCppProperty here as well)
    fn.Next = cls.Children 
    cls.Children = fn

    let uprops = fnField.signature.map(p=>createProperty(fn, p))
   
    cls.addFunctionToFunctionMap(fn, fnName)
        

    fn.setNativeFunc(makeFNativeFuncPtr(fnImpl))
    fn.staticLink(true)
    let isReturnProp = (p:FPropertyPtr) => (p.getPropertyFlags() and CPF_ReturnParm) == CPF_ReturnParm
    fn.parmsSize = uprops.foldl(a + b.getSize(), 0)
   
    fn

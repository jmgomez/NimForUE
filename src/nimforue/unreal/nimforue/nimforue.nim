import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/[unrealstring, array]
import nimforuebindings
import ../../macros/uebind
import std/strformat
include ../definitions



import std/[typetraits, strutils, sequtils, sugar]
#This file contains logic on top of ue types that it isnt necessarily bind 

#not sure if I should make a specific file for object extensions that are outside of the bindings
proc getDefaultObjectFromClassName*(clsName:FString) : UObjectPtr = getClassByName(clsName).getDefaultObject()


proc getFPropsFromUStruct*(ustr:UStructPtr, flags=EFieldIterationFlags.None) : seq[FPropertyPtr] = 
    var xs : seq[FPropertyPtr] = @[]
    var fieldIterator = makeTFieldIterator[FProperty](ustr, flags)
    for it in fieldIterator:
        xs.add it.get()
    xs
proc getFuncsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[UFunctionPtr] = 
    var xs : seq[UFunctionPtr] = @[]
    var fieldIterator = makeTFieldIterator[UFunction](cls, flags)
    for it in fieldIterator:
        xs.add it.get()
    xs


proc getPropsWithFlags*(fn:UFunctionPtr, flag:EPropertyFlags) : TArray[FPropertyPtr] = 
    let isIn = (p:FPropertyPtr) => flag in p.getPropertyFlags()

    getFPropertiesFrom(fn).filter(isIn)


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
    
    let uprops : seq[FPropertyPtr] = fnField.signature.map(p=>(createProperty(fn, p)))
   
    cls.addFunctionToFunctionMap(fn, fnName)

    fn.setNativeFunc(makeFNativeFuncPtr(fnImpl))
    
    fn.staticLink(true)
    fn.parmsSize = uprops.foldl(a + b.getSize(), 0)
   
    fn

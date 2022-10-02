import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/[unrealstring, array]
import nimforuebindings
import ../../macros/uebind
import std/[strformat, options]
include ../definitions
import ../../typegen/models
import ../../utils/[utils, ueutils]

import std/[typetraits, strutils, sequtils, sugar]



#This file contains logic on top of ue types that it isnt necessarily bind 

#not sure if I should make a specific file for object extensions that are outside of the bindings
proc getDefaultObjectFromClassName*(clsName:FString) : UObjectPtr {.exportcpp.} = getClassByName(clsName).getDefaultObject()

proc removeFunctionFromClass*(cls:UClassPtr, fn:UFunctionPtr) =
    cls.removeFunctionFromFunctionMap(fn)
    cls.Children = fn.Next 

proc getFPropsFromUStruct*(ustr:UStructPtr, flags=EFieldIterationFlags.None) : seq[FPropertyPtr] = 
    var xs : seq[FPropertyPtr] = @[]
    var fieldIterator = makeTFieldIterator[FProperty](ustr, flags)
    for it in fieldIterator:
        let prop = it.get()
        # if CPF_BlueprintVisible in prop.getPropertyFlags():
        xs.add prop
    xs
proc getFuncsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[UFunctionPtr] = 
    var xs : seq[UFunctionPtr] = @[]
    var fieldIterator = makeTFieldIterator[UFunction](cls, flags)
    for it in fieldIterator:
        let fn = it.get()
      #  if FUNC_BlueprintCallable in fn.functionFlags: 
        xs.add fn
    xs

proc getFuncsParamsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[FPropertyPtr] = 
    cls
    .getFuncsFromClass(flags)
    .mapIt(it.getFPropsFromUStruct(flags))
    .foldl(a & b, newSeq[FPropertyPtr]())
        


#it will call super until UObject is reached
iterator getClassHierarchy*(cls:UClassPtr) : UClassPtr = 
    var super = cls
    let uObjCls = staticClass[UObject]()
    while super != uObjCls:
        super = super.getSuperClass()
        yield super

func getFirstCppClass*(cls:UClassPtr) : UClassPtr =
    for super in getClassHierarchy(cls):
        if tryUECast[UNimClassBase](super).isSome():
            continue
        return super

proc getPropsWithFlags*(fn:UFunctionPtr, flag:EPropertyFlags) : TArray[FPropertyPtr] = 
    let isIn = (p:FPropertyPtr) => flag in p.getPropertyFlags()

    getFPropertiesFrom(fn).filter(isIn)



    
type UFunctionNativeSignature* = proc (context:UObjectPtr, stack:var FFrame,  result: pointer) : void {. cdecl .}


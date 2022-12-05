import ../coreuobject/[uobject, unrealtype, templates/subclassof, nametypes]
import ../core/containers/[unrealstring, map, array]
import nimforuebindings
import ../../macros/uebind
import std/[strformat, options]
include ../definitions
import ../../typegen/models
import ../../utils/[utils, ueutils]
import ../core/enginetypes
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
        xs.add prop
    xs
proc getFuncsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[UFunctionPtr] = 
    var xs : seq[UFunctionPtr] = @[]
    var fieldIterator = makeTFieldIterator[UFunction](cls, flags)
    for it in fieldIterator:
        let fn = it.get()
        xs.add fn
    xs

proc getFuncsParamsFromClass*(cls:UClassPtr, flags=EFieldIterationFlags.None) : seq[FPropertyPtr] = 
    cls 
    .getFuncsFromClass(flags)
    .mapIt(it.getFPropsFromUStruct(flags))
    .foldl(a & b, newSeq[FPropertyPtr]())
        
proc getAllPropsOf*[T : FProperty](ustr:UStructPtr) : seq[ptr T] = 
    ustr.getFPropsFromUStruct()
        .filterIt(castField[T](it).isNotNil())
        .mapIt(castField[T](it))

   
proc getAllPropsWithMetaData*[T : FProperty](ustr:UStructPtr, metadataKey:string) : seq[ptr T] = 
    ustr.getAllPropsOf[:T]()
        .filterIt(it.hasMetaData(metadataKey))

#it will call super until UObject is reached
iterator getClassHierarchy*(cls:UClassPtr) : UClassPtr = 
    var super = cls
    let uObjCls = staticClass[UObject]()
    while super != uObjCls:
        super = super.getSuperClass()
        yield super

func isBPClass(cls:UClassPtr) : bool =
    result = (CLASS_CompiledFromBlueprint.uint32 and cls.classFlags.uint32) != 0
    

func getFirstCppClass*(cls:UClassPtr) : UClassPtr =
    for super in getClassHierarchy(cls):
        if super.isNimClass() or super.isBPClass():
            continue
        return super

proc getPropsWithFlags*(fn:UFunctionPtr, flag:EPropertyFlags) : TArray[FPropertyPtr] = 
    let isIn = (p:FPropertyPtr) => flag in p.getPropertyFlags()

    getFPropertiesFrom(fn).filter(isIn)


proc `$`*(obj:UObjectPtr) : string = 
    if obj.isNil(): "nill"
    else: $obj.getName()


#Probably these should be repr

func `$`*(prop:FPropertyPtr):string=
  let meta = prop.getMetadataMap()
  &"Prop: {prop.getName()} CppType: {prop.getCppType()} Flags: {prop.getPropertyFlags()} Metadata: {meta}"


    

func `$`*(fn:UFunctionPtr):string = 
  let metadataMap = fn.getMetadataMap()
  if metadataMap.len() > 0:
    metadataMap.remove(n"Comment")
    metadataMap.remove(n"ToolTip")
  let params = getFPropsFromUStruct(fn).mapIt($it).join("\n\t")
    #PROPS?
  &"""Func: {fn.getName()} Flags: {fn.functionFlags} Metadata: {metadataMap}
  
  Params: 
    {params}
  """
    
include ../unreal/prelude
include ../utils/utils
import std/[sugar, macros, strutils, strformat, genasts, sequtils, options]

import uemeta

#Maybe it should hold the old type, the ptr to the struct and the func gen. So we can check for changes?


#Global var that contains all the emitters. Only modififed via the funcs below

#[ FRom pywrapper object 1800
    const FString OldClassName = MakeUniqueObjectName(OldClass->GetOuter(), OldClass->GetClass(), *FString::Printf(TEXT("%s_REINST"), *OldClass->GetName())).ToString();
		OldClass->ClassFlags |= CLASS_NewerVersionExists;
		OldClass->SetFlags(RF_NewerVersionExists);
		OldClass->ClearFlags(RF_Public | RF_Standalone);
		OldClass->Rename(*OldClassName, nullptr, REN_DontCreateRedirectors);
]#


type 
    EmitterInfo = object
        generator : UPackagePtr->UStructPtr
        ueType : UEType
        uStructPointer : UStructPtr

    UEEmitter* = ref object 
        emitters : seq[EmitterInfo]


var ueEmitter = UEEmitter() 

proc prepareClassForReinst(prevClass : UClassPtr) = 
    # prevClass.classFlags = prevClass.classFlags | CLASS_NewerVersionExists
    prevClass.addClassFlag CLASS_NewerVersionExists
    prevClass.setFlags(RF_NewerVersionExists)
    prevClass.clearFlags(RF_Public | RF_Standalone)
    let prevNameStr : FString =  fmt("{prevClass.getName()}_REINST")
    let oldClassName = makeUniqueObjectName(prevClass.getOuter(), prevClass.getClass(), makeFName(prevNameStr))
    discard prevClass.rename(oldClassName.toFString(), nil, REN_DontCreateRedirectors)

proc prepareScriptStructForReinst(prevScriptStruct : UScriptStructPtr) = 
    prevScriptStruct.addScriptStructFlag(STRUCT_NewerVersionExists)
    prevScriptStruct.setFlags(RF_NewerVersionExists)
    prevScriptStruct.clearFlags(RF_Public | RF_Standalone)
    let prevNameStr : FString =  fmt("{prevScriptStruct.getName()}_REINST")
    let oldClassName = makeUniqueObjectName(prevScriptStruct.getOuter(), prevScriptStruct.getClass(), makeFName(prevNameStr))
    discard prevScriptStruct.rename(oldClassName.toFString(), nil, REN_DontCreateRedirectors)


proc addEmitterInfo*(ueType:UEType, fn : UPackagePtr->UStructPtr) : void =  
    ueEmitter.emitters.add(EmitterInfo(ueType:ueType, generator:fn))

proc emitUStructsForPackage*(pkg: UPackagePtr) : FNimHotReloadPtr = 
    var hotReloadInfo = newNimHotReload()

    for emitter in ueEmitter.emitters:
        case emitter.ueType.kind:
        of uetStruct:
            let prevStructPtr = getScriptStructByName emitter.ueType.name.removeFirstLetter()
            let thereIsPrevStruct = not prevStructPtr.isNil()
            if thereIsPrevStruct:
                prevStructPtr.prepareScriptStructForReinst()
            
            let newStructPtr = ueCast[UScriptStruct](emitter.generator(pkg))
            if thereIsPrevStruct:
                hotReloadInfo.bShouldHotReload = true
                hotReloadInfo.structsToReinstance.add(prevStructPtr, newStructPtr)
                UE_Log "ScriptStruct already exists: " & emitter.ueType.name & " will be replaced"
            else:
                UE_Log "ScriptStruct added: " & emitter.ueType.name
        of uetClass:
            let prevClassPtr = getClassByName emitter.ueType.name.removeFirstLetter()
            let thereIsPrevCls = not prevClassPtr.isNil()
            if thereIsPrevCls:
                prevClassPtr.prepareClassForReinst()

            let newClassPtr = ueCast[UNimClassBase](emitter.generator(pkg))
            if thereIsPrevCls:
                hotReloadInfo.bShouldHotReload = true
                hotReloadInfo.classesToReinstance.add(prevClassPtr, newClassPtr)
                UE_Log "Class already exists: " & emitter.ueType.name & " will be replaced"
            else:
                UE_Log "Class added: " & emitter.ueType.name
        of uetEnum:
            discard
    hotReloadInfo

func emitUStruct(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => toUStruct[name](typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]
    # debugEcho repr result

func emitUClass(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => toUClass(typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]

macro emitType*(typeDef : static UEType) : untyped = 
    case typeDef.kind:
        of uetClass: discard
        of uetStruct: 
            result = emitUStruct(typeDef)
        of uetEnum: discard



#iterate childrens and returns a sequence fo them
func childrenAsSeq*(node:NimNode) : seq[NimNode] =
    var nodes : seq[NimNode] = @[]
    for n in node:
        nodes.add n
    nodes

func fromStringAsMetaToFlag(meta:seq[string]) : (EPropertyFlags, seq[UEMetadata]) = 
    # var flags : EPropertyFlags = CPF_SkipSerialization
    var flags : EPropertyFlags = CPF_NoDestructor
    var metadata : seq[UEMetadata] = @[]
    # var flags : EPropertyFlags = CPF_None
    #TODO a lot of flags are mutually exclusive, this is a naive way to go about it
    for m in meta:
        if m == "BlueprintReadOnly":
            flags = flags | CPF_BlueprintVisible | CPF_BlueprintReadOnly
        if m == "BlueprintReadWrite":
            flags = flags | CPF_BlueprintVisible
        if m == "EditAnywhere":
            flags = flags | CPF_Edit
        if m == "ExposeOnSpawn":
                flags = flags | CPF_ExposeOnSpawn
                metadata.add(UEMetadata(name:"ExposeOnSpawn", value:true))
        if m == "VisibleAnywhere":
                flags = flags | CPF_SimpleDisplay
        if m == "Transient":
                flags = flags | CPF_Transient
        
    (flags, metadata)
        


func fromUPropNodeToField(node : NimNode) : seq[UEField] = 
    let metas = node.childrenAsSeq()
                    .filter(n=>n.kind==nnkIdent and n.strVal().toLower() != "uprop")
                    .map(n=>n.strVal())
                    .fromStringAsMetaToFlag()

    #TODO Metas to flags
    let ueFields = node.childrenAsSeq()
                   .filter(n=>n.kind==nnkStmtList)
                   .head()
                   .map(childrenAsSeq)
                   .get(@[])
                   .map(n => makeFieldAsUProp(n[0].repr, n[1].repr.strip(), metas[0], metas[1]))
    ueFields


func getMetasForType(body:NimNode) : seq[UEMetadata] = 
    body.toSeq()
        .filter(n=>n.kind==nnkPar or n.kind == nnkTupleConstr)
        .map(n => n.children.toSeq())
        .foldl( a & b, newSeq[NimNode]())
        .map(n=>n.strVal().strip())
        .map(makeUEMetadata)

func getUPropsAsFieldsForType(body:NimNode) : seq[UEField] = 
    body.toSeq()
        .filter(n=>n.kind == nnkCall and n[0].strVal() == "uprop")
        .map(fromUPropNodeToField)
        .foldl(a & b)
    
macro uStruct*(name:untyped, body : untyped) : untyped = 
    let structTypeName = name.strVal()#notice that it can also contains of meaning that it inherits from another struct
    let structMetas = getMetasForType(body)
    let ueFields = getUPropsAsFieldsForType(body)
    let structFlags = (STRUCT_NoFlags)
    let ueType = makeUEStruct(structTypeName, ueFields, "", structMetas, structFlags)

    emitUStruct(ueType) 

macro uClass*(name:untyped, body : untyped) : untyped = 
    if name.toSeq().len() < 3:
        error("uClass must explicitly specify the base class. (i.e UMyObject of UObject)", name)

    let parent = name[^1].strVal()
    let className = name[1].strVal()
    let classMetas = getMetasForType(body)
    let ueFields = getUPropsAsFieldsForType(body)
    let classFlags = (CLASS_Inherit | CLASS_ScriptInherit ) #| CLASS_CompiledFromBlueprint
    let ueType = makeUEClass(className, parent, classFlags, ueFields, classMetas)
    
    emitUClass(ueType)
  


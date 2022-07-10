include ../unreal/prelude
include ../utils/utils
import std/[sugar, macros, strutils, genasts, sequtils, options]

import uemeta

#Maybe it should hold the old type, the ptr to the struct and the func gen. So we can check for changes?

#Global var that contains all the emitters. Only modififed via the funcs below
type 
    UEEmitter* = ref object 
        uStructsEmitters : seq[UPackagePtr->UStructPtr]
        uStructsPtrs : seq[UStructPtr]

var ueEmitter = UEEmitter() 

proc addUStructEmitter*(fn : UPackagePtr->UStructPtr) : void =  ueEmitter.uStructsEmitters.add(fn)

proc emitUStructsForPackage*(pkg: UPackagePtr) : void = 
    for structEmmitter in ueEmitter.uStructsEmitters:
        let scriptStruct = structEmmitter(pkg)
        ueEmitter.uStructsPtrs.add(scriptStruct)
        UE_Log "Struct created with emit type " & scriptStruct.getName()


proc destroyAllUStructs*() : void = 
    for structPtr in ueEmitter.uStructsPtrs:
        UE_Log "Destroying struct " & structPtr.getName()
        structPtr.conditionalBeginDestroy()
    ueEmitter.uStructsEmitters = @[]
    ueEmitter.uStructsPtrs = @[]

func emitUStruct(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addUStructEmitter((package:UPackagePtr) => toUStruct[name](typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]
    # debugEcho repr result


func emitUClass(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addUStructEmitter((package:UPackagePtr) => toUClass(typeDefAsNode, package))

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

func fromStringAsMetaToFlag(meta:seq[string]) : EPropertyFlags = 
    var flags : EPropertyFlags = CPF_None
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
        
    flags
        


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
                   .map(n => makeFieldAsUProp(n[0].repr, n[1].repr.strip(), metas))
    ueFields

macro uStruct*(name:untyped, body : untyped) : untyped = 
    let structTypeName = name.strVal()#notice that it can also contains of meaning that it inherits from another struct


    let structMetas = body.childrenAsSeq()
                   .filter(n=>n.kind==nnkPar or n.kind == nnkTupleConstr)
                   .map(n => n.children.toSeq())
                   .foldl( a & b, newSeq[NimNode]())
                   .map(n=>n.strVal().strip())
                   .map(makeUEMetadata)


    let ueFields = body.childrenAsSeq()
                       .filter(n=>n.kind == nnkCall and n[0].strVal() == "uprop")
                       .map(fromUPropNodeToField)
                       .foldl(a & b)

    let ueType = makeUEStruct(structTypeName, ueFields, "", structMetas)
    
    emitUStruct(ueType)

macro uClass*(name:untyped, body : untyped) : untyped = 
    let className = name.strVal()#notice that it can also contains of meaning that it inherits from another struct


    let classMetas = body.childrenAsSeq()
                   .filter(n=>n.kind==nnkPar or n.kind == nnkTupleConstr)
                   .map(n => n.children.toSeq())
                   .foldl( a & b, newSeq[NimNode]())
                   .map(n=>n.strVal().strip())
                   .map(makeUEMetadata)


    let ueFields = body.childrenAsSeq()
                       .filter(n=>n.kind == nnkCall and n[0].strVal() == "uprop")
                       .map(fromUPropNodeToField)
                       .foldl(a & b)

    let classFlags = (CLASS_Inherit | CLASS_ScriptInherit )

    let ueType = makeUEClass(className, "UObject", classFlags, ueFields, classMetas)
    
    emitUClass(ueType)


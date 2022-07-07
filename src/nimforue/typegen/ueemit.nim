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

proc genUStructsForPackage*(pkg: UPackagePtr) : void = 
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
    debugEcho repr result

macro emitType*(typeDef : static UEType) : untyped = 
    case typeDef.kind:
        of uClass: discard
        of uStruct: 
            result = emitUStruct(typeDef)
        of uEnum: discard




#iterate childrens and returns a sequence fo them
func childrenAsSeq*(node:NimNode) : seq[NimNode] =
    var nodes : seq[NimNode] = @[]
    for n in node:
        nodes.add n
    nodes


func fromUPropNodeToField(node : NimNode) : seq[UEField] = 
    let metas = node.childrenAsSeq()
                    .filter(n=>n.kind==nnkIdent and n.strVal().toLower() != "uprop")

    let flags = CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn
    #TODO Metas to flags
    let ueFields = node.childrenAsSeq()
                   .filter(n=>n.kind==nnkStmtList)
                   .head()
                   .map(childrenAsSeq)
                   .get(@[])
                   .map(n => makeFieldAsUProp(n[0].repr, n[1].repr.strip(), flags))
    ueFields

macro UStruct*(name:untyped, body : untyped) : untyped = 

    let structTypeName = name.strVal()#notice that it can also contains of meaning that it inherits from another struct

    let ueFields = body.childrenAsSeq()
                       .filter(n=>n.kind == nnkCall and n[0].strVal() == "uprop")
                       .map(fromUPropNodeToField)
                       .foldl(a & b)

    let ueType = makeUEStruct(structTypeName, ueFields)
    
    emitUStruct(ueType)


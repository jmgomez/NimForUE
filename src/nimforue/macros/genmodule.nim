import std/[options, osproc, strutils,sugar, sequtils,strformat,  genasts, macros, importutils, os]

include ../unreal/definitions
import ../utils/ueutils

import ../utils/utils
import ../unreal/coreuobject/[uobjectflags]
import ../typegen/[nuemacrocache, models]

import uebind




func genUClassTypeDefBinding(t: UEType, r: UERule = uerNone): seq[NimNode] =
    if r == uerCodeGenOnlyFields: 
        @[]
    else:
        @[
            # type Type* {.importcpp.} = object of Parent
            nnkTypeDef.newTree(
                nnkPragmaExpr.newTree(
                    nnkPostFix.newTree(ident "*", ident t.name),
                    nnkPragma.newTree(
                        nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")),
                        nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
                    )
                ),
                newEmptyNode(),
                nnkObjectTy.newTree(
                    newEmptyNode(), 
                    nnkOfInherit.newTree(ident t.parent),
                    newEmptyNode()
                )
            ),
            # ptr type TypePtr* = ptr Type
            nnkTypeDef.newTree(
                nnkPostFix.newTree(ident "*", ident t.name & "Ptr"),
                newEmptyNode(),
                nnkPtrTy.newTree(ident t.name)
            )
        ]

func genUClassImportTypeDefBinding(t: UEType, r: UERule = uerNone): seq[NimNode] =
    if r == uerCodeGenOnlyFields: 
        @[]
    else:
        @[
            # type Type* {.importcpp.} = object of Parent
            nnkTypeDef.newTree(
                nnkPragmaExpr.newTree(
                    nnkPostFix.newTree(ident "*", ident t.name),
                    nnkPragma.newTree(
                        nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")),
                        ident "inheritable",
                        nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
                    )
                ),
                newEmptyNode(),
                nnkObjectTy.newTree(
                    newEmptyNode(), 
                    nnkOfInherit.newTree(ident t.parent),
                    newEmptyNode()
                )
            ),
            # ptr type TypePtr* = ptr Type
            nnkTypeDef.newTree(
                nnkPostFix.newTree(ident "*", ident t.name & "Ptr"),
                newEmptyNode(),
                nnkPtrTy.newTree(ident t.name)
            )
        ]

func genUEnumTypeDefBinding(t: UEType): NimNode =
    let enumTy = t.fields
                        .map(f => ident f.name)
                        .foldl(a.add b, nnkEnumTy.newTree)
    enumTy.insert(0, newEmptyNode()) #required empty node in enums
    nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            nnkPostFix.newTree(ident "*", ident t.name),
            nnkPragma.newTree(nnkExprColonExpr.newTree(ident "size", nnkCall.newTree(ident "sizeof", ident "uint8")), ident "pure")
        ),
        newEmptyNode(),
        enumTy
    )


func genUStructImportCTypeDefBinding(t: UEType): NimNode =
    var recList = t.fields
        .map(prop => nnkIdentDefs.newTree(
                getFieldIdent(prop), 
                prop.getTypeNodeFromUProp(), 
                newEmptyNode()
            )
        )
        .foldl(a.add b, nnkRecList.newTree)
    nnkTypeDef.newTree(
        nnkPragmaExpr.newTree([
            nnkPostfix.newTree([ident "*", ident t.name]),
            nnkPragma.newTree(
                ident "inject",
                nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")),
                nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h"))
            )
        ]),
        newEmptyNode(),
        nnkObjectTy.newTree(
            newEmptyNode(), newEmptyNode(), recList
        )
    )





func genImportCProp(typeDef : UEType, prop : UEField) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
  
    let className = typeDef.name.substr(1)

    let typeNode = case prop.kind:
                    of uefProp: getTypeNodeFromUProp(prop)
                    else: newEmptyNode() #No Support 
    let typeNodeAsReturnValue = case prop.kind:
                            of uefProp: prop.getTypeNodeForReturn(typeNode)
                            else: newEmptyNode()#No Support as UProp getter/Seter
    
    
    let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)).nimToCppConflictsFreeName()

    let setPropertyName = newStrLitNode(&"set{prop.name.firstToLow()}(@)")
    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, setPropertyName, typeNodeAsReturnValue):
            proc `propIdent`* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue {. importcpp:"$1(@)", header:"UEGenBindings.h" .}
            proc `propIdent=`*(obj {.inject.} : ptrName, val {.inject.} : typeNode) : void {. importcpp: setPropertyName, header:"UEGenBindings.h" .}
          
    
func genUClassImportCTypeDef(typeDef : UEType, rule : UERule = uerNone) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
    let parent = ident typeDef.parent
    let props = nnkStmtList.newTree(
                typeDef.fields
                    .filter(prop=>prop.kind==uefProp)
                    .map(prop=>genImportCProp(typeDef, prop)))

    let funcs = nnkStmtList.newTree(
                    typeDef.fields
                       .filter(prop=>prop.kind==uefFunction)
                       .map(fun=>genImportCFunc(typeDef, fun)))
    
    #[
    let typeDecl = if rule == uerCodeGenOnlyFields: newEmptyNode()
                   else: genAst(name = ident typeDef.name, ptrName, parent, props, funcs):
                    type  #notice the header is temp.
                        name* {.inject, importcpp.} = object of parent #TODO OF BASE CLASS 
                        ptrName* {.inject.} = ptr name
    ]# 
    result = 
        genAst(props, funcs):
            props
            funcs








proc genImportCTypeDecl*(typeDef : UEType, rule : UERule = uerNone) : NimNode =
    case typeDef.kind:
        of uetClass: 
            genUClassImportCTypeDef(typeDef, rule)
        of uetStruct:
            genUStructTypeDef(typeDef, rule, uexImport)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate: #No exporting dynamic delegates. Not sure if they make sense at all. 
            genDelType(typeDef, uexImport)



proc genDelTypeDef*(delType:UEType, exposure:UEExposure) : NimNode = 
    let typeName = ident delType.name
    
    let delBaseType = 
        case delType.delKind 
        of uedelDynScriptDelegate: ident "FScriptDelegate"
        of uedelMulticastDynScriptDelegate: ident "FMulticastScriptDelegate"
    
    if exposure == uexImport:
        genAst(typeName, delBaseType):
                typeName {. inject, importcpp, header:"UEGenBindings.h".} = object of delBaseType
    else:
        genAst(typeName, delBaseType):
                typeName {. inject, exportcpp.} = object of delBaseType



proc genImportCModuleDecl*(moduleDef:UEModule) : NimNode =
    result = nnkStmtList.newTree()

    var typeSection = nnkTypeSection.newTree()
    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
            of uetClass: 
                typeSection.add genUClassImportTypeDefBinding(typeDef, rules)
            of uetStruct:
                typeSection.add genUStructImportCTypeDefBinding(typedef)
            of uetEnum:
                typeSection.add genUEnumTypeDefBinding(typedef)
            of uetDelegate:
                typeSection.add genDelTypeDef(typeDef, uexImport)
                
    result.add typeSection

    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
        of uetClass:
            result.add genImportCTypeDecl(typeDef, rules)
        # of uetDelegate: #TODO genDelFuncs
        #     result.add genDelType(typeDef, uexImport)
        else:
            continue

proc genExportModuleDecl*(moduleDef:UEModule) : NimNode = 
    result = nnkStmtList.newTree()

    var typeSection = nnkTypeSection.newTree()
    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
        of uetClass:
            typeSection.add genUClassTypeDefBinding(typedef, rules)
        of uetStruct:
            typeSection.add genUStructTypeDefBinding(typedef, rules)
        of uetEnum:
            typeSection.add genUEnumTypeDefBinding(typedef)
        of uetDelegate:
            typeSection.add genDelTypeDef(typeDef, uexExport)
        else: continue
    result.add typeSection

    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
        of uetClass, uetStruct:
            result.add genTypeDecl(typeDef, rules, uexExport)
        #  of uetDelegate: #TODO genDelFuncs
        #     result.add genDelType(typeDef, uexExport)
        else: continue

proc genModuleRepr*(moduleDef: UEModule, isImporting: bool): string =
    #TODO import/export should be local to add cohesion to the funcs
    let moduleNode = if isImporting: genImportCModuleDecl(moduleDef) else: genExportModuleDecl(moduleDef)
    let preludePath = "include " & (if isImporting: "" else: "../") & "../prelude\n"

    preludePath & 
        #"{.experimental:\"codereordering\".}\n" &
        moduleDef.dependencies.mapIt("import " & it.toLower()).join("\n") &
        repr(moduleNode)
            .multiReplace(
        ("{.inject.}", ""),
        ("{.inject, ", "{."),
        ("<", "["),
        (">", "]"), #Changes Gen. Some types has two levels of inherantce in cpp, that we dont really need to support
        ("::Type", ""), #Enum namespaces EEnumName::Type
        ("::Mode", ""), #Enum namespaces EEnumName::Type
        ("::", "."), #Enum namespace
        ("__DelegateSignature", ""))
    
#notice this is only for testing ATM the final shape probably wont be like this
macro genUFun*(className : static string, funField : static UEField) : untyped =
    let ueType = UEType(name:className, kind:uetClass) #Notice it only looks for the name and the kind (delegates)
    genFunc(ueType, funField)
        

proc genHeaders*(moduleDef: UEModule,  headersPath: string) = 
    #There is one main header that pulls the rest.
    #Every other header is in the module paths
    let validCppParents = ["UObject", "AActor", "UInterface", "UActorComponent", "UDeveloperSettings"]#TODO this should be introduced as param

    let getParentName = (uet:UEType) => uet.parent & 
        (if uet.parent in validCppParents or uerCodeGenOnlyFields == getAllMatchingRulesForType(moduleDef, uet): "" else: "_")

    let classDefs = moduleDef.types
                        .filterIt(it.kind == uetClass and uerCodeGenOnlyFields != getAllMatchingRulesForType(moduleDef, it))
                        .mapIt(&"class {it.name}_ : public {getParentName(it)}{{}};\n")
                        .join()
   
    let headerName = (name:string) => &"{name.firstToUpper()}.h"
    let includeHeader = (name:string) => &"#include \"{headerName(name)}\" \n"
    let headerPath = headersPath / "Modules" / headerName(moduleDef.name)
    let deps = moduleDef
                .dependencies
                .map(includeHeader)
                .join()
    let headerContent = &"""
#pragma once
#include "UEDeps.h"
{deps}
{classDefs}
"""
    writeFile(headerPath, headerContent)
    #Main header
    let headersAsDeps = 
        walkDir( headersPath / "Modules")
        .toSeq()
        .filterIt(it[0] == pcFile and it[1].endsWith(".h"))
        .mapIt(it[1].split("\\")[^1].replace(".h", ""))
        .mapIt("Modules/" & it)
        .map(includeHeader)
        .join()

    let mainHeaderPath = headersPath / "UEGenClassDefs.h"
    let headerAsDep = includeHeader(moduleDef.name)
    let mainHeaderContent = &"""
#pragma once
#include "UEDeps.h"
{headersAsDeps}
"""
    # if headerAsDep notin mainHeaderContent:
    writeFile(mainHeaderPath, mainHeaderContent)
    
macro genBindings*(moduleDef: static UEModule, exportPath: static string, importPath: static string, headersPath: static string) =
    proc genCode(filePath: string, preludePath: string, moduleDef: UEModule, moduleNode: NimNode) =
        let code = 
            preludePath & 
            #"{.experimental:\"codereordering\".}\n" &
            moduleDef.dependencies.mapIt("import " & it.toLower()).join("\n") &
            repr(moduleNode)
                .multiReplace(
            ("{.inject.}", ""),
            ("{.inject, ", "{."),
            ("<", "["),
            (">", "]"), #Changes Gen. Some types has two levels of inherantce in cpp, that we dont really need to support
            ("::Type", ""), #Enum namespaces EEnumName::Type
            ("::Mode", ""), #Enum namespaces EEnumName::TypeB
            ("::", "."), #Enum namespace

            ("__DelegateSignature", ""))
        writeFile(filePath, code)

    genCode(exportPath, "include ../../prelude\n", moduleDef, genExportModuleDecl(moduleDef))
    genCode(importPath, "include ../prelude\n", moduleDef, genImportCModuleDecl(moduleDef))

    genHeaders(moduleDef, headersPath)
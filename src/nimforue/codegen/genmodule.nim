import std/[options, osproc, strutils, sugar, sequtils, strformat, strutils, genasts, macros, importutils, os]

import ../utils/ueutils

import ../utils/utils
import ../unreal/coreuobject/[uobjectflags]
import ../codegen/[nuemacrocache, models, modulerules, projectinstrospect]
import ../../buildscripts/nimforueconfig
import uebind

type CodegenTarget = enum
  ctImport
  ctExport
  ctVM

func genUClassExportTypeDefBinding(ueType: UEType, rule: UERule = uerNone) : seq[NimNode] =
  let pragmas = 
    if ueType.isInPCH:
      nnkPragmaExpr.newTree(
          nnkPostFix.newTree(ident "*", ident ueType.name),
          nnkPragma.newTree(ident "importcpp", ident "inheritable", ident "pure")
        )
    else:
      nnkPragmaExpr.newTree(
          nnkPostFix.newTree(ident "*", ident ueType.name),
          nnkPragma.newTree(
            # ident "exportc",#, newStrLitNode("$1_")), #Probably we dont need _ anymore but it be useful to see the distinction when debugging the code, if so it needs to be passed to the template
            nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1_")), 
            ident "inheritable",
            ident "pure",
            # nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
            # nnkExprColonExpr.newTree(ident "codegenDecl", ident "UClassTemplate")
        )
      )
  let isNothingToDo = rule == uerCodeGenOnlyFields or ueType.forwardDeclareOnly or ueType.name in NimDefinedTypesNames
  if isNothingToDo: @[]    
  else:
    @[
      nnkTypeDef.newTree(
        pragmas,
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident ueType.parent),
          newEmptyNode()
        )
      ),
      # ptr type TypePtr* = ptr Type
      nnkTypeDef.newTree(
        nnkPostFix.newTree(ident "*", ident ueType.name & "Ptr"),
        newEmptyNode(),
        nnkPtrTy.newTree(ident ueType.name)
      )
    ]


func genUClassImportTypeDefBinding(ueType: UEType, rule: UERule = uerNone): seq[NimNode] =
  let pragmas = 
    if ueType.isInPCH:
      nnkPragmaExpr.newTree(
          nnkPostFix.newTree(ident "*", ident ueType.name),
          nnkPragma.newTree(ident "importcpp", ident "inheritable", ident "pure")
        )
    else:
      nnkPragmaExpr.newTree(
          nnkPostFix.newTree(ident "*", ident ueType.name),
          nnkPragma.newTree(
            nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")), #Probably we dont need _ anymore but it be useful to see the distinction when debugging the code, if so it needs to be passed to the template
            ident "inheritable",
            ident "pure",
            nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
        )
      )
      
  if rule == uerCodeGenOnlyFields or ueType.forwardDeclareOnly or ueType.name in NimDefinedTypesNames:
    @[]
  else:
    @[
      # type Type* {.importcpp.} = object of Parent
      nnkTypeDef.newTree(
        pragmas,
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident ueType.parent),
          newEmptyNode()
        )
      ),
      # ptr type TypePtr* = ptr Type
      nnkTypeDef.newTree(
        nnkPostFix.newTree(ident "*", ident ueType.name & "Ptr"),
        newEmptyNode(),
        nnkPtrTy.newTree(ident ueType.name)
      )
    ]

func genUClassVMTypeDefBindings(ueType: UEtype, rule: UERule = uerNone): seq[NimNode] = 
  if rule == uerCodeGenOnlyFields or ueType.forwardDeclareOnly or ueType.name in NimDefinedTypesNames:
    @[]
  else:
    @[
      # type Type* = object of Parent
      nnkTypeDef.newTree(
        nnkPostFix.newTree(ident "*", ident ueType.name),
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident ueType.parent),
          newEmptyNode()
        )
      ),
      # ptr type TypePtr* = ptr Type
      nnkTypeDef.newTree(
        nnkPostFix.newTree(ident "*", ident ueType.name & "Ptr"),
        newEmptyNode(),
        nnkPtrTy.newTree(ident ueType.name)
      )
    ]

func genUEnumTypeDefBinding(ueType: UEType, target: CodegenTarget): NimNode =
  let pragmas = 
    case target:
    of ctImport, ctExport: 
      nnkPragma.newTree(nnkExprColonExpr.newTree(ident "size", nnkCall.newTree(ident "sizeof", ident "uint8")), ident "pure")
    of ctVM: newEmptyNode()

  let enumTy = ueType.fields
    .map(f => ident f.name)
    .foldl(a.add b, nnkEnumTy.newTree)
  enumTy.insert(0, newEmptyNode()) #required empty node in enums
  nnkTypeDef.newTree(
    nnkPragmaExpr.newTree(
      nnkPostFix.newTree(ident "*", ident ueType.name),
      pragmas
    ),
    newEmptyNode(),
    enumTy
  )


func genUStructCodegenTypeDefBinding(ueType: UEType, target: CodegenTarget): NimNode =
  #TODO move export here and separate it enterely from the dsl

  let pragmas = 
    case target:
    of ctImport:
      (if ueType.isInPCH:     
        nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(
            ident "inject",
            ident "inheritable",
            ident "pure",
            nnkPragma.newTree(ident "importcpp", ident "inheritable", ident "pure")
          )
        ])
      else:
        nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(
          ident "inject",
          ident "inheritable",
          ident "pure",
          nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h"))
        )
        ])
      )
    of ctExport: newEmptyNode() #TODO
    of ctVM:
        nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(       
          ident "inheritable",          
        )
        ])
      
  var recList = ueType.fields
    .map(prop => nnkIdentDefs.newTree(
        getFieldIdentWithPCH(ueType, prop, target == ctImport),
        prop.getTypeNodeFromUProp(isVarContext=false),
        newEmptyNode()
      )
    )
    .foldl(a.add b, nnkRecList.newTree)
  nnkTypeDef.newTree(pragmas,
    newEmptyNode(),
    nnkObjectTy.newTree(
      newEmptyNode(), newEmptyNode(), recList
    )
  )



func genImportCProp(typeDef: UEType, prop: UEField): NimNode =
  let ptrName = ident typeDef.name & "Ptr"
  let className = typeDef.name.substr(1)
  let typeNode = case prop.kind:
    of uefProp: getTypeNodeFromUProp(prop, isVarContext=false)
    else: newEmptyNode() #No Support
  let typeNodeAsReturnValue = case prop.kind:
    of uefProp: prop.getTypeNodeForReturn(typeNode)
    else: newEmptyNode() #No Support as UProp getter/Seter
  let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)).nimToCppConflictsFreeName()
  let setPropertyName = newStrLitNode(&"set{prop.name.firstToLow()}(@)")
  result =
    genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, setPropertyName, typeNodeAsReturnValue):
      proc `propIdent`*(obj {.inject.}: ptrName): typeNodeAsReturnValue {.importcpp: "$1(@)", header: "UEGenBindings.h".}
      proc `propIdent=`*(obj {.inject.}: ptrName, val {.inject.}: typeNode): void {.importcpp: setPropertyName, header: "UEGenBindings.h".}


func genUClassImportCTypeDef(typeDef: UEType, rule: UERule = uerNone): NimNode =
  let ptrName = ident typeDef.name & "Ptr"
  let parent = ident typeDef.parent
  let props = nnkStmtList.newTree(
                            typeDef.fields
                              .filter(prop=>prop.kind == uefProp)
                              .map(prop=>genImportCProp(typeDef, prop)))

  let funcs = nnkStmtList.newTree(
                            typeDef.fields
                              .filter(prop=>prop.kind == uefFunction)
                              .map(fun=>genImportCFunc(typeDef, fun)))

  result =
    genAst(props, funcs):
      props
      funcs
  if not (typeDef.forwardDeclareOnly and typeDef.isInCommon): #the common def doesnt have interfaces
    result = nnkStmtList.newTree(genInterfaceConverers(typeDef), result)


proc genImportCTypeDecl*(typeDef: UEType, rule: UERule = uerNone): NimNode =
  case typeDef.kind:
    of uetClass:
      genUClassImportCTypeDef(typeDef, rule)
    of uetStruct:
      genUStructTypeDef(typeDef, rule, uexImport)
    of uetEnum:
      genUEnumTypeDef(typeDef, uexImport)
    of uetDelegate: #No exporting dynamic delegates. Not sure if they make sense at all.
      genDelType(typeDef, uexImport)
    of uetInterface:
      error("Interfaces are not supported yet")
      newEmptyNode()

proc genDelTypeDef*(delType: UEType, exposure: UEExposure): NimNode =
  let typeName = identPublic delType.name

  let delBaseType =
    case delType.delKind
    of uedelDynScriptDelegate: ident "FScriptDelegate"
    of uedelMulticastDynScriptDelegate: ident "FMulticastScriptDelegate"

  if exposure == uexImport:
    genAst(typeName, delBaseType):
      typeName {.inject, importcpp: "$1_", header: "UEGenBindings.h".} = object of delBaseType
  else:
    genAst(typeName, delBaseType):
      typeName {.inject, exportcpp: "$1_".} = object of delBaseType

proc genImportCModuleDecl*(moduleDef: UEModule): NimNode =
  result = nnkStmtList.newTree()
  var typeSection = nnkTypeSection.newTree()
  for typeDef in moduleDef.types:
    let rules = moduleDef.getAllMatchingRulesForType(typeDef)
    case typeDef.kind:
      of uetClass:
        typeSection.add genUClassImportTypeDefBinding(typeDef, rules)
      of uetStruct:
        typeSection.add genUStructCodegenTypeDefBinding(typedef, ctImport)
      of uetEnum:
        typeSection.add genUEnumTypeDefBinding(typedef, ctImport)
      of uetDelegate:
        typeSection.add genDelTypeDef(typeDef, uexImport)
      of uetInterface:
        error("Interfaces are not supported yet")      
  
  result.add typeSection
  for typeDef in moduleDef.types:
    let rules = moduleDef.getAllMatchingRulesForType(typeDef)
    case typeDef.kind:
    of uetClass:
      result.add genImportCTypeDecl(typeDef, rules)    
    else:
      continue

proc genExportModuleDecl*(moduleDef: UEModule): NimNode =
  result = nnkStmtList.newTree()
  var typeSection = nnkTypeSection.newTree()
  for typeDef in moduleDef.types:
    let rules = moduleDef.getAllMatchingRulesForType(typeDef)
    case typeDef.kind:
    of uetClass:
      typeSection.add genUClassExportTypeDefBinding(typeDef, rules)
    of uetStruct:
      typeSection.add genUStructTypeDefBinding(typedef, rules)
    of uetEnum:
      typeSection.add genUEnumTypeDefBinding(typedef, ctExport)
    of uetDelegate:
      typeSection.add genDelTypeDef(typeDef, uexExport)
    of uetInterface:
      error("Interfaces are not supported yet")

  result.add typeSection
  for typeDef in moduleDef.types:
    let rules = moduleDef.getAllMatchingRulesForType(typeDef)
    case typeDef.kind:
    of uetClass, uetStruct, uetEnum:
      result.add genTypeDecl(typeDef, rules, uexExport)   
    else: continue

proc genVMModuleDecl*(moduleDef: UEModule): NimNode =
  ##Let's start only with classes
  result = nnkStmtList.newTree()
  var typeSection = nnkTypeSection.newTree()
  for typeDef in moduleDef.types:
    let rules = moduleDef.getAllMatchingRulesForType(typeDef)
    case typeDef.kind:
    of uetClass:
      typeSection.add genUClassVMTypeDefBindings(typeDef, rules)
    of uetStruct:
      typeSection.add genUStructCodegenTypeDefBinding(typedef, ctVM)
    of uetEnum:
      typeSection.add genUEnumTypeDefBinding(typedef, ctVM)
    else: continue
  
  result.add typeSection



proc genCode(filePath: string, moduleStrTemplate: string, moduleDef: UEModule, moduleNode: NimNode, target:CodegenTarget) =
  proc getImport(moduleName: string): string =
      let isOneFilePkg = "/" notin moduleDef.name
      var moduleName = moduleName.toLower()
      if moduleDef.name.split("/")[0] == moduleName.split("/")[0]: 
        let depName = moduleName.toLower().split("/")[^1]
        &"import {depName}"
      else:
        if isOneFilePkg: &"import {moduleName}" #we are in the same level that the module root
        else:
          case target:
            of ctImport: &"import ../../imported/{moduleName}" #we are inside a module folder and need to go up one level
            of ctExport: &"import ../../exported/{moduleName}"
            of ctVM:     &"import ../../vm/{moduleName}" 

  let code =
    moduleStrTemplate &
    #"{.experimental:\"codereordering\".}\n" &
    moduleDef.dependencies.map(getImport).join("\n") &
    repr(moduleNode)
      .multiReplace(
    ("{.inject.}", ""),
    ("{.inject, ", "{."),
    ("<", "["),
    (">", "]"),     #Changes Gen. Some types has two levels of inherantce in cpp, that we dont really need to support
    ("::Type", ""), #Enum namespaces EEnumName::Type
    ("::Outcome", ""), #Enum namespaces EEnumName::Outcome
    ("::Mode", ""), #Enum namespaces EEnumName::Mode
    ("::Primitive", ""), #Enum namespaces EEnumName::Mode
    ("::", "."),    #Enum namespace
    ("\"##", "  ##"),
    ("__DelegateSignature", ""))
  writeFile(filePath, code)

proc getModuleHashFromFile*(filePath: string): Option[string] =
  try:
    if not fileExists(filePath): return none[string]()
    readLines(filePath, 1)
      .head()
      .map(line => line.split(":")[^1].strip())
  except:
    return none[string]()

macro genProjectBindings*(project: static UEProject, pluginDir: static string) =
  let bindingsDir = pluginDir / BindingsDir
  let nimHeadersDir = pluginDir / NimHeadersDir # need this to store forward decls of classes
  for module in project.modules:
    let module = module
    let isOneFilePkg = "/" notin module.name
    let moduleFolder = module.name.toLower().split("/")[0]
    let actualModule = module.name.toLower().split("/")[^1]
    let path = 
      if isOneFilePkg: actualModule
      else: moduleFolder / actualModule        
    let exportBindingsPath = bindingsDir / "exported" / path & ".nim"
    let importBindingsPath = bindingsDir / "imported" / path & ".nim"
    let vmBindingsPath = bindingsDir / "vm" / path & ".nim"
    let prevModHash = getModuleHashFromFile(importBindingsPath).get("_")
    if prevModHash == module.hash and uerIgnoreHash notin module.rules:
      echo "Skipping module: " & module.name & " as it has not changed"
      # continue
    let preludeRelative =  if isOneFilePkg: "../" else: "../../"            
    let moduleImportStrTemplate = &"""
#hash:{module.hash}
when not defined(nimsuggest):
  include {preludeRelative}../prelude
  const BindingPrefix {{.strdefine.}} = ""  
  {{.compile: BindingPrefix&"{module.name.tolower().replace("/", "@s")}.nim.cpp".}}
   
"""
    let moduleExportStrTemplate = &"""
include {preludeRelative}../prelude
proc keep{module.name.replace("/", "")}() {{.exportc.}} = discard    
"""

    let vmEngineTypes = if isOneFilePkg: "enginetypes" else: "../enginetypes"
    let moduleVMStrTemplate = &"""
import {vmEngineTypes}
"""    

    echo &"Generating bindings for {module.name}"
    genCode(importBindingsPath, moduleImportStrTemplate, module, genImportCModuleDecl(module), ctImport)
    genCode(exportBindingsPath, moduleExportStrTemplate, module, genExportModuleDecl(module), ctExport)
    genCode(vmBindingsPath, moduleVMStrTemplate, module, genVMModuleDecl(module), ctVM)
    # genHeaders(module, nimHeadersDir)

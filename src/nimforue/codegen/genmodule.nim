import std/[options, osproc, strutils, sugar, sequtils, strformat, strutils, genasts, macros, importutils, os]

import ../utils/ueutils

import ../utils/utils
import ../unreal/coreuobject/[uobjectflags]
import ../codegen/[nuemacrocache, models, modulerules, projectinstrospect]
import ../../buildscripts/nimforueconfig
import uebind, uebindcore
import ../vm/vmmacros


func genUClassExportTypeDefBinding(ueModule: UEModule, ueType: UEType, rule: UERule = uerNone) : seq[NimNode] =
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
            nnkExprColonExpr.newTree(ident "codegenDecl", newStrLitNode ueType.getClassTemplate(true)), 
            ident "inheritable",
            ident "pure",
            # nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
            # nnkExprColonExpr.newTree(ident "codegenDecl", ident "UClassTemplate")
        )
      )
  if ueType.forwardDeclareOnly or (ueType.name in NimDefinedTypesNames and ueModule.name != ManuallyImportedModule):
    # debugEcho "[export] nothing to do for " & ueType.name
    @[]    
  else:
    @[
      nnkTypeDef.newTree(
        pragmas,
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident ueType.parent),
          ueType.genPropsAsRecList(rule, false)
        )
      ),
      # ptr type TypePtr* = ptr Type
      nnkTypeDef.newTree(
        nnkPostFix.newTree(ident "*", ident ueType.name & "Ptr"),
        newEmptyNode(),
        nnkPtrTy.newTree(ident ueType.name)
      )
    ]


func genUClassImportTypeDefBinding(ueModule: UEModule, ueType: UEType, rule: UERule = uerNone): seq[NimNode] =
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
            nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h"))
        )
      )
      
  if (ueType.forwardDeclareOnly) or (ueType.name in NimDefinedTypesNames and ueModule.name != ManuallyImportedModule):
    # debugEcho "[import] nothing to do for " & ueType.name
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
          ueType.genPropsAsRecList(rule, true)
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
  if rule == uerCodeGenOnlyFields or ueType.forwardDeclareOnly or 
    ueType.name in NimDefinedTypesNames: @[]
  else: genVMClassTypeDef(ueType)

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
  var getterImport = newStrLitNode "$1(@)"
  if typeNodeAsReturnValue.repr.contains("var "):
    getterImport = newStrLitNode "(*$1(@))" #avoids importcpp to import it by copy producing #fixes #26

  if CPF_BlueprintAssignable in prop.propFlags:
    result = 
      genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, typeNodeAsReturnValue):
        proc `propIdent`*(obj {.inject.}: ptrName): (UObjectPtr, ptr FMulticastDelegateProperty) = 
          let prop {.inject.}  = obj.getClass.getFPropertyByName(propUEName).castField[:FMulticastDelegateProperty]()
          (obj, prop)
  else:
    result =
      genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, setPropertyName, typeNodeAsReturnValue, getterImport):
        proc `propIdent`*(obj {.inject.}: ptrName): typeNodeAsReturnValue {.importcpp: getterImport, header: "UEGenBindings.h".}
        proc `propIdent=`*(obj {.inject.}: ptrName, val {.inject.}: typeNode): void {.importcpp: setPropertyName, header: "UEGenBindings.h".}


func genUClassImportCTypeDef(typeDef: UEType, rule: UERule = uerNone): NimNode =
  let ptrName = ident typeDef.name & "Ptr"
  let parent = ident typeDef.parent
  let props = nnkStmtList.newTree(
                            typeDef.fields
                              .filter(prop => typeDef.shouldGenGetterSetters(prop, false))
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
    result = nnkStmtList.newTree(genInterfaceConverers(typeDef, uexImport), result)


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
        typeSection.add genUClassImportTypeDefBinding(moduleDef, typeDef, rules)
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


#TODO at some point use it generated uClasses too
proc makeVTableConstructor*(uet: UEType): NimNode = 
  assert uet.kind == uetClass
  let fnName = ident "make" & uet.name.capitalizeAscii()
  let typ = ident uet.name
  let suffix = if uet.isParentInPCH or uet.parent in ManuallyImportedClasses: ""
               else: "_"
  let ctorContent = newLit &"""$1('1& #1):{uet.parent}{suffix}(#1)"""
  genAst(fnName, typ, ctorContent):
    proc fnName(helper{.inject.} : FVTableHelper): typ {.constructor:ctorContent.} = 
      discard

proc genExportModuleDecl*(moduleDef: UEModule): NimNode =
  result = nnkStmtList.newTree()
  var typeSection = nnkTypeSection.newTree()
  for typeDef in moduleDef.types:
    let rules = moduleDef.getAllMatchingRulesForType(typeDef)
    case typeDef.kind:
    of uetClass:
      typeSection.add genUClassExportTypeDefBinding(moduleDef, typeDef, rules)
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
      # if typeDef.kind == uetClass and not typeDef.isInPCH: 
        # if (moduleDef.isCommon and typeDef.isInCommon) or (not moduleDef.isCommon and not typeDef.forwardDeclareOnly):          
        #   result.add makeVTableConstructor(typeDef)   
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
    of uetDelegate:
      typeSection.add genDelegateVMTypeDefBinding(typeDef, ctVM)
    else: continue
  
  result.add typeSection
  for typeDef in moduleDef.types:
    case typeDef.kind:
    of uetClass:
      result.add genUCalls(typeDef)
    else: continue



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

  proc shoudGenImports(dep: string): bool = 
    moduleDef.name.split("/")[^1].toLower notin ["delegates", "enums"]
   
  
  let code =
    moduleStrTemplate &
    #"{.experimental:\"codereordering\".}\n" &
    
    moduleDef.dependencies
      .filter(shoudGenImports) #skip impots for these as they dont have deps
      .map(getImport).join("\n") &
    repr(moduleNode)
      .multiReplace(
    ("{.inject.}", ""),
    ("{.inject, ", "{."),
    ("<", "["),
    (">", "]"),     #Changes Gen. Some types has two levels of inherantce in cpp, that we dont really need to support
    # ("::Type", ""), #Enum namespaces EEnumName::Type
    # ("::Outcome", ""), #Enum namespaces EEnumName::Outcome
    # ("::Mode", ""), #Enum namespaces EEnumName::Mode
    # ("::Primitive", ""), #Enum namespaces EEnumName::Mode
    # ("::", "."),    #Enum namespace
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
    when not defined(skipCodegenCache):
      let prevModHash = getModuleHashFromFile(importBindingsPath).get("_")
      if prevModHash == module.hash and uerIgnoreHash notin module.rules:
        echo "Skipping module: " & module.name & " as it has not changed"
        continue
    let preludeRelative =  if isOneFilePkg: "../" else: "../../"            
    let moduleImportStrTemplate = &"""
#hash:{module.hash}
when not defined(nimsuggest) and not defined(nimcheck):
  include {preludeRelative}../prelude
  const BindingPrefix {{.strdefine.}} = ""  
  {{.compile: BindingPrefix&"{module.name.tolower().replace("/", "@s")}.nim.cpp".}}
   
"""
    let moduleExportStrTemplate = &"""
include {preludeRelative}../prelude
proc keep{module.name.replace("/", "")}() {{.exportc.}} = discard    
"""

    let vmEngineTypes = if isOneFilePkg: "vmtypes" else: "../vmtypes"
    let runtimeFields = (if isOneFilePkg: "" else: "../") & "../../../vm/[runtimefield, exposed]"
    let moduleVMStrTemplate = &"""
import std/[options]
import utils/[ueutils]
import {vmEngineTypes}
import {runtimeFields}
"""    
    echo &"Generating bindings for {module.name}."
    genCode(importBindingsPath, moduleImportStrTemplate, module, genImportCModuleDecl(module), ctImport)
    genCode(exportBindingsPath, moduleExportStrTemplate, module, genExportModuleDecl(module), ctExport)
    genCode(vmBindingsPath, moduleVMStrTemplate, module, genVMModuleDecl(module), ctVM)
    # genHeaders(module, nimHeadersDir)

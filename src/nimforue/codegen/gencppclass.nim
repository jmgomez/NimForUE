import std/[sequtils, strutils, strformat, sugar, macros, genasts, os, strutils]
import ../../buildscripts/nimforueconfig
import ../codegen/[models, modulerules]
import ../utils/[ueutils, utils]


  #no fields for now. They could be technically added though



func convertNimTypeStrToCpp(nimType:string) : string = 
  #would this need to handle the types with underscore (our fake types)?
  #todo handle numbers
  #nim int is 64 bits
  #nim float is 64 bits

  case nimType:
  of "int": "int64"
  of "float": "double"
  of "float32": "float"
  of "float64": "double"
  else:
    if nimType.endswith("Ptr"): nimType.removeLastLettersIfPtr() & "*"
    elif nimType.contains("var"): convertNimTypeStrToCpp(nimType.replace("var", "").strip()) & "&"
    elif nimType.isGeneric(): 
      nimType
        .applyFunctionToInnerGeneric(convertNimTypeStrToCpp)
        .replace("[", "<")
        .replace("]", ">") #only one level
    else: nimType


func funParamToStrSignature(param:CppParam) : string = 
  let constModifier = if param.modifiers == cmConst: "const" else: ""
  &"{constModifier} {convertNimTypeStrToCpp(param.typ)}  {param.name}"

func funParamsToStrSignature(fn:CppFunction) : string = fn.params.map(funParamToStrSignature).join(", ")

func funParamToCallWithModifiers(param:CppParam) : string = 
  if not param.typ.endsWith("Ptr") and not param.typ.contains("var"): 
    return convertNimTypeStrtoCpp(param.name)

  if param.modifiers == cmConst: 
    &"const_cast<{convertNimTypeStrtoCpp(param.typ)}>({param.name})" 
  else: param.name

func funParamsToCallWithModifiers(fn:CppFunction) : string = fn.params.map(funParamToCallWithModifiers).join(", ")
func funParamsToCall(fn:CppFunction) : string = fn.params.mapIt(it.name).join(", ")

func toStr*(cppCls: CppClassType): string =
  func funcForwardDeclare(fn:CppFunction) : string = 
    let constModifier = if fn.modifiers == cmConst: "const" else: ""
    let superReturn = if fn.returnType == "void": "" else: "return "
    let returnType = fn.returnType.convertNimTypeStrToCpp()
    let accessSpecifier = #not used
      case fn.accessSpecifier:
      of caPublic: "public"
      of caPrivate: "private"
      of caProtected: "protected"

    &"""
  virtual {returnType} {fn.name}({fn.funParamsToStrSignature()}) {constModifier} override;
  {returnType} {fn.name}Super({fn.funParamsToStrSignature()}) {{ {superReturn} {cppCls.parent}::{fn.name}({fn.funParamsToCall}); }}
    """
  
  let funcs = cppCls.functions.mapIt(it.funcForwardDeclare()).join("\n")
  let kind = if cppCls.kind == cckClass: "class" else: "struct"
  let parent = if cppCls.parent.len > 0: &"  : public {cppCls.parent}  " else: ""
  let constructors = if cppCls.isUObjectBased: &"""
public:
  {cppCls.name}() = default;
  {cppCls.name}(FVTableHelper& Helper) : {cppCls.parent}(Helper) {{}}
""" else : "" #TODO custom constructors?
 
  &"""
{kind} {cppCls.name} {parent} {{
  {constructors}
public:
{funcs}
  }};
  """


func `$`*(cppCls: CppClassType): string = toStr(cppCls)

func `$`*(cppHeader: CppHeader): string =
  let includes = cppHeader.includes.mapIt(&"#include \"{it}\"").join("\n")
  let classes = cppHeader.classes.mapIt(it.`$`()).join("\n")
  &"""
#pragma once
{includes}
{classes}
  """



proc saveHeader*(cppHeader: CppHeader, folder: string = ".") =
  if OutputHeader == "": return #TODO assert when done
  let path = PluginDir / folder / cppHeader.name 
  writeFile(path,  $cppHeader)

#Not used for UETypes. Will be used in the future when supporting non UObject base types.
func createNimType(typedef: CppClassType, header:string): NimNode = 
  let ptrName = ident typeDef.name & "Ptr"
  let parent = ident typeDef.parent
  result = genAst(name = ident typeDef.name, ptrName, parent):
          type 
            name* {.inject, importcpp, header:header .} = object of parent #TODO OF BASE CLASS 
            ptrName* {.inject.} = ptr name

func toEmmitTemplate*(fn:CppFunction, class:string) : string  = 
  let constModifier = if fn.modifiers == cmConst: "const" else: ""
  let this = if fn.modifiers == cmConst: &"const_cast<{class}*>(this)"  else: "this"

  let comma = if fn.params.len > 0: "," else: ""
  let returns = if fn.returnType == "void": "" else: "return "
  &"""

{fn.returnType.convertNimTypeStrToCpp} {class}::{fn.name}({fn.funParamsToStrSignature()}) {constModifier} {{
     {returns} {fn.name.firstToLow()}_impl({this} {comma} {fn.funParamsToCallWithModifiers()});
}}
  """

func genSuperFunc*(fn:NimNode, class:string) : NimNode = 
  let superName = fn.name.strVal.capitalizeAscii() & "Super"
  let name = ident(superName)
  let nameLit = newStrLitNode(superName)

  let clsNamePtr = ident class & "Ptr"
  result = genAst(name, nameLit, ):
    proc super() {.importcpp:nameLit.}
  result.params = fn.params 


func genOverride*(fn:NimNode, fnDecl : CppFunction, class:string) : NimNode = 
  let exportCppPragma =
    nnkExprColonExpr.newTree(
      ident("exportcpp"),
      newStrLitNode("$1_impl")#Import the cpp func. Not sure if the value will work across all the signature combination
    )
  #Adds the parameter to the nim function so we can call it
  fn.params.insert(1, nnkIdentDefs.newTree(ident "self", ident class & "Ptr", newEmptyNode()))
  fn.addPragma(exportCppPragma)
  fn.body.insert(0, genSuperFunc(fn, class))
  
  let toEmit = toEmmitTemplate(fnDecl, class)
  let override = 
    genAst(fn, toEmit):
      fn
      {.emit: toEmit.}
  result = override
  # debugEcho result.repr

#TODO change this for macro cache
var cppHeader* {.compileTime.} = CppHeader(name: OutputHeader, includes: @["UEDeps.h"])
var emittedClasses* {.compileTime.} = newSeq[string]()

# func getOrCreateCppClass*(name, parent :string) : CppClass = 
#   let cls = cppHeader.classes.filterIt(it.name == name)
#   if cls.len > 0: cls[0]
#   else:
#     CppClass(name: name, kind: cckClass, parent: parent, functions: @[])

const header = "UEGenClassDefs.h"
static:
  when defined(game):
    cppHeader.includes.add header


#Only function overrides
func toCppClass*(ueType:UEType) : CppClassType = 
    case ueType.kind:
    of uetClass:
      var parent = uetype.parent
      {.cast(noSideEffect).}:
        if not ueType.isParentInPCH and parent notin (ManuallyImportedClasses & emittedClasses):
          parent = ueType.parent & "_" #The fake classes have a _ at the end we need to remove the emitted classes from here as well

      CppClassType(name:ueType.name, kind: cckClass, isUObjectBased:true, parent:parent, functions: ueType.fnOverrides)
    of uetStruct: #Structs can keep inhereting from Nim structs for now. We will need to do something about the produced fields in order to gen funcs. 
      CppClassType(name:ueType.name, kind: cckStruct, parent:ueType.superStruct, functions: @[])
    else:
      error("Cant convert a non class or struct to a CppClassType")
      CppClassType() 

proc addCppClass*(class: CppClassType) =
  
  cppHeader.classes.add class
  saveHeader(cppHeader, "NimHeaders") #it would be better to do it only once



#notice even though the name says cpp we are converting Nim types to string here. The cpp is only to show that it has to do with the cpp generation
#in the future this can be standalone and then we can remove the cpp part of the name
func getCppTypeFromParamType(paramType:NimNode) : string = 
  case paramType.kind:
    of nnkIdent: paramType.strVal
    of nnkVarTy: "var " & getCppTypeFromParamType(paramType[0])
    of nnkBracketExpr: 
        #only arity one for now
        &"{paramType[0].strVal}[{paramType[1].strVal}]"

    else:
      debugEcho treeRepr paramType
      error("Cant parse param type " & paramType.repr)
      ""

func isParamCppConst(identDef:NimNode) : bool = 
    assert identDef.kind == nnkIdentDefs
    case identDef[0].kind:
    of nnkIdent: false
    # of nnkBracket: false
    of nnkPragmaExpr: identDef[0][1][0].strVal == "constcpp"
    else: 
      error("Cant parse param pragma " & identDef[0].kind.repr)
      false


         
func getCppParamFromIdentDefs(identDef : NimNode) : CppParam =
  assert identDef.kind == nnkIdentDefs

  let name = 
    case identDef[0].kind:
    of nnkIdent: identDef[0].strVal
    # of nnkBracket: identDef[0][0].strVal
    of nnkPragmaExpr: identDef[0][0].strVal
    else: 
      error("Cant parse param " & identDef[0].kind.repr) 
      ""
      
  let isConst = identDef.isParamCppConst()
  
  let modifiers = if isConst: cmConst else: cmNone
  let typ = getCppTypeFromParamType(identDef[1])
  CppParam(name: name, typ: typ, modifiers: modifiers)

func removeConstFromParam(identDef : NimNode) : NimNode =
  let isConst = identDef.isParamCppConst()
  result = identDef
  if isConst: #This remove all pragmas
    result[0] = identDef[0][0]


func getCppFunctionFromNimFunc(fn : NimNode) : CppFunction =
  let returnType = if fn.params[0].kind == nnkEmpty: "void" else: fn.params[0].strVal

  let isConstFn = fn.pragma.children.toSeq().filterIt(it.strVal() == "constcpp").any()
  let modifiers = if isConstFn: cmConst else: cmNone
  fn.pragma = newEmptyNode() #TODO remove const instead of removing all pragmas and move the pragmas to the impl
  let params = fn.params.filterIt(it.kind == nnkIdentDefs).map(getCppParamFromIdentDefs)
  let name =  fn.name.strVal.capitalizeAscii()
  CppFunction(name: name, returnType: returnType, params: params, modifiers: modifiers)



#TODO implement forwards
func overrideImpl(fn : NimNode, className:string) : (CppFunction, NimNode) =
  let cppFunc = getCppFunctionFromNimFunc(fn)
#   debugEcho treeRepr fn
  let paramsWithoutConst = fn.params.children.toSeq.filterIt(it.kind == nnkIdentDefs).map(removeConstFromParam)
  fn.params = nnkFormalParams.newTree(fn.params[0] & paramsWithoutConst)
  (cppFunc, genOverride(fn, cppFunc, className))


func getCppOverrides*(body:NimNode, typeName:string) : seq[(CppFunction, NimNode)] =    
    #TODO add forwards
    let overrideBlocks = 
            body.toSeq()
                .filterIt(it.kind == nnkCall and it[0].strVal().toLower() in ["override"])
    let overrides = overrideBlocks
        .mapIt(it[^1].children.toSeq())
        .flatten().filterIt(it.kind == nnkProcDef)
        .mapIt(overrideImpl(it, typeName))
    overrides

proc getTypeNodeFromUClassName(name:NimNode) : (string, string, seq[string]) =    
    let className = name[1].strVal()
    case name[^1].kind:
    of nnkIdent: 
        let parent = name[^1].strVal()
        (className, parent, newSeq[string]())
    of nnkCommand:
        let parent = name[^1][0].strVal()
        let iface = name[^1][^1][^1].strVal()
        (className, parent, @[iface])
    else:
        error("Cant parse the class " & repr name)
        ("", "", newSeq[string]())


proc genRawCppTypeImpl(name, body : NimNode, kind:CppClassKind) : NimNode =     
  let (className, parent, interfaces) = getTypeNodeFromUClassName(name)
  let overrides = getCppOverrides(body, className)  
  let cppType = CppClassType(name:className, kind: kind, 
    parent:parent, functions: overrides.mapIt(it[0]))
  addCppClass(cppType)   

  let  
    typeName = ident className
    typeNamePtr = ident $className & "Ptr"
    typeParent = ident parent
    typeDefs=
      genAst(typeName, typeNamePtr, typeParent):
        type 
          typeName {.importcpp.} = object of typeParent
          typeNamePtr = ptr typeName

  result = newStmtList(typeDefs & overrides.mapIt(it[1]))
  echo repr result


macro class*(name:untyped, body : untyped) : untyped = 
  genRawCppTypeImpl(name, body, cckClass)
macro struct*(name:untyped, body : untyped) : untyped = 
  genRawCppTypeImpl(name, body, cckStruct)





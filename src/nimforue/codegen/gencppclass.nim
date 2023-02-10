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

func `$`*(cppCls: CppClassType): string =
  func funcForwardDeclare(fn:CppFunction) : string = 
    let constModifier = if fn.modifiers == cmConst: "const" else: ""
    let superReturn = if fn.returnType == "void": "" else: "return "
    let returnType = fn.returnType.convertNimTypeStrToCpp()
    let accessSpecifier = 
      case fn.accessSpecifier:
      of caPublic: "public"
      of caPrivate: "private"
      of caProtected: "protected"

    &"""
{accessSpecifier}:
  virtual {returnType} {fn.name}({fn.funParamsToStrSignature()}) {constModifier} override;
  {returnType} {fn.name}Super({fn.funParamsToStrSignature()}) {{ {superReturn} {cppCls.parent}::{fn.name}({fn.funParamsToCall}); }}
    """
  
  let funcs = cppCls.functions.mapIt(it.funcForwardDeclare()).join("\n")
  let kind = if cppCls.kind == cckClass: "class" else: "struct"
  let parent = if cppCls.parent.len > 0: &"  : public {cppCls.parent}  " else: ""
 
  &"""
  DLLEXPORT {kind} {cppCls.name} {parent} {{
    {funcs}
  }};
  """

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
  debugEcho result.repr

#TODO change this for macro cache
var cppHeader* {.compileTime.} = CppHeader(name: OutputHeader, includes: @["UEDeps.h"])
var emittedClasses* {.compileTime.} = newSeq[string]()

# func getOrCreateCppClass*(name, parent :string) : CppClass = 
#   let cls = cppHeader.classes.filterIt(it.name == name)
#   if cls.len > 0: cls[0]
#   else:
#     CppClass(name: name, kind: cckClass, parent: parent, functions: @[])

# const header = "UEGenClassDefs.h"
# static:
#   when defined(game):
#     cppHeader.includes.add header


#Only function overrides
func toCppClass*(ueType:UEType) : CppClassType = 
    case ueType.kind:
    of uetClass:
        CppClassType(name:ueType.name, kind: cckClass, parent:ueType.parent, functions: ueType.fnOverrides)
    of uetStruct: #Structs can keep inhereting from Nim structs for now. We will need to do something about the produced fields in order to gen funcs. 
        CppClassType(name:ueType.name, kind: cckStruct, parent:ueType.superStruct, functions: @[])
    else:
        error("Cant convert a non class or struct to a CppClassType")
        CppClassType() 

proc addCppClass*(class: CppClassType) =
  var class = class
  if class.parent notin (ManuallyImportedClasses & emittedClasses) and class.kind == cckClass:
    class.parent =  class.parent & "_" #The fake classes have a _ at the end we need to remove the emitted classes from here as well

  
  cppHeader.classes.add class
  saveHeader(cppHeader, "NimHeaders") #it would be better to do it only once







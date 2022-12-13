import std/[sequtils, strutils, strformat, sugar, macros, genasts, os]
import ../../buildscripts/nimforueconfig
import ../codegen/modulerules
import ../utils/utils

type 
  CppParam* = object #TODO take const, refs, etc. into account
    name*: string
    typ*: string
  CppFunction* = object #visibility?
    name*: string
    returnType*: string
    params*: seq[CppParam] #void if none. this is not expressed as param
  CppClassKind* = enum #TODO add more
    cckClass, cckStruct
  CppClassType* = object
    name*, parent*: string
    functions*: seq[CppFunction]
    kind*: CppClassKind
  CppHeader* = object
    name*: string
    includes*: seq[string]
    classes*: seq[CppClassType]
  #no fields for now. They could be technically added though



func funParamsToStrSignature(fn:CppFunction) : string = fn.params.mapIt(it.typ & " " & it.name).join(", ")
func funParamsToStrCall(fn:CppFunction) : string = fn.params.mapIt(it.name).join(", ")

func `$`*(cppCls: CppClassType): string =
  func funcForwardDeclare(fn:CppFunction) : string = 
    &"virtual {fn.returnType} {fn.name}({fn.funParamsToStrSignature()}) override;"
    # &"virtual {fn.returnType} {fn.name}({fn.funParamsToStrSignature()}) override{{}};"
  let funcs = cppCls.functions.mapIt(it.funcForwardDeclare()).join("\n")
  let kind = if cppCls.kind == cckClass: "class" else: "struct"
  &"""
{kind} {cppCls.name} : public {cppCls.parent} {{
    public:
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

func toEmmitTemplate*(fn:CppFunction, class:string) : string  = 
  let comma = if fn.params.len > 0: "," else: ""
  let returns = if fn.returnType == "void": "" else: "return "
  &"""
    {fn.returnType} {class}::{fn.name}({fn.funParamsToStrSignature()}) {{
     {returns} {fn.name.firstToLow()}_impl(this {comma} {fn.funParamsToStrCall});
    }}
  """

proc saveHeader*(cppHeader: CppHeader, folder: string = ".") =
  let path = folder / cppHeader.name 
  writeFile(path,  $cppHeader)

#Not used for UETypes. Will be used in the future when supporting non UObject base types.
func createNimType(typedef: CppClassType, header:string): NimNode = 
  let ptrName = ident typeDef.name & "Ptr"
  let parent = ident typeDef.parent
  result = genAst(name = ident typeDef.name, ptrName, parent):
          type 
            name* {.inject, importcpp, header:header .} = object of parent #TODO OF BASE CLASS 
            ptrName* {.inject.} = ptr name

func implementOverride*(fn:NimNode, fnDecl : CppFunction, class:string) : NimNode = 
  let exportCppPragma =
    nnkExprColonExpr.newTree(
      ident("exportcpp"),
      newStrLitNode("$1_impl")#Import the cpp func. Not sure if the value will work across all the signature combination
    )
  fn.addPragma(exportCppPragma)
  
  let toEmit = toEmmitTemplate(fnDecl, class)
  genAst(fn, toEmit):
    fn
    {.emit: toEmit.}


#TODO change this for macro cache
var cppHeader* {.compileTime.} = CppHeader(name: OutputHeader, includes: @["UEDeps.h", "UEGenClassDefs.h"])


proc addClass*(class: CppClassType) =
  var class = class
  if class.parent notin ManuallyImportedClasses and class.kind == cckClass:
    class.parent =  class.parent & "_" #The fake classes have a _ at the end

  if class.name == "ANimBeginPlayOverrideActor":
    debugEcho "Function added"
    let beginPlay = CppFunction(name: "BeginPlay", returnType: "void", params: @[])
    class.functions.add(beginPlay)
    
  cppHeader.classes.add class
  saveHeader(cppHeader, "NimHeaders") #it would be better to do it only once






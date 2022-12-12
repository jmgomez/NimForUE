import std/[sequtils, strutils, strformat, sugar, macros, genasts, os]

import ../codegen/modulerules

type 
  CppParam* = object #TODO take const, refs, etc. into account
    name*: string
    typ*: string
  CppFunction* = object #visibility?
    name*: string
    returnType*: string
    params*: seq[CppParam] #void if none. this is not expressed as param
  CppClassType* = object
    name*, parent*: string
    functions*: seq[CppFunction]
  CppHeader* = object
    name*: string
    includes*: seq[string]
    classes*: seq[CppClassType]
  #no fields for now. They could be technically added though



func funParamsToStrSignature(fn:CppFunction) : string = fn.params.mapIt(it.typ & " " & it.name).join(", ")
func funParamsToStrCall(fn:CppFunction) : string = fn.params.mapIt(it.name).join(", ")

func `$`*(cppCls: CppClassType): string =
  func funcForwardDeclare(fn:CppFunction) : string = 
    &"virtual {fn.returnType} {fn.name}({fn.funParamsToStrSignature()}) const override;"
  let funcs = cppCls.functions.mapIt(it.funcForwardDeclare()).join("\n")
  &"""
class {cppCls.name} : public {cppCls.parent} {{
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
  &"""
    {fn.returnType} {class}::{fn.name}({fn.funParamsToStrSignature()}) {{
      {fn.name}_impl(this, {fn.funParamsToStrCall});
    }}
  """

proc saveHeader*(cppHeader: CppHeader, folder: string = ".") =
  let path = folder / cppHeader.name 
  writeFile(path,  $cppHeader)

#Not used for UETypes. Will be used in the future when supporting non UObject base types.
func createNimType(typedef: CppClassType): NimNode = 
  let ptrName = ident typeDef.name & "Ptr"
  let parent = ident typeDef.parent
  result = genAst(name = ident typeDef.name, ptrName, parent):
          type 
            name* {.inject, importcpp, header:"test.h" .} = object of parent #TODO OF BASE CLASS 
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

var cppHeader* {.compileTime.} = CppHeader(name: "test.h", includes: @["UEDeps.h", "UEGenClassDefs.h"]) #TODO change this for macro cache


proc addClass*(class: CppClassType) =
  var class = class
  if class.parent notin ManuallyImportedClasses:
    class.parent =  class.parent & "_" #The fake classes have a _ at the end

  cppHeader.classes.add class
  saveHeader(cppHeader, "NimHeaders") #it would be better to do it only once

# macro addClass*(class: CppClassType) =
  # cppHeader.classes.add class

  # let test = bindSym("AActor")
  # let impl =  test.getImpl()
  # debugEcho treeRepr impl

#the header should be in the cache

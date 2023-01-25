import std/[sequtils, strutils, strformat, sugar, macros, genasts, os]
import ../../buildscripts/nimforueconfig
import ../codegen/[models, modulerules]
import ../utils/utils


  #no fields for now. They could be technically added though



func funParamsToStrSignature(fn:CppFunction) : string = fn.params.mapIt(it.typ & " " & it.name).join(", ")
func funParamsToStrCall(fn:CppFunction) : string = fn.params.mapIt(it.name).join(", ")

func `$`*(cppCls: CppClassType): string =
  func funcForwardDeclare(fn:CppFunction) : string = 
    let accessSpecifier = 
      case fn.accessSpecifier:
      of caPublic: "public"
      of caPrivate: "private"
      of caProtected: "protected"

    &"""
{accessSpecifier}:
  virtual {fn.returnType} {fn.name}({fn.funParamsToStrSignature()}) override;
    """
    
#     &"""
# {accessSpecifier}:
#   virtual {fn.returnType} {fn.name}({fn.funParamsToStrSignature()}) override {{}};
#     """
    
  let funcs = cppCls.functions.mapIt(it.funcForwardDeclare()).join("\n")
  let kind = if cppCls.kind == cckClass: "class" else: "struct"
  let parent = if cppCls.parent.len > 0: &"  : public {cppCls.parent}  " else: ""
  let constructor = if cppCls.name == "ANimBeginPlayOverrideActor": 
      """DECLARE_CLASS_INTRINSIC(ANimBeginPlayOverrideActor, AActor, CLASS_MatchedSerializers, TEXT("/Script/Nim"))"""
      # "DECLARE_CLASS(ANimBeginPlayOverrideActor, AActor, 0, Engine);"
      # &"static void __DefaultConstructor(const FObjectInitializer& X) {{ new((EInternal*)X.GetObj())ANimBeginPlayOverrideActor; }}" 
    else: 
      ""
  # let extra = &"IMPLEMENT_CLASS_NO_AUTO_REGISTRATION({cppCls.name})"

  let extra = 
    if cppCls.name == "ANimBeginPlayOverrideActor": 
      # &"IMPLEMENT_CLASS_NO_AUTO_REGISTRATION({cppCls.name})"
       &"""IMPLEMENT_INTRINSIC_CLASS({cppCls.name}, NIMFORUE_API, AActor, ENGINE_API, "/Script/Nim", {{}});"""
      #  &"IMPLEMENT_CLASS_({cppCls.name}, 0);"
    else: 
      ""
  
  &"""
  DLLEXPORT {kind} {cppCls.name} {parent} {{
    public:
    {constructor}
    {funcs}
  }};
  {extra}
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
var cppHeader* {.compileTime.} = CppHeader(name: OutputHeader, includes: @["UEDeps.h"])
var emittedClasses* {.compileTime.} = newSeq[string]()
const header = "UEGenClassDefs.h"
static:
  when defined(game):
    cppHeader.includes.add header



proc addCppClass*(class: CppClassType) =
  var class = class
  if class.parent notin (ManuallyImportedClasses & emittedClasses) and class.kind == cckClass:
    class.parent =  class.parent & "_" #The fake classes have a _ at the end we need to remove the emitted classes from here as well

  if class.name == "ANimBeginPlayOverrideActor":
    debugEcho "Function added"
    let beginPlay = CppFunction(name: "BeginPlay", returnType: "void", accessSpecifier:caProtected, params: @[])
    class.functions.add(beginPlay)
    
    
  cppHeader.classes.add class
  saveHeader(cppHeader, "NimHeaders") #it would be better to do it only once







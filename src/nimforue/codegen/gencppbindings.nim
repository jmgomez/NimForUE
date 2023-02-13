include ../unreal/prelude
import std/[macros, sequtils, strutils,genasts, os]
import ../codegen/[models,uebind, uemeta]


#import all bindings in the exported directory so they can be exported when compiling this file
macro importAllBindings() : untyped = 
  let exportBindingsPath = "src/nimforue/unreal/bindings/exported/"
  let modules = 
        walkDir(exportBindingsPath)
        .toSeq()
        .filterIt(it[0] == pcFile and it[1].endsWith(".nim"))
        .filterIt(not it[1].contains("blueprintgraph_unrealed"))
        .mapIt(it[1].split(PathSeparator)[^1].replace(".nim", ""))
              
  func importStmts(modName:string) : NimNode =
    genAst(module=ident modName):
      import ../unreal/bindings/exported/module

  result = nnkStmtList.newTree(modules.map(importStmts))


importAllBindings()


# Include all files from in the bindings


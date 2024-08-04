include ../unreal/prelude
import std/[macros, sequtils, strutils,genasts, os]
import ../codegen/[models,uebind, uemeta]


#import all bindings in the exported directory so they can be exported when compiling this file
macro importAllBindings() : untyped =
  let exportBindingsPath = "src/nimforue/unreal/bindings/exported/"
  let modules =
        walkDirRec(exportBindingsPath)
        .toSeq()
        .filterIt(it.endsWith(".nim") and ManuallyImportedModule.toLower notin it)
        .mapIt(
          it.split(PathSeparator).join("/").split("bindings/exported/")[^1].replace(".nim", "").toLower)

  func importStmts(modName:string) : NimNode =
    genAst(module=ident modName):
      import ../unreal/bindings/exported/module

  result = nnkStmtList.newTree(modules.map(importStmts))

importAllBindings()

# We only compile this code to run the Nim VM on the reflectiondata to generate the nim bindings.
const codegen_nim_template* = """
import std/[os, strutils, strformat]
import ../nimforue/typegen/models
import ../nimforue/macros/uebind

const module* = $1
const bindingsPath = $2

macro genCode(module:static UEModule) =
  let code = repr(genModuleDecl(module))
              .multiReplace(
    ("{.inject.}", ""),
    ("{.inject, ", "{."),
    ("__DelegateSignature", "")
  )
  #It will require prelude 
  writeFile(bindingsPath, code)

genCode(module)
"""
# We only compile this code to run the Nim VM on the reflectiondata to generate the nim bindings.
const codegenNimTemplate* = """
import std/[os, strutils, strformat]
import ../nimforue/typegen/models
import ../nimforue/macros/uebind

const module* = $1
const bindingsPath = $2 
const cppBindingsPath = $3

macro genCode(module:static UEModule) =
  let code = genModuleRepr(module, false)
  writeFile(bindingsPath, code)

macro genImportCCode(module:static UEModule) =
  let code = genModuleRepr(module, true)
  writeFile(cppBindingsPath, code)

genCode(module)
genImportCCode(module)
"""
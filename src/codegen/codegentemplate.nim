# We only compile this code to run the Nim VM on the reflectiondata to generate the nim bindings.
const codegenNimTemplate* = """
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
    ("::Type", ""), #Enum namespaces EEnumName::Type
    ("::", "."), #Enum namespace
    ("__DelegateSignature", "")
  )
  #It will require prelude 
  writeFile(bindingsPath, "include ../prelude\n{.experimental:\"codereordering\".}\n" & code)

genCode(module)
"""
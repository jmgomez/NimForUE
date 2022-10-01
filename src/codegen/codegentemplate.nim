# We only compile this code to run the Nim VM on the reflectiondata to generate the nim bindings.
const codegenNimTemplate* = """
import std/[json, jsonutils]
import ../nimforue/typegen/models
import ../nimforue/macros/uebind

const module* = $1
const exportBindingsPath = $2
const importBindingsPath = $3
const genModuleHeadersDir = $4
genBindings(parseJson(module).jsonTo(UEModule), exportBindingsPath, importBindingsPath, genModuleHeadersDir)
"""
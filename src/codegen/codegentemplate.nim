import std/[strformat]

const genCodeHeader = """
include ../../prelude

{.experimental:"codereordering".}
import chaos
import whatever

"""

const genImportCCodeHeader = """
include ../prelude

{.experimental:"codereordering".}

"""


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
              
  
  #It will require prelude 
  writeFile(bindingsPath, code)

macro genImportCCode(module:static UEModule) =
  let code = genModuleRepr(module, true)
             
  #It will require prelude 
  writeFile(cppBindingsPath, code)




genCode(module)
genImportCCode(module)
"""
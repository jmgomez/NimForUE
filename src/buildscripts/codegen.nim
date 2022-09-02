import ../.reflectiondata/engine
import ../nimforue/macros/uebind
import ../nimforue/typegen/models

import std/[os, strutils, strformat]




macro genCode(module:static UEModule) =
  let code = repr(genModuleDecl(module)) 
  #It will require prelude 
  let path = "src"/"nimforue"/"unreal"/"bindings"/module.name.toLower() & ".nim"
  writeFile(path, code)
  echo &"Bindings generated for {module.name} in {path}"

genCode(module)
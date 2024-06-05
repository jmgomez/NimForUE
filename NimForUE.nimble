import std/strformat
import std/os
# Package

version       = "0.1.0"
author        = "jmgomez"
description   = "A plugin for UnrealEngine 5"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.1"

backend = "cpp"
#bin = @["nue"]

let buildNueCmd = &"nim cpp -p:./  -d:nimOldCaseObjects -d:nimBin={selfExe()}  --nimcache:./.nimcache/nue src/nue.nim" # see src/nue.nims for conf
task nue, "Build the NimForUE tool":
  exec buildNueCmd


task ok, "Make sure NUE and Host are built at least once (ment to be called for UBT)":
  let (output, _) = gorgeEx("./nue ok")
  if not output.contains "ok host built":
    exec buildNueCmd

task nuesetup, "Setup the plugin":
  exec buildNueCmd
  exec "./nue setup"

task shownim, "":
  echo getCurrentCompilerExe()

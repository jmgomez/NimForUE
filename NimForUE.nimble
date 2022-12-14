# Package

version       = "0.1.0"
author        = "jmgomez"
description   = "A plugin for UnrealEngine 5"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.4"

backend = "cpp"
#bin = @["nue"]

let buildNueCmd = "nim cpp -p:./ -d:danger --nimcache:./.nimcache/nue src/nue.nim" # see src/nue.nims for conf
task nue, "Build the NimForUE tool":
  exec buildNueCmd

task setup, "Setups the plugin":
  exec buildNueCmd
  exec "./nue setup"

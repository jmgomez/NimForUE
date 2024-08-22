import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig]

let androidSwitches = @[
  "--cc:clang",
  "-t:-stdlib=libc++",
  "-t:-fno-unsigned-char",
  "-t:-std=c++17",
  "-t:-fno-rtti",
  "-t:-fasm-blocks",
  "-t:-fvisibility-ms-compat",
  "-t:-fvisibility-inlines-hidden",
  "-t:-fno-delete-null-pointer-checks",
  "-t:-pipe",
  "-t:-fmessage-length=0",
  "-t:-Wno-macro-redefined",
  "-t:-Wno-duplicate-decl-specifier",
  "-t:-mincremental-linker-compatible",
  "-u:nimEmulateOverflowChecks",
  "--os:android",
] 

proc getPlatformSwitches*(withPch, withDebug : bool, target:string) : seq[string] = 
  let config = getNimForUEConfig()
  let platformDir =  "Android" #only used here so no need for const
  let nueModule = "NimForUE" # if target == "game": "NimForUEGame" else: "NimForUE"
  let pchPath = PluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / $config.targetConfiguration / nueModule / &"PCH.{nueModule}.h.gch"
  if withPch:
    androidSwitches & @["-t:"&escape("-include-pch " & pchPath)]
  else: androidSwitches


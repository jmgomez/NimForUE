import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig]

let config = getNimForUEConfig()

let macSwitches = @[
  "--cc:clang",
  "-t:-stdlib=libc++",
  "--putenv:MACOSX_DEPLOYMENT_TARGET=10.15",
  "-t:\"-x objective-c++\"",
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
]


proc getPlatformSwitches*(withPch, withDebug : bool, target:string) : seq[string] = 
  
  let platformDir =  "Mac/x86_64" 
  let nueModule = if target == "game": "NimForUEGame" else: "NimForUE"
  let pchPath = PluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / $config.targetConfiguration / nueModule / &"PCH.{nueModule}.h.gch"
  if withPch:

    macSwitches & @["-t:"&escape("-include-pch " & pchPath)]
  else: macSwitches


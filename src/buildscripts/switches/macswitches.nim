import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig, nimcachebuild]

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


proc getPlatformSwitches*(withPch, withDebug : bool) : seq[string] = 
  let platformDir =  "Mac/x86_64" 
  let pchPath = config.pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / $config.targetConfiguration / "NimForUE" / "PCH.NimForUE.h.gch"
  if withPch:
    macSwitches & @["-t:"&escape("-include-pch " & pchPath)]
  else: macSwitches


elif defined(windows):
  let pluginPlatformSwitches* = 
    # vccCompileFlags.mapIt("-t:" & (it)) & hostPlatformSwitches
    vccCompileFlags.mapIt("-t:" & (it)) & hostPlatformSwitches &
    (if withPCH:
      hostPlatformSwitches & @["-l:" & pchObjPath]
    else: @[])
        

else: discard

import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig, nimcachebuild]


let config = getNimForUEConfig()
const withDebug* = true
const withPCH* = true

let ueincludes* = getUEHeadersIncludePaths(config).map(headerPath => "-t:-I" & quotes(headerPath))
let uesymbols* = getUESymbols(config).map(symbolPath => "-l:" & quotes(symbolPath))


let buildSwitches* = @[

  "--outdir:./Binaries/nim/",
  "--mm:orc",
  "--backend:cpp",
  "--exceptions:cpp",
  "--warnings:off",
  "--ic:off",
  "--threads:off",
  "--path:$nim",
  # "--hints:off",
  "--hint:XDeclaredButNotUsed:off",
  "--hint:Name:off",
  "--hint:DuplicateModuleImport:off",
  "-d:useMalloc",
  "-d:withReinstantiation",
  "-d:genFilePath:" & quotes(config.genFilePath),
  "-d:pluginDir:" & quotes(config.pluginDir),

]


let targetSwitches* =
  case config.targetConfiguration:
    of Debug, Development:
      var ts = @["--opt:none"]
      if withDebug:
        ts &= @["--debugger:native", "--stacktrace:on"]
      ts
    of Shipping: @["--danger"]
      

let hostPlatformSwitches* =
  block:
    when defined windows:
      @[
        "--cc:vcc"
      ]
    elif defined macosx:
      
      @[
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
    else:
      @[]

#Plugin, not sure if it should belong here
let platformDir = 
  if config.targetPlatform == Mac: 
    "Mac/x86_64" 
  else: 
    $config.targetPlatform
  #I'm pretty sure there will more specific handles for the other platforms
  #/Volumes/Store/Dropbox/GameDev/UnrealProjects/NimForUEDemo/MacOs/Plugins/NimForUE/Intermediate/Build/Mac/x86_64/UnrealEditor/Development/NimForUE/PCH.NimForUE.h.gch
let pchPath = config.pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / $config.targetConfiguration / "NimForUE" / "PCH.NimForUE.h.gch"

let pluginPlatformSwitches* = 
        hostPlatformSwitches &
        (if withPCH: @["-t:"&escape("-include-pch " & pchPath)] else: @[])

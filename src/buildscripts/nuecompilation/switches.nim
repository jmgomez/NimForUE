
import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig, nimcachebuild]


let config = getNimForUEConfig()
const withDebug* = false
const withPCH* = false

proc foldIncludes(paths: seq[string]):string =
    paths.foldl(a & " -I" & quotes(b), " ")

let ueincludes* = getUEHeadersIncludePaths(config).map(headerPath => "--t:-I" & quotes(headerPath))
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



#WINDOWS SPECIFIC

# Find the definitions here:
# https://docs.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-alphabetically?view=msvc-170
# These flags are from the .response in the Intermediate folder for the UE Modules
# TODO?: get the flags from the PCH response file in Intermediate instead of hardcoding
let vccCompileFlags = [
"/c",
(if withDebug: "/Od /Z7" else: "/O2"), # To support hot reloading while debugging, we use /Z7 and regenerate the pdb each time from the guest pch objs. Using /Zi produces an LNK4204 error due to a mismatch between the winpch pdb and guestpch objs pdb.
"--platform:amd64",
"/nologo",
"/EHsc",
"-DWIN32_LEAN_AND_MEAN",
"/D_CRT_STDIO_LEGACY_WIDE_SPECIFIERS=1",
"/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS=1",
"/D_WINDLL",
"/D_DISABLE_EXTENDED_ALIGNED_STORAGE",
"/DPLATFORM_EXCEPTIONS_DISABLED=0",
"/FS",
"/Zc:inline", #Remove unreferenced functions or data if they're COMDAT or have internal linkage only (off by default).
"/Oi", # generate intrinsics
"/Gw", # Enables whole-program global data optimization.
"/Gy", # Enables function-level linking.
"/Ob2", # /Ob<n>	Controls inline expansion. 2 The default value under /O1 and /O2. Allows the compiler to expand any function not explicitly marked for no inlining.
#"/Ox", # A subset of /O2 that doesn't include /GF or /Gy. Enable Most Speed Optimizations
"/Ot", # Favors fast code.
"/GF", # Enables string pooling.
"/bigobj", # Increases the number of addressable sections in an .obj file.
"/GR-", # /GR[-]	Enables run-time type information (RTTI).
#"/std:c++latest", # unreal uses std:c++17, we need c++20 for designated initializers, but unreal uses c++latest if C++ 20 modules are enabled via ModuleRules bEnableCPPModules
"/std:c++20", # we're sticking to 20 for now (need to update as time goes on). unreal uses std:c++17, we need c++20 for designated initializers, but unreal uses c++latest if C++ 20 modules are enabled via ModuleRules bEnableCPPModules
"/Zc:strictStrings-", # need this for converting const char []  to NCString since it loses const, for std:c++20
"/Zp8",
"/source-charset:utf-8" ,
"/execution-charset:utf-8",
"/MD",
"/fp:fast", # "fast" floating-point model; results are less predictable.
#"/W4", # Set output warning level.
# /we<n>	Treat the specified warning as an error.
"/we4456",
"/we4458",
"/we4459",
"/we4668",
# /wd<n>  Disable the specified warning.
"/wd4819", 
"/wd4463",
"/wd4244",
"/wd4838"
]


when defined(macosx):
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

elif defined(windows):
  let pluginPlatformSwitches* = 
    vccCompileFlags.mapIt("-t:" & escape(it)) & hostPlatformSwitches
        

else: discard
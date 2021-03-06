# script to build the from .nimcache
import std / [os, osproc, strutils, sequtils, times, options, strformat, sugar, threadpool]
import nimforueconfig

template quotes(path: string): untyped =
  "\"" & path & "\""

const withPCH = true
const parallelBuild = true # for debugging purposes, normally we want to execute in parallel
const PCHFile = "UEDeps.h"

let nueConfig = getNimForUEConfig()
let platformDir = if nueConfig.targetPlatform == Mac: "Mac/x86_64" else: $nueConfig.targetPlatform
let confDir = $nueConfig.targetConfiguration
let engineDir = nueConfig.engineDir
let pluginDir = nueConfig.pluginDir
let cacheDir = pluginDir / ".nimcache/guestpch"

let isDebug = nueConfig.targetConfiguration in [Debug, Development]
let debugFlags =
  if isDebug:
    let pdbFile = quotes(pluginDir / ".nimcache/guestpch/nimforue.pdb")
    &"/Fd{pdbFile} /link /ASSEMBLYDEBUG /DEBUG /PDB:{pdbFile}"
  else:
    ""

type BuildStatus* = enum
  Success
  NoChange
  FailedCompile
  FailedLink


proc usesPCHFile(path: string): bool =
  for l in path.lines:
    if PCHFile in l:
      return true
    if "LANGUAGE_C" in l:
      break
  false




# Find the definitions here:
# https://docs.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-alphabetically?view=msvc-170
# These flags are from the .response in the Intermediate folder for the UE Modules
# TODO?: get the flags from the PCH response file in Intermediate instead of hardcoding
let CompileFlags = [
"/c",
(if isDebug: "/Od /Z7" else: "/O2"),
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
"/std:c++17",
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

let pchFilepath = pluginDir / ".nimcache/winpch/nue.win.pch"
proc pchFlags(shouldCreate: bool = false): string =
  # Precompiled header files https://docs.microsoft.com/en-us/cpp/build/creating-precompiled-header-files?view=msvc-170
  # /Yc https://docs.microsoft.com/en-us/cpp/build/reference/yc-create-precompiled-header-file?view=msvc-170
  # /Yu https://docs.microsoft.com/en-us/cpp/build/reference/yu-use-precompiled-header-file?view=msvc-170
  # /Fp https://docs.microsoft.com/en-us/cpp/build/reference/fp-name-dot-pch-file?view=msvc-170
  let Yflag = if shouldCreate: "/Yc" else: "/Yu"
  
  result = Yflag & PCHFile & " /Fp" & quotes(pchFilepath)

# User defined types can appear in Nim std lib cpp files
# When we import types from an external header when used with generic containers.
# We need to move the inclusion of Unreal headers above nimbase.h to get them to compile.
proc validateNimCPPHeaders(path: string): string =
  result = path
  if usesPCHFile(path):
    var dx = -1
    var ndx = -1
    var pdx = -1
    for line in path.lines:
      inc dx
      if "nimbase.h" in line:
        ndx = dx
      elif PCHFile in line:
        if ndx > -1:
          pdx = dx
        break
      elif "LANGUAGE_C" in line:
        break

    if ndx < pdx: # the nimbase.h comes before the PCHFile
      echo " Validating the headers for PCH. File: " & path
      # make a copy of the file and return the new path for the compile cmd
      var lines = path.lines.toSeq
      var pchlines = lines[(pdx-1)..pdx]
      lines.delete((pdx-1)..pdx)
      lines.insert(pchlines, ndx)

      result &= ".nue.cpp"
      writeFile(path & ".nue.cpp", lines.join("\n"))

proc isCompiled(path: string): bool = 
  let objpath = path & ".obj"
  return fileExists(objpath) and getLastModificationTime(objpath) > getLastModificationTime(path)

# example compile command
# vccexe.exe /c --platform:amd64  /nologo /EHsc -DWIN32_LEAN_AND_MEAN /FS /std:c++17 /Zp8 /source-charset:utf-8 /execution-charset:utf-8 /MD -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUE -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Source\NimForUEBindings\Public\ -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Inc\NimForUEBindings -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\NimHeaders -I"D:\UE_5.0\Engine\Source\Runtime\Engine\Classes" -I"D:\UE_5.0\Engine\Source\Runtime\Engine\Classes\Engine" -I"D:\UE_5.0\Engine\Source\Runtime\Net\Core\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Net\Core\Classes" -I"D:\UE_5.0\Engine\Source\Runtime\CoreUObject\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Core\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Engine\Public" -I"D:\UE_5.0\Engine\Source\Runtime\TraceLog\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Launch\Public" -I"D:\UE_5.0\Engine\Source\Runtime\ApplicationCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Projects\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Json\Public" -I"D:\UE_5.0\Engine\Source\Runtime\PakFile\Public" -I"D:\UE_5.0\Engine\Source\Runtime\RSA\Public" -I"D:\UE_5.0\Engine\Source\Runtime\RenderCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\NetCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\CoreOnline\Public" -I"D:\UE_5.0\Engine\Source\Runtime\PhysicsCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Experimental\Chaos\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Experimental\ChaosCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\InputCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\RHI\Public" -I"D:\UE_5.0\Engine\Source\Runtime\AudioMixerCore\Public" -I"D:\UE_5.0\Engine\Source\Developer\DesktopPlatform\Public" -I"D:\UE_5.0\Engine\Source\Developer\ToolMenus\Public" -I"D:\UE_5.0\Engine\Source\Developer\TargetPlatform\Public" -I"D:\UE_5.0\Engine\Source\Developer\SourceControl\Public" -I"D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Inc\NetCore" -I"D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Inc\Engine" -I"D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Inc\PhysicsCore" -IG:\Dropbox\GameDev\UnrealProjects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUE\ /Z7 /FS /Od   /IC:\Nim\lib /ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\src /nologo /FoD:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@sdigitsutils.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@sdigitsutils.nim.cpp
proc compileCmd(cpppath: string, objpath: string): string =
  "vccexe.exe" & " " &
    CompileFlags.join(" ") & " " &
    (if withPCH and usesPCHFile(cppPath): pchFlags() else: "") & " " &
    getUEHeadersIncludePaths(nueConfig).foldl(a & " -I" & b, " ") & " " &
    "/Fo" & objpath & " " & cppPath &
    " " & debugFlags



# generate the pch file for windows
proc winpch*() =
  if execCmd("nim cpp --genscript --app:lib --nomain --nimcache:.nimcache/winpch src/nimforue/unreal/winpch.nim") != 0:
    quit("! Error: Could not compile winpch.")

  var pchCmd = r"vccexe.exe /c --platform:amd64 /nologo "& pchFlags(shouldCreate = true) & " " &
    CompileFlags.join(" ") & " " & getUEHeadersIncludePaths(nueConfig).foldl( a & " -I" & b, " ")

  let definitionsCppPath = pluginDir / ".nimcache/winpch/@mdefinitions.nim.cpp"
  if fileExists(definitionsCppPath):
    pchCmd &= " " & definitionsCppPath
  else:
    quit("!Error: " & definitionsCppPath & " not found!")

  let curDir = getCurrentDir()
  pchCmd &= " " & debugFlags
  #echo pchCmd
  setCurrentDir(".nimcache/winpch")
  discard execCmd(pchCmd)
  setCurrentDir(curDir)


proc compileThread(cmd: string):int {.thread.} =
  execCmd(cmd)

proc nimcacheBuild*(): BuildStatus =
  # Generate commands for compilation and linking by examining the contents of the nimcache
  let start = now()

  if withPCH and defined(windows) and not fileExists(pchFilepath):
    echo("PCH file " & pchFilepath & " not found. Building...")
    winpch()

  var compileCmds: seq[string]

  var objpaths: seq[string]
  for kind, path in walkDir(cacheDir):
    var cpppath = path
    var objpath = path & ".obj"
    case kind:
    of pcFile:
      if cpppath.endsWith("nim.cpp"): #ignore nue.cpp
        if not isCompiled(cpppath):
          cpppath = validateNimCPPHeaders(cpppath)
          compileCmds.add compileCmd(cpppath, objpath)
        objpaths.add(objpath)
    else:
      continue

  if compileCmds.len == 0:
    echo "-- No changes detected --"
    return NoChange

  if parallelBuild:
    var res = newSeq[FlowVar[int]]()
    for i, cmd in compileCmds:
      res.add(spawn compileThread(cmd))
    sync()

    var isCompileSuccessful = true
    for f in res:
      if ^f != 0:
        isCompileSuccessful = false

    if not isCompileSuccessful:
      return FailedCompile
  else:
    for i, cmd in compileCmds:
      if compileThread(cmd) != 0:
        return FailedCompile
  
  # link if all the compiles succeed
  # example link command
  # vccexe.exe  /LD --platform:amd64 /FeD:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Binaries\nim\nimforue.dll  D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@sdigitsutils.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sassertions.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@ssystem@sdollars.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@ssyncio.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@ssystem.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@smath.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@sstrutils.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@sCore@sContainers@sunrealstring.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@scoreuobject@suobject.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@scoreuobject@sunrealtype.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@snimforue@snimforuebindings.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@score@smath@svector.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@score@senginetypes.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@sdynlib.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@swindows@swinlean.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@stimes.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@swin_setenv.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@sos.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@smanualtests@smanualtestsarray.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sffinimforue.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@stest@stestuobject.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@stest@stest.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue.nim.cpp.obj  /nologo   "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\Core\UnrealEditor-Core.lib" "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\CoreUObject\UnrealEditor-CoreUObject.lib" "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\Engine\UnrealEditor-Engine.lib" "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\Projects\UnrealEditor-Projects.lib" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\UnrealEditor-NimForUEBindings.lib"   /Zi /FS /Od "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\Module.NimForUEBindings.cpp.obj" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\Module.NimForUEBindings.gen.cpp.obj" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h.obj"

  var pchObj = quotes(pluginDir / ".nimcache/winpch/@mdefinitions.nim.obj")
  let dllpath = quotes(pluginDir / "Binaries/nim/nimforue.dll")

  var dllFlag = if isDebug: "/LDd" else: "/LD"

  let linkcmd = &"vccexe.exe {dllFlag} --platform:amd64  /nologo /Fe" & dllpath & " " &
    getUESymbols(nueConfig).foldl(a & " " & b, " ") & " " & objpaths.join(" ") & " " & (if withPCH: pchObj else: "") &
    " " & debugFlags

 
  let linkRes = execCmd(linkCmd)
  if linkRes != 0:
    return FailedLink

  Success


when isMainModule:
  #compileBat()
  nimcacheBuild()
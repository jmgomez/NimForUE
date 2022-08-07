# script to build the from .nimcache
import std / [os, osproc, strutils, sequtils, times, options, strformat, sugar, threadpool, algorithm, strscans]
import nimforueconfig
import copylib

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

proc debugFlags(): string =
  if isDebug:
    let pdbFolder = pluginDir / ".nimcache/guestpch/pdbs"
    createDir(pdbFolder)

    proc toVersion(s: string):int =
      let (_, f, _) = s.splitFile
      var n : int
      discard f.scanf("nimforue-$i", n)
      n

    # generate a new pdb name
    # get the version numbers and inc the highest to get the next
    let versions : seq[int] = walkFiles(pdbFolder/"nimforue*.pdb").toSeq.map(toVersion).sorted(Descending)
    let version : string =
      if versions.len > 0:
        "-" & $(versions[0]+1)
      else: ""

    # clean up pdbs
    for pdbPath in walkFiles(pdbFolder/"nimforue*.pdb"):
      discard tryRemoveFile(pdbPath)

    let pdbFile = pdbFolder / "nimforue" & version & ".pdb"
    &"/Fd{pdbFile} /link /ASSEMBLYDEBUG /DEBUG /PDB:{pdbFile}"
  else:
    ""

type BuildStatus* = enum
  Success
  NoChange
  FailedCompile
  FailedLink
  FailedPreprocess


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
    " " & debugFlags()

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
  pchCmd &= " " & debugFlags()
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

  # if compileCmds.len == 0:
  #   echo "-- No changes detected --"
  #   return NoChange

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
    " " & debugFlags()

 
  let linkRes = execCmd(linkCmd)
  if linkRes != 0:
    return FailedLink

  Success

proc preprocessCmd(cpppath: string): string =
  echo &"{cpppath = }"
  echo cpppath.parentDirs(fromRoot = true).toSeq()
  let baseDir = absolutePath(cpppath.parentDirs(fromRoot = true).toSeq()[1])

  echo &"{baseDir = }"

  let includeDirs = collect:
      for path in baseDir.walkDirRec(yieldFilter = {pcDir}):
        quotes(path)
  
  echo &"{includeDirs = }"

  # pulled from AppData/Local/UnrealBuildTool/Log.txt
  let ubtflags = "/D_WIN64 /I \"C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Tools\\MSVC\\14.32.31326\\INCLUDE\" /I \"C:\\Program Files (x86)\\Windows Kits\\NETFXSDK\\4.8\\include\\um\" /I \"C:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.18362.0\\ucrt\" /I \"C:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.18362.0\\shared\" /I \"C:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.18362.0\\um\" /I \"C:\\Program Files (x86)\\Windows Kits\\10\\include\\10.0.18362.0\\winrt\" /DIS_PROGRAM=0 /DUE_EDITOR=1 /DENABLE_PGO_PROFILE=0 /DUSE_VORBIS_FOR_STREAMING=1 /DUSE_XMA2_FOR_STREAMING=1 /DWITH_DEV_AUTOMATION_TESTS=1 /DWITH_PERF_AUTOMATION_TESTS=1 /DUNICODE /D_UNICODE /D__UNREAL__ /DIS_MONOLITHIC=0 /DWITH_ENGINE=1 /DWITH_UNREAL_DEVELOPER_TOOLS=1 /DWITH_UNREAL_TARGET_DEVELOPER_TOOLS=1 /DWITH_APPLICATION_CORE=1 /DWITH_COREUOBJECT=1 /DWITH_VERSE=0 /DUSE_STATS_WITHOUT_ENGINE=0 /DWITH_PLUGIN_SUPPORT=0 /DWITH_ACCESSIBILITY=1 /DWITH_PERFCOUNTERS=1 /DUSE_LOGGING_IN_SHIPPING=0 /DWITH_LOGGING_TO_MEMORY=0 /DUSE_CACHE_FREED_OS_ALLOCS=1 /DUSE_CHECKS_IN_SHIPPING=0 /DUSE_ESTIMATED_UTCNOW=0 /DWITH_EDITOR=1 /DWITH_IOSTORE_IN_EDITOR=1 /DWITH_SERVER_CODE=1 /DWITH_PUSH_MODEL=1 /DWITH_CEF3=1 /DWITH_LIVE_CODING=1 /DWITH_CPP_MODULES=0 /DWITH_CPP_COROUTINES=0 /DUBT_MODULE_MANIFEST=\"UnrealEditor.modules\" /DUBT_MODULE_MANIFEST_DEBUGGAME=\"UnrealEditor-Win64-DebugGame.modules\" /DUBT_COMPILED_PLATFORM=Win64 /DUBT_COMPILED_TARGET=Editor /DUE_APP_NAME=\"UnrealEditor\" /DNDIS_MINIPORT_MAJOR_VERSION=0 /DWIN32=1 /D_WIN32_WINNT=0x0601 /DWINVER=0x0601 /DPLATFORM_WINDOWS=1 /DPLATFORM_MICROSOFT=1 /DOVERRIDE_PLATFORM_HEADER_NAME=Windows /DRHI_RAYTRACING=1 /DNDEBUG=1 /DUE_BUILD_DEVELOPMENT=1 /DORIGINAL_FILE_NAME=\"UnrealEditor-NimForUEEditor.dll\" /DBUILT_FROM_CHANGELIST=20979098 /DBUILD_VERSION=++UE5+Release-5.0-CL-20979098 /DBUILD_ICON_FILE_NAME=\"\\\"..\\Build\\Windows\\Resources\\Default.ico\\\"\" /DPROJECT_COPYRIGHT_STRING=\"Fill out your copyright notice in the Description page of Project Settings.\" /DPROJECT_PRODUCT_NAME=\"Third Person Game Template\" /DPROJECT_PRODUCT_IDENTIFIER=NimForUEDemo"
  let winsdkflags = "/D__midl=0 /DUE_ENABLE_ICU=0 /DWITH_DIRECTXMATH=0"

  let (dir, filename, ext) = cpppath.splitFile
  let destPath = quotes(pluginDir / ".nimcache/preprocess" / filename / filename & ".i")
  "vccexe.exe" & " " &
    CompileFlags.dup(`[]=`(0, &"/P /C /Fi{destPath} {ubtflags} {winsdkflags}")).join(" ") & " " &
    getUEHeadersIncludePaths(nueConfig).foldl(a & " -I" & b, " ") & " " &
    includeDirs.foldl(a & " -I" & b, " ") & " " &
    " " & cppPath

proc preprocess*(srcPath: string) =

  let (_, filename, _) = srcPath.splitFile
  let processedDir = pluginDir / ".nimcache/preprocess" / filename
  createDir(processedDir)

  let cmd = preprocessCmd(srcPath)
  echo &"--- preprocessing"
  let res = execCmd(cmd)
  if res == 0:
    let destPath = quotes(processedDir / filename & ".i")
    echo &"Generated: {destPath}"

when isMainModule:
  nimcacheBuild()
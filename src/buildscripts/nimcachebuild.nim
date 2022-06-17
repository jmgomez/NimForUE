# script to build the from .nimcache
import std / [os, osproc, strutils, sequtils, times, options, strformat, sugar, threadpool]
import nimForUEConfig

# example compile command
#vccexe.exe /c --platform:amd64  /nologo /EHsc -DWIN32_LEAN_AND_MEAN /FS /std:c++17 /Zp8 /source-charset:utf-8 /execution-charset:utf-8 /MD -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUE -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Source\NimForUEBindings\Public\ -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Inc\NimForUEBindings -ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\NimHeaders -I"D:\UE_5.0\Engine\Source\Runtime\Engine\Classes" -I"D:\UE_5.0\Engine\Source\Runtime\Engine\Classes\Engine" -I"D:\UE_5.0\Engine\Source\Runtime\Net\Core\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Net\Core\Classes" -I"D:\UE_5.0\Engine\Source\Runtime\CoreUObject\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Core\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Engine\Public" -I"D:\UE_5.0\Engine\Source\Runtime\TraceLog\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Launch\Public" -I"D:\UE_5.0\Engine\Source\Runtime\ApplicationCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Projects\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Json\Public" -I"D:\UE_5.0\Engine\Source\Runtime\PakFile\Public" -I"D:\UE_5.0\Engine\Source\Runtime\RSA\Public" -I"D:\UE_5.0\Engine\Source\Runtime\RenderCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\NetCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\CoreOnline\Public" -I"D:\UE_5.0\Engine\Source\Runtime\PhysicsCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Experimental\Chaos\Public" -I"D:\UE_5.0\Engine\Source\Runtime\Experimental\ChaosCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\InputCore\Public" -I"D:\UE_5.0\Engine\Source\Runtime\RHI\Public" -I"D:\UE_5.0\Engine\Source\Runtime\AudioMixerCore\Public" -I"D:\UE_5.0\Engine\Source\Developer\DesktopPlatform\Public" -I"D:\UE_5.0\Engine\Source\Developer\ToolMenus\Public" -I"D:\UE_5.0\Engine\Source\Developer\TargetPlatform\Public" -I"D:\UE_5.0\Engine\Source\Developer\SourceControl\Public" -I"D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Inc\NetCore" -I"D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Inc\Engine" -I"D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Inc\PhysicsCore" -IG:\Dropbox\GameDev\UnrealProjects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUE\ /Z7 /FS /Od   /IC:\Nim\lib /ID:\unreal-projects\NimForUEDemo\Plugins\NimForUE\src /nologo /FoD:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@sdigitsutils.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@sdigitsutils.nim.cpp
# example link command
# vccexe.exe  /LD --platform:amd64 /FeD:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Binaries\nim\nimforue.dll  D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@sdigitsutils.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sassertions.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@ssystem@sdollars.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@ssyncio.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@ssystem.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@smath.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@sstrutils.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@sCore@sContainers@sunrealstring.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@scoreuobject@suobject.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@scoreuobject@sunrealtype.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@snimforue@snimforuebindings.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@score@smath@svector.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sunreal@score@senginetypes.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@sdynlib.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@swindows@swinlean.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@stimes.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@sstd@sprivate@swin_setenv.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mC@c@sNim@slib@spure@sos.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@smanualtests@smanualtestsarray.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@sffinimforue.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@stest@stestuobject.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue@stest@stest.nim.cpp.obj D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\.nimcache\nimforuepch\@mnimforue.nim.cpp.obj  /nologo   "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\Core\UnrealEditor-Core.lib" "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\CoreUObject\UnrealEditor-CoreUObject.lib" "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\Engine\UnrealEditor-Engine.lib" "D:\UE_5.0\Engine\Intermediate\Build\Win64\UnrealEditor\Development\Projects\UnrealEditor-Projects.lib" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\UnrealEditor-NimForUEBindings.lib"   /Zi /FS /Od "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\Module.NimForUEBindings.cpp.obj" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\Module.NimForUEBindings.gen.cpp.obj" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h.obj"

type BuildStatus* = enum
  Success
  NoChange
  FailedCompile
  FailedLink

const withPCH = true
const parallelBuild = true # for debugging purposes, normally we want to execute in parallel

# Can we detect the lib path?
const NimLibPath = r"C:\Nim\lib"


let nueConfig = getNimForUEConfig()
let platformDir = if nueConfig.targetPlatform == Mac: "Mac/x86_64" else: $nueConfig.targetPlatform
let confDir = $nueConfig.targetConfiguration
let engineDir = nueConfig.engineDir
let pluginDir = nueConfig.pluginDir

#let cacheDir = pluginDir / ".nimcache/nimforuepch"
#let batFile = cacheDir / "compile_nimforue.bat"
#let libDir = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / confDir / "NimForUEBindings"

template quotes(path: string): untyped =
  "\"" & path & "\""

proc isNimFile(path: string): bool =
  # hack to determine if a file is a Nim library file
  # The nimforue files include definitions which has an INCLUDESECTION before #include "nimbase.h"
  for l in path.lines:
    if l.contains("INCLUDESECTION"):
      return false
    if l.contains("nimbase.h"):
      break
  true

#[
proc updateNimCmd(cmd: string): string =
  # removes pch flags
  # assumes cmd contains /Yu
  # find /Yu" or /Yu
  var dx = cmd.find("/Yu\"")
  var endChar = ' '
  if dx == -1:
    dx = cmd.find("/Yu")
    if cmd[dx + 3] == '"':
      endChar = '"'

  var ndx = cmd.find(endChar, start = dx + 3)
  # next should be " /Fp"
  ndx += 4
  if cmd[ndx] == '"':
    ndx = cmd.find("\" ", start = ndx) + 2
  else:
    ndx = cmd.find(' ', start = ndx) + 1
  
  result = cmd[0 ..< dx] & cmd[ndx .. ^1]

proc getPath(cmd: string): string =
  if cmd.endsWith("\""):
    return cmd[0 ..< ^1].rsplit('\"', 1)[^1]
  else:
    return cmd.rsplit(' ', 1)[^1]

proc compileBat*() =
  let start = now()


  if withPCH:
    var cmds = batFile.lines.toSeq
    for i, cmd in cmds[0 ..< ^1]: # skip the last cmd for the linker
      let path = getPath(cmd)
      if cmd.contains("/Yu") and isNimFile(path):
        cmds[i] = updateNimCmd(cmd)
      #cmds[i] = cmd & " " & ResponseFlags.join(" ")

    # check the linker command for pch objs
    if not cmds[^1].contains("PCH.NimForUEBindings.h.obj"):
      # The obj.response files in D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings
      # that have a /Fp"D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h.pch"
      # Need to be linked in.
      var pchObjs = foldl(
        @["Module.NimForUEBindings.cpp.obj", "Module.NimForUEBindings.gen.cpp.obj", "PCH.NimForUEBindings.h.obj"],
        a & " " & quotes(libDir / b), "")
      cmds[^1] &= pchObjs
      writeFile(batFile, cmds.join("\n"))

  discard execCmd(cacheDir / "compile_nimforue.bat")

  echo "--- nimcachebuild.nim Time to compile: ", (now() - start)
]#

proc getHeadersIncludePaths*() : seq[string] = 
  let pluginDefinitionsPaths = pluginDir / "/Intermediate"/"Build" / platformDir / "UnrealEditor" / confDir  #Notice how it uses the TargetPlatform, The Editor?, and the TargetConfiguration
  let nimForUEBindingsHeaders =  pluginDir / "Source/NimForUEBindings/Public/"
  let nimForUEBindingsIntermidateHeaders = pluginDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / "Inc" / "NimForUEBindings"

  proc getEngineRuntimeIncludePathFor(engineFolder, moduleName:string) : string = quotes(engineDir / "Source" / engineFolder / moduleName / "Public")
  proc getEngineIntermediateIncludePathFor(moduleName:string) : string = quotes(engineDir / "Intermediate" / "Build" / platformDir / "UnrealEditor" / "Inc" / moduleName)

  let essentialHeaders = @[
      pluginDefinitionsPaths / "NimForUE",
      pluginDefinitionsPaths / "NimForUEBindings",
      nimForUEBindingsHeaders,
      nimForUEBindingsIntermidateHeaders,
      pluginDir / "NimHeaders",
      #engine
      quotes(engineDir / "Source/Runtime/Engine/Classes"),
      quotes(engineDir / "Source/Runtime/Engine/Classes/Engine"),
      quotes(engineDir / "Source/Runtime/Net/Core/Public"),
      quotes(engineDir / "Source/Runtime/Net/Core/Classes")
  ]
  let runtimeModules = @["CoreUObject", "Core", "Engine", "TraceLog", "Launch", "ApplicationCore", 
      "Projects", "Json", "PakFile", "RSA", "Engine", "RenderCore",
      "NetCore", "CoreOnline", "PhysicsCore", "Experimental/Chaos", 
      "Experimental/ChaosCore", "InputCore", "RHI", "AudioMixerCore"]

  let developerModules = @["DesktopPlatform", "ToolMenus", "TargetPlatform", "SourceControl"]
  let intermediateGenModules = @["NetCore", "Engine", "PhysicsCore"]

  let moduleHeaders = 
      runtimeModules.map(module=>getEngineRuntimeIncludePathFor("Runtime", module)) & 
      developerModules.map(module=>getEngineRuntimeIncludePathFor("Developer", module)) & 
      intermediateGenModules.map(module=>getEngineIntermediateIncludePathFor(module))

  essentialHeaders & moduleHeaders

proc getLinkSymbols() : string =
  proc getEngineRuntimeSymbolPathFor(prefix, moduleName:string) : string =  
    let libName = &"{prefix}-{moduleName}" 
    when defined windows:
      return quotes(engineDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / moduleName / libName & ".lib")
    elif defined macosx:
      let platform = $nueConfig.targetPlatform #notice the platform changed for the symbols (not sure how android/consoles/ios will work)
      return  engineDir / "Binaries" / platform / libName & ".dylib"

  # get engine weak symbols for modules
  for module in @["Core", "CoreUObject", "Engine", "Projects"]:
    result &= getEngineRuntimeSymbolPathFor("UnrealEditor", module) & " "

  # addNewForUEBindings()
  when defined macosx:
    result &= pluginDir / "Binaries"/ $nueConfig.targetPlatform / "UnrealEditor-NimForUEBindings.dylib"
  elif defined windows:
    let libName = fmt "UnrealEditor-NimForUEBindings.lib" 
    result &= quotes(pluginDir / "Intermediate/Build" / platformDir / "UnrealEditor" / confDir / "NimForUEBindings/UnrealEditor-NimForUEBindings.lib")


# Find the definitions here:
# https://docs.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-alphabetically?view=msvc-170
#[
const ResponseFlags = [
"/Zc:inline", #Remove unreferenced functions or data if they're COMDAT or have internal linkage only (off by default).
"/nologo", # Suppresses display of sign-on banner.
"/Oi", # generate intrinsics
"/FC", # Displays the full path of source code files passed to cl.exe in diagnostic text.
"/c", # Compiles without linking.
"/Gw", # Enables whole-program global data optimization.
"/Gy", # Enables function-level linking.
"/Zm1000", # Specifies the precompiled header memory allocation limit.
# /D<name>{=|#}<text>	Defines constants and macros.
"/D_CRT_STDIO_LEGACY_WIDE_SPECIFIERS=1",
"/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS=1",
"/D_WINDLL",
"/D_DISABLE_EXTENDED_ALIGNED_STORAGE",
"/DPLATFORM_EXCEPTIONS_DISABLED=0",
"/source-charset:utf-8", # Set source character set.
"/execution-charset:utf-8", # Set execution character set.
"/Ob2", # /Ob<n>	Controls inline expansion. 2 The default value under /O1 and /O2. Allows the compiler to expand any function not explicitly marked for no inlining.
"/Ox", # A subset of /O2 that doesn't include /GF or /Gy. Enable Most Speed Optimizations
"/Ot", # Favors fast code.
"/GF", # Enables string pooling.
"/errorReport:prompt", # Deprecated. Error reporting is controlled by Windows Error Reporting (WER) settings.
"/EHsc", # Enable C++ exception handling (no SEH exceptions).
"/Z7", # Generates C 7.0-compatible debugging information. The /Z7 option produces object files that also contain full symbolic debugging information for use with the debugger.
"/MD", # Compiles to create a multithreaded DLL, by using MSVCRT.lib.
"/bigobj", # Increases the number of addressable sections in an .obj file.
"/fp:fast", # "fast" floating-point model; results are less predictable.
"/Zo", # Generate richer debugging information for optimized code.
"/Zp8", # /Zp[n] n	Packs structure members.
# /we<n>	Treat the specified warning as an error.
"/we4456",
"/we4458",
"/we4459",
"/we4668",
# /wd<n>  Disable the specified warning.
"/wd4819", 
"/wd4463",
"/wd4244",
"/wd4838",
"/TP", # Specifies all source files are C++.
"/GR-", # /GR[-]	Enables run-time type information (RTTI).
"/W4", # Set output warning level.
"/std:c++17", # C++17 standard ISO/IEC 14882:2017.
]
]#

# These flags are from the .response in the Intermediate folder for the UE Modules
const CompileFlags = [
"/c",
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
"/Z7",
"/Od", # debug flag, should use O2 for release?
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

proc pchFlags(shouldCreate: bool = false): string =
  let Yflag = if shouldCreate: "/Yc" else: "/Yu"
  # UE generated
  #result = Yflag & r"D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h /FpD:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h.pch"

  # nim generated
  let pluginDir = nueConfig.pluginDir
  let cacheDir = pluginDir / ".nimcache/winpch"
  result = Yflag & "UEDeps.h /Fp" & quotes(cacheDir / "nue.win.pch")

proc compileCmd(path: string): Option[string] =
  let objpath = path & ".obj"
  if fileExists(objpath) and getLastModificationTime(objpath) > getLastModificationTime(path):
    return none[string]()

  # Continue here: add getHeadersIncludePaths to cmd below
  some("vccexe.exe" & " " &
    CompileFlags.join(" ") & " " &
    (if withPCH and not isNimFile(path): pchFlags() else: "") & " " &
    "/I" & NimLibPath & " " &
    foldl(getHeadersIncludePaths(), a & "-I" & b & " ", "") & " " &
    "/Fo" & objpath & " " & path
    )

proc compileThread(cmd: string):int {.thread.} =
  execCmd(cmd)

proc nimcacheBuild*(): BuildStatus =
  # Generate commands for compilation and linking by examining the contents of the nimcache
  let start = now()

  let pluginDir = getCurrentDir()
  let cacheDir = pluginDir / ".nimcache/nimforuepch"
  # TODO: get the flags from the PCH response file in Intermediate

  var compileCmds: seq[string]

  var objpaths: seq[string]
  for kind, path in walkDir(cacheDir):
    case kind:
    of pcFile:
      if path.endsWith(".cpp"):
        objpaths.add(path & ".obj")
        let cmd = compileCmd(path)
        if cmd.isSome:
          #echo cmd.get()
          compileCmds.add cmd.get()
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
  
  #echo "-!compile complete! now link"
  # link if all the compiles succeed

  var pchObj = quotes(pluginDir / ".nimcache/winpch/@mdefinitions.nim.obj")
  let dllpath = quotes(pluginDir / "Binaries/nim/nimforue.dll")
  let linkcmd = "vccexe.exe /LD --platform:amd64  /nologo /Fe" & dllpath & " " &
    getLinkSymbols() & " " & objpaths.join(" ") & " " & (if withPCH: pchObj else: "")
 
  #echo linkcmd

  let linkRes = execCmd(linkCmd)
  if linkRes != 0:
    return FailedLink

  Success


proc winpch*() =
  var createPCHCmd = r"vccexe.exe /c --platform:amd64 /nologo "& pchFlags(shouldCreate = true) & " " &
    CompileFlags.join(" ") & " " &
    foldl(getHeadersIncludePaths(), a & "-I" & b & " ", "")

  let cacheDir = pluginDir / ".nimcache/winpch"
  for kind, path in walkDir(cacheDir):
    case kind:
    of pcFile:
      if path.endsWith(".cpp") and path.contains("definitions.nim"):
        createPCHCmd &= " " & path
    else:
      continue
  let curDir = getCurrentDir()
  echo createPCHCmd
  setCurrentDir(".nimcache/winpch")
  discard execCmd(createPCHCmd)
  setCurrentDir(curDir)


when isMainModule:
  #compileBat()
  nimcacheBuild()
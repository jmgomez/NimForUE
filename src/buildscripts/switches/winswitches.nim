
import std / [ options, strscans, algorithm, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig, nimcachebuild]


let config = getNimForUEConfig()


#WINDOWS SPECIFIC

# Find the definitions here:
# https://docs.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-alphabetically?view=msvc-170
# These flags are from the .response in the Intermediate folder for the UE Modules
# TODO?: get the flags from the PCH response file in Intermediate instead of hardcoding
let vccCompileFlags = [
"/c",
# (if withDebug: "/Od /Z7" else: "/O2"), # To support hot reloading while debugging, we use /Z7 and regenerate the pdb each time from the guest pch objs. Using /Zi produces an LNK4204 error due to a mismatch between the winpch pdb and guestpch objs pdb.
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
].mapIt("-t:" & it) & @[&"--cc:vcc"]

let pluginDir = config.pluginDir
let pchDir = pluginDir / "Intermediate\\Build\\Win64\\UnrealEditor\\Development\\NimForUE"
let pchObjPath = pchDir / "PCH.NimForUE.h.obj"
let pchPdbPath = pchDir / "PCH.NimForUE.h.pdb"

let pchCompileFlags = @[
  &"/FI\"{pchDir}\\PCH.NimForUE.h\"",
  &"/Yu\"{pchDir}\\PCH.NimForUE.h\"",
  &"/Fp\"{pchDir}\\PCH.NimForUE.h.pch\"",
  &"/Fd\"{pchDir}\\PCH.NimForUE.h.pdb\"",
]
const PCHFile = "nimbase.h"
# const PCHFile = "UEDeps.h"
# let pchObjPath = quotes(pluginDir / ".nimcache/winpch/@mdefinitions.nim.obj")

let pchFilepath = pluginDir / ".nimcache/winpch/nue.win.pch"
proc pchFlags*(shouldCreate: bool = false): seq[string] =
  # Precompiled header files https://docs.microsoft.com/en-us/cpp/build/creating-precompiled-header-files?view=msvc-170
  # /Yc https://docs.microsoft.com/en-us/cpp/build/reference/yc-create-precompiled-header-file?view=msvc-170
  # /Yu https://docs.microsoft.com/en-us/cpp/build/reference/yu-use-precompiled-header-file?view=msvc-170
  # /Fp https://docs.microsoft.com/en-us/cpp/build/reference/fp-name-dot-pch-file?view=msvc-170
  let yflag = if shouldCreate: "/Yc /Yd " else: "/Yu"
  
  result = (yflag & PCHFile & "/Fp" & quotes(pchFilepath)).split("/").mapIt("/"&it)# & compilerFlags



proc vccPchCompileFlags*(withDebug, withPch, createPch : bool) : seq[string] = 
  @[
    (if withDebug: "/Od" else: "/O2"),
    (if withDebug: "/Zi" else: ""),
    "/Zc:inline", #Remove unreferenced functions or data if they're COMDAT or have internal linkage only (off by default).
    "/nologo",
    "/Oi",
    "/FC",
    "/c",
    "/Gw", # Enables whole-program global data optimization.
    "/Gy", # Enables function-level linking.
    "/Zm1000", 
    "/wd4819",
    "/D_CRT_STDIO_LEGACY_WIDE_SPECIFIERS=1",
    "/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS=1",
    "/D_WINDLL",
    "/D_DISABLE_EXTENDED_ALIGNED_STORAGE",
    "/source-charset:utf-8",
    "/execution-charset:utf-8",
    "/Ob2",
    "/Od",
    "/errorReport:prompt",
    "/EHsc",
    "/DPLATFORM_EXCEPTIONS_DISABLED=0",
    "/MD",
    "/bigobj",
    "/fp:fast", # "fast" floating-point model; results are less predictable.
    "/Zp8",
    # /we<n>	Treat the specified warning as an error.

    "/we4456", # // 4456 - declaration of 'LocalVariable' hides previous local declaration
    "/we4458",#  4458 - declaration of 'parameter' hides class member
    "/we4459",# 4459 - declaration of 'LocalVariable' hides global declaration
    "/wd4463",#  4463 - overflow; assigning 1 to bit-field that can only hold values from -1 to 0
    "/we4668",
    "/wd4244",
    "/wd4838",
    "/TP",
    "/GR-", # /GR[-]	Enables run-time type information (RTTI).
    "/W4",
    "/std:c++latest",
    "/wd5054",
    "/FS", #syn writes
    #extras:
    "/Zc:strictStrings-", # need this for converting const char []  to NCString since it loses const, for std:c++20
    #
    

    "/Zf",
    "/MP",
  
    "--sdkversion:10.0.18362.0" #for nim vcc wrapper. It sets the SDK to match the unreal one. This could be extracted from UBT if it causes issues down the road
  # ] & (if withPch: pchFlags(createPch) else: @[])
  ] & (pchCompileFlags)


proc vccPchCompileSwitches*(withDebug : bool) : seq[string]= 
  vccPchCompileFlags(withDebug, withPch = true, createPch = false).mapIt("-t:" & it) & @[&"--cc:vcc"]
# pchCompileFlags).mapIt("-t:" & it) & @[&"--cc:vcc"]

let vccCompilerSwitchesNoPch* = vccPchCompileFlags(false, false, false).mapIt("-t:" & it) & @[&"--cc:vcc"]

proc debugFlags*():string =
  # This has some hardcoded paths for guestpch!
  let pdbFolder = pluginDir / ".nimcache/guest/pdbs"
  createDir(pdbFolder)

  # clean up pdbs
  for pdbPath in walkFiles(pdbFolder/"nimforue*.pdb"):
    discard tryRemoveFile(pdbPath) # ignore if the pdb is locked by the debugger

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
  
  let pdbFile = pdbFolder / "nimforue" & version & ".pdb"
  &"/Fd{pdbFile} /link /ASSEMBLYDEBUG /DEBUG /PDB:{pdbFile}"




var pdbFileTest = ""
proc debugSwhitches*(): seq[string] =
 # This has some hardcoded paths for guestpch!
  let pdbFolder = pluginDir / ".nimcache/guest/pdbs"
  createDir(pdbFolder)

  # clean up pdbs
  for pdbPath in walkFiles(pdbFolder/"nimforue*.pdb"):
    discard tryRemoveFile(pdbPath) # ignore if the pdb is locked by the debugger

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
    
  
  let pdbFile = pdbFolder / "nimforue" & version & ".pdb"
  pdbFileTest = pdbFile
  # let pdbFile = pchPdbPath
  # @[&"/Fd{pdbFile}"].mapIt("-t:" & it) &
  # (&" /LDd /INCREMENTAL:NO /DEBUG:FULL /PDB:\"{pdbFile}\"").split("/").filterIt(len(it)>1).mapIt("-l:/" & it.strip())
  # (&" /LDd /INCREMENTAL:NO /DEBUG /PDB:\"{pdbFile}\"").split("/").filterIt(len(it)>1).mapIt("-l:/" & it.strip())


proc getPlatformSwitches*(withPch, withDebug : bool) : seq[string] = 
  discard debugSwhitches()#increase pdb
  result = vccPchCompileSwitches(withDebug) & @["-l:" & pchObjPath] & 
  #  &"-l:/link /DLL /FS /INCREMENTAL:NO /OPT:REF /OPT:ICF /LTCG /MACHINE:X64 /SUBSYSTEM:WINDOWS /MANIFEST:NO /NOLOGO /DEBUG /PDB:\"{pdbFileTest}\"".split("/").filterIt(len(it)>1).mapIt("-l:/" & it.strip())
  (&"-l:/link /INCREMENTAL /DEBUG /PDB:\"{pdbFileTest}\"").split("/").filterIt(len(it)>1).mapIt("-l:/" & it.strip())


          

  # if withDebug: 
  #   return result & debugSwhitches().join(" ")
  # return result & (if withDebug: @["/Od", "/Z7"] else: @["/O2"]).mapIt("-t:" & it)

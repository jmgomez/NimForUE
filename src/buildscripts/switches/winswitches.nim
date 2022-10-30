
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

let pchCompileFlags = @[
  &"/FI\"{pchDir}\\PCH.NimForUE.h\"",
  &"/Yu\"{pchDir}\\PCH.NimForUE.h\"",
  &"/Fp\"{pchDir}\\PCH.NimForUE.h.pch\"",
]

let vccPchCompileFlags = (@[
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
  "/Z7",
  "/MD",
  "/bigobj",
  "/fp:fast", # "fast" floating-point model; results are less predictable.
  "/Zp8",
  # /we<n>	Treat the specified warning as an error.

  "/we4456",
  "/we4458",
  "/we4459",
  "/wd4463",
  "/we4668",
  "/wd4244",
  "/wd4838",
  "/TP",
  "/GR-", # /GR[-]	Enables run-time type information (RTTI).
  "/W4",
  "/std:c++latest",
  "/wd5054",

  #extras:
  "/Zc:strictStrings-", # need this for converting const char []  to NCString since it loses const, for std:c++20
  
  
 
  "--sdkversion:10.0.18362.0" #for nim vcc wrapper. It sets the SDK to match the unreal one. This could be extracted from UBT if it causes issues down the road
] & pchCompileFlags).mapIt("-t:" & it) & @[&"--cc:vcc"]



proc debugFlags():seq[string] =
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
  let compilerFlags = @[&"/Fd\"{pdbFile}\""].mapIt("-t:" & it)
  let linkerFlags = @["/ASSEMBLYDEBUG", "/DEBUG", &"/PDB:\"{pdbFile}\"", "/LDd"].mapIt("-l:" & it)
  compilerFlags & linkerFlags

proc getPlatformSwitches*(withPch, withDebug : bool) : seq[string] = 
  result = if withPch: vccPchCompileFlags & @["-l:" & pchObjPath]
           else: vccCompileFlags
  if withDebug: 
    return result & debugFlags()
  # return result & (if withDebug: @["/Od", "/Z7"] else: @["/O2"]).mapIt("-t:" & it)

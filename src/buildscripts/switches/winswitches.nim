
import std / [ options, strscans, algorithm, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig]


let config = getNimForUEConfig()

let unrealFolder = if WithEditor: "UnrealEditor" else: "UnrealGame"


let pchDir = PluginDir / "Intermediate\\Build"/ WinPlatformDir / unrealFolder / $config.targetConfiguration 

func getModuleName(target:string) : string = 
  # if target == "game": "NimForUEGame"
  # else: "NimForUE"
  "NimForUE"
proc pchObjPath(target:string) : string = 
  let module = getModuleName(target)
  pchDir / module / &"PCH.{module}.h.obj"


proc pchCompileFlags(target:string) : seq[string] = 
  let module = getModuleName(target)
  let pchCompileFlags = @[
    &"/FI\"{pchDir}\\{module}\\PCH.{module}.h\"",
    &"/Yu\"{pchDir}\\{module}\\PCH.{module}.h\"",
    &"/Fp\"{pchDir}\\{module}\\PCH.{module}.h.pch\"",
    # &"/Fd\"{pchDir}\\PCH.NimForUE.h.pdb\"",
  ]
  pchCompileFlags

#The file is created from a function in host which is called from the build rules on the plugin when UBT runs
proc getSdkVersion() : string =
  let sdkVersion = "10.0.18362.0"
  let path = PluginDir / "sdk_version.txt"
  if fileExists(path):
    return readFile(path)
  sdkVersion

proc getCompilerVersion() : string = 
  let compilerVersion = "14.34.31937"
  let path = PluginDir / "compiler_version.txt"
  if fileExists(path):
    return readFile(path)
  compilerVersion.split(".")[0] & "0"


proc vccPchCompileFlags*(withDebug, withIncremental, withPch:bool, target:string) : seq[string] = 
  result = @[
    # "/Zc:inline", #Remove unreferenced functions or data if they're COMDAT or have internal linkage only (off by default).
    "/nologo",
    # "/Oi", #optimize comde
    "/FC",
    "/c",
    # "/Gw", # Enables whole-program global data optimization.
    # "/Gy", # Enables function-level linking.
    "/Zm2000", 
    "/D_CRT_STDIO_LEGACY_WIDE_SPECIFIERS=1",
    "/D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS=1",
    "/D_WINDLL",
    "/D_DISABLE_EXTENDED_ALIGNED_STORAGE",
    "/source-charset:utf-8",
    "/execution-charset:utf-8",
    # "/Ob2", #inline function expansion?
    "/errorReport:prompt",
    "/EHs",
    "/DPLATFORM_EXCEPTIONS_DISABLED=0",
    "/MD",
    "/bigobj", # Increases the number of addressable sections in an .obj file.
    "/fp:fast", # "fast" floating-point model; results are less predictable.
    "/Zp8",
    # /we<n>	Treat the specified warning as an error.
    "/W4", #we need to be consistent with the PCH
    "/we4456", # // 4456 - declaration of 'LocalVariable' hides previous local declaration
    "/we4458",#  4458 - declaration of 'parameter' hides class member
    "/we4459",# 4459 - declaration of 'LocalVariable' hides global declaration
    "/we4668",
    "/wd4244",
    "/wd4838",
    "/wd4996", #Disables deprecation warning (until we change the usage of ANY_PACKAGE)
    "/wd4463",#  4463 - overflow; assigning 1 to bit-field that can only hold values from -1 to 0
    "/wd5054",
    "/wd4819",
    "/wd4703",#disables warning C4701: potentially uninitialized local variable 'dc' used   
    
    "/TP",
    "/GR-", # /GR[-]	Enables run-time type information (RTTI).
  
    "/std:c++20",
    # "/FS", #syn writes
    #extras:
    "/Zc:strictStrings-", # need this for converting const char []  to NCString since it loses const, for std:c++20
    #
    "/Zf", #faster pdb gen
    "/MP",
    # "--sdkversion:10.0.18362.0" #for nim vcc wrapper. It sets the SDK to match the unreal one. This could be extracted from UBT if it causes issues down the road
    "--sdkversion:" & getSdkVersion(),
    # "--noCommand",
    # "--printPath",
    # "--command:./nue echotask --test",
    # "--vccversion:0" #$ & getCompilerVersion()
  ] & (if UEVersion >= 5.2: 
        @[
          "/Zc:__cplusplus"
        
        ] else: @[])

  result &= (if withDebug: 
              @["/Od", "/Z7"] 
            else: 
              @["/O2"])
  if withPch: 
    result &= pchCompileFlags(target)


 

#nimforue or game are the target, the folder and the base name must match
proc getPdbFilePath*(targetName:static string): string =
 # This has some hardcoded paths for guestpch!
  let pdbFolder = PluginDir / ".nimcache" / targetName / "pdbs"
  createDir(pdbFolder)

  # clean up pdbs
  for pdbPath in walkFiles(pdbFolder/ (targetName) & "*.pdb"):
    discard tryRemoveFile(pdbPath) # ignore if the pdb is locked by the debugger

  proc toVersion(s: string):int =
    let (_, f, _) = s.splitFile
    var n : int
    discard f.scanf(targetName & "-$i", n)
    n

  # generate a new pdb name
  # get the version numbers and inc the highest to get the next
  let versions : seq[int] = walkFiles(pdbFolder/(targetName) & "*.pdb").toSeq.map(toVersion).sorted(Descending)
  let version : string =
    if versions.len > 0:
      "-" & $(versions[0]+1)
    else: ""
    
  
  let pdbFile = pdbFolder / targetName & version & ".pdb"
  pdbFile

proc vccCompileSwitches*(withDebug, withIncremental, withPch : bool, target:static string) : seq[string]= 
  var switches = vccPchCompileFlags(withDebug, withIncremental, withPch, target).mapIt("-t:" & it) & @[&"--cc:vcc"]
  if withPch:
    switches.add "-l:" & pchObjPath(target)
  if withDebug: 
      let debugSwitches = (&"/link /INCREMENTAL /DEBUG /PDB:\"{getPdbFilePath(target)}\"").split("/").filterIt(len(it)>1).mapIt("-l:/" & it.strip())

      # let debugSwitches = "-l:\"/INCREMENTAL /DEBUG\"" & &"-l:/PDB:\"{getPdbFilePath(debugFolder)}\""
      switches & debugSwitches
  else: switches & @["-l:/INCREMENTAL"]



proc getPlatformSwitches*(withPch, withDebug : bool, target:static string) : seq[string] = 
  result = vccCompileSwitches(withDebug, not withDebug, withPch, target) 

#Host guest (which will be renamed as plugin) and the game will be compiled from this file. Nue will use functions from here. 
#We may extrac the compilation option to another file since there are a lot of platforms. 

import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times, sequtils ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig]
import ../switches/switches
import nimforue/utils/utils

let config = getNimForUEConfig()

let nimCmd = "nim" #so we can easy switch with nim_temp
# let nimCmd = "nim_temp" #so we can easy switch with nim_temp

func getBaseNimCacheDir(folderName:string): string =
  let platformDir = 
    when defined windows: "win"
    else: "mac"
  &".nimcache/{folderName}/{platformDir}/"

#In mac we need to do a universal 
proc compileHostMac*() =
  let common = @[
    "--cc:clang",
    "--debugger:native",
    "--threads:off",
    "--tlsEmulation:off",
    "--app:lib",
    "--d:host",
    "--nimBasePattern:nimbasenue.h",
    "--debugger:native",
    # "--header:NimForUEFFI.h",
  ]
  let macArmSwitches = @[
    "--putenv:MACOSX_DEPLOYMENT_TARGET=10.15",
    "-l:'-target arm64-apple-macos11'",
    "-t:'-target arm64-apple-macos11'",
  ]
  let macx86Switches = @[
    "-l:'-target x86_64-apple-macos10.15'",
    "-t:'-target x86_64-apple-macos10.15'",
  ]
  let buildFlagsArm = @[macArmSwitches & common, buildSwitches].foldl(a & " " & b.join(" "), "")
  let armOutDir = "Binaries/nim/hostarm"
  doAssert(execCmd(&"nim cpp {buildFlagsArm} --outDir: {armOutDir}   --nimcache:.nimcache/hostarm src/hostnimforue/hostnimforue.nim") == 0)
 
  let x86OutDir = "Binaries/nim/hostx86"
  let buildFlagsx86 = @[macx86Switches, common, buildSwitches].foldl(a & " " & b.join(" "), "")
  doAssert(execCmd(&"nim cpp {buildFlagsx86} --outDir: {x86OutDir}  --nimcache:.nimcache/hostx86 src/hostnimforue/hostnimforue.nim") == 0)
  let lipoCmd = &"lipo -create {armOutDir}/libhostnimforue.dylib {x86OutDir}/libhostnimforue.dylib -output Binaries/nim/libhostnimforue.dylib"
  doAssert(execCmd(lipoCmd) == 0)
  # copy header
  # let ffiHeaderSrc = ".nimcache/hostarm/NimForUEFFI.h"
  # let ffiHeaderDest = "NimHeaders" / "NimForUEFFI.h"
  # copyFile(ffiHeaderSrc, ffiHeaderDest)
  # log("Copied " & ffiHeaderSrc & " to " & ffiHeaderDest)
  let libDir = "./Binaries/nim"
  let libDirUE = libDir / "ue"
  createDir(libDirUE)

  let hostLibName = "hostnimforue"
  let baseFullLibName = getFullLibName(hostLibName)
  let fileFullSrc = libDir/baseFullLibName
  let fileFullDst = libDirUE/baseFullLibName

  copyFile(fileFullSrc, fileFullDst)

  let dst = "/usr/local/lib" / baseFullLibName.replace(".dylib", "")
  copyFile(fileFullSrc, dst)
  log("Copied " & fileFullSrc & " to " & dst)


proc compileHost*() = 
 
  let hostSwitches = @[
    "--nimBasePattern:nimbasenue.h"
    
  ]
  let buildFlags = @[buildSwitches & hostSwitches].foldl(a & " " & b.join(" "), "")
  doAssert(execCmd(&"{nimCmd} cpp {buildFlags}  --cc:vcc --passC:/EHs  --debugger:native --threads:off --tlsEmulation:off --app:lib --d:host --nimcache:.nimcache/host src/hostnimforue/hostnimforue.nim") == 0)
  
  # copy header
  # let ffiHeaderSrc = ".nimcache/host/NimForUEFFI.h"
  # let ffiHeaderDest = "NimHeaders" / "NimForUEFFI.h"
  # copyFile(ffiHeaderSrc, ffiHeaderDest)
  # log("Copied " & ffiHeaderSrc & " to " & ffiHeaderDest)

  # copy lib
  let libDir = "./Binaries/nim"
  let libDirUE = libDir / "ue"
  createDir(libDirUE)

  let hostLibName = "hostnimforue"
  let baseFullLibName = getFullLibName(hostLibName)
  let fileFullSrc = libDir/baseFullLibName
  let fileFullDst = libDirUE/baseFullLibName

  try:
    copyFile(fileFullSrc, fileFullDst)
  except OSError as e:
    when defined windows: # This will fail on windows if the host dll is in use.
      quit("Error copying to " & fileFullDst & ". " & e.msg, QuitFailure)

  log("Copied " & fileFullSrc & " to " & fileFullDst)

  when defined windows:
    let weakSymbolsLib = hostLibName & ".lib"
    copyFile(libDir/weakSymbolsLib, libDirUE/weakSymbolsLib)
  elif defined macosx: #needed for dllimport in ubt mac only
    var dst = "/usr/local/lib" / baseFullLibName
    copyFile(fileFullSrc, dst)
    log("Copied " & fileFullSrc & " to " & dst)

    # dst = "/usr/local/lib" / baseFullLibName.replace(".dylib", "")
    # copyFile(fileFullSrc, dst)
    # log("Copied " & fileFullSrc & " to " & dst)

    


proc compilePlugin*(extraSwitches:seq[string],  withDebug:bool) =
  
  generateFFIGenFile(config)
  let guestSwitches = @[
    "-d:BindingPrefix=.nimcache/gencppbindings/@m..@sunreal@sbindings@sexported@s",
    "-d:guest",
    "-d:libname:guest",
    "-d:OutputHeader:Guest.h",
  ]
  let nimcacheDir = getBaseNimCacheDir("guest")
  let buildFlags = @[buildSwitches, targetSwitches(withDebug, "guest"), ueincludes, uesymbols, pluginPlatformSwitches(withDebug), extraSwitches, guestSwitches].foldl(a & " " & b.join(" "), "")
  let compCmd = &"{nimCmd} cpp {buildFlags} --app:lib --d:genffi -d:withPCH --nimcache:{nimcacheDir} src/nimforue.nim"
  doAssert(execCmd(compCmd)==0)
  
  copyNimForUELibToUEDir("nimforue")




proc ensureGameConfExists() = 
  let fileTemplate = """
import std/[os, compilesettings, sequtils]
when querySetting(command) == "check":
  switch("define", "nimcheck")


let currentDir = getCurrentDir()

echo "Current dir is ", currentDir

var pluginDirs = 
  if fileExists(currentDir / "game.nim"): 
    @[getCurrentDir() / "../Plugins/NimForUE"]
  elif dirExists("NimForUE"): @["."]
  else:
    @[getCurrentDir() / "../../Plugins/NimForUE"]


pluginDirs = pluginDirs.filter(dirExists)
assert pluginDirs.len == 1
echo "Using plugin dir: ", $pluginDirs


proc setPath(pluginDir: string) = 
  switch("path", pluginDir)
  switch("path", pluginDir / "src")
  switch("path", pluginDir / "src/nimforue")
  switch("path", pluginDir / "src/nimforue/game")
  switch("path", pluginDir / "src/nimforue/unreal")
  switch("path", pluginDir / "src/nimforue/unreal/bindings/imported")
  switch("path", pluginDir / "src/nimforue/vm")
  when defined(nimsuggest): #only needed for script.nim and nimsuggest
    switch("path", pluginDir / "src/nimforue/unreal/bindings/vm")


for dir in pluginDirs:
  setPath(dir)

switch("backend", "cpp")

"""
  let gameConf = NimGameDir() / "config.nims"
  if not fileExists(gameConf):
    writeFile(gameConf, fileTemplate)

proc getBindingsLib(): string = 
  when defined windows:
   "Binaries/nim/bindings.lib"
  else:
    "Binaries/nim/libbindings.a"

proc compileLib*(name:string, extraSwitches:seq[string], withDebug, withRelease:bool, withThreads = false) = 
  var extraSwitches = extraSwitches
  let isVm = "vm" in name
  var gameSwitches = @[
    "-d:game",
    "-d:OutputHeader:" & name.capitalizeAscii() & ".h",
    "-d:libname:" & name,
    (if isVm: "-d:vmhost" else: ""),
    &"-d:BindingPrefix={PluginDir}/.nimcache/gencppbindings/@m..@sunreal@sbindings@sexported@s",
    # "-l:" & getBindingsLib()
  ] 
  let isCompileOnly = "--compileOnly" in extraSwitches
  if isCompileOnly:
    gameSwitches.add("--genScript")
  else:
    gameSwitches.add("--app:lib")

  extraSwitches.remove("--compileOnly")


  ensureGameConfExists()
  
  let nimCache = getBaseNimCacheDir(name)/(if withDebug and not isCompileOnly: "debug" else: "release")
  let isGame = name == "game"
  
  let entryPoint = NimGameDir() / (if isGame: "game.nim" else: &"{name}/{name}.nim")
  let releaseFlag = if withRelease: "-d:danger" else: ""
  let threadFlag = if withThreads: "--threads:on" else: "" #off by default (switches)
  let buildFlags = @[buildSwitches, targetSwitches(withDebug, "game"), ueincludes, uesymbols, gamePlatformSwitches(withDebug), gameSwitches, extraSwitches].foldl(a & " " & b.join(" "), "")
  let compCmd = &"{nimCmd} cpp {buildFlags} {releaseFlag} {threadFlag}  --nimMainPrefix:{name.capitalizeAscii()}  -d:withPCH --nimcache:{nimCache} {entryPoint}"
  # echo compCmd
  doAssert(execCmd(compCmd)==0)


  if not isCompileOnly:
    copyNimForUELibToUEDir(name)
  

proc compileGame*(extraSwitches:seq[string], withDebug, withRelease:bool) = 
  compileLib("game", extraSwitches, withDebug, withRelease)






proc compileGameToUEFolder*(extraSwitches:seq[string], withDebug:bool) = 
  let gameSwitches = @[
    "-d:game",
    &"-d:BindingPrefix={PluginDir}/.nimcache/gencppbindings/@m..@sunreal@sbindings@sexported@s"
  ]
  #TODO Clean this up
  let bindingsDir = PluginDir / ".nimcache/gencppbindings"
  ensureGameConfExists()
  let entryPointDir = &"{PluginDir}/src/nimforue/game/"
  let gameConf = NimGameDir() / "config.nims"
  copyFile(gameConf, entryPointDir / "config.nims")
  var content = readFile( entryPointDir / "config.nims").replace("../Plugins/NimForUE/src/nimforue/", "../")
  content = content & """switch("path", "../../../../../NimForUE")""" #Adds the game folder path 
  writeFile(entryPointDir / "config.nims", content)
    


  #We compile from the engine directory so we dont surpass the windows argument limits for the linker 
  let engineBase = parentDir(config.engineDir)
  # setCurrentDir(engineBase)
  #TODO the final path will be relative to the engine dir this is just a hack to get it working for now
  # var uesymbols = uesymbols.mapIt(it.replace(config.engineDir, "Engine"))
  let gameFolder = NimGameDir()
  let nimCache = ".nimcache/nimforuegame"/(if withDebug: "debug" else: "release")

  let buildFlags = @[buildSwitches, targetSwitches(withDebug, "game"), ueincludes, uesymbols, gamePlatformSwitches(withDebug), gameSwitches, extraSwitches].foldl(a & " " & b.join(" "), "")
  let compCmd = &"nim cpp {buildFlags} --genScript --nimMainPrefix:Game   -d:withPCH --nimcache:{nimCache} {entryPointDir}/gameentrypoint.nim"
  doAssert(execCmd(compCmd)==0)
  #Copy the header into the NimHeaders
  # copyFile(nimCache / "NimForUEGame.h", NimHeadersDir / "NimForUEGame.h")
  #We need to copy all cpp files into the private folder in the plugin
  let privateFolder = PluginDir / "Source" / "NimForUEGame" / "Private" 
  let privateGameFolder = privateFolder / "Game"
  let privateBindingsFolder = privateFolder / "Bindings"
  
  # removeDir(privateGameFolder)
  createDir(privateGameFolder)
  for cppFile in walkFiles(nimCache / &"*.cpp"):
    #we need to clean the cpp file to avoid a const error on NCString (which is defined as const char* due to strict strings)
    #Probably this is windows only
    let cppFileContent = readFile(cppFile)
    let formsToMatch = ["(NCSTRING)", "(NCSTRING*)"]
    if formsToMatch.any(x=> x in cppFileContent):
      let cleanedCppFileContent = cppFileContent.multiReplace(("(NCSTRING)", "(char*)"), ("(NCSTRING*)", "(char**)"))
      writeFile(cppFile, cleanedCppFileContent)
    #checks if the file changed so UE doesnt compile it again:
    let filename = cppFile.extractFilename()
   
    let cppDst = privateGameFolder / filename
    if fileExists(cppDst) and readFile(cppFile) == readFile(cppDst):
      continue
    else:
      log "Will recompile " & cppDst
      copyFile(cppFile, cppDst)

#TODO use the nimscript to check if something changes
  # removeDir(privateBindingsFolder)
  createDir(privateBindingsFolder)
  #TODO pick only the used bindings files (by collecting them at compile time)
  for cppFile in walkFiles(bindingsDir/ &"*.cpp"):
    let filename = cppFile.extractFilename()
    if filename.contains("sbindings@sexported") and not (filename.contains("unrealed") or filename.contains("umgeditor")): 
      let path = privateBindingsFolder / filename
      if not fileExists path:
        copyFile(cppFile, path)


proc updateFile(src, dst: string) = 
  if fileExists(dst) and readFile(src) == readFile(dst):
    return
  else:
    copyFile(src, dst)

proc copyNewCppTo(srcFolder, dstFolder: string) = 
  var filesUpdated = 0
  for file in walkFiles(srcFolder / "*.cpp"):
    let filename = file.extractFilename()
    let dstFile = dstFolder / filename
    inc filesUpdated
    updateFile(file, dstFile)   

  if filesUpdated > 0:
    log "Copied " & $filesUpdated & " files to " & dstFolder
  else:
    log "No files copied to " & dstFolder & " as is up to date"

proc compileGenerateBindings*() = 
  let withDebug = false #TODO disable on final builds
  let buildFlags = @[buildSwitches, targetSwitches(withDebug, "bindings"), bindingsPlatformSwitches(withDebug), ueincludes, uesymbols].foldl(a & " " & b.join(" "), "")
  # doAssert(execCmd(&"{nimCmd}  cpp {buildFlags} --linedir:off  --noMain --compileOnly --header:UEGenBindings.h  --nimcache:.nimcache/gencppbindings src/nimforue/codegen/maingencppbindings.nim") == 0)
  doAssert(execCmd(&"nim  cpp {buildFlags} -d:bindings   --noMain --app:staticlib --compileOnly  --outDir:Binaries/nim/ --header:UEGenBindings.h --out:{getBindingsLib()} --nimcache:.nimcache/gencppbindings src/nimforue/codegen/maingencppbindings.nim") == 0)
  let ueGenBindingsPath =  config.nimHeadersDir / "UEGenBindings.h"
  copyFile("./.nimcache/gencppbindings/UEGenBindings.h", ueGenBindingsPath)
  #It still generates NimMain in the header. So we need to get rid of it:
  let nimMain = "N_CDECL(void, NimMain)(void);"
  writeFile(ueGenBindingsPath, readFile(ueGenBindingsPath).replace(nimMain, ""))

  let autoBindingsPath = "./Source" / "NimForUEAutoBindings"
  let cppDestiny = autoBindingsPath / "Private" / "autogen"
  createDir(cppDestiny)
  copyNewCppTo("./.nimcache/gencppbindings", cppDestiny)
  updateFile(ueGenBindingsPath, autoBindingsPath / "Public" / "UEGenBindings.h")
  




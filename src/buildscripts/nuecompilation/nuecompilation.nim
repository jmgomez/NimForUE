#Host guest (which will be renamed as plugin) and the game will be compiled from this file. Nue will use functions from here. 
#We may extrac the compilation option to another file since there are a lot of platforms. 

import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts/[buildcommon, buildscripts, nimforueconfig]
import ../switches/switches
let config = getNimForUEConfig()



#In mac we need to do a universal 
proc compileHostMac*() =
  let common = @[
    "--cc:clang",
    "--debugger:native",
    "--threads",
    "--tlsEmulation:off",
    "--app:lib",
    "--d:host",
    "--header:NimForUEFFI.h",
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
  let ffiHeaderSrc = ".nimcache/hostarm/NimForUEFFI.h"
  let ffiHeaderDest = "NimHeaders" / "NimForUEFFI.h"
  copyFile(ffiHeaderSrc, ffiHeaderDest)
  log("Copied " & ffiHeaderSrc & " to " & ffiHeaderDest)
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
 
  
  let buildFlags = @[buildSwitches].foldl(a & " " & b.join(" "), "")
  doAssert(execCmd(&"nim cpp {buildFlags} --cc:vcc  --header:NimForUEFFI.h --debugger:native --threads --tlsEmulation:off --app:lib --d:host --nimcache:.nimcache/host src/hostnimforue/hostnimforue.nim") == 0)
  
  # copy header
  let ffiHeaderSrc = ".nimcache/host/NimForUEFFI.h"
  let ffiHeaderDest = "NimHeaders" / "NimForUEFFI.h"
  copyFile(ffiHeaderSrc, ffiHeaderDest)
  log("Copied " & ffiHeaderSrc & " to " & ffiHeaderDest)

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
  ]
  let buildFlags = @[buildSwitches, targetSwitches(withDebug), ueincludes, uesymbols, pluginPlatformSwitches(withDebug), extraSwitches, guestSwitches].foldl(a & " " & b.join(" "), "")
  let compCmd = &"nim cpp {buildFlags} --app:lib --d:genffi -d:withPCH --nimcache:.nimcache/guest src/nimforue.nim"
  doAssert(execCmd(compCmd)==0)
  
  copyNimForUELibToUEDir("nimforue")




proc ensureGameConfExists() = 
  let fileTemplate = """
switch("path", "../Plugins/NimForUE/src/nimforue/unreal/bindings")
switch("path","../Plugins/NimForUE/src/nimforue/game")
switch("path","../Plugins/NimForUE/src/nimforue/")
"""
  let gameConf = NimGameDir / "config.nims"
  if not fileExists(gameConf):
    writeFile(gameConf, fileTemplate)

proc compileGame*(extraSwitches:seq[string], withDebug:bool) = 
  let gameSwitches = @[
    "-d:game",
    &"-d:BindingPrefix={PluginDir}/.nimcache/gencppbindings/@m..@sunreal@sbindings@sexported@s"
  ]
  ensureGameConfExists()
  #We compile from the engine directory so we dont surpass the windows argument limits for the linker 
  let engineBase = parentDir(config.engineDir)
  # setCurrentDir(e ngineBase)
  #TODO the final path will be relative to the engine dir this is just a hack to get it working for now
  # var uesymbols = uesymbols.mapIt(it.replace(config.engineDir, "Engine"))
  let gameFolder = NimGameDir
  let nimCache = ".nimcache/game"/(if withDebug: "debug" else: "release")

  let buildFlags = @[buildSwitches, targetSwitches(withDebug), ueincludes, uesymbols, gamePlatformSwitches(withDebug), gameSwitches, extraSwitches].foldl(a & " " & b.join(" "), "")
  let compCmd = &"nim cpp {buildFlags} --app:lib   -d:withPCH --nimcache:{nimCache} {gameFolder}/game.nim"
  doAssert(execCmd(compCmd)==0)
  # setCurrentDir(PluginDir)
  copyNimForUELibToUEDir("game")
  #We need to make sure that gen cpp files doenst exists in editor builds
  let privateFolder = PluginDir / "Source" / "NimForUE" / "Private" / "NimForUEGame"
  # removeDir(privateFolder)


proc compileGameNonEditor*(extraSwitches:seq[string], withDebug:bool) = 
  let gameSwitches = @[
    "-d:game",
    &"-d:BindingPrefix={PluginDir}/.nimcache/gencppbindings/@m..@sunreal@sbindings@sexported@s"
  ]
  let bindingsDir = PluginDir / ".nimcache/gencppbindings"
  ensureGameConfExists()
  #We compile from the engine directory so we dont surpass the windows argument limits for the linker 
  let engineBase = parentDir(config.engineDir)
  # setCurrentDir(engineBase)
  #TODO the final path will be relative to the engine dir this is just a hack to get it working for now
  # var uesymbols = uesymbols.mapIt(it.replace(config.engineDir, "Engine"))
  let gameFolder = NimGameDir
  let nimCache = ".nimcache/nimforuegame"/(if withDebug: "debug" else: "release")

  let buildFlags = @[buildSwitches, targetSwitches(withDebug), ueincludes, uesymbols, gamePlatformSwitches(withDebug), gameSwitches, extraSwitches].foldl(a & " " & b.join(" "), "")
  let compCmd = &"nim cpp {buildFlags} --compileOnly  -d:withPCH --nimcache:{nimCache} {gameFolder}/game.nim"
  doAssert(execCmd(compCmd)==0)
  #Copy the header into the NimHeaders
  # copyFile(nimCache / "NimForUEGame.h", NimHeadersDir / "NimForUEGame.h")
  #We need to copy all cpp files into the private folder in the plugin
  let privateFolder = PluginDir / "Source" / "NimForUE" / "Private" / "NimForUEGame"
  removeDir(privateFolder)
  createDir(privateFolder)
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
    let cppDst = privateFolder / filename
    if fileExists(cppDst) and readFile(cppFile) == readFile(cppDst):
      continue
    else:
      log "Will recompile " & cppDst
      copyFile(cppFile, cppDst)


  # for cppFile in walkFiles(bindingsDir/ &"*.cpp"):
  #   let filename = cppFile.extractFilename()
  #   if filename.contains("sbindings@") and not (filename.contains("unrealed") or filename.contains("umgeditor")): 
  #     copyFile(cppFile, privateFolder / filename)





proc compileGenerateBindings*() = 
  let buildFlags = @[buildSwitches, targetSwitches(false), pluginPlatformSwitches(false), ueincludes, uesymbols].foldl(a & " " & b.join(" "), "")
  doAssert(execCmd(&"nim  cpp {buildFlags}  --noMain --compileOnly --header:UEGenBindings.h  --nimcache:.nimcache/gencppbindings src/nimforue/codegen/maingencppbindings.nim") == 0)
  let ueGenBindingsPath =  config.nimHeadersDir / "UEGenBindings.h"
  copyFile("./.nimcache/gencppbindings/UEGenBindings.h", ueGenBindingsPath)
  #It still generates NimMain in the header. So we need to get rid of it:
  let nimMain = "N_CDECL(void, NimMain)(void);"
  writeFile(ueGenBindingsPath, readFile(ueGenBindingsPath).replace(nimMain, ""))

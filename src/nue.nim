
# tooling for NimForUE
import std / [ options, os, osproc, parseopt, sequtils, strformat, json, strutils, sugar, tables, times ]
import buildscripts / [buildcommon, buildscripts, nimforueconfig, plugingenerator]
import buildscripts/nuecompilation/nuecompilation
import buildscripts/switches/switches
import nimforue/utils/[stringutils, utils]
import nimforue/codegen/[headerparser]
import  buildscripts/keyboard


var taskOptions: Table[string, string]

type
  Task = object
    name: string
    description: string
    routine: proc(taskOptions: Table[string, string]) {.nimcall.}

var tasks: seq[tuple[name:string, t:Task]]

template task(taskName: untyped, desc: string, body: untyped): untyped =
  proc `taskName`(taskOptions: Table[string, string]) {.nimcall.} =
    let config {.inject.} = getNimForUEConfig()
    let start = now()
    let curDir = getCurrentDir()
    setCurrentDir(PluginDir)
    log ">>>> Task: " & astToStr(taskName) & " <<<<"
    body
    log "!!>> " & astToStr(taskName) & " Time: " & $(now() - start) & " <<<<"
    setCurrentDir(curDir)
  tasks.add (name:astToStr(taskName), t:Task(name: astToStr(taskName), description: desc, routine: `taskName`))


proc echoTasks() =
  log "Here are the task available: "
  for t in tasks:
    log("  " & t.name & (if t.name.len < 6: "\t\t" else: "\t") & t.t.description)

proc getPlatformTargetFromOptions(taskOptions: Table[string, string]): PlatformTargetKind =
  if "platform" in taskOptions:
    taskOptions["platform"].getPlatformTarget()
  else:
    getPlatformTarget("") #not specify defaults to the current platform

proc getPluginName(): string = 
  result = 
    if "pluginname" in taskOptions: taskOptions["pluginname"] else: "Nue" & GameName()
  #plugins are created per platform so we append the platform to the name
  result = result & ($getPlatformTargetFromOptions(taskOptions)).capitalizeAscii()

proc main() =
  if commandLineParams().join(" ").len == 0:
    log "nue: NimForUE tool"
    echoTasks()

  var p = initOptParser()
  var taskk:Option[Task]
  for kind, key, val in p.getopt():
    case kind
    of cmdEnd: doAssert(false) # cannot happen with getopt
    of cmdShortOption, cmdLongOption:
      case key:
      of "h", "help":
        log "Usage, Commands and Options for nue"
        echoTasks()
        quit()
      else:
        taskOptions[key] = val
    of cmdArgument:
      let res = tasks.filterIt(it.name == key) #TODO: Match first characters if whole word doesn't match, so we don't need task aliases
      if res.len > 0:
        taskk = some(res[0].t)
      elif taskk.isSome():
        doAssert(not taskOptions.hasKey("task_arg"), "TODO: accept more than one task argument")
        taskOptions["task_arg"] = key
      elif key in getAllGameLibs():
        taskk = some(tasks.filterIt(it.name == "lib")[0].t)
        taskOptions["name"] = key
      else:
        log &"!! Unknown task {key}."
        echoTasks()

  if taskk.isSome():
    taskk.get().routine(taskOptions)




# --- Define Tasks ---

task guest, "Builds the main lib. The one that makes sense to hot reload.":
  var extraSwitches = newSeq[string]()
  if "f" in taskOptions: 
    extraSwitches.add "-f" #force 
  if "nolinedir" in taskOptions:  
    extraSwitches.add "--linedir:off"
  if "noline" in taskOptions:
    extraSwitches.add "--linedir:off --linetrace:off"
  
  let debug = "debug" in taskOptions
  if debug:
    log "Compiling with Debug"

  compilePlugin(extraSwitches, debug)





task host, "Builds the host that's hooked to unreal":
  when defined(windows):
    compileHost()
  elif defined(macosx):
    compileHostMac()
  else:
    log "Host compilation not supported on this platform"

task h, "Alias to host":
  host(taskOptions)



task cleanh, "Clean the .nimcache/host folder":
  removeDir(".nimcache/host")

task cleanlibs, "Clean the .nimcache for plugin, game and libs":
  removeDir(".nimcache/guest")
  #log getAllGameLibs().repr
  getAllGameLibs()
    .forEach((dir:string)=>removeDir(".nimcache"/dir))


when defined windows:
  task killvcc, "Windows: Kills cl.exe and link.exe if they're running":
    log("Killing cl.exe", lgWarning)
    discard execCmd("taskkill /F /T /IM cl.exe")
    log("Killing link.exe", lgWarning)
    discard execCmd("taskkill /F /T /IM link.exe")

task clean, "Clean the nimcache folder":
  when defined windows:
    killvcc(taskOptions)
  cleanh(taskOptions)
  cleanlibs(taskOptions)

task ugenproject, "Calls UE Generate Project":
  when defined(macosx):
    let uprojectFile = GamePath()
    let cmd = &"{config.engineDir}/Build/BatchFiles/Mac/GenerateProjectFiles.sh -project={uprojectFile} -game"
    log cmd
    doAssert(execCmd(cmd) == 0)
  else:
    log "Project generation not supported on this platform"

task ubuild, "Calls Unreal Build Tool for your project":
  #This logic is temporary. We are going to get of most of the config data
  #and just define const globals for all the paths we can deduce. The moment to do that is when supporting Game builds
  if isLiveCodingRunning():
    triggerLiveCoding(10)
    return
  let curDir = getCurrentDir()
  let uprojectFile = GamePath()
  proc isTargetFile(filename:string) : bool = 
    if WithEditor: "Editor" in filename
    else: "Editor" notin filename

  let walkPattern = config.gameDir & "/Source/*.Target.cs"
  let targetFiles = walkPattern.walkFiles.toSeq().filter(isTargetFile)
  log "Targe files: " &  $targetFiles
  #left for reference in case new way doest work with 5.1 logic
# let target = targetFiles[0].split(".")[0].split(PathSeparator)[^1] #i.e " NimForUEDemoEditor "
  assert targetFiles.len > 0, "No target files found. Make sure you have an Unreal C++ project."
  let target = targetFiles[0].split(PathSeparator)[^1].split(".")[0] #i.e " NimForUEDemoEditor "

  log "Target is " & target
  try:
    setCurrentDir(config.engineDir)
    let buildCmd =  
      case config.targetPlatform
        of Win64: "Build" / "BatchFiles" / "Build.bat"
        of Mac: "./Build/BatchFiles/Mac/Build.sh" # untested
      

 
    let cmd = &"{buildCmd} {target} {config.targetPlatform} {config.targetConfiguration} {uprojectFile} -waitmutex"
    
    log cmd
    doAssert(execCmd(cmd) == 0)
    setCurrentDir(curDir)
  except:
    #TODO control livecoding here
    log getCurrentExceptionMsg(), lgError
    log getCurrentException().getStackTrace(), lgError
    quit(QuitFailure)
    


# task game, "Builds the game lib":
#   var extraSwitches = newSeq[string]()
#   if "f" in taskOptions: 
#     extraSwitches.add "-f" #force 
#   if "nolinedir" in taskOptions:  
#     extraSwitches.add "--linedir:off"
 
#   let debug = "debug" in taskOptions
#   let livecoding = "livecoding" in taskOptions
#   if config.withEditor and not livecoding:
#     compileGame(extraSwitches, debug)
#   else:
#     compileGameToUEFolder(extraSwitches, debug)
#     if livecoding and isLiveCodingRunning(): 
#       triggerLiveCoding(10)
#     else:
#       ubuild(taskOptions)



task lib, "Builds a game lib":
  let pluginName = if "pluginname" in taskOptions: taskOptions["pluginname"] else: "Nue" & GameName()

  var extraSwitches = newSeq[string]()
  var withLiveCoding = false
  let withEditor = config.withEditor

  if "f" in taskOptions: 
    extraSwitches.add "-f" #force 
  if "nolinedir" in taskOptions:  
    extraSwitches.add "--linedir:off"
  if "noline" in taskOptions:
    extraSwitches.add "--linedir:off --linetrace:off"

  if "livecoding" in taskOptions: #notice when doing non editor builds we will be doing the same process
    withLiveCoding = true
  let shouldGenerateModule = withLiveCoding or not withEditor
  if shouldGenerateModule:
    extraSwitches.add "--compileOnly"
  else:
    discard
    #TODO remove autogen plugin

  let debug = "debug" in taskOptions
  let release = "release" in taskOptions
  let threads = "threads" in taskOptions

  if "name" in taskOptions:
    let name = taskOptions["name"]
    log "Compiling lib " & name & "..."
    if debug:
      log "\twith debug"
    assert name in getAllGameLibs(), "The lib " & name & " doesn't exist in the game. You need to create one first by adding a folder and a file like so: 'mylib/mylib.nim`"         
    let platformTarget = getPlatformTargetFromOptions(taskOptions)
    compileLib(taskOptions["name"], extraSwitches, debug, release, threads, platformTarget, genCompileScript, runCompileScript)
    if shouldGenerateModule:
      generatePlugin(getPluginName(), platformTarget)
      generateModule(name.capitalizeAscii(), getPluginName(), platformTarget)
      #TODO remove this module dll so it isnt loaded
      # ubuild(taskOptions)
  else:
    log "You need to specify a name for the lib. i.e. 'nue lib --name=mylib'"
 

task rebuildlibs, "Rebuilds the plugin, game and libs":
  cleanlibs(taskOptions)
  guest(taskOptions)
  for lib in getAllGameLibs():
    taskOptions["name"] = lib
    lib(taskOptions)

task dumpConfig, "Displays the config variables":
  dump config

task codegen, "Generate the bindings structure from the persisted json (TEMPORAL until we have it incremental)":
  createDir(config.nimHeadersModulesDir) # we need to create the bindings folder here because we can't importc
  createDir(config.bindingsImportedDir) # we need to create the bindings folder here because we can't importc
  createDir(config.bindingsExportedDir) # we need to create the bindings folder here because we can't importc
  let skipCodegenCache = if "skipcodegencache" in taskOptions: "--d:skipCodegenCache" else: ""
  let buildFlags = @[buildSwitches, @[skipCodegenCache]].foldl(a & " " & b.join(" "), "")
  doAssert(execCmd(&"nim cpp {buildFlags} --compileonly -f --nomain --maxLoopIterationsVM:400000000 --nimcache:.nimcache/projectbindings src/nimforue/codegen/genprojectbindings.nim") == 0)

task cleanbindingheader, "Process the UEGenBindings  file":
  #since Nim 2.0 we need to clean up the produced header:
  let headerFile = config.nimHeadersDir / "UEGenBindings.h"
  var lines = readFile(headerFile).split("\n")
  let typesToSkip = @[
    #Notice these types are drag by Nim in some cases into the header causing collisions with the exported module.
    #The commit below will prevent most non needed pulls
    #https://github.com/nim-lang/Nim/pull/23369
    "TNimNode", "NimStrPayload", "NimStringV2", "TNimTypeV2", "Exception",
    "TNimType", "RootObj", "RootEffect", "TSafePoint", "GcFrameHeader", 
    "ForLoopStmt"
  ]
  var header = ""
  var insideType = false
  for l in lines:
    for t in typesToSkip:
      if l.contains(&"struct " & t & " {") or
      l.contains(&"struct " & t & " : public"):
      
        insideType = true    
    if not insideType:
      header.add l & "\n"

    if insideType and l.contains("};"):
      insideType = false

  writeFile(headerFile, header)

task gencppbindings, "Generates the codegen and cpp bindings":
  if "only" notin taskOptions:
    codegen(taskOptions)
  log "compiling generated bindings"
  compileGenerateBindings()
  cleanbindingheader(taskOptions)
  ubuild(taskOptions)



task cleanbindings, "Clears the bindings and autogenerated data":
  proc removeFileWithPatterFromDirRec(dir : string, criteria : proc(s:string):bool) =
    walkDirRec(dir)
    .toSeq()
    .filter(criteria) 
    .forEach(removeFile)

  removeDir("./.nimcache/gencppbindings")

  removeFileWithPatterFromDirRec(config.nimHeadersModulesDir, file=>file.endsWith(".h"))
  removeFileWithPatterFromDirRec(config.bindingsDir, file=>file.endsWith(".nim"))

  discard tryRemoveFile(config.nimHeadersDir / "UEGenBindings.h")
  discard tryRemoveFile(config.nimHeadersDir / "UEGenClassDefs.h")
  writeFile(config.nimHeadersDir / "UEGenBindings.h", "#pragma once\n\n")
  writeFile(config.nimHeadersDir / "UEGenClassDefs.h", "#pragma once\n\n")

  if "g" in taskOptions:
    removeDir("./.nimcache/guest")


task rebuild, "Cleans and rebuilds the unreal plugin, host, guest and cpp bindings":
  var attempts = 0
  while dirExists(".nimcache/guest"):
    try:
      clean(taskOptions)
    except:
      log("Could not clean nimcache. Retrying...\n", lgWarning)
      inc attempts
      if attempts > 5:
        quit("Could not clean nimcache. Aborting.", QuitFailure)
  ubuild(taskOptions)
  gencppbindings(taskOptions)
  host(taskOptions)

#TODO: Unify all bindings related tasks into this one
task genbindings, "Runs the Generate Bindings commandlet":
  let silent = if "silent" in taskOptions: "-silent" else: ""
  when defined windows:
    let cmd = &"{config.engineDir}\\Binaries\\Win64\\UnrealEditor.exe {GamePath()} -run=GenerateBindings {silent} " 
    echo "Running " & cmd
    let outPut = execProcess(cmd, getCurrentDir())
    echo outPut.replace("\n", "") #for some reason it will output a new line per character otherwise
  else:
    let cmd = &"{config.engineDir}/Binaries/Mac//UnrealEditor.app/Contents/MacOS/UnrealEditor  {GamePath()} -run=GenerateBindings {silent}"
    discard execCmd(cmd)

task genbindingsall, "Runs the Generate Bindings commandlet":
  # guest(taskOptions)
  genbindings(taskOptions)
  gencppbindings(taskOptions)

task creategame, "Creates the sample Game plugin":
  createGameDir()

task setup, "Setups the plugin by building the initial tasks in order":
  creategame(taskOptions)
  addCompilerOptionsToProject()
  ubuild(taskOptions)
  guest(taskOptions)
  genbindingsall(taskOptions)
  rebuildlibs(taskOptions)
  addNUEPluginToProject()
  compileLib("game", @[], false, false, false, getPlatformTargetFromOptions(taskOptions))

task addnueplugin, "add NimForUE plugin to project":
  addNUEPluginToProject()

task starteditor, "opens the editor":
  ubuild(taskOptions)
  when defined windows:
    let cmd = case config.targetConfiguration:
    of Development:
      &"{config.engineDir}\\Binaries\\Win64\\UnrealEditor.exe {squotes(GamePath(withQuotes=false))}" 
    of Debug:
      &"{config.engineDir}\\Binaries\\Win64\\UnrealEditor-Win64-{config.targetConfiguration}.exe {squotes(GamePath(withQuotes=false))}" 
    else:
      log &"{config.targetConfiguration} not supported"
      quit()
      ""
    log &"{cmd}"
    discard execCmd(&"powershell.exe {cmd}")
  else:
    discard execCmd("open " & GamePath())

task ue, "alias for starteditor":
  starteditor(taskOptions)

task targetconfig, "switch the targetConfiguration and rebuild (options are --dev, --debug, --shipping)":
  var otc = none[TargetConfiguration]()
  if "dev" in taskOptions or "development" in taskOptions: 
    otc = some(Development)
  elif "debug" in taskOptions:
    otc = some(Debug)
  elif "shipping" in taskOptions:
    otc = some(Shipping)
    log "TODO Need to test this path! quitting for now", lgError
    quit()

  if otc.isNone():
    log &"Current targetConfiguration: {config.targetConfiguration}"
    log "\tTo switch use --dev for Development, --debug for Debug, or --shipping for Shipping to update.", lgWarning
    quit()

  let tc = otc.get()
  log &"Updating targetConfiguration {tc}\n\tin {getConfigPath()}", lgWarning

  var c = getOrCreateNUEConfig()
  c.targetConfiguration = tc
  c.saveConfig()

  ubuild(taskOptions)
  taskOptions["only"] = ""
  gencppbindings(taskOptions)
  rebuildLibs(taskOptions) # pass --debug to rebuild


task showincludes, "Traverses UEDeps.h gathering includes and shows then in the script":
  let useCache = "usecache" in taskOptions
  let includes = getPCHIncludes(useCache)
  if "save" in taskOptions:
    writeFile taskOptions["save"], $includes
  log $len(includes)

task showtypes, "Traverses UEDeps.h looking for types (uclasses only for now)":
  let useCache = "usecache" in taskOptions
  let types = getAllPCHTypes(useCache)
  log &"There are {len(types)} PCH types"



task ok, "prints ok if NUE and Host are built":
  if fileExists(HostLibPath()):
    log "ok host built"
  else:
    log "host not built"
    host(taskOptions)
  let pchTypes = "./headerdata/allpchtypes.json"
  if fileExists(pchTypes):
    log "ok pch types generated"
  else:
    log "Needs to generate pch types"    
    taskOptions["usecache"] = "true"
    showtypes(taskOptions)  
  createDir(BindingsVMDir)
  if not fileExists(BindingsVMDir / "guest.nim"):
    writeFile(BindingsVMDir / "guest.nim", "")

task copybuildconfiguration, "Copies the unreal build configuration from the plugin to APPData/Roaming/Unreal Engine/BuildConfiguration":
  let buildConfigFile = PluginDir / "BuildConfiguration.xml"
  let appDataDir = getEnv("USERPROFILE")
  let buildConfigFileDest =  appDataDir / "Unreal Engine/UnrealBuildTool/BuildConfiguration.xml"
  log "Copying build configuration from " & buildConfigFile & " to " & buildConfigFileDest
  createDir(buildConfigFileDest.parentDir)
  copyFile(buildConfigFile, buildConfigFileDest)

task cleanmodules, "Removes the generated code from the game and libs":
  let pluginName = if "name" in taskOptions: taskOptions["name"] else: "Nue" & GameName()
  let genPluginDir = parentDir(PluginDir) / pluginName
  let libs = getAllGameLibs()
  log "Cleaning Nim only lib " & $libs
  for lib in libs:
    taskOptions["name"] = lib   
    removeDir(PluginDir/".nimcache"/lib)
    log "Cleaning generate code for " & lib 
    cleanGenerateCode(lib.capitalizeAscii(), genPluginDir)



task buildmodules, "Rebuilds the plugin, game and libs":
  let pluginName = if "pluginname" in taskOptions: taskOptions["pluginname"] else: "Nue" & GameName()

  #remove code on the plugin 
  taskOptions["nobuild"] = ""
  taskOptions["livecoding"] = ""
  let platformTarget = getPlatformTargetFromOptions(taskOptions)
  let libs = getAllGameLibs()
  log "Compiling Nim only lib " & $libs
  for lib in libs:
    taskOptions["name"] = lib   
    lib(taskOptions)
    generateModule(lib.capitalizeAscii(), pluginName, platformTarget)  

task genplugin, "Creates a plugin, by default it uses the name of the game with NUE as prefix":  
  #TODO replace this with a call to all libs 
  let platformTarget = getPlatformTargetFromOptions(taskOptions)
  generatePlugin(getPluginName(), platformTarget)

task removeplugin, "Removes the plugin, by default it uses the name of the game with NUE as prefix":  
  removePlugin(getPluginName())


task setupvm, "Creates the vm module library and adds a scratchup to it": 
  let dir = NimGameDir() / "vm"
  let vmFile = dir / "vm.nim"
  let scratchpadFile = dir / "scratchpad.nim"
  if fileExists(NimGameDir() / "vm" / "vm.nim"):
    log "vm module already exists"
    return
  const vmTemplate = """
include unrealprelude
import vm/nimvm
import vmlibrary
"""
  const scratchpadTemplate = """
include vmprelude
log "Hello World!"

"""

  createDir(dir)
  writeFile(vmFile, vmTemplate)
  writeFile(scratchpadFile, scratchpadTemplate)
  log "vm module created"
  compilePlugin(@[], true)

  taskOptions["name"] = "vm"
  taskOptions["release"] = ""  
  lib(taskOptions)

task macossetup, "Optional setup for MacOs so both project can live in the same folder":
  #Manually create the GameMacOs folder #=
  #Manyally copy (uproject) 
  #create syslinks (Config, Content, Plugins, Source)
  let sourceDir = getOrCreateNUEConfig().gameDir.parentDir()
  let dstDir = getOrCreateNUEConfig().gameDir
  for dir in ["NimForUE", "Config", "Content", "Plugins", "Source"]:
    log &"Creating symlink for {sourceDir / dir} to {dstDir / dir}"
    createSymlink(sourceDir / dir, dstDir / dir)

task cook, "Cooks the game":
  #[
  cd /D "UE4_ROOT_DIR\Engine\Build\BatchFiles"
RunUAT BuildCookRun -project=PROJECT_ROOT_DIR\PROJECT_NAME.uproject -build -cook -clientconfig=Development -NoP4 -pak -crashreporter -stage -serverplatform=Win64 -stagingdirectory=PROJECT_ROOT_DIR\Build
pause
  ]#
  when not defined(windows):
    log "Cooking is not supported on non windows platforms", lgError
    quit()
  let uproject = getGamePathFromGameDir()
  let projectDir = parentDir(uproject)
  let stagingDir = projectDir / "Build"
  let uat = config.engineDir  / "Build" / "BatchFiles" / "RunUAT.bat"
  let cmd = &"""powershell.exe {uat} BuildCookRun -project="{uproject}" -build -cook -clientconfig={config.targetConfiguration} -NoP4 -pak -crashreporter -stage -serverplatform={config.targetPlatform} -stagingdirectory="{stagingDir}"""
  echo cmd
  doAssert(execCmd(cmd) == 0, "Cooking failed. Check the logs for more details")

# --- End Tasks ---
ok(taskOptions)
main()

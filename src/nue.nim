# tooling for NimForUE
import std / [ options, os, osproc, parseopt, sequtils, strformat, json, strutils, sugar, tables, times ]
import buildscripts / [buildcommon, buildscripts, nimforueconfig]
import buildscripts/nuecompilation/nuecompilation
import nimforue/utils/utils

var taskOptions: Table[string, string]
let config = getNimForUEConfig()

type
  Task = object
    name: string
    description: string
    routine: proc(taskOptions: Table[string, string]) {.nimcall.}

var tasks: seq[tuple[name:string, t:Task]]

template task(taskName: untyped, desc: string, body: untyped): untyped =
  proc `taskName`(taskOptions: Table[string, string]) {.nimcall.} =
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

proc main() =
  if commandLineParams().join(" ").len == 0:
    log "nue: NimForUE tool"
    echoTasks()

  var p = initOptParser()
  var ts:Option[Task]
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
        ts = some(res[0].t)
      elif ts.isSome():
        doAssert(not taskOptions.hasKey("task_arg"), "TODO: accept more than one task argument")
        taskOptions["task_arg"] = key
      else:
        log &"!! Unknown task {key}."
        echoTasks()

  if ts.isSome():
    ts.get().routine(taskOptions)




# --- Define Tasks ---

task guest, "Builds the main lib. The one that makes sense to hot reload.":
  var extraSwitches = newSeq[string]()
  if "f" in taskOptions: 
    extraSwitches.add "-f" #force 
  if "nolinedir" in taskOptions:  
    extraSwitches.add "--linedir:off"
  
  let debug = "debug" in taskOptions

  compilePlugin(extraSwitches, debug)

task game, "Builds the game lib":
  var extraSwitches = newSeq[string]()
  if "f" in taskOptions: 
    extraSwitches.add "-f" #force 
  if "nolinedir" in taskOptions:  
    extraSwitches.add "--linedir:off"
 
  let debug = "debug" in taskOptions

  compileGame(extraSwitches, debug)


task host, "Builds the host that's hooked to unreal":
  compileHost()

task h, "Alias to host":
  host(taskOptions)


task cleanh, "Clean the .nimcache/host folder":
  removeDir(".nimcache/host")

task cleang, "Clean the .nimcache guest and winpch folder":
  removeDir(".nimcache/guest")

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
  cleang(taskOptions)

task ubuild, "Calls Unreal Build Tool for your project":
  #This logic is temporary. We are going to get of most of the config data
  #and just define const globals for all the paths we can deduce. The moment to do that is when supporting Game builds

  let curDir = getCurrentDir()
  let uprojectFile = GamePath
  let walkPattern = config.gameDir & "/Source/*Editor.Target.cs"
  let targetFiles = walkPattern.walkFiles.toSeq()

  #For now only editor
  let target = targetFiles[0].split(".")[0].split(PathSeparator)[^1] #i.e " NimForUEDemoEditor "

  log target
  try:
    setCurrentDir(config.engineDir)
    let buildCmd =  
      case config.targetPlatform
        of Win64: r"Build\BatchFiles\Build.bat"
        of Mac: "./Build/BatchFiles/Mac/Build.sh" # untested
      
 
    let cmd = &"{buildCmd} {target} {config.targetPlatform} {config.targetConfiguration} {uprojectFile} -waitmutex"
    
    log cmd
    doAssert(execCmd(cmd) == 0)
    setCurrentDir(curDir)
  except:
    log getCurrentExceptionMsg(), lgError
    log getCurrentException().getStackTrace(), lgError
    quit(QuitFailure)

task dumpConfig, "Displays the config variables":
  dump config

task codegen, "Generate the bindings structure from the persisted json (TEMPORAL until we have it incremental)":
  createDir(config.nimHeadersModulesDir) # we need to create the bindings folder here because we can't importc
  createDir(config.bindingsExportedDir) # we need to create the bindings folder here because we can't importc
  doAssert(execCmd(&"nim cpp --mm:orc --compileonly -f --nomain --maxLoopIterationsVM:400000000 --nimcache:.nimcache/projectbindings src/nimforue/codegen/genprojectbindings.nim") == 0)

task gencppbindings, "Generates the cpp bindings":
  codegen(taskOptions)
  compileGenerateBindings()

task cleanbindings, "Clears the bindings and autogenerated data":
  removeDir("./.nimcache/gencppbindings")
  removeDir(config.nimHeadersModulesDir)
  removeDir(config.bindingsDir)
  discard tryRemoveFile(config.nimHeadersDir / "UEGenBindings.h")
  discard tryRemoveFile(config.nimHeadersDir / "UEGenClassDefs.h")
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


task setup, "Setups the plugin by building the initial tasks in order":
  ubuild(taskOptions)
  guest(taskOptions)


task ok, "prints ok if NUE and Host are built":
  if fileExists(HostLibPath):
    log "ok host built"
  else:
    log "host not built"
    host(taskOptions)
  
  
  
# --- End Tasks ---
main()

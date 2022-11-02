# tooling for NimForUE
import std / [ options, os, osproc, parseopt, sequtils, strformat, strutils, sugar, tables, times ]
import buildscripts / [buildcommon, buildscripts, nimforueconfig, nimcachebuild]
import buildscripts/nuecompilation/nuecompilation

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
    log ">>>> Task: " & astToStr(taskName) & " <<<<"
    body
    log "!!>> " & astToStr(taskName) & " Time: " & $(now() - start) & " <<<<"
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

# task guestpch, "Builds the hot reloading lib. Options -f to force rebuild, --nogen to compile from nimcache cpp sources without generating, --nolinedir turns off #line directives in cpp output.": 
#   generateFFIGenFile(config) 
 
#   var force = "" 
#   if "f" in taskOptions: 
#     force = "-f" 
#   var noGen = "nogen" in taskOptions 
#   var lineDir = "on" 
#   var curTargetSwitches = targetSwitches 
#   if "nolinedir" in taskOptions:  
#     lineDir = "off" 
#     curTargetSwitches = targetSwitches.filterIt(it[0] != "debugger" and it[0] != "stacktrace") 
 
#   let buildFlags = @[ 
#       buildSwitches, curTargetSwitches, platformSwitches,  
#       ueincludes, uesymbols 
       
#     ].foldl(a & " " & fold(b), "") 
 
#   if not noGen: 
#     # doAssert(execCmd(&"nim cpp {force} --lineDir:{lineDir} {buildFlags} --genscript --app:lib --nomain --d:genffi -d:withPCH --nimcache:.nimcache/guestpch src/nimforue.nim") == 0) 
#     doAssert(execCmd(&"nim cpp {force} --lineDir:{lineDir} {buildFlags} --genscript --app:lib --nomain --d:genffi -d:withPCH --nimcache:.nimcache/guestpch src/nimforue.nim") == 0) 
 
#   if nimcacheBuild(buildFlags, "guestpch", "nimforue") == Success: 
#     copyNimForUELibToUEDir() 
#   else: 
#     log("!!>> Task: guestpch failed to build. <<<<", lgError) 
#     quit(QuitFailure) 
 
# task g, "Alias to guestpch": 
#   guestpch(taskOptions) 


task guest, "Builds the main lib. The one that makes sense to hot reload.":
  var extraSwitches = newSeq[string]()
  if "f" in taskOptions: 
    extraSwitches.add "-f" #force 
  if "nolinedir" in taskOptions:  
    extraSwitches.add "--linedir:off"
     
  compilePlugin(extraSwitches)

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
  let curDir = getCurrentDir()
  let walkPattern = config.pluginDir & "/../../*.uproject"
  let uprojectFiles = walkPattern.walkFiles.toSeq()
  doAssert(uprojectFiles.len == 1, &"There should only be 1 uproject file. uprojectfiles: {uprojectFiles}")

  let uprojectFile = uprojectFiles[0]
  try:
    setCurrentDir(config.engineDir)
    let buildCmd = r"Build\BatchFiles\" & (
      case config.targetPlatform
        of Win64: "Build.bat"
        of Mac: r"BatchFiles\Mac\Build.sh" # untested
      )

    doAssert(execCmd(buildCmd & " NimForUEDemoEditor " &
      $config.targetPlatform & " " &
      $config.targetConfiguration & " " &
      uprojectFile & " -waitmutex") == 0)
    setCurrentDir(curDir)
  except:
    log("Could not find uproject here: " & walkPattern & "\n", lgError)
    quit(QuitFailure)

task dumpConfig, "Displays the config variables":
  dump config

task codegen, "Generate the bindings structure from the persisted json (TEMPORAL until we have it incremental)":
  doAssert(execCmd(&"nim cpp --compileonly -f --nomain --maxLoopIterationsVM:400000000 --nimcache:.nimcache/projectbindings src/codegen/genprojectbindings.nim") == 0)

task gencppbindings, "Generates the cpp bindings":
  codegen(taskOptions)
  compileGenerateBindings()

task cleanbindings, "Clears the bindings and autogenerated data":
  removeDir("./.nimcache/gencppbindings")
  removeDir("./NimHeaders/Modules")
  # removeDir("./src/.reflectiondata")
  removeDir("./src/nimforue/unreal/bindings")
  discard tryRemoveFile("./NimHeaders/UEGenBindings.h")
  discard tryRemoveFile("./NimHeaders/UEGenClassDefs.h")
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

# --- End Tasks ---
makeSureFolderStructureIsAsExpected()

main()


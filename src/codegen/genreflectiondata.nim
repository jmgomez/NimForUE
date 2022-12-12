include ../nimforue/unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../nimforue/typegen/uemeta
import ../buildscripts/[nimforueconfig, buildscripts]
import ../nimforue/macros/genmodule #not sure if it's worth to process this file just for one function? 
import modulerules
const pluginDir {.strdefine.}: string = ""
proc getGameModules*(): seq[string] =
  try:        
    let projectJson = readFile(GamePath).parseJson()
    let modules = projectJson["Modules"]
                    .mapIt(it["Name"].jsonTo(string))
    return modules
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to parse project json"
    return @[]

proc getAllInstalledPlugins*(): seq[string] =
  try:        
    let projectJson = readFile(GamePath).parseJson()
    let plugins = projectJson["Plugins"]
                    .filterIt(it["Enabled"].jsonTo(bool))
                    .mapIt(it["Name"].jsonTo(string))
    
    return plugins
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to parse project json"
    return @[]

proc genReflectionData*(gameModules, plugins: seq[string]): UEProject =
  let deps = plugins 
              .mapIt(getAllModuleDepsForPlugin(it).mapIt($it).toSeq())
              .foldl(a & b, newSeq[string]()) & extraModuleNames & gameModules#, "Engine", "UMG", "UnrealEd"]
  
  # UE_Log &"Plugins: {plugins}"
  #Cache with all modules so we dont have to collect the UETypes again per deps
  var modCache = newTable[string, UEModule]()

  proc getUEModuleFromModule(module: string): Option[UEModule] =
    #TODO adds exclude deps as a rule per module
    var excludeDeps = @["CoreUObject"]
    if module == "Engine":
      excludeDeps.add "UMG"
      excludeDeps.add "Chaos"
      excludeDeps.add "AudioMixer"

    # if module == "SlateCore":
    #   excludeDeps.add "Slate"
    # # if module == "UMG":
    #   excludeDeps.add "MovieScene"

    var includeDeps = newSeq[string]() #MovieScene doesnt need to be bound
    if module == "MovieScene":
      includeDeps.add "Engine"

    #By default all modules that are not in the list above will only export BlueprintTypes
    let bpOnlyRules = makeImportedRuleModule(uerImportBlueprintOnly)
    
    let rules = 
      if module in moduleRules: 
        moduleRules[module] & codeGenOnly
      elif module in extraNonBpModules: 
        @[codeGenOnly]
      else: 
        @[bpOnlyRules, codeGenOnly]


    if module notin modCache: #if it's in the cache the virtual modules are too.
      let ueMods = tryGetPackageByName(module)
            .map((pkg:UPackagePtr) => pkg.toUEModule(rules, excludeDeps, includeDeps))
            .get(newSeq[UEModule]())

      if ueMods.isEmpty():
        UE_Error &"Failed to get module {module}. Did you restart the editor already?"
        return none[UEModule]()

      for ueMod in ueMods:
        UE_Log &"Caching {ueMod.name}"
        modCache.add(ueMod.name, ueMod)

    some modCache[module] #we only return the actual uemod


  proc getDepsFromModule(modName:string, currentLevel=0) : seq[string] = 
    if currentLevel > 5: 
      UE_Warn &"Reached max level for {modName}. Breaking the cycle"
      return @[]
    # UE_Log &"Getting deps for {modName}"
    let deps = getUEModuleFromModule(modName).map(x=>x.dependencies).get(newSeq[string]())
    deps &
      deps
        .mapIt(getDepsFromModule(it, currentLevel+1))
        .foldl(a & b, newSeq[string]()) 
        .deduplicate()


  let starts = now()
  let modules = (deps.mapIt(getDepsFromModule(it))
                    .foldl(a & b, newSeq[string]()) & deps)
                    .deduplicate()

  var ends = now() - starts
  let config = getNimForUEConfig()
  createDir(config.bindingsDir)
  let bindingsPath = (modName:string) => config.bindingsDir / modName.toLower() & ".nim"

  let modulesToGen = modCache
                      .values
                      .toSeq()
                      .filterIt(
                        it.hash != getModuleHashFromFile(bindingsPath(it.name)).get("_") or 
                        uerIgnoreHash in it.rules)
                      

  UE_Log &"Modules to gen: {modulesToGen.len}"
  UE_Log &"Modules in cache {modCache.len}"
  UE_Log &"Modules to gen {modulesToGen.mapIt(it.name)}"
  let ueProject = UEProject(modules:modulesToGen)
  
  #Show all deps for testing purposes
  UE_Log "All module deps:"
  # for m in ueProject.modules:
  #   UE_Log &"{m.name}: {m.dependencies}"

  let ueProjectAsStr = $ueProject
  let codeTemplate = """
import ../nimforue/typegen/models
const project* = $1
"""

  createDir(config.reflectionDataDir)
  writeFile(config.reflectionDataFilePath, codeTemplate % [ueProjectAsStr])

  ends = now() - starts
  UE_Log &"It took {ends} to gen all deps"
  return ueProject
  # UE_Warn $deps
  # UE_Warn $ueProject


proc genUnrealBindings*(gameModules, plugins: seq[string]) =
  try:
    let ueProject = genReflectionData(gameModules, plugins)
    # return

    # UE_Log $ueProject
    if ueProject.modules.isEmpty():
      UE_Log "No modules to generate"
      return

    # let config = getNimForUEConfig()
    # let cmd = &"{config.pluginDir}\\nue.exe gencppbindings"
    when defined(windows):
      var cmd = f &"{pluginDir}\\nue.exe"    
    else:
      var cmd = f &"{pluginDir}/nue"
    var
      args = f"gencppbindings"
      dir = f pluginDir
      stdOut : FString
      stdErr : FString

    let code = executeCmd(cmd, args, dir, stdOut, stdErr)

    # let str = execProcess(cmd, 
    #       workingDir=config.pluginDir, 
    #     #  options={poEvalCommand, poDaemon}
    # )
    UE_Log $code
    UE_Warn "output" & stdOut
    # UE_Error "error" & stdErr
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to generate reflection data"


proc NimMain() {.importc.}
proc execBindingsGenerationInAnotherThread*() {.cdecl.}= 
  # genUnrealBindings()
  # UE_Warn "Hello from another thread"
  proc ffiWraper(config:ptr NimForUEConfig) {.cdecl.} = 
    # NimMain()   
    UE_Log "Hello from another thread"
    UE_Log $config[]
    # genUnrealBindings(plugins)
    discard

  let plugins = getAllInstalledPlugins()
  let gameModules = getGameModules()
  # executeTaskInTaskGraph[ptr NimForUEConfig](config.unsafeAddr, ffiWraper)
  genUnrealBindings(gameModules, plugins)
include ../unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os]
import ../codegen/[models, modulerules, genmodule, uemeta]
import ../../buildscripts/[nimforueconfig, buildscripts]
import modulerules
import headerparser
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
    let excludePlugins = getGameUserConfigValue("exclude", newSeq[string]())
    let projectJson = readFile(GamePath).parseJson()
    let plugins = projectJson["Plugins"]
                    .filterIt(it["Enabled"].jsonTo(bool))
                    .mapIt(it["Name"].jsonTo(string))
                    .filterIt(it notin excludePlugins)
    
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
    var excludeDeps = @["CoreUObject"] 
   
#TODO make this a rule
    var includeDeps = newSeq[string]() #MovieScene doesnt need to be bound

    if module == "MovieSceneTracks":
      includeDeps.add "MovieSceneTools"
    
    if module == "GameFeatures":
      includeDeps.add "DataRegistry" #TODO investigate why it isnt being pulled


    #By default all modules that are not in the list above will only export BlueprintTypes
    #Update: Not anymore #TODO code to be deleted once this is working 
    let bpOnlyRules = makeImportedRuleModule(uerImportBlueprintOnly)
    let bpOnly = getGameUserConfigValue("bpOnly", false)
    let ruleBp = if bpOnly: @[bpOnlyRules] else: @[]
    let rules = 
      if module in moduleImportRules: 
        moduleImportRules[module] & codeGenOnly & ruleBp
      elif module in extraNonBpModules: 
        @[codeGenOnly]
      else: 
        @[codeGenOnly] & ruleBp

   
    if module notin modCache:# or module in modCache.values.toSeq.mapit(it.name): #if it's in the cache the virtual modules are too.
      let ueMods = tryGetPackageByName(module.split("/")[0])
            .map((pkg:UPackagePtr) => pkg.toUEModule(rules, excludeDeps, includeDeps, getPCHIncludes()))
            .get(newSeq[UEModule]())

      if ueMods.isEmpty():
        UE_Error &"Failed to get module {module}. Did you restart the editor already?"
        return none[UEModule]()

      for ueMod in ueMods:
        UE_Log &"Caching {ueMod.name}"
        modCache.add(ueMod.name, ueMod)

    some modCache[module] #we only return the actual uemod


  proc getDepsFromModule(modName:string, currentLevel=0) : seq[string] = 
    if modName. in modCache:
        return modCache[modName].dependencies
    const maxLevel = 5
    if currentLevel > maxLevel: 
      UE_Log &"Reached max level ({maxLevel}) for {modName}. Breaking the cycle"
      UE_Warn &"Current Module {modName}. Current module cache: {modCache.keys.toSeq()}"
      return @[]
    # UE_Log &"Getting deps for {modName}"
    let deps = getUEModuleFromModule(modName).map(x=>x.dependencies).get(newSeq[string]())
    deps &
      deps
        .mapIt(getDepsFromModule(it, currentLevel+1))
        .foldl(a & b, newSeq[string]()) 
        .deduplicate()


  let modules = (deps.mapIt(getDepsFromModule(it))
                    .foldl(a & b, newSeq[string]()) & deps)
                    .deduplicate()

  let config = getNimForUEConfig()
  createDir(config.bindingsDir)
  let bindingsPath = (modName:string) => config.bindingsDir / modName.toLower() & ".nim"

  #we save the pch types right before we discard the cached modules to avoid race conditions
  
  savePCHTypes(modCache.values.toSeq)

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
  let ueProjectAsStr = $ueProject
  let codeTemplate = """
import ../nimforue/codegen/[models, modulerules]
const project* = $1
"""

  # createDir(config.reflectionDataDir)
  # writeFile(config.reflectionDataFilePath, codeTemplate % [ueProjectAsStr])

  
  return ueProject
  # UE_Warn $deps
  # UE_Warn $ueProject


#Fire and forget 
proc genBindingsAsync*() = 
  when defined(windows):
    var cmd = f &"{pluginDir}\\nue.exe"    
  else:
    var cmd = f &"{pluginDir}/nue"
  var
    args = f"genbindings"
    dir = f pluginDir
    stdOut : FString
    stdErr : FString

  let code = executeCmd(cmd, args, dir, stdOut, stdErr)
  UE_Log $code
  UE_Warn "output" & stdOut

proc genUnrealBindings*(gameModules, plugins: seq[string], shouldRunSync:bool) =
  try:
    let ueProject = genReflectionData(gameModules, plugins)
    
    
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

    var code : int
    if shouldRunSync:
      let (output, _) = execCmdEx(&"{cmd} {args}")
      UE_Log output
    else:
      code = executeCmd(cmd, args, dir, stdOut, stdErr)
      UE_Log $code
      UE_Warn "output" & stdOut
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to generate reflection data"


proc NimMain() {.importc.}
proc execBindingGeneration*(shouldRunSync:bool) {.cdecl.}= 
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
  UE_Warn &"Plugins: {plugins}"
  UE_Warn &"Game Modules: {gameModules}"
  
  let starts = now()

  # executeTaskInTaskGraph[ptr NimForUEConfig](config.unsafeAddr, ffiWraper)
  genUnrealBindings(gameModules, plugins, shouldRunSync)
  var ends = now() - starts

  UE_Log &"It took {ends} to gen all deps"
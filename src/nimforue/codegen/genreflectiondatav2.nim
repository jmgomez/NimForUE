include ../unreal/prelude
import ../codegen/[codegentemplate,modulerules, headerparser, models, uemeta, genreflectiondata]
import std/[strformat, tables, hashes, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans, algorithm, macros]
import ../../buildscripts/[buildscripts, nimforueconfig]





template measureTime*(name: static string, body: untyped) =
  let starts = now()
  body
  let ends = (now() - starts)
  UE_Log (name & " took " & $ends & "  seconds")




proc getAllTypesFromFileTree(fileTree:NimNode) : seq[string] = 

  proc typeDefToName(typeNode: NimNode) : seq[string] = 
    case typeNode.kind
    of nnkTypeSection: 
      typeNode
        .children
        .toSeq
        .map(typeDefToName)
        .flatten()
    of nnkTypeDef:
      let nameNode = typeNode[0]
      if nameNode.kind == nnkIdent: #TYPE ALIAS
        return @[nameNode.strVal]
      if nameNode[0].kind == nnkPostFix: 
        @[nameNode[0][^1].strVal]
      else: 
        @[nameNode[0].strVal]
    else: 
      error("Error got " & $typeNode.kind)
      newSeq[string]()

  let typeNames = 
    fileTree
      .children
        .toSeq
        .filterIt(it.kind == nnkTypeSection)
        .map(typeDefToName)
        .flatten
        .filterIt(it != "*")
  typeNames


proc getAllImportsAsRelativePathsFromFileTree(fileTree:NimNode) : seq[string] = 
  func parseImportBracketsPaths(path:string) : seq[string] = 
    if "[" notin path:  return @[path]
    let splited = path.split("[")
    let (dir, files) = (splited[0], splited[1].split("]")[0].split(","))
    return files.mapIt(dir & "/" & it) #Not sure if you can have multiple [] nested in a import
      
      
  let imports = 
    fileTree
      .children
        .toSeq
        .filterIt(it.kind in [nnkImportStmt, nnkIncludeStmt])
        .mapIt(parseImportBracketsPaths(repr it[0]))
        .flatten
        .mapIt(it.split("/").mapIt(strip(it)).join("/")) #clean spaces
        
  imports



proc getAllTypesOf() : seq[string] = 
  let dir = PluginDir / "src" / "nimforue" / "unreal" 
  let path = dir / "prelude.nim"
  let nimCode = readFile(path)
  let entryPointFileTree = parseStmt(nimCode)

  let nimFilePaths = 
    getAllImportsAsRelativePathsFromFileTree(entryPointFileTree)
    .mapIt(it.absolutePath(dir) & ".nim")

  let fileTrees = 
    entryPointFileTree & nimFilePaths.mapIt(it.readFile.parseStmt)

  let typeNames = fileTrees.map(getAllTypesFromFileTree).flatten()

  typeNames

const DefinedTypes = getAllTypesOf()
const PrimitiveTypes = @[ 
  "bool", "float32", "float64", "int16", "int32", "int64", "int8", "uint16", "uint32", "uint64", "uint8"
]




func getAllFieldsFromUEType(uet:UEType) : seq[UEField] = 
  # Returns all fields for delegates, classes and structs. Notice it wont retunr enum fields
  case uet.kind:
  of uetEnum, uetInterface: @[]
  else: uet.fields

func getAllTypesFromUEField(uef:UEField) : seq[string] = 
  # Returns all types for a field. It will return generic types as they are in Nim.
  case uef.kind:
  of uefProp: @[uef.uePropType]
  of uefFunction: uef.signature.map(getAllTypesFromUEField).flatten()
  of uefEnumVal: @[]

func getNameFromUEPropType(nimType:string) : seq[string] = 
  # Will return the name of the type cleaned. No Ptr, no Generic, no Var, etc.
  var nimType = nimType
  if "var " in nimType:
    nimType = nimType.replace("var ", "").strip()
    
  if nimType.isGeneric:
    if "TMap" in nimType:
      nimType.extractKeyValueFromMapProp().map(getNameFromUEPropType).flatten()
    else:
      getNameFromUEPropType(nimType.extractInnerGenericInNimFormat())
  else:
    @[nimType.removeLastLettersIfPtr()]


func getCleanedDependencyNamesFromUEType(uet:UEType) : seq[string] = 
  {.cast(noSideEffect).}: #Accessing PCH types is safe
    #Consider returning empty for primitive types
    let fields = getAllFieldsFromUEType(uet)
    let extraTypes = 
      case uet.kind:
      of uetClass:
        (if uet.forwardDeclareOnly: @[uet.name, uet.parent] 
          else: @[uet.parent]) &
        uet.interfaces
      of uetStruct: @[uet.superStruct]
      else: @[]
    let types = fields.map(getAllTypesFromUEField).flatten() & extraTypes
    let cleanedTypes = 
      types.map(getNameFromUEPropType)
        .flatten()
        .deduplicate()
        .filterIt(it notin DefinedTypes & PrimitiveTypes)
        .filterIt(it != "")
        # .filterIt(it notin getAllPCHTypes())
    cleanedTypes

func getCleanedDependencyTypes*(uem:UEModule) : seq[string] = 
  let types = uem.types
  let cleanedTypes = types.map(getCleanedDependencyNamesFromUEType).flatten()
  cleanedTypes.deduplicate()

func getCleanedDefinitionNamesFromUEType(uet:UEType) : seq[string] = 
  #only name?
  #should not return fw declare only types:
  @[uet.name.replace(DelegateFuncSuffix, "")]

func getCleanedDefinitionTypes(uem:UEModule) : seq[string] = 
  let types = uem.types
  let cleanedTypes = types
    .map(getCleanedDefinitionNamesFromUEType).flatten()
  cleanedTypes.deduplicate()

func isTypeDefinedInModule(uem:UEModule, typeName:string) : bool = 
  let cleanedTypes = getCleanedDefinitionTypes(uem)
  typeName in cleanedTypes

func getModuleNameForType(typeDefinitions : Table[string, seq[string]], typeName:string) : Option[string] = 
  for key, value in typeDefinitions.pairs:
    if typeName in value:
      return some(key)

func getTypeDefinitions*(modules:seq[UEModule], common:UEModule) : Table[string, seq[string]] = 
  var typeDefinitions = initTable[string, seq[string]]()
  for module in modules:
    let typeDefs = getCleanedDefinitionTypes(module)
    for typeDef in typeDefs:
      if typeDef in common.types.mapIt(it.name) and module.name != common.name:
        continue
      if module.name notin typeDefinitions:
        typeDefinitions[module.name] = newSeq[string]()
      else:
        typeDefinitions[module.name].add(typeDef)
    
  typeDefinitions

func depsFromModule*(uem:UEModule, typeDefs : Table[string, seq[string]]) : seq[string] = 
  uem
    .getCleanedDependencyTypes
    .mapIt(getModuleNameForType(typeDefs, it))
    .sequence
    .deduplicate()
    .filterIt(it != uem.name)


func getFirstLevelCycles(modules:seq[UEModule]) : TableRef[string, seq[string]] = 
  let moduleNames = modules.mapIt(it.name)
  var allCycles = newTable[string, seq[string]]()
  for m in modules:
    let depOfs = modules.filterIt(m.name in it.dependencies).mapIt(it.name)
    let cycles = m.dependencies.filterIt(it in depOfs)
    if cycles.any:
      allCycles[m.name] = cycles

  allCycles

func moveTypeFrom(uet:UEType, source, destiny : var UEModule) = 
  #conceptually move types from source to destiny. 
  #if it's struct moves the whole type and removes it from source
  #if it's class, marks it as forwardDeclare only and do not remove for source. Doesnt copy fields

  let index = source.types.firstIndexOf((typ:UEType)=>typ.name == uet.name)
  case uet.kind:
  of uetClass:
    #The type is already defined in EngineTypes so no need to move it.
    if uet.name in ManuallyImportedClasses:
      return
    # UE_Log &"Moving type :{uet.name} from {source.name} to {destiny.name}"
    var uet = uet
    uet.isInCommon = true
    uet.forwardDeclareOnly = true
    source.types[index] = uet
    uet.forwardDeclareOnly = false
    uet.fields = @[]
    destiny.types.insert(uet) #Insert at the beggining so we got around and issue where the child is defined befpre the parent
  of uetEnum, uetStruct:
    source.types.del(index)
    destiny.types.add(uet)
  else: discard #only move structs, classes and enums for now

func moveTypesFrom(uets:seq[UEType], source, destiny : var UEModule) =
  for uet in uets:
    moveTypeFrom(uet, source, destiny)

func getDependentTypesFrom(uemDep, uemDefined : UEModule, typeDefinitions : Table[string, seq[string]]) : seq[string] = 
  #Return all types that are defined in uemDefined and are used in uemDep
  let allDefTypes = typeDefinitions[uemDefined.name]
  let allDepTypes = uemDep.getCleanedDependencyTypes()
  let dependentTypes = allDefTypes.filterIt(it in allDepTypes)
  dependentTypes

func removeDepsFromModule*(modDep, modDef, commonModule: var UEModule, typeDefinitions : Table[string, seq[string]]) =
  let dependentTypesNames = getDependentTypesFrom(modDep, modDef, typeDefinitions)
  let dependentTypes = modDef.types.filterIt(it.name in dependentTypesNames).deduplicate()
  modDef.dependencies.add commonModule.name #maybe common should be included?
  modDep.dependencies.add commonModule.name
  modDef.dependencies = modDef.dependencies.deduplicate()
  modDep.dependencies = modDef.dependencies.deduplicate().filterIt(it != modDef.name)
  # commonModule.types.add dependentTypes
  moveTypesFrom(dependentTypes, modDef, commonModule)


func fixCommonModuleDeps*(project: var UEProject, commonModule : var UEModule) : UEProject = 
  #Common module needs to gather its deps from the rest of the modules
  let afterTypeDefinitions = getTypeDefinitions(project.modules & commonModule, commonModule)
  let commonDefs = afterTypeDefinitions["Engine/Common"]
  let commonDeps = commonModule.getCleanedDependencyTypes().filterIt(it notin commonDefs)
  #Create the module as key and the common deps as value
  var commonDepsFromMod = initTable[string, seq[string]]()
  for modName, modTypes in afterTypeDefinitions.pairs:
    if modName == "Engine/Common": continue
    let commonDepsInMod = modTypes.filterIt(it in commonDeps)
    if commonDepsInMod.len > 0:
      commonDepsFromMod[modName] = commonDepsInMod

  var projectModules = project.modules
  for commonDep, typeNames in commonDepsFromMod.pairs:
    var modDef = projectModules.first(m=>m.name == commonDep).get()
    let types = modDef.types.filterIt(it.name in typeNames)
    moveTypesFrom(types, modDef, commonModule)
    projectModules = projectModules.replaceFirst((m:UEModule)=>m.name == modDef.name, modDef)


  project.modules = projectModules 
  project

func reorderTypesSoParentAreDeclaredFirst*(uem: var UEModule) : UEModule = 
  proc splitTypesWithParentDeclaredInThisModule(types:seq[UEType]) :  (seq[UEType], seq[UEType]) =
    let (withParentTypes, otherTypes) = types.partition((it:UEType)=> it.kind == uetClass and it.parent in types.mapIt(it.name))
    if withParentTypes.isEmpty():
      return (@[], otherTypes)
    else:
      let (withParentTypes2, otherTypes2) = splitTypesWithParentDeclaredInThisModule(withParentTypes)
      return (withParentTypes2, otherTypes & otherTypes2)
      
  
  let (_, otherTypes) = splitTypesWithParentDeclaredInThisModule(uem.types)
  uem.types = otherTypes
  uem

#Notice that type deps will vary based on how many modules are in the project. i.e. the same type 
#can be defined in common or somewhere else depending on the num of interdependencies
func makeSureCommonModuleIsInAllTypesThatDependOnIt(project: UEProject, commonModule:UEModule) : UEProject = 
    var projectModules = project.modules
      #makes sure common module is a dep for a modules that uses it
    let commonDefinedTypes = commonModule.getCleanedDefinitionTypes()
    for uem in projectModules:
      if commonModule.name notin uem.dependencies:
        let deps = uem.getCleanedDependencyTypes()
        # UE_Log &"Checking {uem.name} for common deps {deps}"
        let undefinedCommonDeps = commonDefinedTypes.filterIt(it in deps)
        
        if undefinedCommonDeps.any():
          # UE_Warn &"Module {uem.name} has common deps {undefinedCommonDeps} but is not a dep of common module"
          # UE_Log &"Common defined types: {commonDefinedTypes}"
          var uem = uem 
          uem.dependencies.add commonModule.name
          projectModules = projectModules.replaceFirst((m:UEModule)=>m.name == uem.name, uem)
    result.modules = projectModules
    


func calculateDeps(project:UEProject, typeDefs : Table[string, seq[string]]) : UEProject = 
  result = project
  var projectModules = newSeq[UEModule]()
  for module in project.modules:
      var uem = module
      uem.dependencies = depsFromModule(module, typeDefs).filterIt(it != uem.name)
      projectModules.add(uem)
  result.modules = projectModules

func addHashToModules*(project:var UEProject) : UEProject = 
  var projectModules = project.modules
  for uem in projectModules:
      var uem = uem
      uem.hash = $hash($uem)
      projectModules = projectModules.replaceFirst((m:UEModule)=>m.name == uem.name, uem)
  project.modules = projectModules
  project

func checkAllDepsAreDefinedWithinTheModule(uem : UEModule ) = 
  let allDeps = uem.getCleanedDependencyTypes()
  let allTypes = uem.getCleanedDefinitionTypes()
  let undefinedDeps = allDeps.filterIt(it notin allTypes)
  
  if undefinedDeps.any():
    UE_Log &"Module {uem.name} has undefined deps: {undefinedDeps}"

func getAllTypesDepsNotDefinedInAllModules*(project:UEProject, typeDefs : Table[string, seq[string]]) : Table[string, seq[string]] = 
  #returns all types that are deps but not defined in the typeDefs table
  var result = initTable[string, seq[string]]()
  let allTypes = typeDefs.values.toSeq.flatten.deduplicate
  UE_Log &"All types: {allTypes.len}"
  for uem in project.modules:
    let allDeps = uem.getCleanedDependencyTypes()
    let undefinedDeps = allDeps.filterIt(it notin allTypes)
    if undefinedDeps.any():
      result[uem.name] = undefinedDeps
  result

func removeDepsFromDelegatesEnumsAndCommon(project : UEProject) : UEProject = 
  result = project
  var projectModules = project.modules
  for uem in projectModules: #Delegate and enums shouldnt have any deps as they are just typedefs without dependencies
    if uem.name.split("/")[^1] in ["Delegates", "Enums", "Common"]:
      var uem = uem
      uem.dependencies = @[] 
      projectModules = projectModules.replaceFirst((m:UEModule)=>m.name == uem.name, uem)
  result.modules = projectModules
  



#Remove ufield from utype by dependency name
func removeDepFrom(uet:UEType, cleanedDepTypeName:string) : UEType = 
  #Only structs and classes can have deps
  if uet.kind notin [uetClass, uetStruct]: return uet 
  var uet = uet
  
  let uefs = uet.fields.filterIt(cleanedDepTypeName in getAllTypesFromUEField(it).map(getNameFromUEPropType).flatten)
  if uefs.any():
    uet.fields = uet.fields.filterIt(it.name notin uefs.mapIt(it.name))
  
  case uet.kind:
    of uetStruct:
      if uet.superStruct == cleanedDepTypeName:
        uet.superstruct = "" #Removes the parent (even though we are nto generating it yet)
    of uetClass:
      if uet.parent == cleanedDepTypeName:
        #TODO: We could get the first parent from the reflection system
        uet.parent =
          if uet.parent[0] == 'A': "AActor"
          else: "UObject"
      if uet.interfaces.any():
        uet.interfaces = uet.interfaces.filterIt(it != cleanedDepTypeName)
    else: 
      discard
  return uet

func removeDepFrom(uem:UEModule, cleanedDepTypeName:string) : UEModule = 
  var uem = uem
  uem.types = uem.types.mapIt(removeDepFrom(it, cleanedDepTypeName))
  uem

func removeAllDepsFrom*(uem:UEModule, cleanedDepTypeNames:seq[string]) : UEModule = 
  var uem = uem 
  for dep in cleanedDepTypeNames:
    uem = removeDepFrom(uem, dep)
  uem



type
  Cycle* = tuple[problematic: string, modules: seq[string]]

proc findCycleProblems*(modules: Table[string, seq[string]]): seq[Cycle] =
  var cycleProblems: seq[Cycle] = @[]

  for startNode in modules.keys:
    var visited = newSeq[string]()
    visited.add(startNode)
    var stack: seq[string] = @[startNode]
    var problemNode: string = ""

    while stack.len > 0:
      let currNode = stack[stack.len - 1]
      var hasChildren = false

      for childNode in modules[currNode]:
        if childNode notin visited:
          visited.add(childNode)
          stack.add(childNode)
          hasChildren = true
        elif childNode == startNode:
          cycleProblems.add((currNode, stack[0..^1]))
      if not hasChildren:
        discard stack.pop()
  return cycleProblems

proc fixCycles*(project: UEProject, commonModule : var UEModule, cycleProblems : seq[Cycle], typeDefs, modDeps : Table[string, seq[string]]) : UEProject = 
  var project = project
  var projectModules = project.modules
  
  UE_Warn &"Cycle problems: {cycleProblems}"
  UE_Log "Will fix cycles now. This may take a few minutes..."
  for cycle in cycleProblems:
    var cycle = cycle
    var problematicMod = projectModules.first(m=>m.name == cycle.problematic).get()
    for modDepName in cycle.modules:
      var modDepName = modDepName
      if modDepName == cycle.problematic: continue
      var modDep = projectModules.first(m=>m.name == modDepName).get()

      # UE_Log &"Cycle: {modDep.name} -> {dep}" 
      var modDef = projectModules.first(m=>m.name == modDepName).get()
      removeDepsFromModule(modDep, problematicMod, commonModule, typeDefs)
      projectModules = projectModules.replaceFirst((m:UEModule)=>m.name == modDepName, modDef)

    projectModules = projectModules.replaceFirst((m:UEModule)=>m.name == problematicMod.name, problematicMod)
  
  project.modules = projectModules
  return project


proc saveProject*(project:UEProject) = 
  let config = getNimForUEConfig()
  let ueProjectAsStr = $project
  let codeTemplate = """
import ../nimforue/codegen/[models, modulerules]

const project* = $1
"""
  #Folders need to be created here because createDir is not available at compile time
  createDir(config.bindingsDir)
  createDir(config.reflectionDataDir)
  writeFile(config.reflectionDataFilePath, codeTemplate % [ueProjectAsStr])

  for module in project.modules:
    let moduleFolder = module.name.toLower().split("/")[0]
    let actualModule = module.name.toLower().split("/")[^1]
    createDir(config.bindingsDir / "exported" / moduleFolder)
    createDir(config.bindingsDir / moduleFolder)
    createDir(PluginDir / NimHeadersModulesDir / moduleFolder)




proc getUEModulesFromDir(path : string) : seq[string] = 
  #TODO make it optionally recursive 
  var modules = newSeq[string]()
  for dir in walkDir(path):
    let name = dir[1].split(PathSeparator)[^1]
    if fileExists(dir[1] / name & ".Build.cs"):
      modules.add(name)
  return modules

proc getEngineCoreModules*(ignore:seq[string] = @[]) : seq[string] = 
  let path = getNimForUEConfig().engineDir / "Source" / "Runtime"       
  getUEModulesFromDir(path).filterIt(it notin ignore)

    # ueProjectRef = new UEProject
    # ueProjectRef[] = project
    
  # return ueProjectRef[]

proc getModules*(moduleName:string, onlyBp : bool) : seq[UEModule] = 
      let pkg = tryGetPackageByName(moduleName)
      let rules = 
        if onlyBp:  
          @[makeImportedRuleModule(uerImportBlueprintOnly)]
        else: 
          @[]

      pkg.map((pkg:UPackagePtr) => pkg.toUEModule(rules, @[], @[])).get(@[])

proc getProject*() : UEProject = 
  # if ueProjectRef.isNil():
    
  let pluginModules = getAllInstalledPlugins() 
    .mapIt(getAllModuleDepsForPlugin(it).mapIt($it).toSeq())
    .flatten()
  let gameModules = getGameModules()
  # let ueModules = getEngineCoreModules(ignore= @["CoreUObject"]) & extraModuleNames
  # let ueModules = @["UnrealEd"]
  # let ueModules = @["Engine"]
  let userModules = getGameUserConfigValue("extraModuleNames", newSeq[string]())
  let ueModules = 
    @["Engine", "Slate", "SlateCore", "PhysicsCore", "Chaos", "InputCore", "UMG", "GameplayAbilities", "EnhancedInput"] &
    userModules
  
  let projectModules = (gameModules & pluginModules & ueModules).deduplicate()
  # let projectModules = ueModules #(gameModules & pluginModules & ueModules).deduplicate()


    
  var project = UEProject()
  measureTime "Getting the project":
    proc getRulesForPkg(packageName:string) : seq[UEImportRule] = 
      if packageName in moduleImportRules: moduleImportRules[packageName] & codegenOnly
      else: @[codegenOnly]
    
    

    project.modules = 
      projectModules
        .mapIt(tryGetPackageByName(it))
        .sequence
        .mapIt(toUEModule(it, getRulesForPkg(it.getShortName()), @[], getPCHIncludes()))
        .flatten()

    UE_Log &"Project has {project.modules.len} modules"
    return project

proc generateProject*(forceGeneration = false) = 
    if not forceGeneration:
      if not isRunningCommandlet():
        return
    
    measureTime "Generate Project":  
      var project = getProject()  
      
      # measureTime "generateUEProject":
      #   project = generateUEProject(getProject())
      var commonModule = UEModule(name: "Engine/Common")
      

      var typeDefs = getTypeDefinitions(project.modules, commonModule)
      let allUndefinedDeps =  project.getAllTypesDepsNotDefinedInAllModules(typeDefs).values.toSeq.flatten.deduplicate.sorted()
      project.modules = project.modules.mapIt(it.removeAllDepsFrom(allUndefinedDeps))


      var projectModules = project.modules
      var modDeps = initTable[string, seq[string]]()
      for m in project.modules:
        modDeps[m.name]= m.depsFromModule(typeDefs)
      
      var cycleTable = initTable[string, seq[string]]()
      let cycleProblems = findCycleProblems(modDeps)
      UE_Log &"Found {cycleProblems.len} cycle problems"
      for cycle in cycleProblems:
        if cycle.problematic notin cycleTable:
          cycleTable.add cycle.problematic, cycle.modules
        else:
          cycleTable[cycle.problematic] = (cycleTable[cycle.problematic] & cycle.modules).deduplicate()
      let minCycles = cycleTable.pairs.toSeq().mapIt((it[0], it[1]))
      UE_Log &"Found {minCycles.len} min cycles"



      
      
      #We could try to do the hash here. It could even be in a another thread when starting the editor and if it needs to regen something we could just do it
   
      project = fixCycles(project, commonModule, minCycles, typeDefs, modDeps)
      
      typeDefs = getTypeDefinitions(projectModules, commonModule)
      for modName, types in typeDefs.pairs:
        UE_Log &"After Module: {modName} Types: {types.len}"


      project.modules = projectModules
      for i in 0..2: #Notice it require various passes because when moving types over there are new deps. TODO Add a proper cheap condition
        project = fixCommonModuleDeps(project, commonModule)

      commonModule.types = commonModule.types.deduplicate()
      commonModule = reorderTypesSoParentAreDeclaredFirst(commonModule)


      project.modules.add commonModule

      #Set final deps
      typeDefs = getTypeDefinitions(project.modules, commonModule)
      modDeps = initTable[string, seq[string]]()
      projectModules = project.modules
      for m in project.modules:
        var m = m
        m.dependencies = m.depsFromModule(typeDefs)
        UE_Log &"Module name {m.name} deps: {m.dependencies}"
        projectModules = projectModules.replaceFirst((uem:UEModule)=>uem.name == m.name, m)
      
      try:
        #Fixes forward declare only types 
        for m in projectModules:
          if m.name == commonModule.name:
            continue
          var m = m
          var typesToRemove = newSeq[string]()
          for t in m.types:
            if t.name in commonModule.types.mapIt(it.name):
              var t = t
              var idx = m.types.firstIndexOf((t2:UEType)=>t2.name == t.name)
              case t.kind
              of uetClass:
                t.forwardDeclareOnly = true
                m.types[idx] = t
              else:
                typesToRemove.add(t.name)
              
          m.types = m.types.filterIt(it.name notin typesToRemove)
            
          projectModules = projectModules.replaceFirst((uem:UEModule)=>uem.name == m.name, m)
      except:
        UE_Error &"Error fixing forward declare only types"
        UE_Error getCurrentExceptionMsg()





      project.modules = projectModules
      UE_Log $project.modules.mapIt( &"Mod: {it.name} Types: {it.types.len} Deps: {it.dependencies} \n")

      project = project.addHashToModules()


      UE_Log &"All module names{project.modules.mapIt(it.name)}"

      # ueProjectRef[] = project
      # UE_Log &"Modules to gen: {project.modules.len}"
      # UE_Log &"Modules to gen: {project.modules.mapIt(it.name)}"
      project.saveProject()



proc genBindingsCMD*() =
  try:
    
    let config = getNimForUEConfig()
    # let cmd = &"{config.pluginDir}\\nue.exe gencppbindings"

    when defined(windows):
      var cmd = f &"{PluginDir}\\nue.exe"    
    else:
      var cmd = f &"{PluginDir}/nue"
    var
      args = f"genbindingsall"
      dir = f PluginDir
      stdOut : FString
      stdErr : FString

    var code : int
    code = executeCmd(cmd, args, dir, stdOut, stdErr)
    UE_Log $code
    UE_Warn "output" & stdOut
  except:
    let e : ref Exception = getCurrentException()
    UE_Error &"Error: {e.msg}"
    UE_Error &"Error: {e.getStackTrace()}"
    UE_Error &"Failed to generate reflection data"
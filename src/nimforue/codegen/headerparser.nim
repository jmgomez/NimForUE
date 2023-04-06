# include ../unreal/prelude

import std/[strformat, tables, enumerate, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans]
import ../../buildscripts/nimforueconfig
import models
import ../utils/utils


proc getHeaderFromPath(path : string) : Option[string] = 
  if fileExists(path):
    some readFile(path)
  else: none(string)

proc getIncludesFromHeader(header : string) : seq[string] = 
  let lines = header.split("\n")
  func getHeaderFromIncludeLine(line: string) : string = 
    line.multiReplace(@[
      ("#include", ""),
      ("<", ""),
      (">", ""),
      ("\"", ""),
      ("\"", ""),
    ]).strip()
    
  lines
    .filterIt(it.startsWith("#include"))
    .map(getHeaderFromIncludeLine)

func getModuleRelativePathVariations(moduleName, moduleRelativePath:string) : seq[string] = 
    var variations = @["Public", "Classes"]
    
    #GameplayAbilities/Public/AbilitySystemGlobals.h <- Header can be included like so
    #"GameplayTags/Classes/GameplayTagContainer.h"
    # Classes/GameFramework/Character.h" <- module relative path
    # Include as "GameFramework/Character.h"
    #Classes/Engine/DataTable.h
    #"Engine/Classes/Engine/DataTable.h

    let header = moduleRelativePath.split("/")[^1]
    result = @[
        moduleRelativePath, #usually is Public/SomeClass.h
        moduleRelativePath.split("/").filterIt(it notin moduleName).join("/"),
        
      ] & #PROBABLY some of this only happens with engine. It may worth to reduce them
      variations.mapIt(&"{moduleName}/{it}/{header}") &
      variations.mapIt(&"{it}/{moduleName}/{header}") &
      variations.mapIt(&"{moduleName}/{it}/{moduleName}/{header}") &
      moduleRelativePath.split("/").filterIt(it notin variations).join("/")
    

func isModuleRelativePathInHeaders*(moduleName, moduleRelativePath:string, headers:seq[string]) : bool = 
  let paths = getModuleRelativePathVariations(moduleName, moduleRelativePath)
  # UE_Log &"Checking if {paths} is in {headers}"
  #We cant just check against the header because some headers may have the same name but be in different folders
  #So we check if the relative path is in the include. 
  if not paths.any(): false
  else: 
    for path in paths:
      if path in headers: 
        return true
    false
  

#returns the absolute path of all the include paths
proc getAllIncludePaths*() : seq[string] = getNimForUEConfig().getUEHeadersIncludePaths()



proc getHeaderIncludesFromIncludePaths(header:string, includePaths:seq[string]) : seq[string] = 
  for path in includePaths:
    let headerPath = path / header
    let header = getHeaderFromPath(headerPath)
    if header.isSome:
      return getIncludesFromHeader(header.get)
  newSeq[string]()


proc traverseAllIncludes*(entryPoint:string, includePaths:seq[string], visited:seq[string], depth=0, maxDepth=3) : seq[string] = 
  let includes = getHeaderIncludesFromIncludePaths(entryPoint, includePaths).filterIt(it notin visited)
  let newVisited = (visited & includes).deduplicate()
  if depth >= maxDepth:
    return newVisited
  includes
    .mapIt(traverseAllIncludes(it, includePaths, newVisited, depth+1))
    .flatten()


proc saveIncludesToFile*(path:string, includes:seq[string]) =   
  writeFile(path, $includes.toJson())

var pchIncludes : seq[string]
proc getPCHIncludes*(useCache=true) : seq[string] = 
  if pchIncludes.any(): 
    return pchIncludes

  let dir = PluginDir/".headerdata"
  createDir(dir)
  let path = dir / "allincludes.json"
  pchIncludes = 
    if useCache and fileExists(path): #TODO Check it's newer than the PCH
      readFile(path).parseJson().to(seq[string])
    else:      
      let includePaths = getNimForUEConfig().getUEHeadersIncludePaths()
      let includes = traverseAllIncludes("UEDeps.h", includePaths, @[]).deduplicate() 
      if useCache: 
        saveIncludesToFile(path, includes)

      includes
  pchIncludes  

  
  # UE_Log &"Includes found on the PCH: {pchIncludes.len}"
  # let uniquePCHIncludes = pchIncludes.mapIt(it.split("/")[^1]).deduplicate()
  # UE_Log &"Unique Includes found on the PCH: {uniquePCHIncludes.len}"

  # uniquePCHIncludes

proc getAllTypes*(useCache:bool=true) : seq[string] #fw (bottom)

#called from genreflection data everytime the bindings are attempted to be generated, before gencppbindings
proc savePCHTypes*(modules:seq[UEModule]) = 
  let dir = PluginDir/".headerdata"
  createDir(dir)
  let path = dir/"allpchtypes.json"
  #Is in PCH is set in UEMEta if the include is in the include list
  let pchTypes = modules.mapIt(it.types).flatten.filterIt(it.isInPCH).mapIt(it.name)
  let allTypes = pchTypes & getAllTypes()

  saveIncludesToFile(path, allTypes.deduplicate())

var pchTypes  : seq[string]
proc getAllPCHTypes*() : seq[string] =
  {.cast(noSideEffect).}:
    when defined(nimvm): #We can use this function at compile time OR when generating the bindings
      if pchTypes.any(): 
        return pchTypes
    #TODO cache it in the macro cache. This is only accessed at compile time
    #If the file gets too big it can be splited between structs, classes (and enums in the future)
    let path = PluginDir/".headerdata"/"allpchtypes.json"
    result = 
      if fileExists(path):
        return readFile(path).parseJson().to(seq[string])
      else: newSeq[string]()

    when defined(nimvm):
      pchTypes = result


proc readHeader(searchPaths:seq[string], header:string) : Option[string]  = 
  result = 
    searchPaths
      .first(dir=>fileExists(dir/header))
      .map(dir=>readFile(dir/header))
  if result.isNone and header.split("/").len>1:    
    return readHeader(searchPaths, header.split("/")[^1])

proc getUClassesNamesFromHeaders(cppCode:string) : seq[string] =   
  let lines = cppCode.splitLines()
  #Two cases (for UStructs and FStrucs) Need to do UEnums
  #1. via separating class ad hoc
  #2. Next line after UCLASS 
  #Probably there is something else nto matching. But this should cover most scenarios
  #At some point we are doing full AST parsing anyways. So this is just a temporary solution
  func getTypeSeparatingSemicolon(typ:string): seq[string] = 
    var needToContains = [typ, ":" ] #only class that has a base
    for idx, line in enumerate(lines):   
      if needToContains.mapIt(line.contains(it)).foldl(a and b, true):
        let separator = if line.contains("final") : "final" else: ":"
        var clsName = line.split(separator)[0].strip.split(" ")[^1]
        if clsName.contains("final"):
          clsName = "con final"
        result.add(clsName)

  func getTypeAfterUType(utype, typ:string) : seq[string] = 
    for idx, line in enumerate(lines):  
      if line.contains(utype):
        if len(lines) > idx+1:
          let nextLine = lines[idx+1]
          if nextLine.contains(typ):
            var clsName = nextline.strip.split(" ")[^1]            
            result.add(clsName)

  result = getTypeSeparatingSemicolon("class")
  result.add(getTypeSeparatingSemicolon("struct"))
  result.add(getTypeAfterUType("UCLASS", "class"))
  result.add(getTypeAfterUType("USTRUCT", "struct"))
  result = result.deduplicate()



proc getAllTypesFromHeader*(includePaths:seq[string], headerName:string) :  seq[string] = 
  let header = readHeader(includePaths, headerName)
  header
    .map(getUClassesNamesFromHeaders)
    .get(newSeq[string]())

#This try to parse types from the PCH but it's not reliable
#It's better to use both the PCH and this ones so PCH returns this too (works for a subset of types that doesnt have a header in the uprops)
#At some point we will parse the AST and retrieve the types from there.
proc getAllTypes*(useCache:bool=true) : seq[string] = 
  let searchPaths = getAllIncludePaths()
  echo $searchPaths
  let includes = getPCHIncludes(useCache=true)
  let includesNoCache = getPCHIncludes(useCache=false)
  let newIncludes = includesNoCache.filterIt(it notin includes)
  let missingIncludes = includes.filterIt(it notin includesNoCache)

  echo "Missing includes: ", missingIncludes
  echo "New includes: ", newIncludes
  echo "Includes: ", includes.len
  
  let typesCache = 
    includes
      .mapIt(getAllTypesFromHeader(searchPaths, it))
      .flatten()

  let typesNoCache = 
    includesNoCache
      .mapIt(getAllTypesFromHeader(searchPaths, it))
      .flatten()
  
  let newTypes = typesNoCache.filterIt(it notin typesCache)
  let missingTypes = typesCache.filterIt(it notin typesNoCache)

  echo "Missing types: ", missingTypes
  echo "New types: ", newTypes
  echo "Types: ", typesCache.len

  let pchTypes = getAllPCHTypes()
  let newPCHTypes = pchTypes.filterIt(it.split(" ")[0] notin typesNoCache)
  let missingPCHTypes = typesNoCache.filterIt(it notin pchTypes)

  # echo "Missing PCH types: ", missingPCHTypes
  echo "New PCH types: ", newPCHTypes
  echo "PCH types: ", pchTypes.len
  

  return newSeq[string]()



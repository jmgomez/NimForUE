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


proc readHeader(includePaths:seq[string], header:string) : Option[string]  = 
  includePaths
    .first(dir=>fileExists(dir/header))
    .map(dir=>readFile(dir/header))

proc getUClassesNamesFromHeaders(cppCode:string) : seq[string] =   
  # let uClasses = cppCode.split("UCLASS(")  
  # for uClass in uClasses:
  #   var ignore, name : string 
  #   if scanf(uClass, "$*_API $* :", ignore, name):
  #     if name.len > 20:
  #       echo uClass
  #       echo cppCode
  #       quit()
  #     result.add(name)
  let lines = cppCode.splitLines()
  for idx, line in enumerate(lines):   
    if line.contains("UCLASS"):
      var nextLine = lines[idx + 1]
      var idx = idx
      while nextLine.strip() == "": #TODO improve condition to check if it's a comment
        inc idx
        nextLine = lines[idx + 1]

      echo "Next line is "
      echo nextLine

      var ignore, name : string 
      if scanf(nextLine, "class $* :", name) or scanf(nextLine, "$* _API $* ", ignore, name):
        result.add(name.split("API")[^1].strip())
    
  


proc getAllTypesFromHeader*(includePaths:seq[string], header:string) :  seq[string] = 
  let header = readHeader(includePaths, header)
  header
    .map(getUClassesNamesFromHeaders)
    .get(newSeq[string]())

#This try to parse types from the PCH but it's not reliable
#It's better to use both the PCH and this ones so PCH returns this too (works for a subset of types that doesnt have a header in the uprops)
#At some point we will parse the AST and retrieve the types from there.
proc getAllTypes*(useCache:bool=true) : seq[string] = 
  #only one header for now
  let includes = getPCHIncludes(useCache=false)
  let searchPaths = getAllIncludePaths()
  #TODO store types in a file
  includes
    .mapIt(getAllTypesFromHeader(searchPaths, it))
    .flatten()

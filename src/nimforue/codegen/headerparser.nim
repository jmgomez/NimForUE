include ../unreal/prelude

import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans]
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

    let header = moduleRelativePath.split("/")[^1]
    @[
      moduleRelativePath, #usually is Public/SomeClass.h
      moduleRelativePath.split("/").filterIt(it notin moduleName).join("/"),
      
    ] & variations.mapIt(&"{moduleName}/{it}/{header}") &
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
proc getPCHIncludes*() : seq[string] = 
  if pchIncludes.any(): 
    return pchIncludes

  let dir = PluginDir/".headerdata"
  createDir(dir)
  let path = dir / "allincludes.json"
  pchIncludes = 
    if fileExists(path): #TODO Check it's newer than the PCH
      readFile(path).parseJson().to(seq[string])
    else:
      #if this takes too long can be cached into a file and
      let includePaths = getNimForUEConfig().getUEHeadersIncludePaths()
      let includes = traverseAllIncludes("UEDeps.h", includePaths, @[]).deduplicate()  
      saveIncludesToFile(path, includes)
      includes

  
  # UE_Log &"Includes found on the PCH: {pchIncludes.len}"
  # let uniquePCHIncludes = pchIncludes.mapIt(it.split("/")[^1]).deduplicate()
  # UE_Log &"Unique Includes found on the PCH: {uniquePCHIncludes.len}"

  # uniquePCHIncludes


#called from genreflection data everytime the bindings are attempted to be generated, before gencppbindings
proc savePCHTypes*(modules:seq[UEModule]) = 
  let dir = PluginDir/".headerdata"
  createDir(dir)
  let path = dir/"allpchtypes.json"
  let pchTypes = modules.mapIt(it.types).flatten.filterIt(it.isInPCH).mapIt(it.name)
  UE_Log &"Types found on the PCH: {pchTypes.len}"
  saveIncludesToFile(path, pchTypes)

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

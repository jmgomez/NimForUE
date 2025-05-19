# include ../unreal/prelude

import std/[strformat, tables, enumerate, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, pegs]
import ../../buildscripts/[nimforueconfig, buildcommon]
import models
import ../utils/utils

type
  CppTypeInfo* = object
    name* : string #Name of the type FSomeType USomeType
    cppDefinitionLine : string #The line where the type is defined. This will be the body at some point
    needsObjectInitializerCtor*: bool

var includeMatch = newSeq[string](1)
let includePeg = peg"""\skip(\s*) '#include' ["<] {(!'>' !'"' .)+} [">]"""
proc getIncludesFromHeader(path, header: string): seq[string] = 
  #path only passed to show better errors
  let lines = header.splitLines()
  let currentIncludeOrderVersion = UEVersion() #We assume the UEVersion matches the IncludeOrderVersion (we could read it from the cs file though)
  # echo "Current Include Order Version: ", currentIncludeOrderVersion
  assert currentIncludeOrderVersion != 0, "Current version is 0. This is not expected. Which means this function is running at compile time and it shouldnt. The cache file must be generated before compiling guest"
  #Everything within 
  #if UE_ENABLE_INCLUDE_ORDER_DEPRECATED_IN_MAJOR_MINOR should only be included if the current version is that one.

  var insideConditionalBlock = false
  var includesInsideCurrentBlock = newSeq[string]()
  var lastConditionalBlockVersion: float
  var isNegated = false #if the condition is negated
  const IncludeOrderDeprecated = "UE_ENABLE_INCLUDE_ORDER_DEPRECATED_IN_"
  
  for idx, line in enumerate(lines):
    if IncludeOrderDeprecated in line and "#endif" notin line:
      try:
        lastConditionalBlockVersion = 
          line
            .multiReplace(@[
              (" ", ""), 
              ("\t", ""),
              (IncludeOrderDeprecated, ""),
              ("_", "."),
              ("#if", ""),  
              ("//", ""),  
              ("!", "")                      
            ])
            .strip()
            .parseFloat()
      except CatchableError:
        echo "Error parsing version in include order:", line
        echo "Line", idx + 1
        echo path
        quit()

      isNegated = ("!" & IncludeOrderDeprecated) in line
      insideConditionalBlock = true
      continue

    if insideConditionalBlock:
      if line.match(includePeg, includeMatch):
        includesInsideCurrentBlock.add includeMatch[0]
        #log &"> {includeMatch[0]} {line = }"
    elif line.match(includePeg, includeMatch):
      #log &"> {includeMatch[0]} {line = }"
      result.add includeMatch[0]

    if insideConditionalBlock:
      if line.contains("#endif"):
        insideConditionalBlock = false        
        if lastConditionalBlockVersion == currentIncludeOrderVersion and not isNegated or
          lastConditionalBlockVersion != currentIncludeOrderVersion and isNegated:
            result.add(includesInsideCurrentBlock)

        # echo "End of conditional include block"
        # echo "Includes inside block", includesInsideCurrentBlock
        includesInsideCurrentBlock = newSeq[string]()

proc getHeaderFromPath(path: string): Option[string] = 
  if fileExists(path):
    # echo "Header found: ", path
    some readFile(path)
  else: 
    none(string)

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
proc getAllIncludePaths*() : seq[string] = 
  result = getNimForUEConfig().getUEHeadersIncludePaths()    
  #some modules doesnt have "Classes" in the include paths so we dont increase the cmd length, they end with "Public"
  #we add it here, because we are not running a cmd and the ubt already does it 
  result.add result.filterIt(it.endsWith "Public").mapIt(it[0..^7] / "Classes")
  result.add NimGameDir()

proc getHeaderIncludesFromIncludePaths(headerName:string, includePaths:seq[string]): seq[string] = 
  for path in includePaths:
    let headerPath = path / headerName
    var header = getHeaderFromPath(headerPath)
    #some modules doesnt have "Classes" in the include paths so we dont increase the cmd length, they end with "Public"
    #we add it here, because we are not running a cmd and the ubt already does it 
    if header.isNone and path.endsWith "Public":
      let clsPath = path[0..^7] / "Classes" / headerName
      header = getHeaderFromPath(clsPath)
    if header.isSome:
      return getIncludesFromHeader(headerPath, header.get)
  newSeq[string]()


proc traverseAllIncludes*(entryPoint:string, includePaths:seq[string], visited:CountTableRef[string], depth=0, maxDepth=3) = 
  let includes = getHeaderIncludesFromIncludePaths(entryPoint, includePaths).filterIt(it notin visited)
  for header in includes:
    visited.inc(header)
  if depth >= maxDepth:
    return
  for header in includes:
    traverseAllIncludes(header, includePaths, visited, depth+1)
  # echo "result", result

proc saveIncludesToFile*(path:string, includes:seq[string]) =   
  writeFile(path, $includes.toJson())

var pchIncludes {.compileTime.} : seq[string]
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
      let includePaths = getAllIncludePaths()
      var includesTable = newCountTable[string]()
      traverseAllIncludes("UEDeps.h", includePaths, includesTable)
      traverseAllIncludes("nuegame.h", includePaths, includesTable)
      # echo "indlude paths", pchIncludes
      var includes = collect:
        for header in includesTable.keys:
          header
      if useCache:
        saveIncludesToFile(path, includes)
      includes
  pchIncludes


  # UE_Log &"Includes found on the PCH: {pchIncludes.len}"
  # let uniquePCHIncludes = pchIncludes.mapIt(it.split("/")[^1]).deduplicate()
  # UE_Log &"Unique Includes found on the PCH: {uniquePCHIncludes.len}"

  # uniquePCHIncludes


# #called from genreflection data everytime the bindings are attempted to be generated, before gencppbindings
# proc savePCHTypes*(modules:seq[UEModule]) = 
#   let dir = PluginDir/".headerdata"
#   createDir(dir)
#   let path = dir/"allpchtypes.json"
#   #Is in PCH is set in UEMEta if the include is in the include list
#   let pchTypes = modules.mapIt(it.types).flatten.filterIt(it.isInPCH).mapIt(it.name)
#   let allTypes = pchTypes & getAllTypes()

#   saveIncludesToFile(path, allTypes.deduplicate())


proc readHeader(searchPaths:seq[string], header:string) : Option[string]  = 
  result = 
    searchPaths
      .first(dir=>fileExists(dir/header))
      .map(dir=>readFile(dir/header))
  if result.isNone and header.split("/").len>1:    
    return readHeader(searchPaths, header.split("/")[^1])


let typePeg = peg"""
\skip(\s*)
t <- (uenum / uclass / ustruct / class / struct)
class <- {'class'} typeName minheritance body
struct <- {'struct'} typeName minheritance body
minheritance <- (':' (sinheritance ',')* sinheritance)?
sinheritance <- \ident? \ident
uclass <- 'UCLASS' metadata class
ustruct <- 'USTRUCT' metadata struct
uenum <- 'UENUM' metadata {'enum'} 'class' {\ident} ':' \ident body
metadata <- '(' metainner* ')'
metainner <- (metaentry / metastring / metakv / \ident) ','?
metaentry <- \ident '=' metadata
metastring <- \ident '=' '"' @'"'
metakv <- \ident '=' \ident
typeName <- (dllexport {\ident} 'final') / ({\ident} 'final') / (dllexport {\ident}) / {\ident}
dllexport <- \ident
body <- {'{' innerBody '};'}
innerBody <- (block / nonblock)*
block <- '{' innerBody '}' ';'?
nonblock <- (!'{' !'}' .)+
"""

let commentPeg = peg"""
comment <- {multiline / single}
multiline <- '/*' (!'*/' .)* '*/'
single <- '//' (!\n .)* \n
"""

let initPeg = peg" \skip(\s*) \ident '(const FObjectInitializer'"


var matches = newSeq[string]()
proc getUClassesNamesFromHeaders(cppCode:string) : seq[CppTypeInfo] =
  var i = 0
  while i < cppCode.len:
    # skip C++ comments
    var commentCap: Captures
    var clen = cppCode.rawMatch(commentPeg, i, commentCap)
    if clen >= 0:
      i = i + clen

    var typeCap: Captures
    var len = cppCode.rawMatch(typePeg, i, typeCap)
    if len >= 0:
      #let typeType = cppCode[(typeCap.bounds(0).first)..(typeCap.bounds(0).last)]
      let typeName = cppCode[(typeCap.bounds(1).first)..(typeCap.bounds(1).last)]
      let body = cppCode[(typeCap.bounds(2).first)..(typeCap.bounds(2).last)]

      let needsObjectInitializerCtor = body.find(initPeg, matches, 0) != -1
      #if needsObjectInitializerCtor:
        #log &"{typeName} has initializer constructor"
      # we can store the body of the class for future parsing of functions in CppTypeInfo's cppDefinitionLine, but leaving it out for now since we're not using it for anything
      #result.add CppTypeInfo(name: typeName, cppDefinitionLine: cppCode[c.bounds(1).first ..< c.bounds(2).first], needsObjectInitializerCtor: needsObjectInitializerCtor)
      result.add CppTypeInfo(name: typeName, cppDefinitionLine:"", needsObjectInitializerCtor: needsObjectInitializerCtor)

      i = i + len
    else:
      inc i

proc getAllTypesFromHeader*(includePaths:seq[string], headerName:string) :  seq[CppTypeInfo] = 
  let header = readHeader(includePaths, headerName)
  result = header
    .map(getUClassesNamesFromHeaders)
    .get(newSeq[CppTypeInfo]())

#This try to parse types from the PCH but it's not reliable
#It's better to use both the PCH and this ones so PCH returns this too (works for a subset of types that doesnt have a header in the uprops)
#At some point we will parse the AST and retrieve the types from there.
var pchTypes {.compileTime.}  : Table[string, CppTypeInfo]
func getAllPCHTypes*(useCache:bool=true) : lent Table[string, CppTypeInfo] =   
  {.cast(noSideEffect).}:
    if pchTypes.len > 0:
      return pchTypes
    else: 
      #TODO cache it in the macro cache. This is only accessed at compile time
      #If the file gets too big it can be splited between structs, classes (and enums in the future)
      let dir = PluginDir/".headerdata"
      let filename =  "allpchtypes.json"
      let path = dir/filename
      if fileExists(path) and useCache:
        pchTypes = readFile(path).parseJson().to(Table[string, CppTypeInfo])#.pairs.toSeq().newTable()
      else:
        #we search them
        let searchPaths = getAllIncludePaths()
        let includes = getPCHIncludes(useCache=useCache)       
        pchTypes = 
          includes
            .mapIt(getAllTypesFromHeader(searchPaths, it))
            .flatten()
            .mapIt((it.name, it))
            .toTable()
            
        if useCache: #first time, store the types
          createDir(dir)
          writeFile(path, $pchTypes.toJson())

    result = pchTypes
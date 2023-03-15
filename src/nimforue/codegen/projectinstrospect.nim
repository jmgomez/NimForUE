import ../utils/[utils, ueutils]

import std/[strformat, tables, hashes, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans, algorithm, macros]
import ../../buildscripts/nimforueconfig


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
  assert PluginDir != ""
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

const NimDefinedTypes* = getAllTypesOf()
const PrimitiveTypes* = @[ 
  "bool", "float32", "float64", "int16", "int32", "int64", "int8", "uint16", "uint32", "uint64", "uint8"
]

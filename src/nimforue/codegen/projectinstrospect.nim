import ../utils/[utils]

import std/[strformat, tables, hashes, options, sugar, json, strutils, jsonutils,  sequtils, strscans, algorithm, macros]


when not defined(nuevm):
  import std/[os]
  import ../../buildscripts/nimforueconfig

type
  NimKind* = enum
    Object, GenericObject, Pointer, Proc, TypeClass, Distinct, Enum

  NimType* = object 
    name* : string
    case kind* : NimKind:
    of Object:
      fields*: seq[string]
    of Pointer:
      ptrType*: string #just the type name as str for now. We could do a lookup in a table
    of Proc, TypeClass, Distinct, Enum, GenericObject: #ignored for now
      discard



func getNameFromTypeDef(typeDef:NimNode) : string = 
  assert typeDef.kind == nnkTypeDef, "Expected nnkTypeDef got " & $typeDef.kind
  let nameNode = typeDef[0]
  case typeDef[0].kind:
  of nnkIdent:      
    nameNode.strVal
  of nnkPostFix: 
    nameNode[^1].strVal
  of nnkPragmaExpr:
    case nameNode[0].kind:
    of nnkIdent:     
      nameNode[0].strVal
    of nnkPostFix:
      nameNode[0][^1].strVal
    else: 
      error &"Error got {nameNode.kind} inside a pragma expr"
      ""
  else: 
    error &"Error got {nameNode.kind} inside a typeDef"    
    ""

func makeEnumNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkEnumTy, "Expected nnkEnumTy got " & $typeDef[2].kind
  NimType(name: typeName, kind:Enum)

func makeDistinctNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkDistinctTy, "Expected nnkDistinkTy got " & $typeDef[2].kind

  NimType(name: typeName, kind:Distinct)

func makeProcNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkProcTy, "Expected nnkProcTy got " & $typeDef[2].kind
  NimType(name: typeName, kind:Proc)
func makeTypeClass(typeName:string, typeDef:NimNode):NimType = 
  assert typeDef[2].kind == nnkInfix, "Expected nnkInfix got " & $typeDef[2].kind
  NimType(name: typeName, kind:TypeClass)

func makePtrNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkPtrTy, "Expected nnkPtrTy got " & $typeDef[2].kind
  assert typeDef[2][0].kind == nnkIdent, "Expected nnkIdent got " & $typeDef[2].kind
  let ptrType = typeDef[2][0].strVal() #
  NimType(name: typeName, kind:Pointer, ptrType:ptrType)


func makeGenericObjectNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkBracketExpr, "Expected nnkBracketExpr got " & $typeDef[2].kind
  NimType(name: typeName, kind:GenericObject)

func makeObjNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkObjectTy, "Expected nnkObjectTy got " & $typeDef[2].kind
  # let fields = typeDef[2].children.mapIt(it[0].strVal)
  NimType(name: typeName, kind:Object)#, fields:fields)

func typeDefToNimType(typeDef: NimNode) : NimType = 
  assert typeDef.kind == nnkTypeDef, "Expected nnkTypeDef got " & $typeDef.kind
  let name = getNameFromTypeDef(typeDef)
  case typeDef[2].kind:
  of nnkObjectTy: makeObjNimType(name, typeDef)
  of nnkPtrTy: makePtrNimType(name, typeDef)
  of nnkProcTy: makeProcNimType(name, typeDef) 
  of nnkInfix: #May be other types of infix
    makeTypeClass(name, typeDef)
  of nnkDistinctTy:
    makeDistinctNimType(name, typeDef)  
  of nnkEnumTy:
    makeEnumNimType(name, typeDef)
  of nnkBracketExpr:
    makeGenericObjectNimType(name, typeDef)
  else:
    debugEcho treeRepr typeDef
    error("Unknown type " & $typeDef[2].kind)
    NimType()
  


func getAllTypeSections(nimNode: NimNode) : seq[NimNode] = 
  nimNode
    .children
    .toSeq
    .filterIt(it.kind == nnkTypeSection)

func typeSectionToTypeDefs(typeSection: NimNode) : seq[NimNode] = 
  assert typeSection.kind == nnkTypeSection
  typeSection
    .children
    .toSeq
    .filterIt(it.kind == nnkTypeDef)

proc getAllTypesFromFileTree(fileTree:NimNode) : seq[NimType] = 
  fileTree
    .getAllTypeSections
    .map(typeSectionToTypeDefs)
    .flatten
    .map(typeDefToNimType)
 


proc getAllImportsAsRelativePathsFromFileTree*(fileTree:NimNode) : seq[string] = 
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



proc getAllTypesOf(dir, entryPoint:string) : seq[NimType] = 
  let nimCode = readFile(entryPoint)
  let entryPointFileTree = parseStmt(nimCode)
  
  let nimFilePaths = 
    getAllImportsAsRelativePathsFromFileTree(entryPointFileTree)
    .mapIt(it.absolutePath(dir) & ".nim")

  let fileTrees = 
    entryPointFileTree & nimFilePaths.mapIt(it.readFile.parseStmt)

  let typeNames = fileTrees.map(getAllTypesFromFileTree).flatten()

  typeNames

# dumpTree:
#   type A* = object
#     a: int
#     b: string
#   type
#     B = object
#       a: int
#       b: string
#     C* = object
#       a: int
#       b: string     
#     D {.importc.} = object
#       a: int
#       b: string  
#     E* {.importc.} = object
#       a: int
#       b: string
    
#     Puntero* = ptr A


# const astStr ="""

# type A* = object
#     a: int
#     b: string
# type
#     B = object
#       a: int
#       b: string
#     C* = object
#       a: int
#       b: string     
#     D {.importc.} = object
#       a: int
#       b: string  
#     E* {.importc.} = object
#       a: int
#       b: string
#     Puntero* = ptr A

 
# """




# static:
#   let nimNode = parseStmt(astStr)

#   let typeDefs = getAllTypeSections(nimNode).map(typeSectionToTypeDefs).flatten
#   echo $len(typeDefs)

#   for t in typeDefs:
#     echo $typeDefToNimType(t)
  

  # echo repr nimNode


when not defined(nuevm):
  const dir = PluginDir / "src" / "nimforue" / "unreal" 
  const entryPoint = dir / "prelude.nim"
  assert PluginDir != ""
  const NimDefinedTypes = getAllTypesOf(dir, entryPoint)
  const NimDefinedTypesNames* = NimDefinedTypes.mapIt(it.name)

  # static:
    # echo $NimDefinedTypes.len()

    # quit()
  
const PrimitiveTypes* = @[ 
  "bool", "float32", "float64", "int16", "int32", "int64", "int8", "uint16", "uint32", "uint64", "uint8"
]

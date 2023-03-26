import ../utils/[utils, ueutils]

import std/[strformat, enumerate, tables, hashes, options, sugar, json, strutils, jsonutils,  sequtils, strscans, algorithm, macros, genasts]


when not defined(nuevm):
  import std/[os]
  import ../../buildscripts/nimforueconfig

type
  NimParamKind* = enum
    TypeInfo, OnlyName
  NimParam* = object
    name*: string
    case kind* : NimParamKind
    of OnlyName: 
      strType*: string #For now only this is used 
    of TypeInfo: 
      typeInfo*: NimType

  NimKind* = enum
    Object, GenericObject, Pointer, Proc, TypeClass, Distinct, Enum

  NimType* = object 
    name* : string
    ast* : string #This field is used only when generating types for the vm. Some types are replaced by an alias (i.e. FString, TArray..)
    case kind* : NimKind:
    of Object:
      parent*: string 
      params*: seq[NimParam]
      
    of Pointer:
      ptrType*: string #just the type name as str for now. We could do a lookup in a table
    of Proc, TypeClass, Distinct, Enum, GenericObject: #ignored for now
      discard
  NimModule* = object
    name*: string
    types*: seq[NimType]
    fullPath*: string
    ast:string
    deps : seq[string] #relative path to module

# func `==`*[T:NimModule](x, y: T): bool =
#   x.name == y.name and x.fullPath == y.fullPath and x.ast == y.ast and x.deps == y.deps and x.types == y.types

func `==`*[T:NimParam](x, y: T): bool =
  x.name == y.name and x.kind == y.kind and
  (case x.kind:
  of TypeInfo:
    x.typeInfo == y.typeInfo
  of OnlyName:
    x.strType == y.strType)
func `==`*[T:NimType](x, y: T): bool =
  x.name == y.name and x.ast == y.ast and x.kind == y.kind and
  (case x.kind:
  of Object:
    x.parent == y.parent and x.params == y.params
  of Pointer:
    x.ptrType == y.ptrType
  of Proc, TypeClass, Distinct, Enum, GenericObject: #ignored for now
    true)

func getTypeFromModule*(modules:seq[NimModule], typeName:string) : Option[NimType] = 
  for module in modules:
    for typ in module.types:
      if typ.name == typeName:
        return some(typ)
  none(NimType)

func getDepsAsModules*(allModules:seq[NimModule], module:NimModule) : seq[NimModule] = 
  module.deps.mapIt(it.split("/")[^1])
    .map(it=>allModules.first(m=>m.name == it))
    .sequence()

func getDepsAsModulesRec*(allModules:seq[NimModule], module:NimModule) : seq[NimModule] = 
  let deps = getDepsAsModules(allModules, module)
  if deps.any():
    deps & deps.mapIt(getDepsAsModulesRec(allModules, it)).flatten()
  else:
    @[]
   


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



func getNameFromIdentDef(identDefs:NimNode) : string = 
  assert identDefs.kind == nnkIdentDefs, "Expected nnkIdentDefs got " & $identDefs.kind
  case identDefs[0].kind:
    of nnkIdent:
      identDefs[0].strVal
    of nnkPostfix:
      identDefs[0][^1].strVal

    of nnkPragmaExpr:
      let pragmaNode = identDefs[0]
      case pragmaNode[0].kind:
      of nnkIdent:
        pragmaNode[0].strVal
      of nnkPostfix:
        let postFixNode = pragmaNode[0]
        case postFixNode[^1].kind:
        of nnkIdent:
          postFixNode[^1].strVal
        of nnkAccQuoted:         
          postFixNode[0].strVal
        else:
          debugEcho treeRepr identDefs
          error &"Error in getParamFromIdentDef got {identDefs[0][0].kind} in pragma expr"
          ""  
      else:
        debugEcho treeRepr identDefs
        error &"Error in getParamFromIdentDef got {identDefs[0][0].kind} in pragma expr"
        ""
    else:
      debugEcho treeRepr identDefs
      error &"Error in getParamFromIdentDef got {identDefs[0].kind} in identDefs name"
      quit()  

func getParamFromIdentDef(identDefs:NimNode) : NimParam =
  assert identDefs.kind == nnkIdentDefs, "Expected nnkIdentDefs got " & $identDefs.kind

  let name = getNameFromIdentDef(identDefs)
  let typ = 
    case identDefs[^2].kind:
    of nnkIdent:
      identDefs[^2].strVal
    of nnkPtrTy:
      let ptrType = identDefs[^2][0]
      $repr ptrType 
    of nnkBracketExpr:
      identDefs[^2][0].strVal  
    of nnkProcTy:
      "proc" #Not supported as param yet but we do validate it  
    else:
      debugEcho treeRepr identDefs
      error &"Error in getParamFromIdentDef got {identDefs[^2].kind} in identDefs type"
      ""
  
  return NimParam(name: name, kind:OnlyName, strType:typ)

func makeObjNimType(typeName:string, typeDef:NimNode) : NimType = 
  let objectTyNode = typeDef[2]
  assert objectTyNode.kind == nnkObjectTy, "Expected nnkObjectTy got " & $typeDef[2].kind
  
  let parent = 
    case objectTyNode[1].kind:
    of nnkEmpty: ""
    of nnkOfInherit: objectTyNode[1][0].strVal
    else: 
      debugEcho treeRepr typeDef
      quit()

  case objectTyNode[^1].kind:
  of nnkEmpty:
    NimType(name: typeName, kind:Object, parent:parent)
  of nnkRecList:
    let recListNode = objectTyNode[^1]
    assert recListNode.kind == nnkRecList, "Expected nnkRecList got " & $recListNode.kind
    let params = 
      recListNode.children.toSeq
        .filterIt(it.kind == nnkIdentDefs)
        .map(getParamFromIdentDef)
        

    NimType(name: typeName, kind:Object, parent:parent, params:params)
  else:  
    debugEcho treeRepr typeDef
    quit()
  #   let fields = typeDef[2].children.mapIt(it[0].strVal)
  # NimType(name: typeName, kind:Object)#, fields:fields)

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
        .filterIt(it.kind in [nnkImportStmt]) #, nnkIncludeStmt])
        .mapIt(parseImportBracketsPaths(repr it[0]))
        .flatten
        .mapIt(it.split("/").mapIt(strip(it)).join("/")) #clean spaces
  imports


proc createModuleFrom(fullPath:string, fileTree:NimNode) : NimModule = 
  let name = fullPath.split(PathSeparator)[^1].split(".")[0]
  let types =
    fileTree
      .getAllTypeSections
      .map(typeSectionToTypeDefs)
      .flatten
      .map(typeDefToNimType)

  let deps = fileTree.getAllImportsAsRelativePathsFromFileTree().mapIt(it.replace("//", "/"))
  NimModule(name:name, fullPath:fullPath, types: types, ast:repr fileTree, deps:deps)



proc paramToIdentDefs(nimParam:NimParam) : NimNode = 
  nnkIdentDefs.newTree(
    nnkPostfix.newTree(
      ident "*", #
      ident nimParam.name
    ),
    ident nimParam.strType,
    newEmptyNode()
  )

proc nimObjectTypeToNimNode(nimType:NimType) : NimNode = 
  if nimType.ast != "": return nimType.ast.parseStmt
  let name = ident nimType.name
  let params = nnkRecList.newTree(@[newEmptyNode(), newEmptyNode()] & nimtype.params.map(paramToIdentDefs))
  result = 
    genAst(name, params):
      type name* = object
        
  
  result.add params
  # echo treeRepr result

proc genNimVMTypeImpl(nimType:NimType) : NimNode =
  #Maybe in the future extrac the type section. For now it's fine
  let name = ident nimType.name
  case nimType.kind:
  of Object: nimObjectTypeToNimNode(nimType)
  of Pointer: 
    #Notice we are not emiting this for the vm but distinct int and then the converter with the ptrType
    #Need to get the parent if any so we can create a converter
    let ptrType = ident nimType.ptrType
    genAst(name, ptrType): 
      type 
        name = ptr ptrType
  else:
    newEmptyNode()


proc genModuleImpl(nimModule :NimModule) : NimNode =
  let imports = nimModule.deps.mapIt(nnkImportStmt.newTree(ident it))
  let types = nimModule.types.map(genNimVMTypeImpl)
  result = nnkStmtList.newTree(imports & types)

proc genVMModuleFile(dir:string, module: NimModule) =
  # let moduleFile = dir / module.fullPath.split("src")[1] # for modDep in engineTypeDeps:
  let moduleFile = dir / module.name & ".nim"
  discard staticExec("mkdir -p " & parentDir(moduleFile)) #TODO extract this and make it work agnostic of os and also make a pr so we dont have to deal with it 
  let moduleVMAst = genModuleImpl(module)
  writeFile(moduleFile, moduleVMAst.repr)

proc genVMModuleFiles*(dir:string, modules: seq[NimModule]) =
  let typesToReplace = { 
    "FString": "type FString* = string", 
    "TArray": "type TArray*[T] = seq[T]", 
  }.toTable()

  var engineTypesModule = modules.filterIt(it.name == "enginetypes").head.get
  let moduleDeps = getDepsAsModulesRec(modules, engineTypesModule).deduplicate()
  var vmTypesDeps = moduleDeps.mapIt(it.types).flatten()    
  for idx, t in enumerate(vmTypesDeps):
    if t.name in typesToReplace:
      let ast = typesToReplace[t.name]
      vmTypesDeps[idx].ast = ast
  engineTypesModule.types = vmTypesDeps
  engineTypesModule.deps = @[]
  genVMModuleFile(dir, engineTypesModule)

proc getAllModulesFrom(dir, entryPoint:string) : seq[NimModule] = 
  let nimCode = readFile(entryPoint)
  let entryPointFileTree = parseStmt(nimCode)
  
  let nimRelativeFilePaths = 
    entryPoint &
    getAllImportsAsRelativePathsFromFileTree(entryPointFileTree)
    .mapIt(it.absolutePath(dir) & ".nim")
  let fileTrees = nimRelativeFilePaths.mapIt(it.readFile.parseStmt)

  let modules = fileTrees.mapi((modAst:NimNode, idx:int) => createModuleFrom(nimRelativeFilePaths[idx], modAst))

  return modules


when not defined(nuevm):
  const dir = PluginDir / "src" / "nimforue" / "unreal" 
  const entryPoint = dir / "prelude.nim"
  assert PluginDir != ""
  const NimModules* = getAllModulesFrom(dir, entryPoint)
  const NimDefinedTypes = NimModules.mapIt(it.types).flatten
  const NimDefinedTypesNames* = NimDefinedTypes.mapIt(it.name)


  # quit()

const PrimitiveTypes* = @[ 
  "bool", "float32", "float64", "int16", "int32", "int64", "int8", "uint16", "uint32", "uint64", "uint8"
]

import ../utils/[utils, ueutils]

import std/[strformat, enumerate, tables, hashes, options, sugar, json, strutils, jsonutils,  sequtils, strscans, algorithm, macros, genasts]


when not defined(nuevm):
  import std/[os]
  import ../../buildscripts/nimforueconfig

type
  NimParamKind* = enum
    TypeInfo, OnlyName, OnlyType
  NimParam* = object
    name*: string
    case kind* : NimParamKind
    of OnlyName, OnlyType: 
      strType*: string #For now only this is used 
    of TypeInfo: 
      typeInfo*: NimType

  NimKind* = enum
    Object, Pointer, Proc, TypeClass, Distinct, Enum, None#Nonsupported types

  NimType* = object 
    name* : string
    originalAst* : string #notice they are always stored as TypeSection (only proc for now but will change the others)
    ast* : string #This field is used only when generating types for the vm. Some types are replaced by an alias (i.e. FString, TArray..)
    case kind* : NimKind:
    of Object:
      parent*: string 
      params*: seq[NimParam]
      typeParams*: seq[NimParam] #for generic objects T etc
    of Pointer:
      ptrType*: string #just the type name as str for now. We could do a lookup in a table
    of Enum:
      enumFields: seq[string] 
    of Proc, TypeClass, Distinct, None: #ignored for now
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
  of OnlyName, OnlyType :
    x.strType == y.strType)
func `==`*[T:NimType](x, y: T): bool =
  x.name == y.name and x.ast == y.ast and x.kind == y.kind and
  (case x.kind:
  of Object:
    x.parent == y.parent and x.params == y.params
  of Pointer:
    x.ptrType == y.ptrType
  of Proc, TypeClass, Distinct, Enum, None: #ignored for now
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
  let enumTy = typeDef[2]
  func parseEnumField(field:NimNode) : string = #this could be improved to also have the value
    case field.kind:
    of nnkIdent:
      field.strVal
    of nnkEnumFieldDef:
      field[0].strVal
    else:
      error &"Error got {field.kind} inside an enum"
      ""

  let enumFields = enumTy.children.toSeq.filterIt(it.kind != nnkEmpty).map(parseEnumField)  
  if not enumFields.any():
    debugEcho treeRepr(typeDef)
    debugEcho typeName & " has no enum fields"
  NimType(name: typeName, kind:Enum, enumFields:enumFields, originalAst: repr(nnkTypeSection.newTree(typeDef)))

func makeDistinctNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkDistinctTy, "Expected nnkDistinkTy got " & $typeDef[2].kind

  NimType(name: typeName, kind:Distinct, originalAst: repr(nnkTypeSection.newTree(typeDef)))

func makeProcNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkProcTy, "Expected nnkProcTy got " & $typeDef[2].kind
  NimType(name: typeName, kind:Proc, originalAst: repr(nnkTypeSection.newTree(typeDef)))

func makeTypeClass(typeName:string, typeDef:NimNode):NimType = 
  assert typeDef[2].kind == nnkInfix, "Expected nnkInfix got " & $typeDef[2].kind
  NimType(name: typeName, kind:TypeClass, originalAst: repr(nnkTypeSection.newTree(typeDef)))

func makePtrNimType(typeName:string, typeDef:NimNode) : NimType = 
  assert typeDef[2].kind == nnkPtrTy, "Expected nnkPtrTy got " & $typeDef[2].kind
  assert typeDef[2][0].kind == nnkIdent, "Expected nnkIdent got " & $typeDef[2].kind
  let ptrType = typeDef[2][0].strVal() #
  NimType(name: typeName, kind:Pointer, ptrType:ptrType, originalAst: repr(nnkTypeSection.newTree(typeDef)))


# func makeAliasToGeneric(typeName:string, typeDef:NimNode) : NimType = 
#   assert typeDef[2].kind == nnkBracketExpr, "Expected nnkBracketExpr got " & $typeDef[2].kind
#   NimType(name: typeName, kind:Alias, originalAst: repr(nnkTypeSection.newTree(typeDef)))



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
          &"`{postFixNode[1][0].strVal}`"
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



func getGenericTypeName(identDefs:NimNode) : seq[NimParam] = 
  assert identDefs.kind == nnkIdentDefs, "Expected nnkIdentDefs got " & $identDefs.kind
  #[
    When 2 idents and TWO empties at the end means all idents are params 
  ]#
  let nIdents = identDefs.children.toSeq.filterIt(it.kind == nnkIdent).len
  let nEmpty = identDefs.children.toSeq.filterIt(it.kind == nnkEmpty).len
  let allIdentParams = nEmpty == 2  or nIdents > 3
  
  func getName(node:NimNode) : string = 
    case node.kind:
    of nnkEmpty, nnkEnumTy: #the enum is because TEnumAsByt[T : enum]:
      ""
    of nnkIdent:
      node.strVal
    of nnkPrefix:  #remove out/in for now
      node[^1].strVal
    else:
      error &"Error in getGenericTypeName got {node.kind}"
      ""
  if not allIdentParams:
    result = @[NimParam(name: getName(identDefs[0]), kind: OnlyName, strType:getName(identDefs[1]))]
  result = identDefs
    .children.toSeq
    .filterIt(it.kind == nnkIdent)
    .mapIt(NimParam(kind: OnlyType, strType:getName(it)))

  

func getParamFromIdentDef(identDefs:NimNode) : NimParam =
  assert identDefs.kind == nnkIdentDefs, "Expected nnkIdentDefs got " & $identDefs.kind

  let name = getNameFromIdentDef(identDefs)
  let typ = 
    case identDefs[^2].kind:
    of nnkIdent:
      identDefs[^2].strVal
    of nnkPtrTy: 
      let ptrType = identDefs[^2][0]    
      "ptr " & $repr ptrType 

    of nnkBracketExpr:
      #TODO dont pass it as a string
      repr identDefs[^2]
      # debugEcho treeRepr identDefs
      # identDefs[^2][0].strVal  
    of nnkProcTy:
      "proc():void" #Not supported as param yet but we do validate it  
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

  let genericParams = 
    case typeDef[^2].kind:
    of nnkGenericParams:      
      typeDef[^2]
      .children.toSeq
      .filterIt(it.kind == nnkIdentDefs)      
      .map(getGenericTypeName)
      .flatten
      
    else: @[]
  # if genericParams.len > 0:
  #   debugEcho treeRepr typeDef
      
  
  case objectTyNode[^1].kind:
  of nnkEmpty:
    NimType(name: typeName, kind:Object, parent:parent, typeParams:genericParams)
  of nnkRecList:
    let recListNode = objectTyNode[^1]
    assert recListNode.kind == nnkRecList, "Expected nnkRecList got " & $recListNode.kind
    let params = 
      recListNode.children.toSeq
        .filterIt(it.kind == nnkIdentDefs)
        .map(getParamFromIdentDef)    
    NimType(name: typeName, kind:Object, parent:parent, params:params, typeParams:genericParams)
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
  of nnkBracketExpr: #GENERIC ALIAS (type FOnInputKeySignature* = TMulticastDelegateOneParam[FInputKeyEventArgsPtr])
    #For now it's fine to just do an object with no params
    NimType(name:name, kind:None)

  else:
    debugEcho treeRepr typeDef
    error("Unknown type " & $typeDef[2].kind)
    NimType(kind:None)
  


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
    .filterIt("std/" notin it ) #no std until we handle search paths
    .filterIt("/models" notin it) #ignore models (uetype) for now


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

# dumpTree:
  # type
  #   Foo* = object
  #     a*: int
  #     b*: string
  #   GenericFoo*[T] = object
  #     a*: int
  #     b*: T
  #   GenericFoo2*[T, out Y] = object
  #     a*: int
  #     b*: T
  #     c*: Foo        

  #   GenericFoo3*[T:int, Y, Z : T] = object
  #     a*: int
  #     b*: T
  #     c*: GenericFoo2[T, Y]    
 
    

func genGenericTypeParams(nimType:NimType) : NimNode =
  if not nimType.typeParams.any():
    return newEmptyNode()

  func genGenericType(typ:string) : NimNode = 
    if typ == "": newEmptyNode()
    else: ident typ

  var genericParams  = nnkGenericParams.newTree()
  var lastIdentDef = nnkIdentDefs.newTree() #we need this beacause generic are a mess
  for nimParam in nimType.typeParams:
    case nimParam.kind:         
    of OnlyName:
        #restart lastIdent
      if lastIdentDef.children.toSeq.len > 0:
        let nIdents = lastIdentDef.children.toSeq.len
        if nIdents <= 2 :
          lastIdentDef.add [newEmptyNode(), newEmptyNode()]
        else:
          lastIdentDef.add newEmptyNode()
         
        genericParams.add lastIdentDef
      lastIdentDef = nnkIdentDefs.newTree()
      genericParams.add nnkIdentDefs.newTree(
        ident nimParam.name, 
        genGenericType(nimParam.strType), 
        newEmptyNode()
      )
    of OnlyType:
      lastIdentDef.add ident nimParam.strType
    of TypeInfo:
      error("TypeParam shouldnt be type info")
    

  if lastIdentDef.children.toSeq.len > 0:
    let nIdents = lastIdentDef.children.toSeq.len
    if nIdents <= 2 :
      lastIdentDef.add [newEmptyNode(), newEmptyNode()]
    else:
      lastIdentDef.add newEmptyNode()
      
    genericParams.add lastIdentDef
  
  debugEcho treeRepr genericParams

  genericParams




func nimObjectTypeToNimNode(nimType:NimType) : NimNode = 
  if nimType.ast != "": 
    var ast = nimType.ast.parseStmt
    ast = ast[0][0] #removes stmt and type section
    return ast
  
  let name = ident nimType.name
  let params = nnkRecList.newTree(@[newEmptyNode(), newEmptyNode()] & nimtype.params.map(paramToIdentDefs))
  let typeParams = genGenericTypeParams(nimType)  

  result = 
   nnkTypeDef.newTree(
    nnkPostfix.newTree(
      ident "*", #
      ident nimType.name
    ),    
    typeParams,
    # newEmptyNode(),
    nnkObjectTy.newTree(
      newEmptyNode(),
      newEmptyNode(),
      # nnkOfInherit.newTree(ident nimType.parent),
      params
    )
   )
 
func nimPtrTypeToNimNode(nimType:NimType) : NimNode = 
  let name = ident nimType.name
  let ptrType = ident nimType.ptrType
  result = 
    genAst(name, ptrType): 
      type 
        name = ptr ptrType
  result = result[0] #removes type section   

func nimEnumTypeToNimNode(nimType:NimType) : NimNode = 
  let name = ident nimType.name
  let enumFields = nimType.enumFields.mapIt(ident it)
  if not enumFields.any():
    return newEmptyNode() #Enums with no fields are not supported without importc 

  nnkTypeDef.newTree(      
    nnkPragmaExpr.newTree(
      nnkPostfix.newTree(
        ident "*", #
        name),   
      nnkPragma.newTree(
        ident "pure"
      ),
    ),
    newEmptyNode(),
    nnkEnumTy.newTree(
      @[newEmptyNode()] & 
      enumFields
    )
  )

func nimProcToNimNode(nimType:NimType) : NimNode =
  let node = nimType.originalAst.parseStmt()[0][0] #remove stmt and type section
  
  #todo remove pragmas
  node


proc genNimVMTypeImpl(nimType:NimType) : NimNode =
  #Maybe in the future extrac the type section. For now it's fine
  case nimType.kind:
  of Object: nimObjectTypeToNimNode(nimType)
  of Pointer: nimPtrTypeToNimNode(nimType)
  of Enum: nimEnumTypeToNimNode(nimType)    
  of Proc: nimProcToNimNode(nimType)
  else:
    debugEcho "NimTypeNotSupported type: " & $nimType.kind
    newEmptyNode()


proc genModuleImpl(nimModule :NimModule) : NimNode =
  let imports = nimModule.deps.mapIt(nnkImportStmt.newTree(ident it))
  let types = nnkTypeSection.newTree nimModule.types.map(genNimVMTypeImpl)
  # let types = nimModule.types.map(genNimVMTypeImpl).filterIt(it.kind != nnkEmpty).mapIt(nnkTypeSection.newTree(it))
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
  var moduleDeps = getDepsAsModulesRec(modules, engineTypesModule).deduplicate()
  # moduleDeps.add modules.filterIt(it.name in ["uobjectflags"])
  var vmTypesDeps = moduleDeps.mapIt(it.types).flatten()    
  echo $vmTypesDeps.mapIt(it.name)

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


when not defined(game) or defined(vmhost):
  const dir = PluginDir / "src" / "nimforue" / "unreal" 
  const entryPoint = dir / "prelude.nim"
  assert PluginDir != ""
  const NimModules* = getAllModulesFrom(dir, entryPoint) & getAllModulesFrom(dir / "coreuobject", dir / "coreuobject" / "uobjectflags.nim"  )
  const NimDefinedTypes = NimModules.mapIt(it.types).flatten
  const NimDefinedTypesNames* = NimDefinedTypes.mapIt(it.name)

  # static:
    # echo $NimModules.mapIt(it.name)
    # echo NimModules.filterIt(it.name == "uobjectflags")
  # quit()

const PrimitiveTypes* = @[ 
  "bool", "float32", "float64", "int16", "int32", "int64", "int8", "uint16", "uint32", "uint64", "uint8"
]

import ../utils/[utils, ueutils]

import std/[strformat, enumerate, tables, hashes, options, sugar, json, strutils, jsonutils,  sequtils, strscans, algorithm, macros, genasts]


when not defined(nuevm):
  import std/[os]
  import ../../buildscripts/nimforueconfig
const PrimitiveTypes* = @[ 
  "bool", "float32", "float64", "int16", "int32", "int64", "int8", "uint16", "uint32", "uint64", "uint8"
]

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
  
  NimEnumField* = object
    name*: string
    value*: int = -1 #if -1 it means it's not set

  NimKind* = enum
    Object, Pointer, Proc, TypeClass, Distinct, Enum, None#Nonsupported types

  NimType* = object 
    name* : string
    originalAst* : string #notice they are always stored as TypeSection (only proc for now but will change the others)
    ast* : string #This field is used only when generating types for the vm. Some types are replaced by an alias (i.e. FString, TArray..)
    case kind* : NimKind:
    of Object:
      isInheritable*: bool #if the original type is marked with the pragma inheritable
      parent*: string 
      params*: seq[NimParam]
      typeParams*: seq[NimParam] #for generic objects T etc
    of Pointer:
      ptrType*: string #just the type name as str for now. We could do a lookup in a table
    of Enum:
      enumFields: seq[NimEnumField] 
    of Proc, TypeClass, Distinct, None: #ignored for now
      discard
  NimFunctionKind* = enum
    Proc, Func #Method
  
  #ignore generic for now as I only want this first iteration to work with the vm/engine via the reflection system
  NimFunction* = object
    name*: string
    module*: string
    kind*: NimFunctionKind
    ast*: string
    params*: seq[NimParam] 
    pragmas*: seq[string] 
    returnType*: string #no empty string allowed. empty type would be void

  NimModule* = object
    name*: string
    types*: seq[NimType]
    functions*: seq[NimFunction]
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

func isUReflect*(fn: NimFunction): bool = "ureflect" in fn.pragmas

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
   
#[
  Need to get all the parents of a child 

]#

func getParentHierarchy(allModules:seq[NimModule], nimType:NimType) : seq[string] = 
  if nimType.parent == "": newSeq[string]()
  else:
    let parent = getTypeFromModule(allModules, nimType.parent)
    if parent.isNone(): newSeq[string]()
    else:
      @[nimType.parent] & getParentHierarchy(allModules, parent.get())

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
  
  # debugEcho "The Enum is", treeRepr enumTy
  func parseEnumField(field:NimNode) : NimEnumField = #this could be improved to also have the value
    case field.kind:
    of nnkIdent:
      NimEnumField(name: field.strVal)
    of nnkEnumFieldDef:
      let val = 
        case field[1].kind:
        of nnkIntLit: field[1].intVal
        of nnkDotExpr: int.high
        else: -1
      NimEnumField(name: field[0].strVal, value: val)
    else:
      error &"Error got {field.kind} inside an enum"
      NimEnumField()

  let enumFields = enumTy.children.toSeq.filterIt(it.kind != nnkEmpty).map(parseEnumField)  
  if not enumFields.any():
    # debugEcho treeRepr(typeDef)
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
      ""

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
    .filterIt(it.kind in {nnkIdent, nnkPrefix})
    .mapIt(NimParam(kind: OnlyType, strType:getName(it)))

  

func getParamFromIdentDef(identDefs:NimNode): seq[NimParam] =
  assert identDefs.kind == nnkIdentDefs, "Expected nnkIdentDefs got " & $identDefs.kind

  var names = @[getNameFromIdentDef(identDefs)]
  #comma separated params in procs
  names.add( 
    identDefs[1..^3]
      .filterIt(it.kind == nnkIdent)
      .mapIt(it.strVal()))
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
    of nnkEmpty:
      #this means it is an infered from the value: arg = value. So we are fucked
      return @[]
    of nnkVarTy:
      case identDefs[^2][0].kind:
      of nnkBracketExpr:
        repr identDefs[^2][0]
      else:
        identDefs[^2][0].strVal
    of nnkInfix:
      #probably a type class, let's just take the first we found for now. In the future this should open the function so there are more than one version or maybe just allow them     
      var child = identDefs[^2].findChild(it.kind == nnkIdent and it.strVal != "|")
      if child.kind == nnkBracketExpr: child[0].strVal()
      elif child.kind == nnkNilLit:
        return @[]
      else: 
        child.strVal()
    of nnkCommand:
      #sink?
      identDefs[^2][1].strVal
    
    of nnkObjectTy:
      if identDefs[0].strVal == "functor":
        return @[]
      error &"Error in getParamFromIdentDef got {identDefs[^2].kind} in identDefs type"
      ""
    of nnkTupleConstr: #Special case for (owner, MulticastDelegateProp)
      ""
    else:
      debugEcho treeRepr identDefs
      debugEcho repr identDefs
      error &"Error in getParamFromIdentDef got {identDefs[^2].kind} in identDefs type"
      ""
  return names.mapIt(NimParam(name: it, kind:OnlyName, strType:typ))


func makeObjNimType(typeName:string, typeDef:NimNode) : NimType = 
  let objectTyNode = typeDef[2]
  assert objectTyNode.kind == nnkObjectTy, "Expected nnkObjectTy got " & $typeDef[2].kind  
  let pragmas = 
    case typeDef[0][^1].kind:
    of nnkPragma:
       typeDef[0][^1].children.toSeq.filterIt(it.kind == nnkIdent).mapIt(it.strVal)
    else: @[]  
  let isInheritable = "inheritable" in pragmas    
  let parent = 
    case objectTyNode[1].kind:
    of nnkEmpty: ""
    of nnkOfInherit: objectTyNode[1][0].strVal
    else: 
      debugEcho treeRepr typeDef
      quit()
      ""

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
    NimType(name: typeName, kind:Object, parent:parent, isInheritable: isInheritable, typeParams:genericParams)
  of nnkRecList:
    let recListNode = objectTyNode[^1]
    assert recListNode.kind == nnkRecList, "Expected nnkRecList got " & $recListNode.kind
    let params = 
      recListNode.children.toSeq
        .filterIt(it.kind == nnkIdentDefs)
        .map(getParamFromIdentDef)    
        .flatten()
    NimType(name: typeName, kind:Object, parent:parent, isInheritable: isInheritable, params:params, typeParams:genericParams)
  else:  
    debugEcho treeRepr typeDef
    quit()
    NimType()
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
  of nnkTypeClassTy:
    #TODO concepts
    NimType(name:name, kind:None)
  of nnkIdent:
    #[TypeDef
  Postfix
    Ident "*"
    Ident "FSimpleMulticastDelegate"
  Empty
  Ident "TMulticastDelegate"]#
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

func getAllFunctions(nimNode: NimNode): seq[NimNode] = 
  result =
    nimNode
      .children
      .toSeq
      .filterIt(it.kind in {nnkProcDef, nnkFuncDef, nnkIteratorDef} and it[0].kind == nnkPostfix and it[0][0].strVal == "*")
  

func makeNimFunction(nimNode: NimNode, modName: string): NimFunction = 
  assert nimNode.kind in {nnkProcDef, nnkFuncDef, nnkIteratorDef}
  let name = nimNode.name.strVal
  let kind = 
    case nimNode.kind:
    of nnkProcDef: NimFunctionKind.Proc
    of nnkFuncDef: NimFunctionKind.Func
    else: NimFunctionKind.Proc
  
  let returnType = if nimNode.params[0].kind == nnkEmpty: "void" else: repr nimNode.params[0] #should be equivalent to makeStringParam as it is only the type
  
  let params = 
      nimNode
      .params
      .filterIt(it.kind == nnkIdentDefs)
      .map(getParamFromIdentDef)
      .flatten()
  let pragmas = 
      nimNode
      .pragma
      .mapIt(repr it)
  let ast = repr nimNode  
  NimFunction(name: name, module: modName, kind: kind, params:params, pragmas: pragmas, returnType: returnType, ast:ast)


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

  let funcs = 
    fileTree
    .getAllFunctions()
    .mapIt(makeNimFunction(it, name))
    

  let deps = fileTree.getAllImportsAsRelativePathsFromFileTree().mapIt(it.replace("//", "/"))
  NimModule(name:name, fullPath:fullPath, types: types, functions: funcs, ast:repr fileTree, deps:deps)



proc paramToIdentDefs(nimParam:NimParam) : NimNode = 
  nnkIdentDefs.newTree(
    nnkPostfix.newTree(
      ident "*", #
      ident nimParam.name
    ),
    ident nimParam.strType,
    newEmptyNode()
  )

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
  
  # debugEcho treeRepr genericParams

  genericParams




func nimObjectTypeToNimNode(nimType:NimType) : NimNode = 
  if nimType.ast != "": 
    var ast = nimType.ast.parseStmt
    ast = ast[0][0] #removes stmt and type section
    return ast
  
  let name = ident nimType.name
  let params = nnkRecList.newTree(@[newEmptyNode(), newEmptyNode()] & nimtype.params.map(paramToIdentDefs))
  let typeParams = genGenericTypeParams(nimType)  
  let baseType = if nimType.isInheritable and nimType.parent == "": "RootObj" else: nimType.parent #Would be better to just mark the type as inheritable?
  let parentNode = if baseType == "": newEmptyNode() else: nnkOfInherit.newTree(ident baseType)
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
      parentNode,
      params
    )
   )
 
func nimPtrTypeToNimNode(nimType:NimType) : NimNode = 
  let name = ident nimType.name
  let ptrType = ident nimType.ptrType
  #what we should do with the base type?
  # result = 
  #   genAst(name, ptrType): 
  #     type 
  #       name* = ptr ptrType
  #Notice the converter needs to be produced afterwards (after the type section)
  result = 
    genAst(name, ptrType):
     type 
      name* = ptr ptrType
  result = result[0] #removes type section   

func fromEnumField(field:NimEnumField): NimNode = 
  if field.value > 0:
    nnkEnumFieldDef.newTree(
      ident field.name,
      newLit(field.value)
    )
  else: ident field.name
  
func nimEnumTypeToNimNode(nimType:NimType) : NimNode = 
  let name = ident nimType.name
  
      
  let enumFields = nimType.enumFields.map(fromEnumField)
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

func genConverter(nameLit: string, parentLit:string) : NimNode =
  let name = ident nameLit
  let parent = ident parentLit & "Ptr"
  let fnName = ident &"{nameLit}To{parentLit}"
  genAst(fnName, name, parent):
    converter fnName*(self{.inject.}:name): parent = parent(int(self))
  
func genNimPtrConverter(nimType:NimType, modules:seq[NimModule]) : NimNode = 
  assert nimType.kind == Pointer
  let name = ident nimType.name
  let types = modules.mapIt(it.types).foldl(a & b, newSeq[NimType]())
  let objType = types.first(x=>x.name == nimType.name.removeLastLettersIfPtr())
  if objType.isNone() or objType.get.parent == "": 
    return newEmptyNode()
  let parents = getParentHierarchy(modules, objType.get())
  result = nnkStmtList.newTree parents.mapIt(genConverter(nimType.name, it))


proc genModuleImpl(nimModule :NimModule, allModules:seq[NimModule]) : NimNode =
  let imports = nimModule.deps.mapIt(nnkImportStmt.newTree(ident it))
  let types = nnkTypeSection.newTree nimModule.types.map(genNimVMTypeImpl)
  # let types = nimModule.types.map(genNimVMTypeImpl).filterIt(it.kind != nnkEmpty).mapIt(nnkTypeSection.newTree(it))
  result = 
      nnkStmtList.newTree(imports & types)

proc genVMModuleFile(dir:string, module: NimModule, modules:seq[NimModule]) =
  # let moduleFile = dir / module.fullPath.split("src")[1] # for modDep in engineTypeDeps:
  let moduleFile = dir / "vmtypes.nim"
  discard staticExec("mkdir -p " & parentDir(moduleFile)) #TODO extract this and make it work agnostic of os and also make a pr so we dont have to deal with it 
  let moduleVMAst = genModuleImpl(module, modules)
  let moduleTemplate = &"""
import std/[tables]

{moduleVMAst.repr}

import corevm
export corevm
"""   
  writeFile(moduleFile, moduleTemplate)

func getProcHeader(fn:NimFunction): string = 
  var fnNode = fn.ast.parseStmt()[0]
  fnNode[0] = ident fn.name #remove *
  fnNode[4] = newEmptyNode() #pragmas
  fnNode[^1] = newEmptyNode() #body
  repr fnNode

proc funcToUEReflectedWrapper(fn: NimFunction): string = 
  #outputs: proc getName(self: UObject): string = uobject.getName(self)
  # proc fnName(paramsWithTypes): string = moduleName.fnName(params)    
  let paramValues = fn.params.mapIt(it.name).join(", ")
  &"{getProcHeader(fn)} = {fn.module}.{fn.name}({paramValues})"
  

proc genVMFunctionLibrary(funcs: seq[NimFunction]) = 
  
  let file = NimGameDir() / "vm" / "vmlibrary.nim"
  let libTemplate = """
include unrealprelude
import vm/vmmacros
uClass UVMFunctionLibrary of UObject:
  ufuncs(Static):
    $1

emitVMTypes()
"""
  let fns = funcs.map(funcToUEReflectedWrapper).join("\n    ")
  writeFile(file, libTemplate % fns)

const unsupportedTypes = ["FNimTestBase", "FClassFinder",
"FActorTickFunction", "FStaticConstructObjectParameters", "FScriptDelegate",
"FRawObjectIterator", "FFrame", "FScriptArrayHelper", "FDelegateHandle", "FMulticastScriptDelegate",
"FTopLevelAssetPath", "FObjectInitializer", "FFieldVariant",
"FScriptMap", "FOnInputKeySignature", "FScriptMapHelper"]

const unsupportedFns = [
  "BroadcastAsset","HasStructOps", "GetAlignment", "GetSize", "HasAddStructReferencedObjects",
  "GetSuperStruct", "FromFString", "FromFName", "ToFString", "ToText", "IsRunningCommandlet", "AssetCreated",
  "ZeroVector", "GetCppName"
  
]
func supportsUEReflection(p:string): bool = 
  if p in unsupportedTypes: return false
  (p.startswith("F") and not p.endsWith("Ptr")) or 
  p in PrimitiveTypes or
  (p.endsWith("Ptr") and p[0] in {'U', 'A'}) or
  p == "void" or
  ["TArray"].any(container=>container in p) #TODO add TSet and TMap once fully supported

func supportsUEReflection(p:NimParam): bool = 
  case p.kind:
  of OnlyName:
    supportsUEReflection(p.strType)
  else:
    false
    # raise newException(Execption, "Shouldnt reach this point as all params should be OnlyName")

    # newException("Shoudnt reach this point as all params should be OnlyName", Exception)

func supportsUEReflection(fn:NimFunction): bool = 
  if fn.name.capitalizeAscii() in unsupportedFns: return false
  let node = fn.ast.parseStmt()[0]
  
  if node[0][1].kind == nnkAccQuoted: return false #ufuncs doesnt support quotes    
  if fn.name.len <= 2 or
    ["[", "|", "="].any(ch => ch in fn.getProcHeader())
  : return false #review later
  fn.params.all(supportsUEReflection) and fn.returnType.supportsUEReflection()

proc genVMModuleFiles*(dir:string, modules: seq[NimModule]) =
  let typesToReplace = { 
    "FString": "type FString* = string", 
    "TArray": "type TArray*[T] = seq[T]", 
    "TSet": "type TSet*[T] = distinct(seq[T])", 
    "TMap": "type TMap*[K, V] = Table[K, V]", 
    "UClass": "type UClass* = object of UStruct",
    "FName": "type FName* = distinct(int)",
    "FText": "type FText* = distinct(string)",
    # "UObject": "type UObject* = object of RootObj",
    # "FVector": "type FVector* = object of RootObj",
    # "FField": "type FField* = object of RootObj",
  }.toTable()

  var engineTypesModule = modules.filterIt(it.name == "enginetypes").head.get
  var moduleDeps = getDepsAsModulesRec(modules, engineTypesModule).deduplicate()
  # moduleDeps.add modules.filterIt(it.name in ["uobjectflags"])
  var vmTypesDeps = moduleDeps.mapIt(it.types).flatten()    
  for idx, t in enumerate(vmTypesDeps):
    if t.name in typesToReplace:
      let ast = typesToReplace[t.name]
      vmTypesDeps[idx].ast = ast
  engineTypesModule.types = vmTypesDeps & engineTypesModule.types  
  engineTypesModule.deps = @[]
  genVMModuleFile(dir, engineTypesModule, modules)
  #funcs 
  let funcs = modules.mapIt(it.functions).flatten.filter(isUReflect)
  genVMFunctionLibrary(funcs)

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

#todo cache to a file
when not defined(game) or defined(vmhost):
  when not defined(nimcheck) and not defined(nimsuggest) and 
  not defined(bindings):
    const dir = PluginDir / "src" / "nimforue" / "unreal" 
    const entryPoint = dir / "prelude.nim"
    # const dir = PluginDir / "src" / "nimforue" / "unreal" / "engine" 
    # const entryPoint = dir / "enginetypes.nim"
    
    assert PluginDir != ""
    const NimModules* = getAllModulesFrom(dir, entryPoint) & 
      getAllModulesFrom(dir / "coreuobject", dir / "coreuobject" / "uobjectflags.nim"  ) 

    const NimDefinedTypes = NimModules.mapIt(it.types).flatten
    const NimDefinedTypesNames* = NimDefinedTypes.mapIt(it.name)

    # static:
      # echo $NimModules.mapIt(it.name)
      # echo NimModules.filterIt(it.name == "uobjectflags")
    # quit()


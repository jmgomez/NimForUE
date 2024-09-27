import std/[sequtils, macros, genasts, sugar, json, jsonutils, strutils, tables, options, strformat, hashes, algorithm, macros, os]
import uebindcore, models, modelconstructor, enumops
import ../utils/[ueutils,utils]

when defined(nuevm):
  import vmtypes #todo maybe move this to somewhere else so it's in the path without messing vm.nim compilation
  import ../vm/[vmmacros, runtimefield, exposed]  
  include guest
else:
  import ueemit, nuemacrocache, headerparser
  import ../unreal/coreuobject/uobjectflags
  import ../unreal/core/net

const WithEditor* {.booldefine.} = true 
const gameDir {.strdefine.} = ""

# import ueemit

macro uEnum*(name:untyped, body : untyped): untyped =       
    let name = name.strVal()
    let metas = getMetasForType(body)
    let fields = body.toSeq().filter(n=>n.kind in [nnkIdent, nnkTupleConstr])
                    .mapIt((if it.kind == nnkIdent: @[it] else: it.children.toSeq()))
                    .foldl(a & b)
                    .mapIt(it.strVal())
                    .mapIt(makeFieldASUEnum(it, name))

    let ueType = makeUEEnum(name, fields, metas)    
    when defined nuevm:
      let types = @[ueType]    
      emitType($(types.toJson()))    
      result = nnkTypeSection.newTree  
      result.add genUEnumTypeDefBinding(ueType, ctVM)
    else:
      addVMType ueType 
      result = emitUEnum(ueType)

func fromCallNodeToIdentDenf(n: NimNode): NimNode = 
  assert n.kind == nnkCall
  let name = identPublic n[0].strVal #first always match #Although we could make it public here
  let typ = 
    if n[1][0].kind in [nnkBracketExpr, nnkIdent]: #n[1] is StmtList always
      n[1][0]
    else:
      debugEcho treeRepr n
      error "Unexpected type of field. Expected ident or bracketExpr got " & $n[1][0].kind
      newEmptyNode()
  let pragms = newEmptyNode() #no pragmas for now
  nnkIdentDefs.newTree(name, typ, pragms)    

func getClassFlags*(body:NimNode, classMetadata:seq[UEMetadata], isInterface: bool) : (EClassFlags, seq[UEMetadata]) = 
    var metas = classMetadata
    var flags = CLASS_Native
    if isInterface:
      flags = flags or (CLASS_Interface | CLASS_Abstract)
    else:
      flags = flags or (CLASS_Inherit ) #| CLASS_CompiledFromBlueprint
   
    for meta in classMetadata:
        if meta.name.toLower() == "config": #Game config. The rest arent supported just yet
            flags = flags or CLASS_Config
            metas = metas.filterIt(it.name.toLower() != "config")
        if meta.name.toLower() == "blueprintable":
            metas.add makeUEMetadata("IsBlueprintBase")
        if meta.name.toLower() == "editinlinenew":
            flags = flags or CLASS_EditInlineNew
    (flags, metas)

proc getTypeNodeFromUClassName(name:NimNode) : (string, string, seq[string]) = 
    if name.toSeq().len() < 3:
        error("uClass must explicitly specify the base class. (i.e UMyObject of UObject)", name)
    let className = name[1].strVal()
#[
  import std/macros
  dumpTree:
    uClass AAuraCharacterBase of ACharacter: discard # name[^1].kind == nnkIdent
    uClass AAuraCharacterBase of ACharacter implements IAbilitySystemInterface: discard # name[^1].kind == nnkCommand inode.kind == nnkIdent
    uClass AAuraCharacterBase of ACharacter implements (IAbilitySystemInterface, IAnother): discard # name[^1].kind == nnkCommand inode.kind == nnkTupleConstr
]#
    case name[^1].kind:
    of nnkIdent: 
        let parent = name[^1].strVal()
        (className, parent, newSeq[string]())
    of nnkCommand:
        let parent = name[^1][0].strVal()
        let inode = name[^1][^1][^1]
        var ifaces:seq[string]
        case inode.kind:
        of nnkIdent:
          let iface = inode.strVal()
          ifaces = @[iface, "U" & iface[1..^1]]
        of nnkTupleConstr:
          for iface in inode:
            ifaces.add iface.strVal()
            ifaces.add "U" & iface.strVal()[1..^1]
        else:
          error("Cant parse the uClass " & repr name)
        #here ifaces

        (className, parent, ifaces)
    else:
        error("Cant parse the uClass " & repr name)
        ("", "", newSeq[string]())

#Returns a tuple with the list of forward declaration for the block and the actual functions impl
func funcBlockToFunctionInUClass(funcBlock : NimNode, ueTypeName:string) :  tuple[fws:seq[NimNode], impl:NimNode, metas:seq[UEMetadata], fnFields: seq[UEField]] = 
    let metas = funcBlock.childrenAsSeq()
                    .tail() #skip ufunc and variations
                    .filterIt(it.kind==nnkIdent or it.kind==nnkExprEqExpr)
                    .map(fromNimNodeToMetadata)
                    .flatten()
    let firstParam = some makeFieldAsUPropParam("self", ueTypeName.addPtrToUObjectIfNotPresentAlready(), ueTypeName, CPF_None) #notice no generic/var allowed. Only UObjects
    let allFuncs = funcBlock[^1].children.toSeq()
      .filterIt(it.kind in {nnkProcDef, nnkFuncDef, nnkIteratorDef})
      .map(procBody=>ufuncImpl(procBody, firstParam, firstParam.get.typeName, metas))
    
    var fws = newSeq[NimNode]()
    var impls = newSeq[NimNode]()
    var fnFields = newSeq[UEField]()
    for (fw, impl, fnField) in allFuncs:
        fws.add fw
        impls.add impl
        fnFields.add fnField
    result = (fws, nnkStmtList.newTree(impls), metas, fnFields)

func getForwardDeclarationForProc(fn:NimNode) : NimNode = 
   result = nnkProcDef.newTree(fn[0..^1])
   result[^1] = newEmptyNode() 

#At this point the fws are reduced into a nnkStmtList and the same with the nodes

type UFuncsInClass* = object
  forwardDeclarations: seq[NimNode]
  implementations: seq[NimNode]
  procs: seq[NimNode]
  fields: seq[UEField]

func toStmtNode*(self: UFuncsInClass, withForwards: bool): NimNode = 
  result = nnkStmtList.newTree()
  if withForwards:
    result.add self.forwardDeclarations
  result &= self.procs & self.implementations


func genUFuncsForUClass*(body:NimNode, ueTypeName:string, nimProcs:seq[NimNode]): UFuncsInClass = 
    ##Returns a triplet with the forward declarations, the actual implementation 
    ##and the fields generated by the functions##
    
    let fnBlocks = body.toSeq()
                      .filter(n=>n.kind == nnkCall and 
                          n[0].strVal().toLower() in ValidUFuncs)

    let fns = fnBlocks.map(fnBlock=>funcBlockToFunctionInUClass(fnBlock, ueTypeName))
    let procFws =nimProcs.map(getForwardDeclarationForProc) #Not used there is a internal error: environment misses: self
    
    for (fw, impl, metas, newfnFields) in fns:
      result.forwardDeclarations.add fw
      result.implementations.add impl
      result.fields.add newfnFields
    result.procs = nimProcs


proc typeParams*(typeDef: NimNode): NimNode = #TODO move to utils
  assert typeDef.kind == nnkTypeDef
  if typeDef[^1][^1].kind == nnkEmpty:
    typeDef[^1][^1] = nnkRecList.newTree()
  typeDef[^1][^1]

proc expandGameplayAttribute(uef: UEField): NimNode =
  assert uef.kind == uefProp
  let capName = uef.name.capitalizeAscii()

  let repMeta = uef.metadata.first((meta)=>meta.name.toLower() == "replicatedusing" or meta.name.toLower() == "gasreplicated")
  let repFunc =
    if repMeta.isSome():
      let meta = repMeta.get()
      let repFn =
        if meta.name.toLower() == "replicatedusing":
          ident meta.value
        else:
          ident "onRep" & capName
      genAst(
        repFn = repFn,
        name = ident uef.name,
        BaseTypeName = ident uef.typeName & "Ptr",
        getAttributeFn = ident "get" & capName & "Attribute"
      ):
        proc repFn(self: BaseTypeName, oldValue: FGameplayAttributeData ) {.virtual.} =
          let asc = self.getOwningAbilitySystemComponent()
          asc.setBaseAttributeValueFromReplication(self.getAttributeFn(), self.name, oldValue)
    else:
      newEmptyNode()

  genAst(
    getAttributeFn = ident "get" & capName & "Attribute",
    setFn = ident "set" & capName,
    getFn = ident "get" & capName,
    initFn = ident "init" & capName,
    repFunc = repFunc,
    nameLit = newLit uef.name,
    name = ident uef.name,
    BaseTypeName = ident uef.typeName & "Ptr"
  ):
    proc getAttributeFn*(self: BaseTypeName): FGameplayAttribute =
      if self.isNil or self.getClass.isNil: return 
      let prop = self.getClass.getFPropertyByName(nameLit)
      makeFGameplayAttribute(prop)

    proc setFn*(self: BaseTypeName, newVal: float32) = 
      let asc = self.getOwningAbilitySystemComponent()
      asc.setNumericAttributeBase(self.getAttributeFn(), newVal)

    proc getFn*(self: BaseTypeName): float32 = self.name.getCurrentValue()

    proc initFn*(self: BaseTypeName, newVal: float32) = 
      self.name.setBaseValue(newVal)
      self.name.setCurrentValue(newVal)

    repFunc


func getCondFromString(cond: string): ELifetimeCondition = 
  for e in ELifetimeCondition:
    if ($e).replace("COND_", "").toLower() == cond.toLower():
      return e    
  COND_None

func getRepNotifyFromString(repNotify: string): ELifetimeRepNotifyCondition = 
  for e in ELifetimeRepNotifyCondition:
    if ($e).replace("REPNOTIFY_", "").toLower() == repNotify.toLower():
      return e    
  REPNOTIFY_OnChanged

func getReplicatedProps(ueType: UEType): seq[UEField] = 
  ueType.fields.filterIt(it.kind == uefProp and ("Replicated" in it.metadata or "ReplicatedUsing" in it.metadata or "GASReplicated" in it.metadata))

proc genGetLifetimeReplicatedProps(ueType: UEType): NimNode =
  #[Generates when needed.
    proc getLifetimeReplicatedProps(outLifetimeProps: var TArray[FLifetimeProperty]) {. virtual, override, constcpp.} =    
    super(outLifetimeProps)  

    let prop = self.getClass.getFPropertyByName("replicatedVar")
    var lifetimeParams = FDoRepLifetimeParams(condition: COND_None, repNotifyCondition: REPNOTIFY_OnChanged)
    registerReplicatedLifetimeProperty(prop, outLifetimeProps, lifetimeParams)
  ]#
  
  let replicatedProps = getReplicatedProps(ueType)
  if replicatedProps.len == 0:
    return newEmptyNode()

  var propAsStatements = newSeq[NimNode]()
  for prop in replicatedProps:
    let cond = getCondFromString(prop.metadata["Cond"].get("None"))
    let repNotify = getRepNotifyFromString(prop.metadata["RepNotify"].get("OnChanged"))
    let propStmt = 
      genAst(prop = ident prop.name, propName = newLit prop.name, cond = newLit cond, repNotify = newLit repNotify):
        let prop {.inject.} = self.getClass.getFPropertyByName(propName)
        var lifetimeParams = FDoRepLifetimeParams(condition: cond, repNotifyCondition: repNotify)
        registerReplicatedLifetimeProperty(prop, getOutLifetimeProps(), lifetimeParams)
    propAsStatements.add propStmt
  
  let propAsStatementsNode = nnkStmtList.newTree(propAsStatements)
  result = genAst(cls = ident ueType.name, selfType = ident (ueType.name & "Ptr"), propAsStatementsNode):
    proc getLifetimeReplicatedProps(self {.inject.}: selfType, outLifetimeProps {.inject.}: var TArray[FLifetimeProperty]) {. virtual: "GetLifetimeReplicatedProps('2 #2) const override".} =    
      proc getOutLifetimeProps(): var TArray[FLifetimeProperty] {.importcpp: "(outLifetimeProps_p0)".} #Skips "ilegal capture" error
      super(getOutLifetimeProps())  
      propAsStatementsNode

  result.body.insert 0, generateSuper(result, ueType.parent)
  # debugEcho repr result


proc genFieldNotifySetterAssignment(field: UEField): NimNode = 
  let setterName = ident field.name & "Setter"
  genAst(propName = newLit field.name, setterName, propType = getTypeNodeFromUProp(field, false)):
    let prop = self.getClass.getFPropertyByName(propName)
    when not propType is UObjectPtr: #UObjectPtr setters has issues
      prop.setSetter(setterName)

proc generateFieldNotifySetter(uet: UEType, field: UEField): NimNode = 
  let clsType = ident uet.name & "Ptr"
  let setterName = ident field.name & "Setter"
  genAst(clsType, propName = ident field.name, propType = getTypeNodeFromUProp(field, false), setterName):
    proc setterName(container{.inject.}: pointer, value{.inject.}: pointer) {.cdecl, codegenDecl: "$1 $2 (void* container_p0, const void* value_p1)".} = 
      let obj = cast[clsType](container)      
      let val = cast[ptr propType](value)
      obj.propName = val[]

type UClassNode = object
  className: string
  parent: string
  interfaces: seq[string]
  ueType: UEType
  gameplayAttributeHelpers: seq[NimNode]
  typeNode: NimNode

proc uClassImpl*(name:NimNode, body:NimNode, withForwards = true): (NimNode, NimNode, UFuncsInClass) = 
    let (className, parent, interfaces) = getTypeNodeFromUClassName(name)    
    let ueProps = getUPropsAsFieldsForType(body, className)
    let isInterface = parent == "UInterface"
    var (classFlags, classMetas) = getClassFlags(body,  getMetasForType(body), isInterface)
    if "DisplayName" notin classMetas.mapIt(it.name):
      classMetas.add(makeUEMetadata("DisplayName", className.removeFirstLetter()))

    var ueType = makeUEClass(className, parent, classFlags, ueProps, classMetas)
    when WithEditor:
      # path is relative to the Plugins/NimForUE/Source/GameNim.Build.cs since classes are emitted to GameNim package
      ueType.moduleRelativePath = ".." / ".." / ".." / ".." / name.lineInfoObj.filename[gameDir.len .. ^1]
    ueType.interfaces = interfaces
    ueType.hasObjInitCtor = NeedsObjectInitializerCtorMetadataKey in ueType.metadata
    let gameplayAttributeHelpers = 
      ueType.fields
      .filterIt(it.kind == uefProp and it.uePropType == "FGameplayAttributeData")
      .map(expandGameplayAttribute)
  
    when defined nuevm:           
      let typeSection = nnkTypeSection.newTree(genVMClassTypeDef(ueType))      
      var members = genUCalls(ueType) 
      # var (fns, fnFields) = genUFuncsForUClass(body, className, @[])      
      let funcInClass = genUFuncsForUClass(body, className, @[])
      var fns = funcInClass.toStmtNode(withForwards)
      members.add fns
      ueType.fields.add funcInClass.fields      
      members.add addVmConstructor(ueType, getPropAssigments(ueType.name, "cdo"))      
      let types = @[ueType]    
      emitType($types.toJson())
      #TODO another delayed call 
    #   let emissionAst = #lets delay the emission so we have time to register the constructor in the borrow map
    #     genAst(json = newLit $(types.toJson())):
    #       emitType(json)  
    #   members.add emissionAst
      result = (typeSection, members, funcInClass)

    else:
      #this may cause a comp error if the file doesnt exist. Make sure it exists first. #TODO PR to fix this 
      ueType.isParentInPCH = ueType.parent in getAllPCHTypes()
      addVMType ueType
      #Call is equivalent with identDefs
      let nimFields = body.children.toSeq
                          .filterIt(it.kind == nnkCall and it[0].strVal() notin @ValidUprops & @["default", "defaults"] & @ValidUFuncs)
                          .map(fromCallNodeToIdentDenf)

      var (typeNode, addEmitterProc) = emitUClass(ueType, some name.lineInfoObj)
      if nimFields.any():
        typeNode[0][0].typeParams.add nimFields
      var procNodes = nnkStmtList.newTree(addEmitterProc)
      procNodes.add gameplayAttributeHelpers
      #returns empty if there is no block defined
      let defaults = genDefaults(body)
      let ctor = genDeclaredConstructor(body, ueType)
        .get(genConstructorForClass(body, ueType, defaults.get(nnkStmtList.newTree())))
      procNodes.add ctor
      procNodes.add genGetLifetimeReplicatedProps(ueType)

      let nimProcs = body.children.toSeq
                      .filterIt(it.kind == nnkProcDef and it.name.strVal notin ["constructor", ueType.name])
                      .mapIt(it.addSelfToProc(className).processVirtual(parent))        

      var funcInClass = genUFuncsForUClass(body, className, nimProcs)
      var fns = funcInClass.toStmtNode(withForwards)
      fns.insert(0, procNodes)
      let ctorContent = newLit &"{className}(const '1& #1) : {ueType.parent}(#1)"
      let initCtor = genAst(cls = ident className, clsCtor = ident className & "Ctor", ctorContent, needsCppCtor = ueType.hasObjInitCtor):
        when cls is UUserWidget or needsCppCtor: #The test type needs to be on sync with the type on the generic ctor in ueemit
          proc clsCtor(): cls {.constructor, nodecl.} = discard
          proc fakeConstructor(init: FObjectInitializer): cls {.constructor: ctorContent .} = discard
        else:
          proc clsCtor(): cls {.constructor.} = discard
          
      fns.add initCtor       
      #Adds the C++ implementation for the field notify
      let fieldNotify = generateFieldNotify(ueType)
      if fieldNotify.isSome:
        let impl: string = fieldNotify.get()[1]
        let fieldNotfiyImpl = 
          genAst(emitContent = newLit impl):
            {.emit: emitContent.}
        fns.add fieldNotfiyImpl

        let fieldsWithNotify = ueType.fields.filterIt(it.kind == uefProp and FieldNotifyMetadataKey in it.metadata)
        for field in fieldsWithNotify:
          ctor[0][1][^1].add genFieldNotifySetterAssignment(field)
          typeNode.add generateFieldNotifySetter(ueType, field)

    result =  (typeNode, fns, funcInClass)    

      # if ueType.name == "UEnhancedInputAbilitySystem":
    # debugEcho repr result

macro uClass*(name:untyped, body : untyped) : untyped = 
  let (uClassNode, fns, _) = uClassImpl(name, body, true)
  result = nnkStmtList.newTree(@[uClassNode] & fns)

  #if name[1].eqIdent("AAuraCharacter"):
  #  here result.repr


func getRawClassTemplate(isSlate: bool, interfaces: seq[string]): string = 
  var cppInterfaces = interfaces.filterIt(it[0] == 'I').mapIt("public " & it).join(", ")
  if cppInterfaces != "":
    cppInterfaces = ", " & cppInterfaces
  let slateContent = 
    (if isSlate:
      """
  SLATE_BEGIN_ARGS($1){}
  SLATE_END_ARGS()
      """
    else: "")
  &"""
struct $1 : public $3{cppInterfaces} {{
  { slateContent }
  $2  
}};
  """

func genGetScriptStruct(ueType: UEType): NimNode = 
  let structIdent = ident uetype.name 
  result = 
    genAst(cls = structIdent, selfType = nnkPtrTy.newTree(structIdent), structIdent):
      proc getScriptStruct(self {.inject.}: selfType): UScriptStructPtr {. virtual: "GetScriptStruct() const".} =    
        structIdent.scriptStruct

macro uStruct*(name:untyped, body : untyped) : untyped = 
  var superStruct = ""
  var structTypeName = ""
  case name.kind
  of nnkIdent:
      structTypeName = name.strVal()
  of nnkInfix:
      superStruct = name[^1].strVal()
      structTypeName = name[1].strVal()
  else:
      error("Invalid node for struct name " & repr(name) & " " & $ name.kind)

  let structMetas = getMetasForType(body)
  let ueFields = getUPropsAsFieldsForType(body, structTypeName)
  let structFlags = (STRUCT_NoFlags) #Notice UE sets the flags on the PrepareCppStructOps fn
  let ueType = makeUEStruct(structTypeName, ueFields, superStruct, structMetas, structFlags)
  let nimFields = body.children.toSeq
    .filterIt(it.kind == nnkCall and it[0].strVal() notin ValidUprops)
    .map(fromCallNodeToIdentDenf)

  var nimProcs = body.children.toSeq
    .filterIt(it.kind in [nnkProcDef, nnkFuncDef, nnkIteratorDef])
    .mapIt(it.addSelfToProc(structTypeName).processVirtual(superStruct))
  
  if superStruct != "":
    nimProcs.add genGetScriptStruct(ueType)

  when defined nuevm:
    let types = @[ueType]    
    emitType($(types.toJson()))  #TODO needs structOps to be implemented
    result = nnkTypeSection.newTree(genUStructCodegenTypeDefBinding(ueType, ctVM))      
  else:
    addVMType ueType 
    result = emitUStruct(ueType)
    if nimFields.any:
      result[0][0][^1][^1].add nimFields
    result = nnkStmtList.newTree(result & nimProcs)

proc genRawCppTypeImpl(name, body : NimNode) : NimNode =     
  #TODO do this better so I can introudce other metas
  when not defined(nuevm):
    let isSlate = 
      body
      .filterIt(it.kind == nnkPar)
      .mapIt(it.children.toSeq)
      .flatten
      .anyIt(it.kind == nnkIdent and it.strVal.toLower == "slate")

    let (className, parent, interfaces) = getTypeNodeFromUClassName(name)
    let nimProcs = body.children.toSeq
      .filterIt(it.kind in [nnkProcDef, nnkFuncDef, nnkIteratorDef])
      .mapIt(it.addSelfToProc(className).processVirtual(parent))

    #Call is equivalent with identDefs
    let nimFields = body.children.toSeq
      .filterIt(it.kind == nnkCall)
      .map(fromCallNodeToIdentDenf)
    
    let recList = nnkRecList.newTree(nimFields)

    for prc in nimProcs:
      prc[0] = identPublic prc[0].strVal()

    let  
      typeName = ident className
      typeNamePtr = ident $className & "Ptr"
      typeParent = ident parent
    var typeDefs=
        genAst(typeName, typeNamePtr, typeParent):
          type 
            typeName {.exportcpp,  inheritable, codegenDecl:"placeholder".} = object of typeParent
            typeNamePtr = ptr typeName
          
    #Replaces the header pragma vale 'placehodler' from above. For some reason it doesnt want to pick the value directly
    typeDefs[0][0][^1][^1][^1] = newLit getRawClassTemplate(isSlate, interfaces)
    typeDefs[0][2][2] = recList #set the fields
    if isSlate:
      let arguments = 
        genAst(name = ident className & "FArguments"): 
          type name* {. inject, importcpp: "cppContent".} = object
      arguments[0][0][^1][^1][^1] = newLit className & "::FArguments"
      typeDefs.add arguments[0]

    result = newStmtList(typeDefs & nimProcs) 
    # echo repr result
    # echo treeRepr body

macro class*(name, body): untyped = 
  genRawCppTypeImpl(name, body)

func functorImpl(body: NimNode): NimNode = 
  when not defined(nuevm):
    var prc = body.filterIt(it.kind == nnkProcDef).head().get()
    let captures = 
      nnkRecList.newTree(
        body
        .filterIt(it.kind == nnkBracket)
        .head.get(newEmptyNode())
        .mapIt(nnkIdentDefs.newTree(identPublic(it[0].strVal()), it[1], newEmptyNode()))
      )
    let name = ident prc.name.strVal.capitalizeAscii()
    prc.name = ident "invoke" & name.strVal()
    prc.addPragma ident "member"
    prc =
      prc
        .addSelfToProc(name.strVal())
        .processVirtual(overrideName = "operator()")

    let typ = genAst(name, namePtr = ident name.strVal() & "Ptr"):
      type 
        name* = object
        namePtr* = ptr name
    typ[0][^1][^1] = captures
    result = nnkStmtList.newTree(typ, prc)

macro functor*(body: untyped): untyped = 
  #[
  (TODO: consider adding an invokation section)
  Produces:
    type
    NimFunctor = object
      self: FTileGridAssetEditorPtr
  proc invoke(f: NimFunctor, args: FSpawnTabArgs): TSharedRef[SDockTab] {.member:"operator ()(const '2& #2)", noresult .} = 
    let dockerTab = sNew[SDockTab]()
    discard dockerTab.setContent(f.self.detailsView.toSharedRef())
    dockerTab
  ]#
  result = functorImpl(body)  

macro uSection*(body: untyped): untyped = 
  when defined(nuevm):
    discard
  else:
    func getFromBody(body:NimNode, name: string): seq[NimNode] = 
        body.filterIt(it.kind in [nnkCommand, nnkCall] and it[0].eqIdent(name))
    let uclasses = body.getFromBody("uClass").mapIt(uClassImpl(it[1], it[^1], withForwards = false))
    let classes = body.getFromBody("class").mapIt(genRawCppTypeImpl(it[1], it[^1]))
    let functors = body.getFromBody("functor").mapIt(functorImpl(it[^1]))
    let userTypes = body.filterIt(it.kind == nnkTypeSection).mapIt(it.children.toSeq()).flatten()
    let userProcs = body.filterIt(it.kind in [nnkProcDef, nnkFuncDef, nnkIteratorDef]) 
    var typSection = nnkTypeSection.newTree(userTypes)
    var fns: seq[NimNode] = userProcs
    let userPrcsFwds = userProcs.map(getForwardDeclarationForProc) 
    var uClassesTypsHelper = newSeq[NimNode]()
    var uClassFns = newSeq[NimNode]()
    var uFuncFws = newSeq[NimNode]()
    for uclass in uclasses:
      let (uClassNode, funcs, funcInClasses) = uclass
      uClassesTypsHelper.add uClassNode
      uClassFns.add funcs
      uFuncFws.add funcInClasses.forwardDeclarations

    for class in classes & functors: 
      let types =  
        class
        .children.toSeq
        .filterIt(it.kind == nnkTypeSection)
        .head()
        .map(section=>section.children.toSeq())
        .get(newSeq[NimNode]())
      typSection.add types
      fns.add class.children.toSeq.filterIt(it.kind in [nnkProcDef, nnkFuncDef, nnkIteratorDef])

    #TODO allow uStructs in sections
    #set all types in the same typesection
    var uprops = nnkStmtList.newTree()
    for typ in uClassesTypsHelper:
      let typDefs = typ[0].children.toSeq()
      typSection.add typDefs
      uprops.add typ[1..^1] #shouldnt this be only for uClasses?

    result = nnkStmtList.newTree(@[typSection] & userPrcsFwds & uFuncFws & uprops & uClassFns & fns)

when not defined nuevm:
  macro uForwardDecl*(name : untyped ) : untyped = 
    let (className, parentName, interfaces) = getTypeNodeFromUClassName(name)
    var ueType = UEType(name:className, kind:uetClass, parent:parentName, interfaces:interfaces)
    ueType.interfaces = interfaces
    ueType.isParentInPCH = ueType.parent in getAllPCHTypes()
    let (typNode, addEmitterProc) = emitUClass(ueType)
    result = nnkStmtList.newTree(typNode, addEmitterProc)
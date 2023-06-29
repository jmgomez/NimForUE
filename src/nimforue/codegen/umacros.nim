import std/[sequtils, macros, genasts, sugar, json, jsonutils, strutils, tables, options, strformat, hashes, algorithm]
import uebindcore, models, modelconstructor, enumops
import ../utils/[ueutils,utils]

when defined(nuevm):
  import vmtypes #todo maybe move this to somewhere else so it's in the path without messing vm.nim compilation
  import ../vm/[vmmacros, runtimefield, exposed]  
  include guest
else:
  import ueemit, nuemacrocache, headerparser
  import ../unreal/coreuobject/uobjectflags
 

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
    when defined nuevm:
      let types = @[ueType]    
      # emitType($(types.toJson()))  #TODO needs structOps to be implemented
      result = nnkTypeSection.newTree  
      #TODO gen types
    else:
      addVMType ueType 
      result = emitUStruct(ueType) 


func getClassFlags*(body:NimNode, classMetadata:seq[UEMetadata]) : (EClassFlags, seq[UEMetadata]) = 
    var metas = classMetadata
    var flags = (CLASS_Inherit | CLASS_Native ) #| CLASS_CompiledFromBlueprint
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
    case name[^1].kind:
    of nnkIdent: 
        let parent = name[^1].strVal()
        (className, parent, newSeq[string]())
    of nnkCommand:
        let parent = name[^1][0].strVal()        
        var ifaces = 
            name[^1][^1][^1].strVal().split(",") 
        if ifaces[0][0] == 'I':
            ifaces.add ("U" & ifaces[0][1..^1])
        # debugEcho $ifaces

        (className, parent, ifaces)
    else:
        error("Cant parse the uClass " & repr name)
        ("", "", newSeq[string]())

#Returns a tuple with the list of forward declaration for the block and the actual functions impl
func funcBlockToFunctionInUClass(funcBlock : NimNode, ueTypeName:string) :  tuple[fws:seq[NimNode], impl:NimNode, metas:seq[UEMetadata], fnFields: seq[UEField]] = 
    let metas = funcBlock.childrenAsSeq()
                    .tail() #skip ufunc and variations
                    .filterIt(it.kind==nnkIdent or it.kind==nnkExprEqExpr)
                    .map(fromNinNodeToMetadata)
                    .flatten()
    #TODO add first parameter
    let firstParam = some makeFieldAsUPropParam("self", ueTypeName.addPtrToUObjectIfNotPresentAlready(), ueTypeName, CPF_None) #notice no generic/var allowed. Only UObjects
    let allFuncs = funcBlock[^1].children.toSeq()
      .filterIt(it.kind==nnkProcDef)
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
func genUFuncsForUClass*(body:NimNode, ueTypeName:string, nimProcs:seq[NimNode]) : (NimNode, seq[UEField]) = 
    let fnBlocks = body.toSeq()
                       .filter(n=>n.kind == nnkCall and 
                            n[0].strVal().toLower() in ["ufunc", "ufuncs", "ufunction", "ufunctions"])

    let fns = fnBlocks.map(fnBlock=>funcBlockToFunctionInUClass(fnBlock, ueTypeName))
    let procFws =nimProcs.map(getForwardDeclarationForProc) #Not used there is a internal error: environment misses: self
    var fws = newSeq[NimNode]() 
    var impls = newSeq[NimNode]()
    var fnFields = newSeq[UEField]()
    for (fw, impl, metas, newfnFields) in fns:
      fws = fws & fw 
      impls.add impl #impl is a nnkStmtList
      fnFields.add newfnFields
    result = (nnkStmtList.newTree(fws &  nimProcs & impls ), fnFields)



proc uClassImpl*(name:NimNode, body:NimNode): (NimNode, NimNode) = 
    let (className, parent, interfaces) = getTypeNodeFromUClassName(name)    
    let ueProps = getUPropsAsFieldsForType(body, className)
    let (classFlags, classMetas) = getClassFlags(body,  getMetasForType(body))
    var ueType = makeUEClass(className, parent, classFlags, ueProps, classMetas)    
    ueType.interfaces = interfaces
    when defined nuevm:
           
      let typeSection = nnkTypeSection.newTree(genVMClassTypeDef(ueType))      
      var members = genUCalls(ueType) 
      var (fns, fnFields) = genUFuncsForUClass(body, className, @[])      
      members.add fns
      ueType.fields.add fnFields
      let types = @[ueType]    
      let emissionAst = #lets delay the emission so we have time to register the constructor in the borrow map
        genAst(json = newLit $(types.toJson())):
          emitType(json)  
      members.add emissionAst
      result = (typeSection, members)

    else:
      #this may cause a comp error if the file doesnt exist. Make sure it exists first. #TODO PR to fix this 
      ueType.isParentInPCH = ueType.parent in getAllPCHTypes()
      addVMType ueType
      var (typeNode, addEmitterProc) = emitUClass(ueType)
      var procNodes = nnkStmtList.newTree(addEmitterProc)
      #returns empty if there is no block defined
      let defaults = genDefaults(body)
      let declaredConstructor = genDeclaredConstructor(body, className)
      if declaredConstructor.isSome(): #TODO now that Nim support constructors maybe it's a good time to revisit this. 
          procNodes.add declaredConstructor.get()
      elif doesClassNeedsConstructor(className) or defaults.isSome():
          let defaultConstructor = genConstructorForClass(body, className, defaults.get(newEmptyNode()))
          procNodes.add defaultConstructor

      let nimProcs = body.children.toSeq
                      .filterIt(it.kind == nnkProcDef and it.name.strVal notin ["constructor"])
                      .mapIt(it.addSelfToProc(className).processVirtual(parent))
      
      var (fns,_) = genUFuncsForUClass(body, className, nimProcs)
      fns.insert(0, procNodes)
      result =  (typeNode, fns)

macro uClass*(name:untyped, body : untyped) : untyped = 
    let (uClassNode, fns) = uClassImpl(name, body)
    result = nnkStmtList.newTree(@[uClassNode] & fns)
    # log repr result
    

macro uSection*(body: untyped): untyped = 
    let uclasses = 
        body.filterIt(it.kind == nnkCommand) 
            .mapIt(uClassImpl(it[1], it[^1]))
    var typs = newSeq[NimNode]()
    var fns = newSeq[NimNode]()
    for uclass in uclasses:
        let (uClassNode, fns) = uclass
        typs.add uClassNode
        fns.add fns
    #TODO allow uStructs in sections
    #set all types in the same typesection
    var typSection = nnkTypeSection.newTree()
    for typ in typs:
        let typDefs = typ[0].children.toSeq()
        typSection.add typDefs
    # let codeReordering = nnkStmtList.newTree nnkPragma.newTree(nnkExprColonExpr.newTree(ident "experimental", newLit "codereordering"))
    result = nnkStmtList.newTree(@[typSection] & fns)


when not defined nuevm:
  macro uForwardDecl*(name : untyped ) : untyped = 
      let (className, parentName, interfaces) = getTypeNodeFromUClassName(name)
      var ueType = UEType(name:className, kind:uetClass, parent:parentName, interfaces:interfaces)
      ueType.interfaces = interfaces
      ueType.isParentInPCH = ueType.parent in getAllPCHTypes()
      let (typNode, addEmitterProc) = emitUClass(ueType)
      result = nnkStmtList.newTree(typNode, addEmitterProc)
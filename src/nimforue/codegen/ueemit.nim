# include ../unreal/prelude
import std/[sugar, macros, algorithm, strutils, strformat, tables, times, genasts, sequtils, options, hashes]
import ../unreal/coreuobject/[uobject, package, uobjectglobals, nametypes]
import ../unreal/core/containers/[unrealstring, array, map]
import ../unreal/nimforue/[nimforue, nimforuebindings]
import ../unreal/engine/enginetypes
import ../utils/[utils, ueutils]
import nuemacrocache
import ../codegen/[emitter,modelconstructor, models,uemeta, uebind,gencppclass]


type

    FNimHotReloadChild* {.importcpp, header:"Guest.h".} = object of FNimHotReload

const getNumberMeta = CppFunction(name: "GetNumber", returnType: "int", params: @[])

const cppHotReloadChild = CppClassType(name: "FNimHotReloadChild", parent: "FNimHotReload", functions: @[], kind: cckStruct)






proc newInstanceInAddr[T](obj:UObjectPtr, fake : ptr T) {.importcpp: "new((EInternal*)#)'*2".} 
  
#It seems we dont need to call super anymore since we are calling the cpp default constructor
proc defaultConstructorStatic*[T](initializer: var FObjectInitializer) {.cdecl.} =
#   {.emit: "#include \"Guest.h\"".}
  newInstanceInAddr[T](initializer.getObj(), nil)
  let obj = initializer.getObj()
  let cls = obj.getClass()

  let actor = tryUECast[AActor](obj)
  if actor.isSome():
    initComponents(initializer, actor.get(), cls)

#rename these to register
proc getFnGetForUClass[T](ueType:UEType) : UPackagePtr->UFieldPtr = 
#    (pkg:UPackagePtr) => ueType.emitUClass(pkg, ueEmitter.fnTable, ueEmitter.clsConstructorTable.tryGet(ueType.name))
    proc toReturn (pgk:UPackagePtr) : UFieldPtr = #the UEType changes when functions are added
        var ueType = getGlobalEmitter().emitters.first(x => x.ueType.name == ueType.name).map(x=>x.ueType).get()
        let clsConstructor = ueEmitter.clsConstructorTable.tryGet(ueType.name).map(x=>x.fn).get(defaultConstructorStatic[T])
        ueType.emitUClass[:T](pgk, ueEmitter.fnTable, clsConstructor)
    toReturn
    
proc addEmitterInfo*(ueType:UEType, fn : UPackagePtr->UFieldPtr) : void =  
    ueEmitter.emitters.add(EmitterInfo(ueType:ueType, generator:fn))

proc addEmitterInfo*[T](ueType:UEType) : void =  
    addEmitterInfo(ueType, getFnGetForUClass[T](ueType))

proc addStructOpsWrapper*(structName : string, fn : UNimScriptStructPtr->void) = 
    ueEmitter.setStructOpsWrapperTable.add(structName, fn)

proc addClassConstructor*(clsName:string, classConstructor:UClassConstructor, hash:string) : void =  
    let ctorInfo = CtorInfo(fn:classConstructor, hash:hash, className: clsName)
    if not ueEmitter.clsConstructorTable.contains(clsName):
        ueEmitter.clsConstructorTable.add(clsName, ctorInfo)
    else:
        ueEmitter.clsConstructorTable[clsName] = ctorInfo 

    #update type information in the constructor
    var emitter =  ueEmitter.emitters.first(e=>e.ueType.name == clsName).get()
    emitter.ueType.ctorSourceHash = hash
    ueEmitter.emitters = ueEmitter.emitters.replaceFirst((e:EmitterInfo)=>e.ueType.name == clsName, emitter)

const ReinstSuffix = "_Reinst"

proc prepReinst(prev:UObjectPtr) =
    const objFlags = RF_NewerVersionExists or RF_Transactional
    prev.setFlags(objFlags)
    UE_Warn &"Reinstancing {prev.getName()}"
    # use explicit casting between uint32 and enum to avoid range checking bug https://github.com/nim-lang/Nim/issues/20024
    # prev.clearFlags(cast[EObjectFlags](RF_Public.uint32 or RF_Standalone.uint32 or RF_MarkAsRootSet.uint32))
    let prevNameStr : FString =  fmt("{prev.getName()}{ReinstSuffix}")
    let oldClassName = makeUniqueObjectName(getTransientPackage(), prev.getClass(), makeFName(prevNameStr))
    discard prev.rename(oldClassName.toFString(), nil, REN_DontCreateRedirectors)

proc prepareForReinst(prevClass : UClassPtr) = 
    # prevClass.classFlags = prevClass.classFlags | CLASS_NewerVersionExists
    prevClass.addClassFlag CLASS_NewerVersionExists
    prepReinst(prevClass)

proc prepareForReinst(prevScriptStruct : UNimScriptStructPtr) = 
    prevScriptStruct.addScriptStructFlag(STRUCT_NewerVersionExists)
    prepReinst(prevScriptStruct)

proc prepareForReinst(prevDel : UDelegateFunctionPtr) = 
    prepReinst(prevDel)
proc prepareForReinst(prevUEnum : UNimEnumPtr) =  
    # prevUEnum.markNewVersionExists()
    prepReinst(prevUEnum)


type UEmitable = UNimScriptStruct | UClass | UDelegateFunction | UEnum
        
#emit the type only if one doesn't exist already and if it's different
proc emitUStructInPackage[T : UEmitable ](pkg: UPackagePtr, emitter:EmitterInfo, prev:Option[ptr T], isFirstLoad:bool) : Option[ptr T]= 
    # when not WithEditor:
    #     let r = emitter.generator(pkg)
    #     return tryUECast[T](r)

    when defined withReinstantiation:
        let reinst = true
    else:
        let reinst = false

    if not isFirstLoad and not reinst:
        UE_Warn "Reinstanciation is disabled."
        return none[ptr T]()

    UE_Log &"Emitter info for {emitter.ueType.name}"
    if prev.isSome: #BUG TRACE
        UE_Log &"Previous type is {prev.get().getName()}"
    else:
        UE_Log &"Previous type is none"
    


    var areEquals = prev.isSome() and prev.get().toUEType().get() == emitter.ueType
  
        
    if areEquals: none[ptr T]()
    else: 
        prev.run prepareForReinst
        tryUECast[T](emitter.generator(pkg))



template registerDeleteUType(T : typedesc, package:UPackagePtr, executeAfterDelete:untyped) = 
     for instance {.inject.} in getAllObjectsFromPackage[T](package):
        if ReinstSuffix in instance.getName(): continue
        let clsName {.inject.} = 
            when T is UNimEnum: instance.getName() 
            elif T is UDelegateFunction:  "F" & instance.getName().replace(DelegateFuncSuffix, "")
            else: instance.getPrefixCpp() & instance.getName()

        if getEmitterByName(clsName).isNone():
            UE_Warn &"No emitter found for {clsName}"
            executeAfterDelete


proc registerDeletedTypesToHotReload(hotReloadInfo:FNimHotReloadPtr, emitter:UEEmitterRaw, package :UPackagePtr)  =    
    #iterate all UNimClasses, if they arent not reintanced already (name) and they dont exists in the type emitted this round, they must be deleted
    let getEmitterByName = (name:FString) => emitter.emitters.map(e=>e.ueType).first((ueType:UEType)=>ueType.name==name)
    registerDeleteUType(UClass, package):
        hotReloadInfo.deletedClasses.add(instance)
    registerDeleteUType(UNimScriptStruct, package):
        hotReloadInfo.deletedStructs.add(instance)
    registerDeleteUType(UDelegateFunction, package):
        hotReloadInfo.deletedDelegatesFunctions.add(instance)
    registerDeleteUType(UNimEnum, package):
        hotReloadInfo.deletedEnums.add(instance)


#32431 
proc emitUStructsForPackage*(ueEmitter : UEEmitterRaw, pkgName : string) : FNimHotReloadPtr = 
    #/Script/PACKAGE_NAME For now {Nim, GameNim}
    let (pkg, wasAlreadyLoaded) = tryGetPackageByName(pkgName).getWithResult(createNimPackage(pkgName))
    UE_Log "Emit ustructs for Pacakge " & pkgName & "  " & $pkg.getName()
    UE_Log "Emit ustructs for Length " & $ueEmitter.emitters.len
    UE_Log $ueEmitter.emitters.mapIt(it.ueType)
    var hotReloadInfo = newCpp[FNimHotReload]()
    for emitter in ueEmitter.emitters:
            case emitter.ueType.kind:
            of uetStruct:
                let structName = emitter.ueType.name.removeFirstLetter()
                let prevStructPtr = someNil getUTypeByName[UNimScriptStruct] structName
                let newStructPtr = emitUStructInPackage(pkg, emitter, prevStructPtr, not wasAlreadyLoaded)

                if prevStructPtr.isSome():
                   #updates the structOps wrapper with the current type information 
                   ueEmitter.setStructOpsWrapperTable[emitter.ueType.name](prevStructPtr.get())

                if prevStructPtr.isNone() and newStructPtr.isSome():
                    hotReloadInfo.newStructs.add(newStructPtr.get())
                if prevStructPtr.isSome() and newStructPtr.isSome():
                    hotReloadInfo.structsToReinstance.add(prevStructPtr.get(), newStructPtr.get())

               
            of uetClass:            
                let clsName = emitter.ueType.name.removeFirstLetter()
                let prevClassPtr = someNil getClassByName(clsName)
                let newClassPtr = emitUStructInPackage(pkg, emitter, prevClassPtr, not wasAlreadyLoaded)
                
                if prevClassPtr.isNone() and newClassPtr.isSome():
                    hotReloadInfo.newClasses.add(newClassPtr.get())
     
                if prevClassPtr.isSome() and newClassPtr.isSome() :
                    hotReloadInfo.classesToReinstance.add(prevClassPtr.get(), newClassPtr.get())

               


                if prevClassPtr.isSome() and newClassPtr.isNone(): #make sure the constructor is updated
                    let ctor = ueEmitter.clsConstructorTable.tryGet(emitter.ueType.name)
                    prevClassPtr.get().setClassConstructor(ctor.map(ctor=>ctor.fn).get(defaultConstructor))

            of uetEnum:
                let prevEnumPtr = someNil getUTypeByName[UNimEnum](emitter.ueType.name)
                let newEnumPtr = emitUStructInPackage(pkg, emitter, prevEnumPtr, not wasAlreadyLoaded)

                if prevEnumPtr.isNone() and newEnumPtr.isSome():
                    hotReloadInfo.newEnums.add(newEnumPtr.get())
                if prevEnumPtr.isSome() and newEnumPtr.isSome():
                    hotReloadInfo.enumsToReinstance.add(prevEnumPtr.get(), newEnumPtr.get())

            of uetDelegate:
                let prevDelPtr = someNil getUTypeByName[UDelegateFunction](emitter.ueType.name.removeFirstLetter() & DelegateFuncSuffix)
                let newDelPtr = emitUStructInPackage(pkg, emitter, prevDelPtr, not wasAlreadyLoaded)
                if prevDelPtr.isNone() and newDelPtr.isSome():
                    hotReloadInfo.newDelegatesFunctions.add(newDelPtr.get())
                if prevDelPtr.isSome() and newDelPtr.isSome():
                    hotReloadInfo.delegatesToReinstance.add(prevDelPtr.get(), newDelPtr.get())
            of uetInterface:
                assert false, "Interfaces are not supported yet"
                


    #Updates function pointers (after a few reloads they got out scope)
    for fnEmitter in ueEmitter.fnTable:
        let funField = fnEmitter.ueField
        let fnPtr = fnEmitter.fnPtr
        let prevFn = tryGetClassByName(funField.className.removeFirstLetter())
                        .flatmap((cls:UClassPtr)=>cls.findFunctionByNameWithPrefixes(funField.name))
                        .flatmap((fn:UFunctionPtr)=>tryUECast[UNimFunction](fn))

       
        if prevFn.isSome():
            let prev = prevFn.get()
            let newHash = funField.sourceHash
            # if not prev.sourceHash.equals(newHash):
            
            prev.setNativeFunc(cast[FNativeFuncPtr](fnPtr)) 
            prev.sourceHash = newHash
 
     
   
    registerDeletedTypesToHotReload(hotReloadInfo,ueEmitter, pkg)

    
    hotReloadInfo.setShouldHotReload()

    UE_Log $hotReloadInfo

    hotReloadInfo






proc emitUStruct(typeDef:UEType) : NimNode =
    var ueType = typeDef #the generated type must be reversed to match declaration order because the props where picked in the reversed order
    ueType.fields = ueType.fields.reversed()
    let typeDecl = genTypeDecl(ueType)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef, structName=newStrLitNode(typeDef.name)): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUStruct[name](typeDefAsNode, package))
                addStructOpsWrapper(structName, (str:UNimScriptStructPtr) => setCppStructOpFor[name](str, nil))
    
    result = nnkStmtList.newTree [typeDecl, typeEmitter]
    # debugEcho repr resulti



proc emitUClass(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode, getFnGetForUClass[name](typeDefAsNode))

    addCppClass(typeDef.toCppClass())
    result = nnkStmtList.newTree [typeDecl, typeEmitter]

proc emitUDelegate(typedef:UEType) : NimNode = 
    let typeDecl = genTypeDecl(typedef)
    
    var typedef = typedef

    let typeEmitter = genAst(typeDefAsNode=newLit typedef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUDelegate(typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]

proc emitUEnum(typedef:UEType) : NimNode = 
    let typeDecl = genTypeDecl(typedef)
    
    let typeEmitter = genAst(name=ident typedef.name, typeDefAsNode=newLit typedef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUEnum(typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]


#iterate childrens and returns a sequence fo them
func childrenAsSeq*(node:NimNode) : seq[NimNode] =
    var nodes : seq[NimNode] = @[]
    for n in node:
        nodes.add n
    nodes
    
 


func fromNinNodeToMetadata(node : NimNode) : seq[UEMetadata] =
    case node.kind:
    of nnkIdent:
        @[makeUEMetadata(node.strVal())]
    of nnkExprEqExpr:
        let key = node[0].strVal()
        case node[1].kind:
        of nnkIdent, nnkStrLit:
            @[makeUEMetadata(key, node[1].strVal())]
        of nnkTupleConstr: #Meta=(MetaVal1, MetaVal2)
            @[makeUEMetadata(key, node[1][0].strVal()),
              makeUEMetadata(key, node[1][1].strVal())]
        else:
            error("Invalid metadata node " & repr node)
            @[]
    of nnkAsgn:
        @[makeUEMetadata(node[0].strVal(), node[1].strVal())]
    else:
        debugEcho treeRepr node
        error("Invalid metadata node " & repr node)
        @[]

func getMetasForType(body:NimNode) : seq[UEMetadata] {.compiletime.} = 
    body.toSeq()
        .filterIt(it.kind==nnkPar or it.kind == nnkTupleConstr)
        .mapIt(it.children.toSeq())
        .flatten()
        .filterIt(it.kind!=nnkExprColonExpr)
        .map(fromNinNodeToMetadata)
        .flatten()

#some metas (so far only uprops)
#we need to remove some metas that may be incorrectly added as flags
#The issue is that some flags require some metas to be set as well
#so this is were they are synced
func fromStringAsMetaToFlag(meta:seq[string], preMetas:seq[UEMetadata], ueTypeName:string) : (EPropertyFlags, seq[UEMetadata]) = 
    var flags : EPropertyFlags = CPF_NativeAccessSpecifierPublic
    var metadata : seq[UEMetadata] = preMetas
    
    #TODO THROW ERROR WHEN NON MULTICAST AND USE MC ONLY
    # var flags : EPropertyFlags = CPF_None
    #TODO a lot of flags are mutually exclusive, this is a naive way to go about it
    #TODO all the bodies simetric with funcs and classes (at least the signature is)
    for m in metadata.mapIt(it.name):
        if m == "BlueprintReadOnly":
            flags = flags | CPF_BlueprintVisible | CPF_BlueprintReadOnly
        if m == "BlueprintReadWrite":
            flags = flags | CPF_BlueprintVisible

        if m in ["EditAnywhere", "VisibleAnywhere"]:
            flags = flags | CPF_Edit
        if m == "ExposeOnSpawn":
                flags = flags | CPF_ExposeOnSpawn
        if m == "VisibleAnywhere": 
                flags = flags | CPF_DisableEditOnInstance
        if m == "Transient":
                flags = flags | CPF_Transient
        if m == "BlueprintAssignable":
                flags = flags | CPF_BlueprintAssignable | CPF_BlueprintVisible
        if m == "BlueprintCallable":
                flags = flags | CPF_BlueprintCallable
        if m.toLower() == "config":
                flags = flags | CPF_Config  
        if m.toLower() == InstancedMetadataKey.toLower():
                flags = flags | CPF_ContainsInstancedReference
                metadata.add makeUEMetadata("EditInline")
            #Notice this is only required in the unlikely case that the user wants to use a delegate that is not exposed to Blueprint in any way
        #TODO CPF_BlueprintAuthorityOnly is only for MC
    
    let flagsThatShouldNotBeMeta = ["config", "BlueprintReadOnly", "BlueprintWriteOnly", "BlueprintReadWrite", "EditAnywhere", "VisibleAnywhere", "Transient", "BlueprintAssignable", "BlueprintCallable"]
    for f in flagsThatShouldNotBeMeta:
        metadata = metadata.filterIt(it.name.toLower() != f.toLower())

  

    if not metadata.any(m => m.name == CategoryMetadataKey):
       metadata.add(makeUEMetadata(CategoryMetadataKey, ueTypeName.removeFirstLetter()))

      #Attach accepts a second parameter which is the socket
    if metadata.filterIt(it.name == AttachMetadataKey).len > 1:
        let (attachs, metas) = metadata.partition((m:UEMetadata) => m.name == AttachMetadataKey)
        metadata = metas & @[attachs[0], makeUEMetadata(SocketMetadataKey, attachs[1].value)]
    (flags, metadata)

const ValidUprops = ["uprop", "uprops", "uproperty", "uproperties"]

func fromUPropNodeToField(node : NimNode, ueTypeName:string) : seq[UEField] = 

    let validNodesForMetas = [nnkIdent, nnkExprEqExpr]
    let metasAsNodes = node.childrenAsSeq()
                    .filterIt(it.kind in validNodesForMetas or (it.kind == nnkIdent and it.strVal().toLower() notin ValidUprops))
    let ueMetas = metasAsNodes.map(fromNinNodeToMetadata).flatten().tail()
    let metas = metasAsNodes
                    .filterIt(it.kind == nnkIdent)
                    .mapIt(it.strVal())
                    .fromStringAsMetaToFlag(ueMetas, ueTypeName)


    proc nodeToUEField (n: NimNode)  : seq[UEField] = #TODO see how to get the type implementation to discriminate between uProp and  uDelegate
        let fieldNames = 
            case n[0].kind:
            of nnkIdent:
                @[n[0].strVal()]
            of nnkTupleConstr:
                n[0].children.toSeq().filterIt(it.kind == nnkIdent).mapIt(it.strVal())
              
            else:
                error("Invalid node for field " & repr(n) & " " & $ n.kind)
                @[]

        proc makeUEFieldFromFieldName(fieldName:string) : UEField = 
            #stores the assignment but without the first ident on the dot expression as we dont know it yet
            func prepareAssignmentForLaterUsage(propName:string, right:NimNode) : NimNode = #to show intent
                nnkAsgn.newTree(
                    nnkDotExpr.newTree( #left
                        #here goes the var sets when generating the constructor, i.e. self, this what ever the user wants
                        ident propName
                    ), 
                    right
                )
            let assignmentNode = n[1].children.toSeq()
                                    .first(n=>n.kind == nnkAsgn)
                                    .map(n=>prepareAssignmentForLaterUsage(fieldName, n[^1]))

            var propType = if assignmentNode.isSome(): n[1][0][0].repr 
                        else: 
                            case n.kind:
                            of nnkIdent: n[1].repr.strip() #regular prop
                            of nnkCall:          
                                repr(n[^1][0]).strip() #(prop1,.., propn) : type
                            else: 
                                error("Invalid node for field " & repr(n) & " " & $ n.kind)
                                ""
            assignmentNode.run (n:NimNode)=> addPropAssignment(ueTypeName, n)
            
            if isMulticastDelegate propType:
                makeFieldAsUPropMulDel(fieldName, propType, metas[0], metas[1])
            elif isDelegate propType:
                makeFieldAsUPropDel(fieldName, propType, metas[0], metas[1])
            else:
                makeFieldAsUProp(fieldName, propType, metas[0], metas[1])
        
        fieldNames.map(makeUEFieldFromFieldName)
    #TODO Metas to flags
    let ueFields = node.childrenAsSeq()
                   .filter(n=>n.kind==nnkStmtList)
                   .head()
                   .map(childrenAsSeq)
                   .get(@[])
                   .map(nodeToUEField)
                   .flatten()
    ueFields


func getUPropsAsFieldsForType(body:NimNode, ueTypeName:string) : seq[UEField]  = 
    body.toSeq()
        .filter(n=>n.kind == nnkCall and n[0].strVal().toLower() in ValidUProps)
        .map(n=>fromUPropNodeToField(n, ueTypeName))
        .flatten()
        .reversed()
    
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
    emitUStruct(ueType) 



func constructorImpl(fnField:UEField, fnBody:NimNode) : NimNode = 
    
    let typeParam = fnField.signature.head().get() #TODO errors

    #prepare for gen ast
    let typeIdent = ident fnField.className
    let typeLiteral = newStrLitNode fnField.className
    let selfIdent = ident typeParam.name #TODO should we force to just use self?
    let initName = ident fnField.signature[1].name #there are always two params.a
    let fnName = ident fnField.name

    #gets the UEType and expands the assignments for the nodes that has cachedNodes implemented
    func insertReferenceToSelfInAssignmentNode(assgnNode:NimNode) : NimNode = 
        if assgnNode[0].len()==1: #if there is any insert it. Otherwise, replace the existing one (user has a defined a custom constructor)
            assgnNode[0].insert(0, selfIdent)
        else:
            assgnNode[0][0] = selfIdent
        assgnNode

    var assignmentsNode = getPropAssignment(fnField.className).get(newEmptyNode()) #TODO error
    let assignments = 
            nnkStmtList.newTree(
                assignmentsNode
                    .children
                    .toSeq()
                    .map(insertReferenceToSelfInAssignmentNode)
            )
    let ctorImpl = genAst(fnName, fnBody, selfIdent, typeIdent,typeLiteral,assignments, initName):
        proc fnName(initName {.inject.}: var FObjectInitializer) {.cdecl, inject.} = 
            var selfIdent{.inject.} = ueCast[typeIdent](initName.getObj())
            when not declared(self): #declares self and initializer so the default compiler compiles when using the assignments. A better approach would be to dont produce the default constructor if there is a constructor. But we cant know upfront as it is declared afterwards by definition
                var self{.inject used .} = selfIdent
          
            #calls the cpp constructor first
            callSuperConstructor(initName)
            assignments
            fnBody
            postConstructor(initName) #inits any missing comp that the user hasnt set
    
    let ctorRes = genAst(fnName, typeLiteral, hash=newStrLitNode($hash(repr(ctorImpl)))):
        #add constructor to constructor table
        addClassConstructor(typeLiteral, fnName, hash)

    result = nnkStmtList.newTree(ctorImpl, ctorRes)




macro uDelegate*(body:untyped) : untyped = 
    let name = body[0].strVal()
    let paramsAsFields = body.toSeq()
                             .filter(n=>n.kind==nnkExprColonExpr)
                             .map(n=>makeFieldAsUPropParam(n[0].strVal(), n[1].repr.strip()))
    let ueType = makeUEMulDelegate(name, paramsAsFields)
    emitUDelegate(ueType)


macro uEnum*(name:untyped, body : untyped) : untyped = 
    # echo body.treeRepr
    let name = name.strVal()
    let metas = getMetasForType(body)
    let fields = body.toSeq().filter(n=>n.kind==nnkIdent)
                    .map(n=>n.repr.strip())
                    .map(str=>makeFieldASUEnum(str))
    let ueType = makeUEEnum(name, fields, metas)
    emitUEnum(ueType)



func isBlueprintEvent(fnField:UEField) : bool = FUNC_BlueprintEvent in fnField.fnFlags

func genNativeFunction(firstParam:UEField, funField : UEField, body:NimNode) : NimNode =
    let ueType = UEType(name:funField.className, kind:uetClass) #Notice it only looks for the name and the kind (delegates)
    let className = ident ueType.name

    
    proc genParamArgFor(param:UEField) : NimNode = 
        let paraName = ident param.name
        
        let genOutParam = 
            if param.isOutParam:
                genAst(paraName, outAddr=ident(param.name & "Out")):
                    var outAddr {.inject.} : pointer
                    if not stack.mostRecentPropertyAddress.isNil(): #look at StepCompiledInReference in the cpp side of things
                        outAddr = stack.mostRecentPropertyAddress
                    else:
                        outAddr = cast[pointer](paraName.addr)
            else: newEmptyNode()

        let paramType = param.getTypeNodeFromUProp(isVarContext=false)# param.uePropType
        
        genAst(paraName, paramType, genOutParam): 
            stack.mostRecentPropertyAddress = nil

            #does the same thing as StepCompiledIn but you dont need to know the type of the Fproperty upfront (which we dont)
            var paraName {.inject.} : paramType #Define the param
            var paramAddr = cast[pointer](paraName.addr) #Cast the Param with   
            if not stack.code.isNil():
                stack.step(context, paramAddr)
            else:
                var prop = cast[FPropertyPtr](stack.propertyChainForCompiledIn)
                stack.propertyChainForCompiledIn = stack.propertyChainForCompiledIn.next
                stepExplicitProperty(stack, paramAddr, prop)
            genOutParam
            
    
    proc genSetOutParams(param:UEField) : NimNode = 
        let paraName = ident param.name
        let paramType = param.getTypeNodeFromUProp(isVarContext=false)# param.uePropType
        genAst(paraName, paramType, outAddr=ident(param.name & "Out")): 
                cast[ptr paramType](outAddr)[] = paraName



    let genParmas = nnkStmtList.newTree(funField.signature
                                                .filter(prop=>not isReturnParam(prop))
                                                .map(genParamArgFor))

    let setOutParams = nnkStmtList.newTree(funField.signature
                                                .filter(isOutParam)
                                                .map(genSetOutParams))
                            
    let returnParam = funField.signature.first(isReturnParam)
    let returnType = returnParam.map(it=>it.getTypeNodeFromUProp(isVarContext=false)).get(ident "void")
    let innerCall = 
        if funField.doesReturn():
            genAst(returnType):
                cast[ptr returnType](returnResult)[] = inner()
        else: nnkCall.newTree(ident "inner")
        
    let innerFunction = 
        genAst(body, returnType, innerCall): 
            proc inner() : returnType = 
                body
            innerCall
    # let innerCall() = nnkCall.newTree(ident "inner", newEmptyNode())
    let fnImplName = ident &"impl{funField.name}{funField.className}" #probably this needs to be injected so we can inspect it later
    let selfName = ident firstParam.name
    let fnImpl = genAst(className, genParmas, innerFunction, fnImplName, selfName, setOutParams):        
            let fnImplName {.inject.} = proc (context{.inject.}:UObjectPtr, stack{.inject.}:var FFrame,  returnResult {.inject.}: pointer):void {. cdecl .} =
                genParmas
                # var stackCopy {.inject.} = stack This would allow to create a super function to call the impl but not sure if it worth the trouble   
                stack.increaseStack()
                let selfName {.inject, used.} = ueCast[className](context) 
                innerFunction
                setOutParams

    var funField = funField
    funField.sourceHash = $hash(repr fnImpl)

    if funField.isBlueprintEvent(): #blueprint events doesnt have a body
        genAst(fnImpl, funField = newLit funField): 
            addEmitterInfo(funField, none[UFunctionNativeSignature]())
    else:
        genAst(fnImplName,fnImpl, funField = newLit funField): 
            fnImpl
            addEmitterInfo(funField, some fnImplName)
    



#first is the param specify on ufunctions when specified one. Otherwise it will use the first
#parameter of the function
#Returns a tuple with the forward declaration and the actual function 
#Notice the impl contains the actual native implementation of the
proc ufuncImpl(fn:NimNode, classParam:Option[UEField], functionsMetadata : seq[UEMetadata] = @[]) : tuple[fw:NimNode, impl:NimNode] = 
    
    let (fnField, firstParam) = uFuncFieldFromNimNode(fn, classParam, functionsMetadata)
    let className = fnField.className

    let (fnReprfwd, fnReprImpl) = genFunc(UEType(name:className, kind:uetClass), fnField)
    let fnImplNode = genNativeFunction(firstParam, fnField, fn.body)

    result =  (fnReprfwd, nnkStmtList.newTree(fnReprImpl, fnImplNode))


macro ufunc*(fn:untyped) : untyped = ufuncImpl(fn, none[UEField]()).impl

#this macro is ment to be used as a block that allows you to define a bunch of ufuncs 
#that share the same flags. You dont need to specify uFunc if the func is inside
#now it only support procDef but it will support funct too 
macro uFunctions*(body : untyped) : untyped = 
    # let structMetas = getMetasForType(body)
    # let ueFields = getUPropsAsFieldsForType(body)
    let metas = getMetasForType(body)
    let firstParam = body.children.toSeq()
                    .filter(n=>n.kind==nnkPar or n.kind == nnkTupleConstr)
                    .map(n => n.children.toSeq())
                    .foldl( a & b, newSeq[NimNode]())
                    .first(n=>n.kind==nnkExprColonExpr)
                    .map(n=>makeFieldAsUPropParam(n[0].strVal(), n[1].repr.strip().addPtrToUObjectIfNotPresentAlready(), CPF_None)) #notice no generic/var allowed. Only UObjects
                    
    let allFuncs = body.children.toSeq()
        .filter(n=>n.kind==nnkProcDef)
        .map(procBody=>ufuncImpl(procBody, firstParam, metas).impl) #TODO add forward declar to this one too?
    
    result = nnkStmtList.newTree allFuncs

macro uConstructor*(fn:untyped) : untyped = 
        #infers neccesary data as UEFields for ergonomics
    let params = fn.params
                   .children
                   .toSeq()
                   .filter(n=>n.kind==nnkIdentDefs)
                   .map(makeUEFieldFromNimParamNode)

    let firstParam = params.head().get() #TODO errors
    let initializerParam = params.tail().head().get() #TODO errors

    let fnField = makeFieldAsUFun(fn.name.strVal(), params, firstParam.uePropType.removeLastLettersIfPtr())
    constructorImpl(fnField, fn.body)

#Returns a tuple with the list of forward declaration for the block and the actual functions impl
func funcBlockToFunctionInUClass(funcBlock : NimNode, ueTypeName:string) :  tuple[fws:seq[NimNode], impl:NimNode, metas:seq[UEMetadata]] = 
    let metas = funcBlock.childrenAsSeq()
                    .tail() #skip ufunc and variations
                    .filterIt(it.kind==nnkIdent or it.kind==nnkExprEqExpr)
                    .map(fromNinNodeToMetadata)
                    .flatten()
    #TODO add first parameter
    let firstParam = some makeFieldAsUPropParam("self", ueTypeName.addPtrToUObjectIfNotPresentAlready(), CPF_None) #notice no generic/var allowed. Only UObjects
   
    # debugEcho "FUNC BLOCK " & funcBlock.treeRepr()

    let allFuncs = funcBlock[^1].children.toSeq()
        .filterIt(it.kind==nnkProcDef)
        .map(procBody=>ufuncImpl(procBody, firstParam, metas))
    
    var fws = newSeq[NimNode]()
    var impls = newSeq[NimNode]()
    for (fw, impl) in allFuncs:
        fws.add fw
        impls.add impl
    result = (fws, nnkStmtList.newTree(impls), metas)

func getForwardDeclarationForProc(fn:NimNode) : NimNode = 
   result = nnkProcDef.newTree(fn[0..^1])
   result[^1] = newEmptyNode() 

#At this point the fws are reduced into a nnkStmtList and the same with the nodes
func genUFuncsForUClass(body:NimNode, ueTypeName:string, nimProcs:seq[NimNode]) : NimNode = 
    let fnBlocks = body.toSeq()
                       .filter(n=>n.kind == nnkCall and 
                            n[0].strVal().toLower() in ["ufunc", "ufuncs", "ufunction", "ufunctions"])

    let fns = fnBlocks.map(fnBlock=>funcBlockToFunctionInUClass(fnBlock, ueTypeName))
    let procFws =nimProcs.map(getForwardDeclarationForProc) #Not used there is a internal error: environment misses: self
    var fws = newSeq[NimNode]() 
    var impls = newSeq[NimNode]()
    for (fw, impl, metas) in fns:
        fws = fws & fw 
        impls.add impl #impl is a nnkStmtList
    result = nnkStmtList.newTree(fws &  nimProcs & impls )

func genConstructorForClass(uClassBody:NimNode, className:string, constructorBody:NimNode, initializerName:string="") : NimNode = 
  var initializerName = if initializerName == "" : "initializer" else : initializerName
  let typeParam = makeFieldAsUPropParam("self", className)
  let initParam = makeFieldAsUPropParam(initializerName, "FObjectInitializer")
  let fnField = makeFieldAsUFun("defaultConstructor"&className, @[typeParam, initParam], className)
  return constructorImpl(fnField, constructorBody)

func genDeclaredConstructor(body:NimNode, className:string) : Option[NimNode] = 

  let constructorBlock = 
    body.toSeq()
    .filterIt(it.kind == nnkProcDef and it[0].strVal().toLower() in ["constructor"])
    .head()
 
  if constructorBlock.isNone():
    return none[NimNode]()
  
  let fn = constructorBlock.get()
  let params = fn.params
  assert params.len == 2, "Constructor must have only one parameter" #Notice first param is Empty
  let param = params[1] #Check for FObjectInitializer


  constructorBlock
    .map(consBody => genConstructorForClass(body, className, consBody.body(), param[0].strVal()))
    

 
func genDefaults(body:NimNode) : Option[NimNode] = 
    func replaceFirstIdentWithSelfDotExpr(assignment:NimNode) : NimNode = 
        case assignment[0].kind:
        of nnkIdent: assignment.kind.newTree(nnkDotExpr.newTree(ident "self", assignment[0]) & assignment[1..^1])
        else: assignment.kind.newTree(replaceFirstIdentWithSelfDotExpr(assignment[0]) & assignment[1..^1])

    result = 
        body.toSeq()
            .filterIt(it.kind == nnkCall and it[0].strVal().toLower() in ["default", "defaults"])
            .head()
            .map(defaultsBlock=>(
                nnkStmtList.newTree(
                    defaultsBlock[^1].children.toSeq()
                    .filterIt(it.kind == nnkAsgn)
                    .map(replaceFirstIdentWithSelfDotExpr)
                )
            )
        )


func getClassFlags*(body:NimNode, classMetadata:seq[UEMetadata]) : (EClassFlags, seq[UEMetadata]) = 
    var metas = classMetadata
    var flags = (CLASS_Inherit | CLASS_ScriptInherit )#| CLASS_Native ) #| CLASS_CompiledFromBlueprint
    for meta in classMetadata:
        if meta.name.toLower() == "config": #Game config. The rest arent supported just yet
            flags = flags or CLASS_Config
            metas = metas.filterIt(it.name.toLower()!= "config")
        if meta.name.toLower() == "blueprintable":
            metas.add makeUEMetadata("IsBlueprintBase")
        if meta.name.toLower() == "editinlinenew":
            flags = flags or CLASS_EditInlineNew
    (flags, metas)

proc getTypeNodeFromUClassName(name:NimNode) : (string, string, seq[string]) = 
    if name.toSeq().len() < 3:
        error("uClass must explicitly specify the base class. (i.e UMyObject of UObject)", name)
    let className = name[1].strVal()
    #Register the class as emitted for us so we can generate the cpp for it and suport vfuncs
    emittedClasses.add className
    case name[^1].kind:
    of nnkIdent: 
        let parent = name[^1].strVal()
        (className, parent, newSeq[string]())
    of nnkCommand:
        let parent = name[^1][0].strVal()
        let iface = name[^1][^1][^1].strVal()
        (className, parent, @[iface])
    else:
        error("Cant parse the uClass " & repr name)
        ("", "", newSeq[string]())
 

func addSelfToProc(procDef:NimNode, className:string) : NimNode = 
    procDef.params.insert(1, nnkIdentDefs.newTree(ident "self", ident className & "Ptr", newEmptyNode()))
    procDef





func getCppParamFromIdentDefs(identDef : NimNode) : CppParam =
  assert identDef.kind == nnkIdentDefs
  let name = identDef[0].strVal
  let typ = identDef[1].strVal
  CppParam(name: name, typ: typ)

func getCppFunctionFromNimFunc(fn : NimNode) : CppFunction =
  let returnType = if fn.params[0].kind == nnkEmpty: "void" else: fn.params[0].strVal
  #We skip the first two params, which are the self and the name of the function
#   debugEcho treeRepr fn
#   {.cast(nosideeffect).}:
#     quit("stop")
#     discard
  let isConstFn = fn.pragma.children.toSeq().filterIt(it.strVal() == "constcpp").any()
  let modifiers = if isConstFn: cmConst else: cmNone
  fn.pragma = newEmptyNode() #TODO remove const instead of removing all pragmas and move the pragmas to the impl
  let params = fn.params.filterIt(it.kind == nnkIdentDefs).map(getCppParamFromIdentDefs)
  let name =  fn.name.strVal.capitalizeAscii()
  CppFunction(name: name, returnType: returnType, params: params, modifiers: modifiers)


#TODO implement forwards
func overrideImpl(fn : NimNode, className:string) : (CppFunction, NimNode) =
  let cppFunc = getCppFunctionFromNimFunc(fn)

  (cppFunc, genOverride(fn, cppFunc, className))
  
# macro overrideCpp(fn : untyped) = overrideImpl(fn)
func getCppOverrides(body:NimNode, ueType:UEType) : (UEType, NimNode) = 
    let overrideBlocks = 
            body.toSeq()
                .filterIt(it.kind == nnkCall and it[0].strVal().toLower() in ["override"])
    if not overrideBlocks.any():
        return (ueType, newEmptyNode())
    let overrides = overrideBlocks.mapIt(it[^1].children.toSeq()).flatten().filterIt(it.kind == nnkProcDef).mapIt(overrideImpl(it, ueType.name))
    var ueType = ueType
    let stmOverrides = nnkStmtList.newTree()
    for (cppFunc, override) in overrides:
        ueType.fnOverrides.add cppFunc
        stmOverrides.add override

    (ueType, stmOverrides)
    
            

macro uClass*(name:untyped, body : untyped) : untyped = 
    let (className, parent, interfaces) = getTypeNodeFromUClassName(name)
    let ueProps = getUPropsAsFieldsForType(body, className)
    let (classFlags, classMetas) = getClassFlags(body,  getMetasForType(body))
    var ueType = makeUEClass(className, parent, classFlags, ueProps, classMetas)
    var cppOverridesNodes : NimNode
    (ueType, cppOverridesNodes) = getCppOverrides(body, ueType)
    ueType.interfaces = interfaces
    var uClassNode = emitUClass(ueType)

    #returns empty if there is no block defined
    let defaults = genDefaults(body)
    let declaredConstructor = genDeclaredConstructor(body, className)
    if declaredConstructor.isSome():
        uClassNode.add declaredConstructor.get()
    elif doesClassNeedsConstructor(className) or defaults.isSome():
        let defaultConstructor = genConstructorForClass(body, className, defaults.get(newEmptyNode()))
        uClassNode.add defaultConstructor

    let nimProcs = body.children.toSeq
                    .filterIt(it.kind == nnkProcDef and it.name.strVal notin ["constructor"])
                    .mapIt(addSelfToProc(it, className))

        
    let fns = genUFuncsForUClass(body, className, nimProcs)
    result =  nnkStmtList.newTree(@[uClassNode] & fns & cppOverridesNodes)
macro uForwardDecl*(name : untyped ) : untyped = 
    let (className, parent, _) = getTypeNodeFromUClassName(name)
    let clsPtr = ident className & "Ptr"
    genAst(clsName=ident className, clsParent = ident parent, clsPtr):
        type 
          clsName = object of clsParent
          clsPtr = ptr clsName


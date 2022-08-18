# include ../unreal/prelude
import std/[sugar, macros, algorithm, strutils, strformat, tables, times, genasts, sequtils, options, hashes]
import ../unreal/coreuobject/[uobject, package, uobjectglobals, nametypes]
import ../unreal/core/containers/[unrealstring, array, map]
import ../unreal/nimforue/[nimforue, nimforuebindings]
import ../utils/[utils, ueutils]
import nuemacrocache
import uemeta
import ../macros/uebind



type 
    EmitterInfo* = object 
        uStructPointer* : UFieldPtr
        ueType : UEType
        generator* : UPackagePtr->UFieldPtr
        
    
    UEEmitter* = ref object 
        emitters* : seq[EmitterInfo]
        # types* : seq[UEType]
        fnTable* : Table[string, Option[UFunctionNativeSignature]]
        clsConstructorTable* : Table[string, CtorInfo]
        

var ueEmitter* = UEEmitter() 

#rename these to register
proc getFnGetForUClass(ueType:UEType) : UPackagePtr->UFieldPtr = 
#    (pkg:UPackagePtr) => ueType.emitUClass(pkg, ueEmitter.fnTable, ueEmitter.clsConstructorTable.tryGet(ueType.name))
    proc toReturn (pgk:UPackagePtr) : UFieldPtr = #the UEType changes when functions are added
        var ueType = ueEmitter.emitters.first(x => x.ueType.name == ueType.name).map(x=>x.ueType).get()
        ueType.emitUClass(pgk, ueEmitter.fnTable, ueEmitter.clsConstructorTable.tryGet(ueType.name))
    toReturn
    
proc addEmitterInfo*(ueType:UEType, fn : UPackagePtr->UFieldPtr) : void =  
    ueEmitter.emitters.add(EmitterInfo(ueType:ueType, generator:fn))

proc addEmitterInfo*(ueType:UEType) : void =  
    addEmitterInfo(ueType, getFnGetForUClass(ueType))

proc addClassConstructor*(clsName:string, classConstructor:UClassConstructor, hash:string) : void =  
    let ctorInfo = CtorInfo(fn:classConstructor, hash:hash, className: clsName)
    if not ueEmitter.clsConstructorTable.contains(clsName):
        ueEmitter.clsConstructorTable.add(clsName, ctorInfo)
    else:
        ueEmitter.clsConstructorTable[clsName] = ctorInfo 

    #update type information in the constructor
    var emitter =  ueEmitter.emitters.first(e=>e.ueType.name == clsName).get()
    emitter.ueType.ctorSourceHash = hash
    ueEmitter.emitters = ueEmitter.emitters.replaceFirst(e=>e.ueType.name == clsName, emitter)


# proc addEmitterInfo*(ueField:UEField, fnImpl:Option[UFunctionNativeSignature]) : void =  
#     var ueClassType = ueEmitter.types.first(t=>t.name == ueField.className).get()
#     ueClassType.fields.add ueField
    
#     ueEmitter.fnTable[ueField.name] = fnImpl
#     ueEmitter.types = ueEmitter.types.replaceFirst(t=>t.name == ueField.className, ueClassType)

proc addEmitterInfo*(ueField:UEField, fnImpl:Option[UFunctionNativeSignature]) : void =  
    var emitter =  ueEmitter.emitters.first(e=>e.ueType.name == ueField.className).get()
    emitter.ueType.fields.add ueField
    ueEmitter.fnTable[ueField.name] = fnImpl

    ueEmitter.emitters = ueEmitter.emitters.replaceFirst(e=>e.ueType.name == ueField.className, emitter)


proc getEmmitedTypes() : seq[UEType] = 
    ueEmitter.emitters.map(e=>e.ueType)

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

proc prepareForReinst(prevClass : UNimClassBasePtr) = 
    # prevClass.classFlags = prevClass.classFlags | CLASS_NewerVersionExists
    # prevClass.addClassFlag CLASS_NewerVersionExists
    prepReinst(prevClass)

proc prepareForReinst(prevScriptStruct : UNimScriptStructPtr) = 
    prevScriptStruct.addScriptStructFlag(STRUCT_NewerVersionExists)
    prepReinst(prevScriptStruct)

proc prepareForReinst(prevDel : UNimDelegateFunctionPtr) = 
    prepReinst(prevDel)
proc prepareForReinst(prevUEnum : UNimEnumPtr) =  
    # prevUEnum.markNewVersionExists()
    prepReinst(prevUEnum)


type UEmitable = UNimScriptStruct | UNimClassBase | UDelegateFunction | UEnum
        
#emit the type only if one doesn't exist already and if it's different
proc emitUStructInPackage[T : UEmitable ](pkg: UPackagePtr, emitter:EmitterInfo, prev:Option[ptr T], isFirstLoad:bool) : Option[ptr T]= 

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
    


    let areEquals = prev.isSome() and prev.get().toUEType() == emitter.ueType
    if areEquals: none[ptr T]()
    else: 
        prev.run prepareForReinst
        some ueCast[T](emitter.generator(pkg))



template registerDeleteUType(T : typedesc, executeAfterDelete:untyped) = 
     for instance {.inject.} in getAllObjectsFromPackage[T](nimPackage):
        if ReinstSuffix in instance.getName(): continue
        let clsName {.inject.} = 
            when T is UNimEnum: instance.getName() 
            elif T is UNimDelegateFunction:  "F" & instance.getName().replace(DelegateFuncSuffix, "")
            else: instance.getPrefixCpp() & instance.getName()

        if getEmitterByName(clsName).isNone():
            UE_Warn &"No emitter found for {clsName}"
            executeAfterDelete


proc registerDeletedTypesToHotReload(hotReloadInfo:FNimHotReloadPtr)  =    
    #iterate all UNimClasses, if they arent not reintanced already (name) and they dont exists in the type emitted this round, they must be deleted
    let getEmitterByName = (name:FString) => ueEmitter.emitters.map(e=>e.ueType).first((ueType:UEType)=>ueType.name==name)
    registerDeleteUType(UNimClassBase):
        hotReloadInfo.deletedClasses.add(instance)
    registerDeleteUType(UNimScriptStruct):
        hotReloadInfo.deletedStructs.add(instance)
    registerDeleteUType(UNimDelegateFunction):
        hotReloadInfo.deletedDelegatesFunctions.add(instance)
    registerDeleteUType(UNimEnum):
        hotReloadInfo.deletedEnums.add(instance)

        
proc emitUStructsForPackage*(isFirstLoad:bool, pkg: UPackagePtr) : FNimHotReloadPtr = 
    var hotReloadInfo = newNimHotReload()
    for emitter in ueEmitter.emitters:
            case emitter.ueType.kind:
            of uetStruct:
                let structName = emitter.ueType.name.removeFirstLetter()
                let prevStructPtr = someNil getUTypeByName[UNimScriptStruct] structName
                let newStructPtr = emitUStructInPackage(pkg, emitter, prevStructPtr, isFirstLoad)

                if prevStructPtr.isNone() and newStructPtr.isSome():
                    hotReloadInfo.newStructs.add(newStructPtr.get())
                if prevStructPtr.isSome() and newStructPtr.isSome():
                    #Updates all prev emitted structs to point to the recently created.
                    for prevInstance in getAllObjectsFromPackage[UNimScriptStruct](nimPackage):
                        if structName in prevInstance.getName() and ReinstSuffix in prevInstance.getName():
                            UE_Warn &"Updating NewNimScriptStruct {prevInstance} to {newStructPtr}"
                            prevInstance.newNimScriptStruct = newStructPtr.get()
                            # prevInstance.childProperties = newStructPtr.get().childProperties
                    hotReloadInfo.structsToReinstance.add(prevStructPtr.get(), newStructPtr.get())

               
            of uetClass:                
                let prevClassPtr = someNil getUTypeByName[UNimClassBase](emitter.ueType.name.removeFirstLetter())
                let newClassPtr = emitUStructInPackage(pkg, emitter, prevClassPtr, isFirstLoad)

                if prevClassPtr.isNone() and newClassPtr.isSome():
                    hotReloadInfo.newClasses.add(newClassPtr.get())
                if prevClassPtr.isSome() and newClassPtr.isSome():
                    hotReloadInfo.classesToReinstance.add(prevClassPtr.get(), newClassPtr.get())

                if prevClassPtr.isSome() and newClassPtr.isNone(): #make sure the constructor is updated
                    let ctor = ueEmitter.clsConstructorTable.tryGet(emitter.ueType.name)
                    UE_Log &"Updating constructor for {emitter.ueType.name}"
                    prevClassPtr.get().setClassConstructor(ctor.map(ctor=>ctor.fn).get(defaultClassConstructor))

            of uetEnum:
                let prevEnumPtr = someNil getUTypeByName[UNimEnum](emitter.ueType.name)
                let newEnumPtr = emitUStructInPackage(pkg, emitter, prevEnumPtr, isFirstLoad)

                if prevEnumPtr.isNone() and newEnumPtr.isSome():
                    hotReloadInfo.newEnums.add(newEnumPtr.get())
                if prevEnumPtr.isSome() and newEnumPtr.isSome():
                    hotReloadInfo.enumsToReinstance.add(prevEnumPtr.get(), newEnumPtr.get())


            of uetDelegate:
                let prevDelPtr = someNil getUTypeByName[UNimDelegateFunction](emitter.ueType.name.removeFirstLetter() & DelegateFuncSuffix)
                let newDelPtr = emitUStructInPackage(pkg, emitter, prevDelPtr, isFirstLoad)
                UE_Warn &"Prev Delegate is {prevDelPtr.isSome()}"
                UE_Warn &"New Delegate is {newDelPtr.isSome()}"
                if prevDelPtr.isNone() and newDelPtr.isSome():
                    hotReloadInfo.newDelegatesFunctions.add(newDelPtr.get())
                if prevDelPtr.isSome() and newDelPtr.isSome():
                    hotReloadInfo.delegatesToReinstance.add(prevDelPtr.get(), newDelPtr.get())



    #Updates function pointers (after a few reloads they got out scope)
    for fnName, fnPtr in ueEmitter.fnTable:
        let funField = getFieldByName(getEmmitedTypes(), fnName)
        let prevFn = funField
                        .flatmap((ff:UEField)=> 
                                tryGetClassByName(ff.className.removeFirstLetter())
                                .flatmap((cls:UClassPtr)=>cls.findFunctionByNameWithPrefixes(ff.name)))
                        .flatmap((fn:UFunctionPtr)=>tryUECast[UNimFunction](fn))

       
        if prevFn.isSome() and funField.isSome():
            let prev = prevFn.get()
            let newHash = funField.get().sourceHash
            # if not prev.sourceHash.equals(newHash):
            # UE_Warn fmt"A function changed {fnName} updating the pointer"
            prev.setNativeFunc(cast[FNativeFuncPtr](fnPtr)) 
            prev.sourceHash = newHash
 
     
   
    registerDeletedTypesToHotReload(hotReloadInfo)

    
    hotReloadInfo.setShouldHotReload()

    UE_Log $hotReloadInfo

    hotReloadInfo


#By default ue types are emitted in the /Script/Nim package. But we can use another for the tests. 
#This emit block below can be moved to the macro cache. And then have another macro that generates the registration of the types. 
#That would allow for intecepting the constructor, but would it worth the extra complexity?

proc emitUStructsForPackage*(isFirstLoad:bool, pkgName:FString = "Nim") : FNimHotReloadPtr = 
    let pkg = findObject[UPackage](nil, convertToLongScriptPackageName("Nim"))
    emitUStructsForPackage(isFirstLoad, pkg)


proc emitUStruct(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUStruct[name](typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]
    # debugEcho repr resulti

proc emitUClass(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode, getFnGetForUClass(typeDefAsNode))

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
    
func fromStringAsMetaToFlag(meta:seq[string]) : (EPropertyFlags, seq[UEMetadata]) = 
    # var flags : EPropertyFlags = CPF_SkipSerialization
    var flags : EPropertyFlags = CPF_NoDestructor
    var metadata : seq[UEMetadata] = @[]
    #TODO THROW ERROR WHEN NON MULTICAST AND USE MC ONLY
    # var flags : EPropertyFlags = CPF_None
    #TODO a lot of flags are mutually exclusive, this is a naive way to go about it
    for m in meta:
        if m == "BlueprintReadOnly":
            flags = flags | CPF_BlueprintVisible | CPF_BlueprintReadOnly
        if m == "BlueprintReadWrite":
            flags = flags | CPF_BlueprintVisible
        if m == "EditAnywhere":
            flags = flags | CPF_Edit
        if m == "ExposeOnSpawn":
                flags = flags | CPF_ExposeOnSpawn
                metadata.add makeUEMetadata "ExposeOnSpawn"
        if m == "VisibleAnywhere":
                flags = flags | CPF_SimpleDisplay
        if m == "Transient":
                flags = flags | CPF_Transient
        if m == "BlueprintAssignable":
                flags = flags | CPF_BlueprintAssignable | CPF_BlueprintVisible
        if m == "BlueprintCallable":
                flags = flags | CPF_BlueprintCallable
            #Notice this is only required in the unlikely case that the user wants to use a delegate that is not exposed to Blueprint in any way
        #TODO CPF_BlueprintAuthorityOnly is only for MC
        

    (flags, metadata)
   


func fromUPropNodeToField(node : NimNode, ueTypeName:string) : seq[UEField] = 
    let metas = node.childrenAsSeq()
                    .filter(n=>n.kind==nnkIdent and n.strVal().toLower() != "uprop")
                    .map(n=>n.strVal())
                    .fromStringAsMetaToFlag()

    func nodeToUEField (n: NimNode)  : UEField = #TODO see how to get the type implementation to discriminate between uProp and  uDelegate
        let fieldName = n[0].repr
        
        #stores the assigment but without the first ident on the dot expression as we dont know it yet
        func prepareAssigmentForLaterUsage(propName:string, right:NimNode) : NimNode = #to show intent
            nnkAsgn.newTree(
                nnkDotExpr.newTree( #left
                    #here goes the var sets when generating the constructor, i.e. self, this what ever the user wants
                    ident propName
                ), 
                right
            )
        let assigmentNode = n[1].children.toSeq()
                                  .first(n=>n.kind == nnkAsgn)
                                  .map(n=>prepareAssigmentForLaterUsage(fieldName, n[^1]))

        var propType = if assigmentNode.isSome(): n[1][0][0].repr else: n[1].repr.strip()
        assigmentNode.run (n:NimNode)=> addPropAssigment(ueTypeName, n)
        if isMulticastDelegate propType:
            makeFieldAsUPropMulDel(fieldName, propType, metas[0], metas[1])
        elif isDelegate propType:
            makeFieldAsUPropDel(fieldName, propType, metas[0], metas[1])
        else:
            makeFieldAsUProp(fieldName, propType, metas[0], metas[1])

    #TODO Metas to flags
    let ueFields = node.childrenAsSeq()
                   .filter(n=>n.kind==nnkStmtList)
                   .head()
                   .map(childrenAsSeq)
                   .get(@[])
                   .map(nodeToUEField)
    ueFields



func getMetasForType(body:NimNode) : seq[UEMetadata] {.compiletime.} = 
    body.toSeq()
        .filter(n=>n.kind==nnkPar or n.kind == nnkTupleConstr)
        .map(n => n.children.toSeq())
        .foldl( a & b, newSeq[NimNode]())
        .filter(n=>n.kind!=nnkExprColonExpr and n.kind!=nnkExprEqExpr) #ignore : and =. The later will be used for category and probably meta, etc. The former is rerserved for specifying types in uFunctions
        .map(n=>n.strVal().strip())
        .map(makeUEMetadata)

func getUPropsAsFieldsForType(body:NimNode, ueTypeName:string) : seq[UEField]  = 
    body.toSeq()
        .filter(n=>n.kind == nnkCall and n[0].strVal().toLower() in ["uprop", "uprops", "uproperty", "uproperties"])
        .map(n=>fromUPropNodeToField(n, ueTypeName))
        .foldl(a & b, newSeq[UEField]())
        .reversed()
    
macro uStruct*(name:untyped, body : untyped) : untyped = 
    let structTypeName = name.strVal()#notice that it can also contains of meaning that it inherits from another struct
    let structMetas = getMetasForType(body)
    let ueFields = getUPropsAsFieldsForType(body, structTypeName)
    let structFlags = (STRUCT_NoFlags) #Notice UE sets the flags on the PrepareCppStructOps fn
    let ueType = makeUEStruct(structTypeName, ueFields, "", structMetas, structFlags)

    emitUStruct(ueType) 



func makeUEFieldFromNimParamNode(n:NimNode) : UEField = 
    #make sure there is no var at this point, but CPF_Out
    
    var nimType = n[1].repr.strip()
    let paramName = n[0].strVal()
    var paramFlags = CPF_Parm
    if nimType.split(" ")[0] == "var":
        paramFlags = paramFlags | CPF_OutParm
        nimType = nimType.split(" ")[1]
    makeFieldAsUPropParam(paramName, nimType, paramFlags)

func constructorImpl(fnField:UEField, fnBody:NimNode) : NimNode = 

    let typeParam = fnField.signature.head().get() #TODO errors

    #prepare for gen ast
    let typeIdent = ident fnField.className
    let typeLiteral = newStrLitNode fnField.className
    let selfIdent = ident typeParam.name
    let initName = ident fnField.signature[1].name #there are always two params.a
    let fnName = ident fnField.name

    #gets the UEType and expands the assigments for the nodes that has cachedNodes implemented
    func insertReferenceToSelfInAssigmentNode(assgnNode:NimNode) : NimNode = 
        if assgnNode[0].len()==1: #if there is any insert it. Otherwise, replace the existing one (user has a defined a custom constructor)
            assgnNode[0].insert(0, selfIdent)
        else:
            assgnNode[0][0] = selfIdent
        assgnNode

    var assigmentsNode = getPropAssigment(fnField.className).get(newEmptyNode()) #TODO error
    let assigments = 
            nnkStmtList.newTree(
                assigmentsNode
                    .children
                    .toSeq()
                    .map(insertReferenceToSelfInAssigmentNode)
            )
    let ctorImpl = genAst(fnName, fnBody, selfIdent, typeIdent,typeLiteral,assigments, initName):
        proc fnName(initName {.inject.}: var FObjectInitializer) {.cdecl, inject.} = 
            var selfIdent{.inject.} = ueCast[typeIdent](initName.getObj())
            when not declared(self): #declares self and initializer so the default compiler compiles when using the assigments. A better approach would be to dont produce the default constructor if there is a constructor. But we cant know upfront as it is declared afterwards by definition
                var self{.inject used .} = selfIdent
            
            when not declared(this): 
                var this{.inject used .} = selfIdent
            
            when not declared(initializer):
                var initializer{.inject.} = initName

            selfIdent.getClass().getFirstCppClass().classConstructor(initializer)
            #calls the cpp constructor first
            assigments
            fnBody #user code
    
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

        var param = param
        param.propFlags = CPF_None #Makes sure there is no CPF_ParmOut flag before calling GetTypeNodeFromUprop so it doenst produce var here
        let paramType = param.getTypeNodeFromUProp()# param.uePropType
        
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
        var param = param
        param.propFlags = CPF_None #Makes sure there is no CPF_ParmOut flag before calling GetTypeNodeFromUprop so it doenst produce var here
        let paramType = param.getTypeNodeFromUProp()# param.uePropType
        genAst(paraName, paramType, outAddr=ident(param.name & "Out")): 
                cast[ptr paramType](outAddr)[] = paraName



    let genParmas = nnkStmtList.newTree(funField.signature
                                                .filter(prop=>not isReturnParam(prop))
                                                .map(genParamArgFor))

    let setOutParams = nnkStmtList.newTree(funField.signature
                                                .filter(isOutParam)
                                                .map(genSetOutParams))
                            
    let returnParam = funField.signature.first(isReturnParam)
    let returnType = ident returnParam.map(x=>x.uePropType).get("void")
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
                let selfName {.inject used.} = ueCast[className](context) 
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
    


func getFunctionFlags(fn:NimNode, functionsMetadata:seq[UEMetadata]) : (EFunctionFlags, seq[UEMetadata]) = 
    var flags = FUNC_Native or FUNC_Public
    var metas : seq[UEMetadata]
    func hasMeta(meta:string) : bool = fn.pragma.children.toSeq().any(n=> repr(n).toLower()==meta.toLower()) or 
                                        functionsMetadata.any(metadata=>metadata.name.toLower()==meta.toLower())

    if hasMeta("BlueprintPure"):
        flags = flags | FUNC_BlueprintPure | FUNC_BlueprintCallable
    if hasMeta("BlueprintCallable"):
        flags = flags | FUNC_BlueprintCallable
    if hasMeta("BlueprintImplementableEvent"):
        flags = flags | FUNC_BlueprintEvent | FUNC_BlueprintCallable
    if hasMeta("Static"):
        flags = flags | FUNC_Static
    if hasMeta("CallInEditor"):
        metas.add(makeUEMetadata("CallInEditor"))
        
    (flags, metas)



#first is the param specify on ufunctions when specified one. Otherwise it will use the first
#parameter of the function
func ufuncImpl(fn:NimNode, classParam:Option[UEField], functionsMetadata : seq[UEMetadata] = @[]) : NimNode = 
 #this will generate a UEField for the function 
    #and then call genNativeFunction passing the body

    #converts the params to fields (notice returns is not included)
    let fnName = fn[0].strVal().firstToUpper()
    let formalParamsNode = fn.children.toSeq() #TODO this can be handle in a way so multiple args can be defined as the smae type
                             .filter(n=>n.kind==nnkFormalParams)
                             .head()
                             .get(newEmptyNode()) #throw error?
                             .children
                             .toSeq()

    let fields = formalParamsNode
                    .filter(n=>n.kind==nnkIdentDefs)
                    .map(makeUEFieldFromNimParamNode)


    #For statics funcs this is also true becase they are only allow
    #in ufunctions macro with the parma.
    let firstParam = classParam.chainNone(()=>fields.head()).getOrRaise("Class not found. Please use the ufunctions macr and specify the type there if you are trying to define a static function. Otherwise, you can also set the type as first argument")
    let className = firstParam.uePropType.removeLastLettersIfPtr()
    

    let returnParam = formalParamsNode #for being void it can be empty or void
                        .first(n=>n.kind==nnkIdent)
                        .flatMap((n:NimNode)=>(if n.strVal()=="void": none[NimNode]() else: some(n)))
                        .map(n=>makeFieldAsUPropParam("toReturn", n.repr.strip(), CPF_Parm | CPF_ReturnParm))

    let actualParams = classParam.map(n=>fields) #if there is class param, first param would be use as actual param
                                 .get(fields.tail()) & returnParam.map(f => @[f]).get(@[])
    
    
    var flagMetas = getFunctionFlags(fn, functionsMetadata)
    if actualParams.any(isOutParam):
        flagMetas[0] = flagMetas[0] or FUNC_HasOutParms


    let fnField = makeFieldAsUFun(fnName, actualParams, className, flagMetas[0], flagMetas[1])

    let fnReprNode = genFunc(UEType(name:className, kind:uetClass), fnField)
    
    let fnImplNode = genNativeFunction(firstParam, fnField, fn.body)

    # echo fnImplNode.repr
    result =  nnkStmtList.newTree(fnReprNode, fnImplNode)
    # debugEcho result.repr

macro ufunc*(fn:untyped) : untyped = ufuncImpl(fn, none[UEField]())

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
        .map(procBody=>ufuncImpl(procBody, firstParam, metas))
    
    # exec("sleep 1")
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

func funcBlockToFunctionInUClass(funcBlock : NimNode, ueTypeName:string) : NimNode = 
    let metas = funcBlock.childrenAsSeq()
                    .filter(n=>n.kind==nnkIdent)
                    .map(n=>n.strVal().strip())
                    .map(makeUEMetadata)
    #TODO add first parameter
    let firstParam = some makeFieldAsUPropParam("self", ueTypeName.addPtrToUObjectIfNotPresentAlready(), CPF_None) #notice no generic/var allowed. Only UObjects
   
    # debugEcho "FUNC BLOCK " & funcBlock.treeRepr()

    let allFuncs = funcBlock[^1].children.toSeq()
        .filter(n=>n.kind==nnkProcDef)
        .map(procBody=>ufuncImpl(procBody, firstParam, metas))

    result = nnkStmtList.newTree allFuncs


func genUFuncsForUClass(body:NimNode, ueTypeName:string) : seq[NimNode] = 
    let fnBlocks = body.toSeq()
                       .filter(n=>n.kind == nnkCall and 
                            n[0].strVal().toLower() in ["ufunc", "ufuncs", "ufunction", "ufunctions"])

    fnBlocks.map(fnBlock=>funcBlockToFunctionInUClass(fnBlock, ueTypeName))
   

macro uClass*(name:untyped, body : untyped) : untyped = 
    if name.toSeq().len() < 3:
        error("uClass must explicitly specify the base class. (i.e UMyObject of UObject)", name)

    let parent = name[^1].strVal()
    let className = name[1].strVal()
    let classMetas = getMetasForType(body)
    let ueProps = getUPropsAsFieldsForType(body, className)
    let classFlags = (CLASS_Inherit | CLASS_ScriptInherit | CLASS_Native) #| CLASS_CompiledFromBlueprint
    let ueType = makeUEClass(className, parent, classFlags, ueProps, classMetas)
    
    var uClassNode = emitUClass(ueType)
  
    if doesClassNeedsConstructor(className):
        let typeParam = makeFieldAsUPropParam("self", className)
        let initParam = makeFieldAsUPropParam("initializer", "FObjectInitializer")
        let fnField = makeFieldAsUFun("defaultConstructor"&className, @[typeParam, initParam], className)
        
        let constructor = constructorImpl(fnField, newEmptyNode())
       
        # echo repr constructor
        uClassNode.add constructor
    # echo treeRepr uClassNode className`
    let fns = genUFuncsForUClass(body, className)
    result =  nnkStmtList.newTree(@[uClassNode] & fns)
   
    
    





#falta genererar el call
#void vs no void
#return type
#param


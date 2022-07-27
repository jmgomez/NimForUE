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
    EmitterKind* = enum
        ekType #Class, Struct, Delegate, Enum
        ekFunction 
    EmitterInfo* = object #The function generator doesnt seem really required. Revisit this and see if I can get it around using the UEType directly. If so, it may be possible to use macro cache instead (so it works with IC)
        uStructPointer* : UFieldPtr
        case kind* : EmitterKind:
        of ekType:
            ueType : UEType
            generator* : UPackagePtr->UFieldPtr
        of ekFunction:
            uFunction* : UEField
            fnImpl* : UFunctionNativeSignature
            fnGenerator*: UClassPtr->UFunctionPtr
        
    
    UEEmitter* = ref object 
        emitters* : seq[EmitterInfo]
        types* : seq[UEType]
        fnTable* : Table[string, Option[UFunctionNativeSignature]]
        clsConstructorTable* : Table[string, Option[UClassConstructor]]


var ueEmitter* = UEEmitter() 

#rename these to register

proc addEmitterInfo*(ueType:UEType) : void =  
    ueEmitter.types.add(ueType)

proc addEmitterInfo*(ueType:UEType, fn : UPackagePtr->UFieldPtr) : void =  
    ueEmitter.emitters.add(EmitterInfo(kind:ekType, ueType:ueType, generator:fn))

proc addClassConstructor*(clsName:string, classConstructor:UClassConstructor) : void =  
    ueEmitter.clsConstructorTable.add(clsName, some classConstructor)

proc addEmitterInfo*(ueField:UEField, fnImpl:Option[UFunctionNativeSignature]) : void =  
    var ueClassType = ueEmitter.types.first(t=>t.name == ueField.className).get()
    ueClassType.fields.add ueField
    
    ueEmitter.fnTable[ueField.name] = fnImpl
    ueEmitter.types = ueEmitter.types.replaceFirst(t=>t.name == ueField.className, ueClassType)

proc prepReinst(prev:UObjectPtr) = 
    prev.setFlags(RF_NewerVersionExists)

    # use explicit casting between uint32 and enum to avoid range checking bug https://github.com/nim-lang/Nim/issues/20024
    prev.clearFlags(cast[EObjectFlags](RF_Public.uint32 or RF_Standalone.uint32))

    let prevNameStr : FString =  fmt("{prev.getName()}_REINST")
    let oldClassName = makeUniqueObjectName(prev.getOuter(), prev.getClass(), makeFName(prevNameStr))
    discard prev.rename(oldClassName.toFString(), nil, REN_DontCreateRedirectors)

proc prepareForReinst(prevClass : UClassPtr) = 
    # prevClass.classFlags = prevClass.classFlags | CLASS_NewerVersionExists
    prevClass.addClassFlag CLASS_NewerVersionExists
    prepReinst(prevClass)

proc prepareForReinst(prevScriptStruct : UScriptStructPtr) = 
    prevScriptStruct.addScriptStructFlag(STRUCT_NewerVersionExists)
    prepReinst(prevScriptStruct)

proc prepareForReinst(prevDel : UDelegateFunctionPtr) = 
    prepReinst(prevDel)
proc prepareForReinst(prevUEnum : UNimEnumPtr) = discard 
    # prevUEnum.markNewVersionExists()
    # prepReinst(prevUEnum)


type UEmitable = UScriptStruct | UClass | UDelegateFunction | UEnum
        
#emit the type only if one doesn't exist already and if it's different
proc emitUStructInPackage[T : UEmitable ](pkg: UPackagePtr, emitter:EmitterInfo, prev:Option[ptr T]) : Option[ptr T]= 
    let areEquals = prev.isSome() and prev.get().toUEType() == emitter.ueType
    if areEquals: none[ptr T]()
    else: 
        prev.run prepareForReinst
        some ueCast[T](emitter.generator(pkg))

proc emitUStructInPackage[T : UEmitable ](pkg: UPackagePtr, ueType:UEType, fnGen:UPackagePtr->UFieldPtr,  prev:Option[ptr T]) : Option[ptr T]= 
    let areEquals = prev.isSome() and prev.get().toUEType() == ueType
    if areEquals: none[ptr T]()
    else: 
        prev.run prepareForReinst
        some ueCast[T](fnGen(pkg))



proc emitUStructsForPackage*(pkg: UPackagePtr) : FNimHotReloadPtr = 
    var hotReloadInfo = newNimHotReload()
    for emitter in ueEmitter.emitters:
        case emitter.kind:
        of ekType:
            case emitter.ueType.kind:
            of uetStruct:
                let prevStructPtr = someNil getScriptStructByName emitter.ueType.name.removeFirstLetter()
                let newStructPtr = emitUStructInPackage(pkg, emitter, prevStructPtr)
                prevStructPtr.flatmap((prev : UScriptStructPtr) => newStructPtr.map(newStr=>(prev, newStr)))
                    .run((pair:(UScriptStructPtr, UScriptStructPtr)) => hotReloadInfo.structsToReinstance.add(pair[0], pair[1]))
            of uetClass:
                #Class are passed as types directly but this will likely break the order of dependencies. Need to jump into use the nim cache
                discard
                # let prevClassPtr = someNil getClassByName emitter.ueType.name.removeFirstLetter()
                # let newClassPtr = emitUStructInPackage(pkg, emitter, prevClassPtr)
                # prevClassPtr.flatmap((prev:UClassPtr) => newClassPtr.map(newCls=>(prev, newCls)))
                #     .run((pair:(UClassPtr, UClassPtr)) => hotReloadInfo.classesToReinstance.add(pair[0], pair[1]))
            of uetEnum:
                let prevEnumPtr = someNil getUTypeByName[UNimEnum](emitter.ueType.name)
                let newEnumPtr = emitUStructInPackage(pkg, emitter, prevEnumPtr)
                prevEnumPtr.flatmap((prev:UNimEnumPtr) => newEnumPtr.map(newEnum=>(prev, newEnum)))
                    .run((pair:(UNimEnumPtr, UNimEnumPtr)) => hotReloadInfo.enumsToReinstance.add(pair[0], pair[1]))
            of uetDelegate:
                let prevDelPtr = someNil getUTypeByName[UDelegateFunction](emitter.ueType.name.removeFirstLetter())
                let newDelPtr = emitUStructInPackage(pkg, emitter, prevDelPtr)
                prevDelptr.flatmap((prev : UDelegateFunctionPtr) => newDelPtr.map(newDel=>(prev, newDel)))
                    .run((pair:(UDelegateFunctionPtr, UDelegateFunctionPtr)) => hotReloadInfo.delegatesToReinstance.add(pair[0], pair[1]))
        of ekFunction: 
            UE_Log "generating the function"
            #resolve the class
            let cls = getClassByName emitter.uFunction.className.removeFirstLetter()
            UE_Log fmt"generating the function for class: {cls.getName()}"
            discard emitter.fnGenerator(cls) 
            
    for ueType in ueEmitter.types: 
        case ueType.kind:
        of uetClass:
            let ueType = ueType
            let fnGen = (pkg:UPackagePtr)=> ueType.emitUClass(pkg, ueEmitter.fnTable, ueEmitter.clsConstructorTable.tryGet(ueType.name).flatten())
            let prevClassPtr = someNil getClassByName ueType.name.removeFirstLetter()
            let newClassPtr = emitUStructInPackage(pkg, ueType, fnGen, prevClassPtr)
            prevClassPtr.flatmap((prev:UClassPtr) => newClassPtr.map(newCls=>(prev, newCls)))
                .run((pair:(UClassPtr, UClassPtr)) => hotReloadInfo.classesToReinstance.add(pair[0], pair[1]))
        else:
            discard

    for fnName, fnPtr in ueEmitter.fnTable:
        let funField = getFieldByName(ueEmitter.types, fnName)
        let prevFn = funField
                        .flatmap((ff:UEField)=>getClassByName(ff.className).findFunctionByNameWithPrefixes(ff.name))
                        .flatmap((fn:UFunctionPtr)=>tryUECast[UNimFunction](fn))
        # let prevFn = someNil getUTypeByName[UNimFunction](fnName)

        if prevFn.isSome() and funField.isSome():
            #TODO improve the check
            let prev = prevFn.get()
            let newHash = funField.get().sourceHash
            if not prev.sourceHash.equals(newHash):
                UE_Warn fmt"A function changed {fnName} updating the pointer"
                prev.setNativeFunc(cast[FNativeFuncPtr](fnPtr)) 
                prev.sourceHash = newHash
        #finds the function in unearl
        #get the fnField from the type
        #if the function exists in both places and it is different, then add it to the hotReload 
        #if it exists see if the source if t
    #check if a fn changed (check if the pointer points to the same direction). But how we can detect that, I mean, how we can detect a change if we cant look into the implementation.. this wont work.
    #ON HOLD
 
    hotReloadInfo.setShouldHotReload()
    hotReloadInfo


#By default ue types are emitted in the /Script/Nim package. But we can use another for the tests. 
proc emitUStructsForPackage*(pkgName:FString = "Nim") : FNimHotReloadPtr = 
    let pkg = findObject[UPackage](nil, convertToLongScriptPackageName("Nim"))
    emitUStructsForPackage(pkg)


proc emitUStruct(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUStruct[name](typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]
    # debugEcho repr result

proc emitUClass(typeDef:UEType) : NimNode =
    let typeDecl = genTypeDecl(typeDef)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfo(typeDefAsNode)

    result = nnkStmtList.newTree [typeDecl, typeEmitter]

proc emitUDelegate(typedef:UEType) : NimNode = 
    let typeDecl = genTypeDecl(typedef)
    
    let typeEmitter = genAst(name=ident typedef.name, typeDefAsNode=newLit typedef): #defers the execution
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
   


func fromUPropNodeToField(node : NimNode) : seq[UEField] = 
    let metas = node.childrenAsSeq()
                    .filter(n=>n.kind==nnkIdent and n.strVal().toLower() != "uprop")
                    .map(n=>n.strVal())
                    .fromStringAsMetaToFlag()

    func nodeToUEField (n: NimNode)  : UEField = #TODO see how to get the type implementation to discriminate between uProp and  uDelegate
        let typ = n[1].repr.strip()
        let name = n[0].repr
        
        if isMulticastDelegate typ:
            makeFieldAsUPropMulDel(name, typ, metas[0], metas[1])
        elif isDelegate typ:
            makeFieldAsUPropDel(name, typ, metas[0], metas[1])
        else:
            makeFieldAsUProp(name, typ, metas[0], metas[1])

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

func getUPropsAsFieldsForType(body:NimNode) : seq[UEField]  = 
    body.toSeq()
        .filter(n=>n.kind == nnkCall and n[0].strVal().toLower() in ["uprop", "uproperty"])
        .map(fromUPropNodeToField)
        .foldl(a & b, newSeq[UEField]())
        .reversed()
    
macro uStruct*(name:untyped, body : untyped) : untyped = 
    let structTypeName = name.strVal()#notice that it can also contains of meaning that it inherits from another struct
    let structMetas = getMetasForType(body)
    let ueFields = getUPropsAsFieldsForType(body)
    let structFlags = (STRUCT_NoFlags)
    let ueType = makeUEStruct(structTypeName, ueFields, "", structMetas, structFlags)

    emitUStruct(ueType) 

macro uClass*(name:untyped, body : untyped) : untyped = 
    if name.toSeq().len() < 3:
        error("uClass must explicitly specify the base class. (i.e UMyObject of UObject)", name)

    let parent = name[^1].strVal()
    let className = name[1].strVal()
    let classMetas = getMetasForType(body)
    let ueFields = getUPropsAsFieldsForType(body)
    let classFlags = (CLASS_Inherit | CLASS_ScriptInherit ) #| CLASS_CompiledFromBlueprint
    let ueType = makeUEClass(className, parent, classFlags, ueFields, classMetas)
    
    emitUClass(ueType)
  

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
    let fnImplName = ident funField.name&"_Impl"&"_"&funField.className #probably this needs to be injected so we can inspect it later
    let selfName = ident firstParam.name
    let fnImpl = genAst(className, genParmas, innerFunction, fnImplName, selfName, setOutParams):        
            let fnImplName {.inject.} = proc (context{.inject.}:UObjectPtr, stack{.inject.}:var FFrame,  returnResult {.inject.}: pointer):void {. cdecl .} =
                genParmas
                # var stackCopy {.inject.} = stack This would allow to create a super function to call the impl but not sure if it worth the trouble   
                stack.increaseStack()
                let selfName {.inject.} = ueCast[className](context) 
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


func makeUEFieldFromNimParamNode(n:NimNode) : UEField = 
    #make sure there is no var at this point, but CPF_Out
    var nimType = n[1].repr.strip()
    let paramName = n[0].strVal()
    var paramFlags = CPF_Parm
    if nimType.split(" ")[0] == "var":
        paramFlags = paramFlags | CPF_OutParm
        nimType = nimType.split(" ")[1]
        
    makeFieldAsUPropParam(paramName, nimType, paramFlags)


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
    # echo treeRepr header
    echo treeRepr fn.params
    let params = fn.params
                   .children
                   .toSeq()
                   .filter(n=>n.kind==nnkIdentDefs)
                   .map(makeUEFieldFromNimParamNode)
    let typeParam = params.head().get() #TODO errors
    let initializerParam = params.tail().head().get() #TODO errors

    let typeIdent = ident typeParam.uePropType.removeLastLettersIfPtr()
    let typeLiteral = newStrLitNode typeParam.uePropType.removeLastLettersIfPtr()
    let selfIdent = ident typeParam.name
    let initName = ident initializerParam.name
    let fnName = fn.name
    let fnBody = fn.body
    result = genAst(fnName, fnBody, selfIdent, typeIdent,typeLiteral, initName):
        proc fnName(initName {.inject.}: var FObjectInitializer) {.cdecl, inject.} = 
            var selfIdent{.inject.} = ueCast[typeIdent](initName.getObj())
            #calls the cpp constructor first
            selfIdent.getClass().getFirstCppClass().classConstructor(initializer)
            fnBody #user code
       
        #add constructor to constructor table
        addClassConstructor(typeLiteral, fnName)



    #body starts in StmtList
    #GenAst first with the call to cpp.
    #Also, when there is something else to emit in the UEType (should be available at this point, emit it.)

    #Last call is to add it to the list of available constructors
    # echo treeRepr result
    # echo repr result


# constructor(UTypeName):
#     echo "hola"

# proc test(myType:UTypeName, initializer:var FObjectInitializer) {.uConstructor.} =
#     echo "hola"
#     echo "whatever"

    



#falta genererar el call
#void vs no void
#return type
#param


# uFunctions:
#     (BlueprintPure, test : UObjectPtr, Category="whatever" BlueprintCallable)

#     proc functionThatReturns(self:UObjectPtr, anotherParam:int, anotherParamMore:bool) : FString  = 
#         return "Whatever"

#     proc functionThatReturns2(self:UObjectPtr) : string {.adasdasd.}  = 

#         discard
#         "Whatever2"
#     #     

#     proc functionThatNoReturns(self:UObjectPtr, anotherParam:int, anotherParamMore:bool)   =  
#         echo "hello mi ninio"
    

        
#     proc functionThatNoReturns2(self:UObjectPtr) : void =  discard


# dumpTree:
#      proc functionThatNoReturns(self:UObjectPtr, anotherParam:int, anotherParamMore:bool) {.ufunc.}   =  
#         echo "hello mi ninio"
    
    # inner(anotherParam, anotherParamMore)
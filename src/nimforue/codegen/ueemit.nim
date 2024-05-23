import std/[sugar, macros, algorithm, strutils, strformat, tables, times, genasts, sequtils, options, hashes]
import ../unreal/coreuobject/[uobject, package, uobjectglobals, nametypes]
import ../unreal/core/containers/[unrealstring, array, map]
import ../unreal/nimforue/[nimforuebindings]
import ../unreal/engine/enginetypes
import ../utils/[utils, ueutils]
import nuemacrocache
import ../codegen/[emitter,modelconstructor, models, uemeta, uebind,gencppclass, headerparser, uebindcore]




    # ueEmitter.emitters[ueField.typeName] = ueEmitter.emitters[ueField.typeName]#.replaceFirst((e:EmitterInfo)=>e.ueType.name == ueField.className, emitter)
# 

proc getEmmitedTypes*(emitter: UEEmitterPtr) : seq[UEType] = 
  emitter.emitters.values.toSeq.mapIt(it.ueType)




type
  FNimHotReloadChild* {.importcpp, header:"Guest.h".} = object of FNimHotReload

const getNumberMeta = CppFunction(name: "GetNumber", returnType: "int", params: @[])

const cppHotReloadChild = CppClassType(name: "FNimHotReloadChild", parent: "FNimHotReload", functions: @[], kind: cckStruct)

import std/typetraits

#	return new (EC_InternalUseOnlyConstructor, (UObject*)GetTransientPackage(), NAME_None, RF_NeedLoad | RF_ClassDefaultObject | RF_TagGarbageTemp) TClass(Helper);
proc newInstanceInAddr*[T](obj:UObjectPtr, fake : ptr T = nil) {.importcpp: "new((EInternal*)#)'*2".} 
# proc newInstanceInAddrWithInit*[T](obj:UObjectPtr, init: var FObjectInitializer, fake : ptr T = nil) {.importcpp: "new((EInternal*)#)'*2(const_cast<FObjectInitializer&>(#))".} 
proc newInstanceInAddrWithInit*[T](obj:UObjectPtr, init: var FObjectInitializer, fake : ptr T = nil) {.importcpp: "new((EInternal*)#)'*3(#)".} 

proc newInstanceWithVTableHelper*[T](helper : var FVTableHelper, fake : ptr T = nil) : UObjectPtr {.importcpp: "new (EC_InternalUseOnlyConstructor, (UObject*)GetTransientPackage(), FName(), RF_NeedLoad | RF_ClassDefaultObject | RF_TagGarbageTemp) '*2(#)".} 
proc newInstanceWithVTableHelperNoEditor*[T](helper : var FVTableHelper, fake : ptr T = nil) : UObjectPtr {.importcpp: "new (EC_InternalUseOnlyConstructor, (UObject*)GetTransientPackage(), FName(), RF_ClassDefaultObject | RF_TagGarbageTemp) '*2(#)".} 
  

proc vtableConstructorStatic*[T](helper : var FVTableHelper): UObjectPtr {.cdecl.} = 
  when WithEditor:
    newInstanceWithVTableHelper[T](helper)
  else:
    newInstanceWithVTableHelperNoEditor[T](helper) #TODO review this

proc defaultConstructorStatic*[T](initializer: var FObjectInitializer) {.cdecl.} =
  const typeName = typeof(T).name
  const ueType = getVMTypes(false).filter(t=>t.name == typeName).head() #Compile time only. This may be expensive. Make it faster (but measure first)
  when ueType.isSome() and ueType.get.hasObjInitCtor or T is UUserWidget: #The type needs to be in sync with umacros 
    newInstanceInAddrWithInit[T](initializer.getObj(), initializer)
  else:
    newInstanceInAddr[T](initializer.getObj())

  var fieldIterator = makeTFieldIterator[FProperty](initializer.getObj.getClass(), None)
  for it in fieldIterator: #Initializes all fields. So things like copy constructors get called. 
    let prop = it.get() 
    let address = prop.containerPtrToValuePtr(initializer.getObj)
    prop.initializeValue(address)

  when T is AActor:
    initComponents(initializer, ueCast[AActor](initializer.getObj()), initializer.getObj.getClass)

proc getVTable*(obj : UObjectPtr) : pointer {. importcpp: "*(void**)#".}
proc setVTable*(obj : UObjectPtr, newVTable:pointer) : void {. importcpp: "((*(void**)#)=(#))".}


proc updateVTable*(prevCls:UClassPtr, newVTable:pointer) : void =
  let oldVTable = getDefaultObject(prevCls).getVTable()
  var objIter = makeFRawObjectIterator()
  for it in objIter.items():
    let obj = it.get()
    if obj.getVTable() == oldVTable:
      setVTable(obj, newVTable)

proc updateVTableStatic*[T](prevCls:UClassPtr) : void =
  var tempObjectForVTable = constructFromVTable(vtableConstructorStatic[T])
  let newVTable = tempObjectForVTable.getVTable()
  updateVTable(prevCls, newVTable)


#rename these to register
proc getFnGetForUClass[T](ueType:UEType) : UPackagePtr->UFieldPtr = 
#    (pkg:UPackagePtr) => ueType.emitUClass(pkg, ueEmitter.fnTable, ueEmitter.clsConstructorTable.tryGet(ueType.name))
    proc toReturn (pgk:UPackagePtr) : UFieldPtr = #the UEType changes when functions are added
        var ueType = getGlobalEmitter().emitters[ueType.name].ueType#.emitters.first(x => x.ueType.name == ueType.name).map(x=>x.ueType).get()
        #SHouldnt user constructor call to the defaultConstructorStatic anyways?? 
        let clsConstructor = getGlobalEmitter().clsConstructorTable.tryGet(ueType.name).map(x=>x.fn).get(defaultConstructorStatic[T])
        let vtableConstructor = vtableConstructorStatic[T]
        ueType.emitUClass[:T](pgk, getGlobalEmitter().fnTable, clsConstructor, vtableConstructor)
    toReturn
    
proc addEmitterInfo*(ueType:UEType, fn : UPackagePtr->UFieldPtr, emitter: UEEmitterPtr = getGlobalEmitter()) : void =  
    emitter.emitters[ueType.name] = EmitterInfo(ueType:ueType, generator:fn)

proc addEmitterInfoForClass*[T](ueType:UEType) : void =  
    addEmitterInfo(ueType, getFnGetForUClass[T](ueType))
  
proc addStructOpsWrapper*(structName : string, fn : UNimScriptStructPtr->void) = 
    getGlobalEmitter().setStructOpsWrapperTable.add(structName, fn)

proc addClassConstructor*[T](clsName: string, classConstructor: UClassConstructor, hash:string) : void =  
    let ctorInfo = CtorInfo(fn:classConstructor, hash:hash, className: clsName,
        vtableConstructor: vtableConstructorStatic[T], updateVTableForType: updateVTableStatic[T])
    if not getGlobalEmitter().clsConstructorTable.contains(clsName):
        getGlobalEmitter().clsConstructorTable.add(clsName, ctorInfo)
    else:
        getGlobalEmitter().clsConstructorTable[clsName] = ctorInfo 

    #update type information in the constructor
    var emitter =  getGlobalEmitter().emitters[clsName]#.first(e=>e.ueType.name == clsName).get()
    emitter.ueType.ctorSourceHash = hash
    getGlobalEmitter().emitters[clsName] = emitter#ueEmitter.emitters.replaceFirst((e:EmitterInfo)=>e.ueType.name == clsName, emitter)

const ReinstSuffix = "_Reinst"

proc prepReinst(prev:UObjectPtr) =
    const objFlags = RF_NewerVersionExists or RF_Transactional
    prev.setFlags(objFlags)
    # UE_Warn &"Reinstancing {prev.getName()}"
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
    let forceReinst = emitter.ueType.hasUEMetadata(ReinstanceMetadataKey)
    var areEquals = prev.isSome() and prev.get().toUEType().get() == emitter.ueType
    if areEquals and not forceReinst: 
        none[ptr T]()
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

proc registerDeletedTypesToHotReload(hotReloadInfo:FNimHotReloadPtr, emitter:UEEmitterPtr, package :UPackagePtr)  =    
    #iterate all UNimClasses, if they arent not reintanced already (name) and they dont exists in the type emitted this round, they must be deleted
    let getEmitterByName = 
      (name:FString) => 
        (
          if name in emitter.emitters:#.map(e=>e.ueType).first((ueType:UEType)=>ueType.name==name)
            some emitter.emitters[name]
          else:
            none[EmitterInfo]()
        )
    registerDeleteUType(UClass, package):
        hotReloadInfo.deletedClasses.add(instance)
    registerDeleteUType(UNimScriptStruct, package):
        hotReloadInfo.deletedStructs.add(instance)
    registerDeleteUType(UDelegateFunction, package):
        hotReloadInfo.deletedDelegatesFunctions.add(instance)
    registerDeleteUType(UNimEnum, package):
        hotReloadInfo.deletedEnums.add(instance)

#32431 
proc emitUStructsForPackage*(ueEmitter : UEEmitterPtr, pkgName : string, emitEarlyLoadTypesOnly:bool) : FNimHotReloadPtr = 
    #/Script/PACKAGE_NAME For now {Nim, GameNim}
    let (pkg, wasAlreadyLoaded) = tryGetPackageByName(pkgName).getWithResult(createNimPackage(pkgName))
    UE_Log "Emit ustructs for Pacakge " & pkgName & "  " & $pkg.getName()
    # UE_Log "Emit ustructs for Length " & $ueEmitter.emitters.len
    var hotReloadInfo = newCpp[FNimHotReload]()
    let emitters = 
        if emitEarlyLoadTypesOnly: ueEmitter.emitters.values.toSeq.filterIt(it.ueType.shouldBeLoadedEarly()) 
        else: ueEmitter.emitters.values.toSeq

    for emitter in emitters:
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
                    let prevCls = prevClassPtr.get()
                    #We update the prev class pointer to hook the new vfuncs in the new objects
                    #we traverse all the object and update the vtable
                    let ctor = ueEmitter.clsConstructorTable.tryGet(emitter.ueType.name)
                    if ctor.isSome():
                        let ctorInfo = ctor.get()
                        prevCls.setClassConstructor(ctorInfo.fn)
                        prevCls.classVTableHelperCtorCaller = ctorInfo.vTableConstructor
                        if ctorInfo.updateVTableForType.isNotNil():
                            ctorInfo.updateVTableForType(prevCls)
                   
                    

            of uetEnum:
                let prevEnumPtr = someNil getUTypeByName[UNimEnum](emitter.ueType.name)
                let newEnumPtr = emitUStructInPackage(pkg, emitter, prevEnumPtr, not wasAlreadyLoaded)
                
                UE_Log &"?Emitting enum {prevEnumPtr} {newEnumPtr}"
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
        let prevFn = tryGetClassByName(funField.typeName.removeFirstLetter())
                        .flatmap((cls:UClassPtr)=>cls.findFunctionByNameWithPrefixes(funField.name))
                        .flatmap((fn:UFunctionPtr)=>tryUECast[UNimFunction](fn))

       
        if prevFn.isSome():
            # UE_Log "Updating function pointer " & funField.name
            let prev = prevFn.get()
            let newHash = funField.sourceHash
            # if not prev.sourceHash.equals(newHash):
            
            prev.setNativeFunc(cast[FNativeFuncPtr](fnPtr)) 
            prev.sourceHash = newHash
 
     
   
    registerDeletedTypesToHotReload(hotReloadInfo,ueEmitter, pkg)

    
    hotReloadInfo.setShouldHotReload()
    
    UE_Log $hotReloadInfo

    hotReloadInfo






proc emitUStruct*(typeDef:UEType) : NimNode =
    var ueType = typeDef #the generated type must be reversed to match declaration order because the props where picked in the reversed order
    ueType.fields = ueType.fields.reversed()
    let typeDecl = genTypeDecl(ueType)
    
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef, structName=newStrLitNode(typeDef.name)): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUStruct[name](typeDefAsNode, package))
                when name is not void:
                    addStructOpsWrapper(structName, (str:UNimScriptStructPtr) => setCppStructOpFor[name](str, nil))
    
    result = nnkStmtList.newTree [typeDecl, typeEmitter]
    # debugEcho repr resulti

proc emitUClass*(typeDef:UEType, lineInfo: Option[LineInfo] = none(LineInfo)): (NimNode, NimNode) =
    let typeDecl = genTypeDecl(typeDef, lineInfo = lineInfo)
    let typeEmitter = genAst(name=ident typeDef.name, typeDefAsNode=newLit typeDef): #defers the execution
                addEmitterInfoForClass[name](typeDefAsNode)
        
    result = (typeDecl, typeEmitter)

proc emitUDelegate(typedef:UEType) : NimNode = 
    let typeDecl = genTypeDecl(typedef)
    
    var typedef = typedef

    let typeEmitter = genAst(typeDefAsNode=newLit typedef): #defers the execution
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUDelegate(typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]

proc emitUEnum*(typedef:UEType) : NimNode = 
    let typeDecl = genTypeDecl(typedef)
    
    let typeEmitter = genAst(name=ident typedef.name, typeDefAsNode=newLit typedef): #defers the execution
                discard
                addEmitterInfo(typeDefAsNode, (package:UPackagePtr) => emitUEnum(typeDefAsNode, package))

    result = nnkStmtList.newTree [typeDecl, typeEmitter]



const CtorPrefix = "defaultConstructor"
const CtorNimInnerPrefix = "defaultConstructorNimInner" 


func constructorImpl(fnField:UEField, fnBody:NimNode) : NimNode = 
    
    let typeParam = fnField.signature.head().get() #TODO errors

    #prepare for gen ast
    let typeIdent = ident fnField.typeName
    let typeLiteral = newStrLitNode fnField.typeName
    let selfIdent = ident typeParam.name #TODO should we force to just use self?
    let initName = ident fnField.signature[1].name #there are always two params.a
    let fnName = ident fnField.name

    let assignments = getPropAssigments(fnField.typeName, typeParam.name)
    let nimInnerCtor = ident &"{CtorNimInnerPrefix}{fnField.typeName}" 
    let ctorImpl = genAst(fnName, fnBody, selfIdent, typeIdent, typeLiteral,assignments, initName, nimInnerCtor):
        
        template genSelf() = 
            var selfIdent{.inject.} = ueCast[typeIdent](initName.getObj())
            when not declared(self): #declares self and initializer so the default compiler compiles when using the assignments. A better approach would be to dont produce the default constructor if there is a constructor. But we cant know upfront as it is declared afterwards by definition
                var self{.inject used .} = selfIdent
        proc nimInnerCtor(initName {.inject.}: var FObjectInitializer) {.cdecl, inject.} =                     
            #it's wrapped so we can call the user constructor from the Nim child classes
            #Maybe in the future we could treat the Nim constructors as C++ constructors and forget about this special treatment (by the time this was designed Nim didnt have cpp constructors compatibility)
            genSelf()
            assignments
            fnBody

        proc fnName(initName {.inject.}: var FObjectInitializer) {.cdecl, inject.} = 
            defaultConstructorStatic[typeIdent](initName)
            genSelf()
            nimInnerCtor(initName)
            postConstructor(initName) #inits any missing comp that the user hasnt set
    
    let ctorRes = genAst(typeIdent, fnName, typeLiteral, hash=newStrLitNode($hash(repr(ctorImpl)))):
        #add constructor to constructor table
        addClassConstructor[typeIdent](typeLiteral, fnName, hash)

    result = nnkStmtList.newTree(ctorImpl, ctorRes)




macro uDelegate*(body:untyped) : untyped = 
    #uDelegate FMyDelegate(str: FString, number: FString, another:int)
    let name = body[0].strVal()
    let paramsAsFields = body.toSeq()
                             .filter(n=>n.kind==nnkExprColonExpr)
                             .map(n=>makeFieldAsUPropParam(n[0].strVal(), n[1].repr.strip(), name))
    let ueType = makeUEMulDelegate(name, paramsAsFields)
    addVMType ueType
    emitUDelegate(ueType)    

func isBlueprintEvent(fnField:UEField) : bool = FUNC_BlueprintEvent in fnField.fnFlags

func genUFuncSuper(fnField: UEField): NimNode =
  var fnField = fnField
  fnField.name = "super"
  let typeDefFn = makeUEClass(fnField.typeName, parent="", CLASS_None, @[fnField])
  result = genFunc(typeDefFn, fnField).impl 

func genNativeFunction(firstParam:UEField, funField : UEField, body:NimNode) : NimNode =    
    let ueType = UEType(name:funField.typeName, kind:uetClass) #Notice it only looks for the name and the kind (delegates)
    let className = ident ueType.name

    let super = genUFuncSuper(funField)
    proc genParamArgFor(param:UEField) : NimNode = 
        let paraName = ident param.name
        let paraNameAddr = ident param.name & "Addr"
        
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
        
        genAst(paraName, paraNameAddr, paramType, genOutParam, isOut=newLit param.isOutParam): 
            stack.mostRecentPropertyAddress = nil
            #does the same thing as StepCompiledIn but you dont need to know the type of the Fproperty upfront (which we dont)
            var paraName {.inject.} : paramType #Define the param
            var paraNameAddr = cast[pointer](paraName.addr) #Cast the Param with   
            when isOut:                    
                paraNameAddr = stack.outParms.propAddr
                paraName = cast[ptr paramType](paraNameAddr)[]
            if not stack.code.isNil():
                stack.step(stack.obj, paraNameAddr)                          # stack.outParms = stack.outParms.nextOutParm
            else:                
                var prop = cast[FPropertyPtr](stack.propertyChainForCompiledIn)
                stack.propertyChainForCompiledIn = stack.propertyChainForCompiledIn.next                
                stepExplicitProperty(stack, paraNameAddr, prop)
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
    let innerName = ident funField.name #& "Inner"
    let innerCall = 
        if funField.doesReturn():
            genAst(returnType, innerName):
                cast[ptr returnType](returnResult)[] = innerName()
        else: nnkCall.newTree(innerName)
        
    let innerFunction = 
        genAst(body, returnType, innerName, innerCall): 
            proc innerName() : returnType =                 
                body
            innerCall
    # let innerCall() = nnkCall.newTree(ident "inner", newEmptyNode())
    let signatureAsStr = funField.signature.mapIt(it.uePropType).join("_")
    let fnImplName = ident &"impl{funField.name}{funField.typeName}{signatureAsStr}" #probably this needs to be injected so we can inspect it later
    let selfName = ident firstParam.name
    let fnImpl = genAst(className, genParmas, super, innerFunction, fnImplName, selfName, setOutParams):        
            let fnImplName {.inject.} = proc (context{.inject.}:UObjectPtr, stack{.inject.}:var FFrame,  returnResult {.inject.}: pointer):void {. cdecl .} =
                genParmas
                # var stackCopy {.inject.} = stack This would allow to create a super function to call the impl but not sure if it worth the trouble   
                stack.increaseStack()
                let selfName {.inject, used.} = ueCast[className](context) 
                super
                innerFunction
                setOutParams

    var funField = funField
    funField.sourceHash = $hash(repr fnImpl)
    safe:
        addVmUFunc(funField)
    if funField.isBlueprintEvent(): #blueprint events doesnt have a body
        result = genAst(fnImpl, funField = newLit funField): 
                    addEmitterInfo(funField, none[UFunctionNativeSignature]())
    else:
        result = genAst(fnImplName,fnImpl, funField = newLit funField): 
                    fnImpl
                    addEmitterInfo(funField, some fnImplName)
       



#first is the param specify on ufunctions when specified one. Otherwise it will use the first
#parameter of the function
#Returns a tuple with the forward declaration and the actual function 
#Notice the impl contains the actual native implementation of the
proc ufuncImpl*(fn:NimNode, classParam:Option[UEField], typeName : string, functionsMetadata : seq[UEMetadata] = @[]) : tuple[fw:NimNode, impl:NimNode, fnField: UEField] = 
  let (fnField, firstParam) = uFuncFieldFromNimNode(fn, classParam, typeName, functionsMetadata)
  let className = fnField.typeName
  let (fnReprfwd, fnReprImpl) = genFunc(UEType(name:className, kind:uetClass), fnField)
  let fnImplNode = genNativeFunction(firstParam, fnField, fn.body)

  result =  (fnReprfwd, nnkStmtList.newTree(fnReprImpl, fnImplNode), fnField)




# macro ufunc*(fn:untyped) : untyped = ufuncImpl(fn, none[UEField](), "") #deprecated TODO revisit

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
                    .map(n=>makeFieldAsUPropParam(n[0].strVal(), n[1].repr.strip().addPtrToUObjectIfNotPresentAlready(), n[1].repr.strip().removeLastLettersIfPtr(), CPF_None)) #notice no generic/var allowed. Only UObjects
                    
    let allFuncs = body.children.toSeq()
        .filter(n=>n.kind==nnkProcDef)
        .map(procBody=>ufuncImpl(procBody, firstParam, firstParam.map(x=>x.typeName).get(), metas).impl) #TODO add forward declar to this one too?
    
    let clsName = firstParam.get.uePropType.removeLastLettersIfPtr()
    let overrides = getCppOverrides(body, clsName)  

    result = nnkStmtList.newTree allFuncs & overrides.mapIt(it[1])
    # echo repr result

macro uConstructor*(fn:untyped) : untyped = 
        #infers neccesary data as UEFields for ergonomics
    let params = fn.params
                   .children
                   .toSeq()
                   .filter(n=>n.kind==nnkIdentDefs)
                   .mapIt(makeUEFieldFromNimParamNode("Constructor.Need to know the type?",it))
                   .flatten()

    let firstParam = params.head().get() #TODO errors
    let initializerParam = params.tail().head().get() #TODO errors

    let fnField = makeFieldAsUFun(fn.name.strVal(), params, firstParam.uePropType.removeLastLettersIfPtr())
    constructorImpl(fnField, fn.body)

func genConstructorForClass*(uClassBody:NimNode, uet: UEType, constructorBody:NimNode, initializerName:string="") : NimNode = 
  var initializerName = if initializerName == "" : "initializer" else : initializerName
  let className = uet.name
  let typeParam = makeFieldAsUPropParam("self", className, className)
  let initParam = makeFieldAsUPropParam(initializerName, "FObjectInitializer", className)
  let fnField = makeFieldAsUFun(CtorPrefix&className, @[typeParam, initParam], className)
  let ctorParentCall = 
    genAst(
      parentCall = ident(CtorNimInnerPrefix & uet.parent),
    ):
        when compiles(parentCall(initializer)):
            parentCall(initializer)
  if constructorBody.kind != nnkEmpty:
    constructorBody.add ctorParentCall
  constructorImpl(fnField, constructorBody)  

func genDeclaredConstructor*(body:NimNode, uet: UEType) : Option[NimNode] = 

  let constructorBlock = 
    body.toSeq()
    .filterIt(it.kind == nnkProcDef and it.name.strVal().toLower() in ["constructor", uet.name])
    .head()
 
  if constructorBlock.isNone():
    return none[NimNode]()
  
  let fn = constructorBlock.get()
  let params = fn.params
  assert params.len == 2, "Constructor must have only one parameter" #Notice first param is Empty
  let param = params[1] #Check for FObjectInitializer
  constructorBlock
    .map(consBody => genConstructorForClass(body, uet, consBody.body(), param[0].strVal()))
    
func genDefaults*(body:NimNode): Option[NimNode] = 
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


func addSelfToProc*(procDef:NimNode, className:string) : NimNode = 
    if procDef.pragma.toSeq.any(it=>it.kind == nnkIdent and it.strVal() == "constructor" or 
        it.kind == nnkExprColonExpr and it[0].strVal() == "constructor"):
        let assignSelf = 
            genAst(res= ident "result"):  
                when (NimMajor, NimMinor) <= (2, 0):           
                    let self {.inject.} = this
                else:
                    let self {.inject.} = res.addr

        procDef.body.insert(0, assignSelf)
        return procDef
    procDef.params.insert(1, nnkIdentDefs.newTree(ident "self", ident className & "Ptr", newEmptyNode()))
    procDef

func generateSuper(procDef: NimNode, parentName: string) : NimNode = 
    let name = procDef.name.strVal().capitalizeAscii()
    let parent = procDef.params[1]
    let content = newLit &"{parentName}::{name}(@)"
    result = 
      genAst(content):
        proc super() {.importcpp: content, nodecl.}  
    result.params = nnkFormalParams.newTree procDef.params.filterIt(it != parent)    

func processVirtual*(procDef: NimNode, parentName: string = "", overrideName: string = "") : NimNode = 
#[
    if the proc has virtual, it will fill it with the proc info:
        - Capitilize the proc name
        - Add const if the proc is const, same with params
        - Add override if the proc is marked with override
    Get rid of the pragmas. 
    If the proc has any content in virtual, it will ignore the pragma and use the content instead 
]#   
    let isPlainVirtual = (it:NimNode) => it.kind == nnkIdent and it.strVal() == "virtual"
    let isPlainMember = (it:NimNode) => it.kind == nnkIdent and it.strVal() == "member"
    let isOverride = (it:NimNode) => it.kind == nnkIdent and it.strVal() == "override"
    let isConstCpp = (it:NimNode) => it.kind == nnkIdent and it.strVal() in ["constcpp", "constref"]
    let isByRef = (it:NimNode) => it.kind == nnkIdent and it.strVal.toLower in ["byref", "constref"]
    let isParamConstCpp = (it:NimNode) => it.kind == nnkIdentDefs and it[0].kind == nnkPragmaExpr and 
        it[0][^1].children.toSeq.any(isConstCpp)
    let constParamContent = (it:NimNode) => (if isParamConstCpp(it): "const " else: "")
    
    let isParamRef = (it:NimNode) => it.kind == nnkIdentDefs and it[0].kind == nnkPragmaExpr and 
        it[0][^1].children.toSeq.any(isByRef)
    let byRefParamContent = (it:NimNode) => (if isParamRef(it): "& " else: "")
    
    let hasVirtual = procDef.pragma.toSeq.any(x => isPlainVirtual(x) or isPlainMember(x)) #with content it will be differnt. But we are ignoring it anyways
    result = procDef
    if not hasVirtual:
        return procDef
    let hasMember = procDef.pragma.toSeq.any(isPlainMember)
    let pragmaIdent = ident (if hasMember: "member" else: "virtual")
    let hasOverride = procDef.pragma.toSeq.any(it=>it.kind == nnkIdent and it.strVal() == "override")
    let hasFnConstCpp = procDef.pragma.toSeq.any(isConstCpp)
    let name = 
        if overrideName == "":
            procDef.name.strVal().capitalizeAscii()        
        else: overrideName
    let params = procDef
        .params
        .filterIt(it.kind == nnkIdentDefs)
        .skip(1)
        .mapi((n, idx) => "$1 '$3 $2 #$3" % [constParamContent(n), byRefParamContent(n), $(idx + 2)])
        .join(", ")

    let override = if hasOverride: "override" else: ""
    let fnConstCpp = if hasFnConstCpp: "const" else: ""
    let virtualContent: string = &"{name}({params}) {fnConstCpp} {override}"
    let keptPragmas = procDef.pragma.toSeq
        .filterIt(not @[isPlainVirtual(it), isOverride(it), isConstCpp(it), isPlainMember(it)].foldl(a or b, false))
    let newVirtual = nnkExprColonExpr.newTree(pragmaIdent, newLit virtualContent)
    let pragmas = nnkPragma.newTree(keptPragmas & newVirtual) 
    if params.len > 0:
      var params = newSeq[NimNode]()
      for param in procDef.params[2..^1]:
        var param = param
        if isParamConstCpp(param):
          param[0][^1] = nnkPragma.newTree param[0][^1].children.toSeq.filterIt(not isConstCpp(it) and not isByRef(it))   
        params.add param
      result[3] = nnkFormalParams.newTree(procDef.params[0..1] & params)

    result.pragma = pragmas   
    if parentName != "":
        result.body.insert 0, generateSuper(procDef, parentName)
    if hasFnConstCpp:
        let selfNoConst =
          genAst():  
            let self {.inject.} = removeConst(self)
        result.body.insert 0, selfNoConst

#Manually added NimForUEBinding. Here to avoid cycle
proc getUETypeFor[T](hasObjInitCtor: static bool = false): UEType =
    const name = typeof(T).name
    const parent = typeof(T).parent()
    const uet = (UEType(name: name,
        fields: seq[UEField](@[]), metadata: seq[UEMetadata](@[]), isInPCH: false,
        moduleRelativePath: "", size: 0'i32, parentSize: 0'i32, alignment: 0'i32,
        kind: UETypeKind(0), isInCommon: false, parent: parent,
        clsFlags: 1252198110'u32, ctorSourceHash: "", interfaces: seq[string](@[]),
        fnOverrides: seq[CppFunction](@[]), isParentInPCH: true,
        forwardDeclareOnly: false, hasObjInitCtor: hasObjInitCtor))
    uet
const manualTypes = @[
    getUETypeFor[UNimFunction](),
    getUETypeFor[UNimEnum](hasObjInitCtor = true),
]
static:
  for uet in manualTypes:
    addVMType uet

proc addManualUClasses() = 
    #TODO find a way to do this automatically without involving a macro.
    # addEmitterInfoForClass[UNimFunction]( getUETypeFor[UNimFunction]())
    addEmitterInfoForClass[UNimEnum](getUETypeFor[UNimEnum](true))

addManualUClasses()
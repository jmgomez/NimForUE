import std/[json, sugar, macros, genasts, options, sequtils, strutils, strformat, bitops]
when defined nuevm:
  import exposed  
  import vmtypes
  import codegen/enumops
else:
  import std/[os]
  import ../../buildscripts/nimforueconfig  
  import ../unreal/coreuobject/uobjectflags
 
import runtimefield
import ../utils/[utils, ueutils]
import ../codegen/[models, modelconstructor, uebindcore, nuemacrocache]

when not defined(log):
  proc log(str: string) = discard #echo str



type CodegenTarget* = enum
  ctImport
  ctExport
  ctVM


#TODO change fn with UEFunc so I can pass it directly from the bindings. 
proc ueBindImpl*(fn: UEField, selfParam: Option[UEField], kind: UECallKind) : NimNode = 
  assert fn.kind == uefFunction
  let isStatic =  selfParam.isNone() or "Static" in fn.metadata
  let clsName = fn.typeName   
  
  let selfAssign = 
    if isStatic: 
      newEmptyNode()
    else: 
      genAst(firstParam = ident selfParam.get.name):
        call.self = cast[int](firstParam)
  
  let returnType = fn.signature.first(isReturnParam).map(x=>getTypeNodeFromUProp(x, false)).get(ident "void")

  let uFunc = UEFunc(name: fn.name, className:clsName)
  let paramsAsExpr = 
      fn.signature      
        .filterIt(not it.isReturnParam())
        .mapIt(it.name.firstToLow.ueNameToNimName())
        .mapIt(nnkExprColonExpr.newTree(ident it, ident it)) #(arg: arg, arg2: arg2, etc.)

  let defaultValue =
    genAst(returnType):
      when returnType is ptr: 0
      else: default returnType

  let rtFieldVal = 
    case kind:
      of uecFunc:
        nnkTupleConstr.newTree(paramsAsExpr)      
      of uecGetProp:
        nnkTupleConstr.newTree(nnkExprColonExpr.newTree(
          ident fn.name.firstToLow.ueNameToNimName(),
          defaultValue
          # nnkCall.newTree(ident "default", returnType)
        ))
      of uecSetProp: 
        nnkTupleConstr.newTree(nnkExprColonExpr.newTree(
          ident fn.name.firstToLow.ueNameToNimName(),
          ident fn.signature[0].name #val
        ))
  let call = 
   case kind:
    of uecFunc:
      if isStatic:
        UECall(kind: uecFunc,fn: uFunc)
      else:
        UECall(kind: uecFunc, fn: uFunc)
    else:    
      UECall(kind: kind, clsName: clsName)    
  
  let fnName = 
    case kind:
    of uecFunc, uecgetProp: identPublic fn.name.firstToLow()
    else: 
      nnkPostfix.newTree(
        ident "*",
        nnkAccQuoted.newTree(
          ident fn.name.firstToLow(),
          ident "="
        )
      )

  let returnBlock = 
    if fn.doesReturn():
      # if fn.getReturnProp.get.name.endsWith("Ptr"):
        genAst(returnType):
          # return castIntToPtr returnType(returnVal.get.runtimeFieldTo(int))
          when returnType is ptr:
            if returnVal.get.intVal == 0: return nil
            else: return cast[returnType](returnVal.get.intVal)
          else:
            return returnVal.get.runtimeFieldTo(returnType)
      # else:
      #   genAst(returnType):
      #     return returnVal.get.runtimeFieldTo(returnType)
    else: newEmptyNode()
  
  func setOutParam(outParam: UEField): NimNode = 
    let name = ident outParam.name.firstToLow()
    let nameLit = newLit outParam.name.firstToLow()
    result = 
      genAst(name, nameLit):
        name = returnVal.outParams[nameLit].runtimeFieldTo(typeof(name))

  let setOutParamsBlock = 
    nnkStmtList.newTree(fn.signature.filter(isOutParam).map(setOutParam))
  
  result = 
    genAst(fnName, selfAssign, returnBlock, setOutParamsBlock, callData=newLit call, rtFieldVal):
      proc fnName() =         
        var call {.inject.} = callData
        call.value = rtFieldVal.toRuntimeField()
        selfAssign
        let returnVal {.used, inject.} = uCall(call)
        setOutParamsBlock
        returnBlock

  result.params = genFormalParamsInFunctionSignature(fn.getFakeUETypeFromFunc(), fn)
  

proc prepareUEFieldFuncFrom*(fn:NimNode, inClsName:string =""): (UEField, UEField) = 
  let clsName = 
    if fn.params.len > 1 and inClsName == "":
      fn.params.filterIt(it.kind == nnkIdentDefs)[0][1].strVal().removeLastLettersIfPtr()
    else: inClsName
      
  let clsFieldMb = 
    if inClsName != "": some makeFieldAsUProp("self", clsName & "Ptr", clsName) 
    else: none[UEField]()
  
  var (ufunc, selfParam) = ufuncFieldFromNimNode(fn, clsFieldMb, clsName)  
  if clsName != "":(ufunc, selfParam)
  else: (ufunc, UEField())

macro uegetter*(getter:untyped): untyped = 
  var (ufunc, selfParam) = prepareUEFieldFuncFrom(getter) 
  ufunc.signature[0].isReturn = true
  result = ueBindImpl(ufunc,some selfParam, uecGetProp) 
  # log "================================================================"
  # log &"\n{repr result}"
  # log &"\n{treeRepr result}"


macro uesetter*(setter:untyped): untyped = 
  var (ufunc, selfParam) = prepareUEFieldFuncFrom(setter) 
  # log "usetter"
  # log $ufunc
  result = ueBindImpl(ufunc, some selfParam, uecSetProp) 
  # log &"\n{repr result}"
  # log &"\n{treeRepr result}"

macro uebind*(fn:untyped) : untyped = 
  #Remove the first arg, which is the self param
  let (ufunc, selfParam) = prepareUEFieldFuncFrom(fn)
  result = ueBindImpl(ufunc, some selfParam, uecFunc)
  # log "================================================================"
  # log repr result
  
macro uebindStatic*(clsName : static string = "", fn:untyped) : untyped = 
  var (ufunc, _) = prepareUEFieldFuncFrom(fn, clsName)
  ufunc.metadata.add makeUEMetadata "Static"
  ufunc.fnFlags = ufunc.fnFlags or FUNC_Static
  result = ueBindImpl(ufunc, none(UEField), uecFunc)



func isAllowedField*(field:UEField) : bool = 
  safe:
    const skipTypes = ["TScriptInterface", "TMap", "TSet"]
    result = 
      not skipTypes.mapIt(field.uePropType.contains(it)).foldl(a or b, false) and 
      field.name.tolower() notin (NimReservedKeywords & NimReservedToCapitalize & @["result"]) #TODO generate appropiate code for both
    # if not result:
    #   debugEcho &"[VM Bindings] Skipping field in {field.typeName} {field.name}: {field.uePropType} "


func genUEnumTypeDefBinding*(ueType: UEType, target: CodegenTarget): NimNode =
  var pragmas = 
    case target:
    of ctImport, ctExport: 
      nnkPragma.newTree(nnkExprColonExpr.newTree(ident "size", nnkCall.newTree(ident "sizeof", ident "uint8")), ident "pure")
    of ctVM: newEmptyNode()
  
  if target in [ctImport, ctExport] and ueType.isInPCH:
    pragmas.add nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode(ueType.cppEnumName))
    
  let enumTy = ueType.fields
    .map(f => ident f.name)
    .foldl(a.add b, nnkEnumTy.newTree)
  enumTy.insert(0, newEmptyNode()) #required empty node in enums
  nnkTypeDef.newTree(
    nnkPragmaExpr.newTree(
      nnkPostFix.newTree(ident "*", ident ueType.name),
      pragmas
    ),
    newEmptyNode(),
    enumTy
  )


  
func genUStructCodegenTypeDefBinding*(ueType: UEType, target: CodegenTarget): NimNode =
  #TODO move export here and separate it enterely from the dsl
  let pragmas = 
    case target:
    of ctImport:
      (if ueType.isInPCH:     
        nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(
            ident "inject",
            ident "bycopy",
            nnkPragma.newTree(ident "importcpp", ident "inheritable", ident "pure")
          )
        ])
      else:
        nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(
          ident "inject",
          ident "inheritable",
          ident "pure",
          nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h")),
          nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")), 
          
        )
        ])
      )
    of ctExport: newEmptyNode() #TODO
    of ctVM:
        nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(       
          ident "inheritable",          
        )
        ])
      
  var recList = ueType.fields
    .filter(isAllowedField)
    .map(prop => nnkIdentDefs.newTree(
        getFieldIdentWithPCH(ueType, prop, target == ctImport),
        prop.getTypeNodeFromUProp(isVarContext=false),
        newEmptyNode()
      )
    )
    .foldl(a.add b, nnkRecList.newTree)
  let superStructNode = 
    if ueType.superStruct != "":
      nnkOfInherit.newTree(ident ueType.superStruct)
    else:
      newEmptyNode()
  result = nnkTypeDef.newTree(
    pragmas,
    newEmptyNode(),
    nnkObjectTy.newTree(
      newEmptyNode(), superStructNode, recList
    )
  )

func genDelegateVMTypeDefBinding*(ueType: UEType, target: CodegenTarget): NimNode =
  let pragmas = nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
        nnkPragma.newTree(       
          ident "inheritable",          
        )
        ])
  nnkTypeDef.newTree(
        pragmas,
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          nnkOfInherit.newTree(ident "FMulticastScriptDelegate"),
          newEmptyNode()
        )
      )

func genVMClassTypeDef*(typeDef: UEType): seq[NimNode] = 
  assert typeDef.kind == uetClass
  #Does not generate the type section. Just the typeDef
  @[
    # type Type* = object of Parent
    nnkTypeDef.newTree(
      nnkPostFix.newTree(ident "*", ident typeDef.name),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        nnkOfInherit.newTree(ident typeDef.parent),
        newEmptyNode()
      )
    ),
    # ptr type TypePtr* = ptr Type
    nnkTypeDef.newTree(
      nnkPostFix.newTree(ident "*", ident typeDef.name & "Ptr"),
      newEmptyNode(),
      nnkPtrTy.newTree(ident typeDef.name)
    )
  ]

proc genUCalls*(typeDef : UEType) : NimNode = 
  #returns a list with all functions and props for a given type
  assert typeDef.kind == uetClass
  result = nnkStmtList.newTree()
  for field in typeDef.fields:
    let firstParam = some makeFieldAsUProp("self", typeDef.name & "Ptr", typeDef.name)
    case field.kind:
      of uefProp:
        if not isAllowedField(field): continue
        let propName = field.name.firstToLow.ueNameToNimName()                
        let getterFn = makeFieldAsUFun(propName, @[makeFieldAsUPropReturnParam("toReturn", field.uePropType, typeDef.name)], typeDef.name)
        let setterFn = makeFieldAsUFun(field.name.firstToLow(), @[makeFieldAsUPropParam("value", field.uePropType, typeDef.name)], typeDef.name) 
        result.add(ueBindImpl(getterFn, firstParam, uecGetProp))
        result.add(ueBindImpl(setterFn, firstParam, uecSetProp))
      of uefFunction:
        let isAllowed = field.signature.map(isAllowedField).foldl(a and b, true)
        if not isAllowed: continue
        if field.isStatic:
          result.add(ueBindImpl(field, none(UEField), uecFunc))
        else:
          result.add(ueBindImpl(field, firstParam, uecFunc))
      else: continue

proc ueBorrowImpl*(clsName : string, fn: NimNode) : NimNode = 
  #TODO: integrate UEField approach 
  let argsWithFirstType =
    fn.params
    .filterIt(it.kind == nnkIdentDefs)
  
  let isStatic = clsName!=""

  let args = 
    if isStatic: argsWithFirstType
    else: argsWithFirstType[1..^1] #Remove the first arg, which is the self param
 
  let clsNameLit = 
    (if isStatic: clsName
    else: argsWithFirstType[0][1].strVal().removeLastLettersIfPtr()).removeFirstLetter()
  
  let classTypePtr = if isStatic: ident clsName else: ident (argsWithFirstType[0][1].strVal())
  let classType = ident classTypePtr.strVal().removeLastLettersIfPtr() 

  let returnTypeLit = if fn.params[0].kind == nnkEmpty: "void" else: fn.params[0].repr()
  let returnType = fn.params[0]

  let fnBody = fn.body
  let fnName = fn.name
  let fnNameLit = fn.name.strVal()
  let fnVmName = ident fnNameLit & "VmImpl"
  let fnVmNameLit = fnNameLit & "VmImpl"

  func injectedArg(arg:NimNode, idx:int) : NimNode =        
    # raise newException(Exception, &"Node is {arg.kind} with tree:\n {treeRepr arg}")    
    let (argName, argNameLit, argType) = 
      case arg[0].kind:
      of nnkIdent: (arg[0], arg[0].strVal, arg[1])
      of nnkPragmaExpr: (arg[0][0], arg[0][0].strVal, arg[1])
      else: raise newException(Exception, &"Node is {arg.kind} with tree:\n {treeRepr arg}")    
    genAst(argName, argNameLit, argType):
      let argName {.inject.} = callInfo.value[argNameLit].runtimeFieldTo(argType)
  
  let injectedArgs = nnkStmtList.newTree(args.mapi(injectedArg))

  let returnBlock = 
    if returnTypeLit == "void":
      genAst(fnBody):
        fnBody
        RuntimeField()
    else:
      genAst(fnBody, returnType):
        let returnVal {.inject.} : returnType = fnBody
        returnVal.toRuntimeField()        

  let vmFn = 
    genAst(funName=fnName, fnNameLit, fnVmName, fnVmNameLit, returnBlock, classType, clsNameLit, returnType, returnTypeLit, injectedArgs, isStatic):
      setupBorrow(UEBorrowInfo(fnName:fnNameLit, className:clsNameLit))
      proc fnVmName*(callInfo{.inject.}:UECall) : RuntimeField = 
        injectedArgs 
        when not isStatic:
          let self {.inject.} = castIntToPtr[classType](callInfo.self)
        returnBlock

  # raise newException(Exception, &"tree:\n {repr vmFn}")    
  result = nnkStmtList.newTree vmFn

macro ueborrow*(fn:untyped) : untyped = ueBorrowImpl("", fn)

macro ueborrowStatic*(clsName : static string, fn:untyped) : untyped = ueBorrowImpl(clsName, fn)

func ueTypeToVMNode(uet: UEType) : seq[NimNode] = 
  case uet.kind:
  of uetClass: genVMClassTypeDef(uet)
  of uetStruct: @[genUStructCodegenTypeDefBinding(uet, ctVM)]
  of uetEnum: @[genUEnumTypeDefBinding(uet, ctVM)]
  of uetDelegate: @[genDelegateVMTypeDefBinding(uet, ctVM)]
  else: @[newEmptyNode()]

#equivalent to the same function in uemit. but for the vm
#calls for the bindings ubindimpl and ueborrowimpl for the implementation
proc ufuncImpl*(fn:NimNode, classParam:Option[UEField], typeName : string, functionsMetadata : seq[UEMetadata] = @[]) : tuple[fw:NimNode, impl:NimNode, fn: UEField] = 
  let (fnField, selfParam) = uFuncFieldFromNimNode(fn, classParam, typeName, functionsMetadata)
  var fn = fn
  fn.params = genFormalParamsInFunctionSignature(fnField.getFakeUETypeFromFunc(), fnField, "self")
  let fnReprImpl = ueBindImpl(fnField, some selfParam, uecFunc)
  #TODO forwardDecalre
  let fnReprfwd = newEmptyNode()
  #this is beyond bad but "" means not static in ueBorrow. TODO REFACTOR!
  let clsName = if fnField.isStatic: typeName else: ""
  let fnImplNode = ueBorrowImpl(clsName, fn)
  result =  (fnReprfwd, nnkStmtList.newTree(fnReprImpl, fnImplNode), fnField)
  

proc addVMConstructor*(uet: var UEType, assigments: NimNode): NimNode = 
  let constructorName = makeVMDefaultConstructorName(uet.name.removeFirstLetter())
  let fnField = makeFieldAsUFun(constructorName, @[], uet.name, metadata= @[makeUEMetadata("Static")])
  uet.fields.add fnField
  let fnName = identPublic constructorName
  let selfType = ident uet.name & "Ptr"
  let fn = genAst(fnName, selfType, assigments):
    proc fnName(self {.inject.}: selfType) = 
      let cdo {.inject.} = cast[selfType](self.getClass.getDefaultObject())
      # vmmacros.log "constructor executed"
      assigments
  let fnReprImpl = ueBindImpl(fnField, none(UEField), uecFunc)
  let borrow = ueBorrowImpl(uet.name, fn)
  result = borrow



macro emitVMTypes*() = 
  let ueTypes = getVMTypes()  
  var typeSection = nnkTypeSection.newTree()
  typeSection.add(
    ueTypes
    .map(ueTypeToVMNode)
    .foldl(a & b, newSeq[NimNode]()))

  let content = 
    repr nnkStmtList.newTree(typeSection & 
      ueTypes
      .filterIt(it.kind == uetClass)
      .map(genUCalls)
      .foldl(a & b, newSeq[NimNode]()))

  const libname {.strdefine.} = ""
  var lib = libname
  if libname == "vm": #to prevent users from include "vm" and drag in the wrong file
    lib = "vmfunctionlibrary"
  when defined(nuevm):
    const BindingsVMDir = "" 
    proc `/`(a: string, b: string): string = ""

  let path = BindingsVMDir / lib & ".nim"
  writeFile(path, content)



macro ddumpTree*(x: untyped) = 
  log treeRepr x
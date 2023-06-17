import std/[json, sugar, macros, genasts, options, sequtils, strutils, strformat]
import exposed 
import runtimefield
import ../utils/[utils, ueutils]
import ../codegen/[models, modelconstructor, uebindcore]

#TODO change fn with UEFunc so I can pass it directly from the bindings. 
proc ueBindImpl*(fn: UEField, selfParam: Option[UEField], kind: UECallKind) : NimNode = 
  assert fn.kind == uefFunction
  let isStatic = selfParam.isNone
  let clsName = fn.typeName   
  let selfAssign = 
    if isStatic: newEmptyNode() 
    else: 
      genAst(firstParam = ident selfParam.get.name):
        call.self = cast[int](firstParam)
  
  let returnParam = fn.signature.first(isReturnParam).map(x=>x.uePropType).get("void")

  let returnType {.inject.} = ident returnParam
  let returnTypeLit {.inject.} = newLit returnParam

  let uFunc = UEFunc(name: fn.name, className:clsName)
  let paramsAsExpr = 
      fn.signature      
        .mapIt(it.name)
        .mapIt(nnkExprColonExpr.newTree(ident it, ident it)) #(arg: arg, arg2: arg2, etc.)
                 
  let rtFieldVal = 
    case kind:
      of uecFunc:
        nnkTupleConstr.newTree(paramsAsExpr)
      else:
        #TODO 
        newEmptyNode()
      # of uecGetProp:
      #   nnkTupleConstr.newTree(nnkExprColonExpr.newTree(
      #     fn.name,
      #     nnkCall.newTree(ident "default", returnType)
      #   ))
      # of uecSetProp:
      #   nnkTupleConstr.newTree(nnkExprColonExpr.newTree(
      #     fn.name,
      #     argsWithFirstType[1][0] #val
      #   ))
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
    of uecFunc, uecgetProp: ident fn.name
    else: 
      genAst(fnName=ident fn.name):
        `fnName=`
        

  result = 
    genAst(fnName, selfAssign, returnType, returnTypeLit, callData=newLit call, rtFieldVal):
      proc fnName() =         
        var call {.inject.} = callData
        call.value = rtFieldVal.toRuntimeField()
        selfAssign
        let returnVal {.used, inject.} = uCall(call) #check return val
        when returnTypeLit != "void": #TODO simplify this. For instance, doesReturn macro above
          when returnTypeLit.endsWith("Ptr"):
            return castIntToPtr returnType(returnVal.get.runtimeFieldTo(int))
          else:
            return returnVal.get.runtimeFieldTo(returnType)
  result.params = genFormalParamsInFunctionSignature(fn.getFakeUETypeFromFunc(), fn)
  
# macro uegetter*(getter:untyped): untyped = ueBindImpl("", getter, uecGetProp) 
# macro uesetter*(setter:untyped): untyped = ueBindImpl("", setter, uecSetProp) 

macro uebind*(fn:untyped) : untyped = 
  let clsName = 
    if fn.params.len > 1:
      fn.params.filterIt(it.kind == nnkIdentDefs)[0][1].strVal().removeLastLettersIfPtr()
    else: 
      ""
  let clsFieldMb = 
    if clsName!="": some makeFieldAsUProp("self", clsName & "Ptr", clsName) 
    else: none[UEField]()
  
  var (ufunc, selfParam) = ufuncFieldFromNimNode(fn, clsFieldMb, clsName)  
  ufunc.signature = ufunc.signature[1..^1] #Remove the first arg, which is the self param
  result = ueBindImpl(ufunc, some selfParam, uecFunc)
  log "================================================================"
  log repr result
  
# macro uebindStatic*(clsName : static string = "", fn:untyped) : untyped = ueBindImpl(clsName, fn, uecFunc)

#Move into utils
proc removeLastLettersIfPtr*(str:string) : string = 
    if str.endsWith("Ptr"): str.substr(0, str.len()-4) else: str


{.experimental: "dynamicBindSym".}
proc ueBorrowImpl(clsName : string, fn: NimNode) : NimNode = 
  #TODO the first block of code it's exactly the same as bind, unify it
  let argsWithFirstType =
    fn.params
    .filterIt(it.kind == nnkIdentDefs)
  
  let isStatic = clsName!=""

  let args = 
    if isStatic: argsWithFirstType
    else: argsWithFirstType[1..^1] #Remove the first arg, which is the self param
  let firstParam = if isStatic: newEmptyNode() else: argsWithFirstType[0][0]
 
  let clsNameLit = 
    (if isStatic: clsName
    else: argsWithFirstType[0][1].strVal().removeLastLettersIfPtr()).removeFirstLetter()
  
  let classTypePtr = if isStatic: newEmptyNode() else: ident (argsWithFirstType[0][1].strVal())
  let classType = ident classTypePtr.strVal().removeLastLettersIfPtr() 

  let returnTypeLit = if fn.params[0].kind == nnkEmpty: "void" else: fn.params[0].repr()
  let returnType = fn.params[0]

  let fnBody = fn.body
  let fnName = fn.name
  let fnNameLit = fn.name.strVal()
  let fnVmName = ident fnNameLit & "VmImpl"
  let fnVmNameLit = fnNameLit & "VmImpl"

  func injectedArg(arg:NimNode, idx:int) : NimNode = 
    let argName = arg[0]
    let argNameLit = argName.strVal()
    let argType = arg[1]
    genAst(argName, argNameLit, argType):
      let argName {.inject.} = callInfo.value[argNameLit].runtimeFieldTo(argType)
  
  let injectedArgs = nnkStmtList.newTree(args.mapi(injectedArg))

  let vmFn = 
    genAst(funName=fnName, fnNameLit, fnVmName, fnVmNameLit, fnBody, classType, clsNameLit, returnType, returnTypeLit, injectedArgs, isStatic):
      setupBorrow(UEBorrowInfo(fnName:fnNameLit, className:clsNameLit))
      proc fnVmName*(callInfo{.inject.}:UECall) : RuntimeField = 
        injectedArgs 
        when not isStatic:
          let self {.inject.} = castIntToPtr[classType](callInfo.self)
        when returnTypeLit == "void":
          fnBody
          RuntimeField() #no return
        else:
          let returnVal {.inject.} : returnType = fnBody
          returnVal.toRuntimeField()

  # let bindFn = ueBindImpl(clsName, fn, uecFunc)
  # result = nnkStmtList.newTree(bindFn, vmFn)
  result = newEmptyNode()
  # log repr result      

macro ueborrow*(fn:untyped) : untyped = ueBorrowImpl("", fn)
macro ueborrowStatic*(clsName : static string, fn:untyped) : untyped = ueBorrowImpl(clsName, fn)





macro ddumpTree*(x: untyped) = 
  log treeRepr x
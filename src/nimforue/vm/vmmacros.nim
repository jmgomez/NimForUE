import std/[json, jsonutils, macros, genasts, options, sequtils, strutils, strformat]
import exposed 
import runtimefield
import ../utils/utils

proc ueBindImpl*(clsName : string, fn: NimNode) : NimNode = 
  let argsWithFirstType =
      fn.params
      .filterIt(it.kind == nnkIdentDefs)
  
  let isStatic = clsName!=""

  let args = 
    if isStatic: argsWithFirstType
    else: argsWithFirstType[1..^1] #Remove the first arg, which is the self param
  let firstParam = if isStatic: newEmptyNode() else: argsWithFirstType[0][0]
  let clsName = 
    if isStatic: clsName
    else: argsWithFirstType[0][1].strVal().replace("Ptr", "")

  let fnName = fn.name

  let returnTypeLit = if fn.params[0].kind == nnkEmpty: "void" else: fn.params[0].repr()
  let returnType = fn.params[0]

  let uFunc = UEFunc(name:fnName.strVal(), className:clsName)
  var funcData = newLit uFunc
  let paramsAsExpr = 
      argsWithFirstType
      .mapIt(it[0].strVal)
      .mapIt(nnkExprColonExpr.newTree(ident it, ident it)) #(arg: arg, arg2: arg2, etc.)
                    
  let valNode =  nnkTupleConstr.newTree( paramsAsExpr)
   
  result = 
    genAst(fnName, funcData, valNode, returnType, returnTypeLit, firstParam, isStatic):
      proc fnName() = 
        when isStatic:
          let callData = UECall(fn: funcData, value: valNode.toRuntimeField()) #No params yet
        else:
          let callData = UECall(fn: funcData, value: valNode.toRuntimeField(), self: int(firstParam)) #No params yet
        let returnVal {.used.} = uCall(callData) #check return val
        # log "VM:" & $callData
        let runtimeField = uCall(callData) #check return val
        #when no return?
        when returnTypeLit != "void":
          runtimeField.get.runtimeFieldTo(returnType)
          
  result.params = fn.params


macro uebind*(fn:untyped) : untyped = ueBindImpl("", fn)
macro uebindStatic*(clsName : static string = "", fn:untyped) : untyped = ueBindImpl(clsName, fn)

#Move into utils
proc removeLastLettersIfPtr*(str:string) : string = 
    if str.endsWith("Ptr"): str.substr(0, str.len()-4) else: str



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
    genAst(funName=fnName, fnNameLit, fnVmName, fnVmNameLit, fnBody, classTypePtr, clsNameLit, returnType, returnTypeLit, injectedArgs, isStatic):
      setupBorrow(UEBorrowInfo(fnName:fnNameLit, className:clsNameLit))

      proc fnVmName*(callInfo{.inject.}:UECall) : RuntimeField = 
        injectedArgs
        # log "call info:"
        # log $callInfo
        when not isStatic:
          let self {.inject.} = classTypePtr(callInfo.self)
        when returnTypeLit == "void":
          fnBody
          RuntimeField() #no return
        else:
          let returnVal : returnType = fnBody
          returnVal.toRuntimeField()

  let bindFn = ueBindImpl(clsName, fn)
  result = nnkStmtList.newTree(bindFn, vmFn)
  # log repr result
      




macro ueborrow*(fn:untyped) : untyped = ueBorrowImpl("", fn)
macro ueborrowStatic*(clsName : static string, fn:untyped) : untyped = ueBorrowImpl(clsName, fn)










macro ddumpTree*(x: untyped) = 
  log treeRepr x
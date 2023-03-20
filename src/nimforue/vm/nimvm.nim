include ../unreal/prelude
import ../unreal/editor/editor

import ../../buildscripts/[nimforueconfig]
import ../unreal/core/containers/containers

import std/[os, times, asyncdispatch, json, jsonutils, tables]
import std/[strutils, options, tables, sequtils, strformat, strutils, sugar]

import compiler / [ast, nimeval, vmdef, vm, llstream, types, lineinfos]
import compiler/options as copt
import ../vm/[uecall]
import ../codegen/[uemeta]


type   
  VMQuit* = object of CatchableError
    info*: TLineInfo





proc onInterpreterError(config: ConfigRef, info: TLineInfo, msg: string, severity : Severity)  {.gcsafe.}  = 
  if severity == Severity.Error and config.error_counter >= config.error_max:
    var fileName: string
    for k, v in config.m.filenameToIndexTbl.pairs:
      if v == info.fileIndex:
        fileName = k
    UE_Error "Script Error: $1:$2:$3 $4." % [fileName, $info.line, $(info.col + 1), msg]
    raise (ref VMQuit)(info: info, msg: msg)



proc implementBaseFunctions(interpreter:Interpreter) = 
  #TODO review this. Maybe even something like nimscripter can help
   #This function can be implemented with uebind directly 
  interpreter.implementRoutine("*", "exposed", "log", proc (a: VmArgs) =
      let msg = a.getString(0)
      UE_Log msg
      discard
    )


  interpreter.implementRoutine("*", "exposed", "uCallInterop", proc (a: VmArgs) =
      let msg = a.getString(0)
      let ueCall = msg.parseJson().to(UECall)
      let result = ueCall.uCall()
      let json = $result.toJson()
      setResult(a, json)
      discard
    )

  #This function can be implemented with uebind directly 
  interpreter.implementRoutine("*", "exposed", "getClassByNameInterop", proc (a: VmArgs) =
      let className = a.getString(0)
      let cls = getClassByName(className)
      let classAddr = cast[int](cls)
      setResult(a, classAddr)
      discard
    )

  interpreter.implementRoutine("*", "exposed", "newUObjectInterop", proc (a: VmArgs) =
      #It needs cls and owner which can be nil
      let owner = cast[UObjectPtr](getInt(a, 0))
      let cls = cast[UClassPtr](getInt(a, 1))

      let obj = newObjectFromClass(owner, cls, ENone)
      obj.setFlags(RF_MarkAsRootSet)
      let objAddr = cast[int](obj)
      setResult(a, objAddr)
      discard
    )

  #This function can be implemented with uebind directly 
  interpreter.implementRoutine("*", "exposed", "getName", proc(a: VmArgs) =
      let actor = cast[UObjectPtr](getInt(a, 0))
      if actor.isNil():
        setResult(a, "nil")
      else:
        setResult(a, actor.getName())
      # setResult(a, $actor.getName())
    )




#should args be here too?
type UEBorrowInfo = object
  fnName: string #nimName 
  className : string
  ueActualName : string #in case it has Received or some other prefix



func getVMImplFuncName*(info : UEBorrowInfo): string = (info.fnName & "VmImpl")


# var borrowedFns = newSeq[UFunctionNativeSignature]()
var borrowTable = newTable[string, UEBorrowInfo]() 

func getBorrowKey*(fn: UFunctionPtr) : string =  fn.getOuter().getName() & fn.getName()

#[
  [] Functions are being replaced, we need to store them with a table. 
]#


var interpreter : Interpreter #needs to be global so it can be accesed from cdecl

proc getValueFromPropInFn[T](context: UObjectPtr, stack: var FFrame) : T = 
  #does the same thing as StepCompiledIn but you dont need to know the type of the Fproperty upfront (which we dont)

  var paramValue {.inject.} : T #Define the param
  var paramAddr = cast[pointer](paramValue.addr) #Cast the Param with   
  if not stack.code.isNil():
      stack.step(context, paramAddr)
  else:
      var prop = cast[FPropertyPtr](stack.propertyChainForCompiledIn)
      stack.propertyChainForCompiledIn = stack.propertyChainForCompiledIn.next
      stepExplicitProperty(stack, paramAddr, prop)
  paramValue

proc borrowImpl(context: UObjectPtr; stack: var FFrame; returnResult: pointer) : void {.cdecl.} =
    stack.increaseStack()
    let fn = stack.node
    let borrowKey = fn.getBorrowKey()
    let borrowInfo = borrowTable[borrowKey]
    let vmFn = interpreter.selectRoutine(borrowInfo.getVMImplFuncName)
    if vmFn.isNil():
      UE_Error &"script does not export a proc of the name: {borrowInfo.fnName}"
      UE_Log &"All exported funcs: {borrowTable}"
      return
    #TODO pass params as json to vm call (from stack but review how it's done in uebind)
    try:
      var args = newJObject()
      let propParams = fn.getFPropsFromUStruct().filterIt(it != fn.getReturnProperty())  
      for prop in propParams:
        let propName = prop.getName().firstToLow()
        let nimTypeStr = getNimTypeAsStr(prop, context).toJson()

        if prop.isInt() or prop.isObjectBased(): #ints a pointers 
          args[propName] = getValueFromPropInFn[int](context, stack).toJson()
        if prop.isFloat():
          args[propName] = getValueFromPropInFn[float](context, stack).toJson()
        
        if prop.isStruct():
          let structProp = castField[FStructProperty](prop)
          let scriptStruct = structProp.getScriptStruct()
          let structProps = scriptStruct.getFPropsFromUStruct() #Lets just do this here before making it recursive
          if structProps.any():                     
            let structValPtr = getValueFromPropInFn[pointer](context, stack) #TODO stepIn should be enough
            args[propName] = getValueFromPropMemoryBlock(structProp, cast[ByteAddress](stack.mostRecentPropertyAddress))
          else:
             UE_Warn &" {scriptStruct.getName()} struct `{propName}` prop doesnt have any props"    
             args[propName] = newJObject() #Not sure if we should query a table for global structs. But so far only FInputActionValue has this issue

        #ahora solo hay un entero
      let ueCall = $makeUECall(makeUEFunc(borrowInfo.fnName, borrowInfo.className), context, args).toJson()

      let res = interpreter.callRoutine(vmFn, [newStrNode(nkStrLit, ueCall)])

      let returnProp = fn.getReturnProperty()
      if fn.doesReturn():
        let json = parseJson(res.strVal)
        var allocated = makeTArray[pointer]()
        setPropWithValueInMemoryBlock(returnProp, cast[ByteAddress](returnResult), json, allocated, 0)
    except:
      UE_Error &"error calling {borrowInfo.fnName} in script"
      UE_Error getCurrentExceptionMsg()
      UE_Error getStackTrace()
    #TODO return value



proc setupBorrow(interpreter:Interpreter) = 
  interpreter.implementRoutine("*", "exposed", "setupBorrowInterop", proc(a: VmArgs) =
    {.cast(noSideEffect).}:
      let borrowInfo = a.getString(0).parseJson().jsonTo(UEBorrowInfo)
    
      
      #At this point it will be the last added or not because it can be updated
      #But let's assume it's the case (we could use a stack or just store the last one separatedly)
      let cls = getClassByName(borrowInfo.className)
      if cls.isNil():
        UE_Error &"could not find class {borrowInfo.className}"
        return

      let ueBorrowUFunc = cls.findFunctionByNameWithPrefixes(borrowInfo.fnName.capitalizeAscii())
      if ueBorrowUFunc.isNone(): 
          UE_Error &"could not find function { borrowInfo.fnName} in class {borrowInfo.className}"
          return
      
      let borrowKey = ueBorrowUFunc.get.getBorrowKey()
      borrowTable.addOrUpdate(borrowKey, borrowInfo)
      #notice we could store the prev version to restore it later on 
      ueBorrowUFunc.get.setNativeFunc((cast[FNativeFuncPtr](borrowImpl)))
  )



proc initInterpreter*(searchPaths:seq[string], script: string = "script.nims") : Interpreter = 
  let std = findNimStdLibCompileTime()
  interpreter = createInterpreter(script, @[
    std,
    std / "pure",
    std / "pure" / "collections",
    std / "core", 
    PluginDir/"src"/"nimforue"/"utils",
    parentDir(currentSourcePath),
   
    ] & searchPaths)
  interpreter.registerErrorHook(onInterpreterError)
  interpreter.implementBaseFunctions()
  interpreter.setupBorrow()
  interpreter




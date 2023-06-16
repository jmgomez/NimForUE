import enumops
import models, modelconstructor
import std/[strformat, sequtils, macros, options, sugar, strutils, genasts]
import utils/[utils, ueutils]
when not defined(nuevm):
  import ../unreal/coreuobject/uobjectflags
else:
  import vmtypes


func getFunctionFlags*(fn:NimNode, functionsMetadata:seq[UEMetadata]) : (EFunctionFlags, seq[UEMetadata]) = 
    var flags = FUNC_Native or FUNC_Public
    func hasMeta(meta:string) : bool = fn.pragma.children.toSeq().any(n => repr(n).toLower()==meta.toLower()) or 
                                        functionsMetadata.any(metadata=>metadata.name.toLower()==meta.toLower())

    var fnMetas = functionsMetadata
    if hasMeta("BlueprintPure"):
        flags = flags | FUNC_BlueprintPure | FUNC_BlueprintCallable
    if hasMeta("BlueprintCallable"):
        flags = flags | FUNC_BlueprintCallable
    if hasMeta("BlueprintImplementableEvent") or hasMeta("BlueprintNativeEvent"):
        flags = flags | FUNC_BlueprintEvent | FUNC_BlueprintCallable
    if hasMeta("Static"):
        flags = flags | FUNC_Static
    if not hasMeta("Category"):
        fnMetas.add(makeUEMetadata("Category", "Default"))
    
    (flags, fnMetas)

func makeUEFieldFromNimParamNode*(typeName: string, n:NimNode) : UEField = 
    #make sure there is no var at this point, but CPF_Out

    var nimType = n[1].repr.strip()
    let paramName = 
      case n[0].kind:
      of nnkPragmaExpr:
        n[0][0].strVal()
      else:            
        n[0].strVal()

    var paramFlags = 
      case n[0].kind:
        of nnkPragmaExpr:
          var flags = CPF_Parm
          let pragmas = n[0][^1].children.toSeq()
          let isOut = pragmas.any(n=>n.kind == nnkMutableTy) #notice out translates to nnkMutableTy
          let isConst = pragmas.any(n=>n.kind == nnkIdent and n.strVal == "constp")
          if isConst:
            flags = flags or CPF_ConstParm #will leave it for refs but notice that ref params are actually ignore when checking funcs (see GetDefaultIgnoredSignatureCompatibilityFlags )
          if isOut:
            flags = flags or CPF_OutParm #out params are also set when var (see below)
          flags
          
        else:    
          CPF_Parm
      
    if nimType.split(" ")[0] == "var":
        paramFlags = paramFlags | CPF_OutParm | CPF_ReferenceParm
        nimType = nimType.split(" ")[1]
    makeFieldAsUPropParam(paramName, nimType, typeName, paramFlags)



proc ufuncFieldFromNimNode*(fn:NimNode, classParam:Option[UEField], typeName:string, functionsMetadata : seq[UEMetadata] = @[]) : (UEField,UEField) =  
    #this will generate a UEField for the function 
    #and then call genNativeFunction passing the body

    #converts the params to fields (notice returns is not included)
    let fnName = fn.name().strVal().firstToUpper()
    let formalParamsNode = fn.children.toSeq() #TODO this can be handle in a way so multiple args can be defined as the smae type
                             .filter(n=>n.kind==nnkFormalParams)
                             .head()
                             .get(newEmptyNode()) #throw error?
                             .children
                             .toSeq()

    let fields = formalParamsNode
                    .filter(n=>n.kind==nnkIdentDefs)
                    .mapIt(makeUEFieldFromNimParamNode(typeName, it))


    #For statics funcs this is also true becase they are only allow
    #in ufunctions macro with the parma.
    let firstParam = classParam.chainNone(()=>fields.head()).getOrRaise("Class not found. Please use the ufunctions macr and specify the type there if you are trying to define a static function. Otherwise, you can also set the type as first argument")
    let className = firstParam.uePropType.removeLastLettersIfPtr()
    
    
    let returnParam = formalParamsNode #for being void it can be empty or void
                        .first(n=>n.kind in [nnkIdent, nnkBracketExpr])
                        .flatMap((n:NimNode)=>(if n.kind==nnkIdent and n.strVal()=="void": none[NimNode]() else: some(n)))
                        .map(n=>makeFieldAsUPropParam("returnValue", n.repr.strip(), typeName, CPF_Parm | CPF_ReturnParm | CPF_OutParm))
    let actualParams = classParam.map(n=>fields) #if there is class param, first param would be use as actual param
                                 .get(fields.tail()) & returnParam.map(f => @[f]).get(@[])
    
    
    var flagMetas = getFunctionFlags(fn, functionsMetadata)
    if actualParams.any(isOutParam):
        flagMetas[0] = flagMetas[0] or FUNC_HasOutParms


    let fnField = makeFieldAsUFun(fnName, actualParams, className, flagMetas[0], flagMetas[1])
    (fnField, firstParam)


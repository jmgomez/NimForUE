import enumops
import models, modelconstructor
import std/[strformat, sequtils, macros, options, sugar, strutils, genasts]
import ../utils/[utils, ueutils]
when not defined(nuevm):
  import ../unreal/coreuobject/uobjectflags
else:
  import vmtypes

func getTypeNodeFromUProp*(prop : UEField, isVarContext:bool) : NimNode 

func ueNameToNimName(propName:string) : string = #this is mostly for the autogen types
    let reservedKeywords = ["object", "method", "type", "interface", "var", "in", "out", "end", "bLock", "from"] 
    let reservedToCapitalize = ["bool", "enum", "else", "new", "template", "continue", "int"]
    let startsWithUnderscore = propName[0] == '_'
    if propName in reservedKeywords or startsWithUnderscore: &"`{propName}`" 
    elif propName in reservedToCapitalize: propName.capitalizeAscii()
    elif propName == "result": "Result"
    else: propName

func isStatic*(funField:UEField) : bool = (FUNC_Static in funField.fnFlags)
func getReturnProp*(funField:UEField) : Option[UEField] =  funField.signature.filter(isReturnParam).head()
func doesReturn*(funField:UEField) : bool = funField.getReturnProp().isSome()



func getTypeNodeForReturn*(prop: UEField, typeNode : NimNode) : NimNode = 
  if prop.shouldBeReturnedAsVar():
    return nnkVarTy.newTree(typeNode)
  typeNode


func identWithInjectAnd(name:string, pragmas:seq[string]) : NimNode {.used.} = 
  nnkPragmaExpr.newTree(
    [
      ident name, 
      nnkPragma.newTree((@["inject"] & pragmas).map( x => ident x))
    ]
    )
func identWithInjectPublic*(name:string) : NimNode = 
  nnkPragmaExpr.newTree([
    nnkPostfix.newTree([ident "*", ident name]),
    nnkPragma.newTree(ident "inject")])
func identWithInjectPublicAnd*(name, anotherPragma:string) : NimNode = 
  nnkPragmaExpr.newTree([
    nnkPostfix.newTree([ident "*", ident name]),
    nnkPragma.newTree(ident "inject", ident anotherPragma)
    

    ])

func identWithInject*(name:string) : NimNode = 
  nnkPragmaExpr.newTree([
    ident name,
    nnkPragma.newTree(ident "inject")])

func identWrapper*(name:string) : NimNode = ident(name) #cant use ident as argument
func identPublic*(name:string) : NimNode = nnkPostfix.newTree([ident "*", ident name])

#helper func used in geneFunc and genParamsInsideFunc
#returns for each param a type definition node
#the functions that it receives as param is used with ident/identWithInject/ etc. to make fields public or injected
#isGeneratingType 
func signatureAsNode(funField:UEField, identFn : string->NimNode, isDefaultValueContext:bool) : seq[NimNode] =  
  proc getDefaultParamValue(param:UEField) : NimNode = 
    func makeFnCall(fnName, val:string) : NimNode = nnkCall.newTree(ident fnName, newLit val)
    if param.defaultParamValue == "" or not isDefaultValueContext: newEmptyNode()
    else: 
      let propType = param.uePropType
      let val = param.defaultParamValue
      case propType:
      of "bool":newLit parseBool(val)
      of "FString": newLit val
      of "float32": newLit parseFloat(val).float32
      of "float64": newLit parseFloat(val).float64
      of "int32": newLit parseInt(val).int32
      of "int": newLit parseInt(val)
      of "FName": makeFnCall("makeFName", val)
      of "FLinearColor": makeFnCall("makeFLinearColor", val)
      of "FVector2D": makeFnCall("makeFVector2D", val)
      of "FVector": makeFnCall("makeFVector", val)
      of "FRotator": makeFnCall("makeFRotator", val)
      else:
        if propType.startsWith("E"): 
          nnkDotExpr.newTree(ident propType, ident val)
        elif @["A", "U"].filterIt(propType.startsWith(it)).any(): #Will be always a null pointer
          ident "nil"
        else:
          error("Unsupported param " & propType)
          newEmptyNode()
  proc getParamNodesFromField(param:UEField) : NimNode =
    result = 
      nnkIdentDefs.newTree(
        identFn(param.name.firstToLow().ueNameToNimName()), 
        param.getTypeNodeFromUProp(isVarContext=true), 
        param.getDefaultParamValue()
      )

  case funField.kind:
  of uefFunction: 
    return funField.signature
      .filterIt(not it.isReturnParam())
      .map(getParamNodesFromField)
  else:
    error("funField: not a func")
    @[]


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

#Converts a UEField type into a NimNode (useful when dealing with generics)
#varContexts refer to if it's allowed or not to gen var (i.e. you cant gen var in a type definition but you can in a func definition)
func getTypeNodeFromUProp*(prop : UEField, isVarContext:bool) : NimNode = 
  func fromGenericStringToNode(generic:string) : NimNode = 
    let genericType = generic.extractOuterGenericInNimFormat()
    
    let innerTypesStr = 
      if genericType.contains("TMap"): generic.extractKeyValueFromMapProp().join(",")
      else: generic.extractTypeFromGenericInNimFormat()
    let innerTypes = 
      innerTypesStr
        .split(",")
        .mapIt(
          (if it.isGeneric(): it.fromGenericStringToNode() 
          else: ident(it.strip())))
        
    result = nnkBracketExpr.newTree((ident genericType) & innerTypes)

  case prop.kind:
    of uefProp:
      let typeNode =  
        if not prop.isGeneric: ident prop.uePropType
        else: fromGenericStringToNode(prop.uePropType)
      #Should not wrap var in all contexts 
      if prop.isOutParam and isVarContext:
        nnkVarTy.newTree typeNode
      else:
        typeNode
      # debugEcho repr typeNode


    else:
      newEmptyNode()


func genFormalParamsInFunctionSignature*(typeDef : UEType, funField:UEField, firstParamName:string = "self") : NimNode = #returns (obj:UObjectPr, param:Fstring..) : FString 
#notice the first part has to be introduced. see the final part of genFunc
  let ptrName = ident typeDef.name & (if typeDef.kind == uetDelegate: "" else: "Ptr") #Delegate dont use pointers

  let returnType =  
    if funField.doesReturn(): 
        # ident funField.getReturnProp().get().uePropType
      getTypeNodeFromUProp(funField.getReturnProp().get(), isVarContext = false)
    else: ident "void"
  
  let objType = if typeDef.kind == uetDelegate:
            nnkVarTy.newTree(ptrName)
          else:
            ptrName
  nnkFormalParams.newTree(
          @[returnType] &
          (if funField.isStatic(): @[] 
          else: @[nnkIdentDefs.newTree([identWithInject firstParamName, objType, newEmptyNode()])]) &  
          funField.signatureAsNode(identWithInject, isDefaultValueContext=true))

func getFakeUETypeFromFunc*(fn:UEField): UEType = 
  assert fn.kind == uefFunction
  UEType(name: fn.typeName, kind: uetClass)
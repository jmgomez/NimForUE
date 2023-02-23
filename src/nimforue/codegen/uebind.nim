import std/[options, strutils, sugar, sequtils, strformat,  genasts, macros, importutils]

include ../unreal/definitions
import ../utils/[utils, ueutils]
import ../unreal/core/containers/[unrealstring, array, map, set]
import ../unreal/coreuobject/[uobjectflags]
import ../codegen/[nuemacrocache, models, modelconstructor]
import modulerules
import ../../buildscripts/nimforueconfig #probably nimforueconfig should be removed from buildscripts

import gencppclass

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

func nimToCppConflictsFreeName*(propName:string) : string = 
  let reservedCppKeywords = ["template", "operator", "enum", "struct", 
    "normal", "networkMask", "shadow", "id", "fraction", "bIsCaseSensitive", #they collide on mac with the apple frameworks
    "namespace", "min", "max", "default", "new", "else"]
  let strictReserved = ["class"]
  if propName in strictReserved: &"{propName.capitalizeASCII()}" 
  elif propName in reservedCppKeywords:  propName.firstToUpper() 
  else: propName

func ueNameToNimName(propName:string) : string = #this is mostly for the autogen types
    let reservedKeywords = ["object", "method", "type", "interface", "var", "in", "out", "end", "bLock", "from"] 
    let reservedToCapitalize = ["bool", "enum", "else", "new", "template", "continue", "int"]
    let startsWithUnderscore = propName[0] == '_'
    if propName in reservedKeywords or startsWithUnderscore: &"`{propName}`" 
    elif propName in reservedToCapitalize: propName.firstToUpper()
    elif propName == "result": "Result"
    else: propName


  # macro ex*(a:untyped):untyped = a

func genProp(typeDef : UEType, prop : UEField) : NimNode = 
  let ptrName = ident typeDef.name & "Ptr"
  
  let className = typeDef.name.substr(1)

  let typeNode = case prop.kind:
          of uefProp: getTypeNodeFromUProp(prop, isVarContext=false)
          else: newEmptyNode() #No Support 
  let typeNodeAsReturnValue = case prop.kind:
              of uefProp: prop.getTypeNodeForReturn(getTypeNodeFromUProp(prop, isVarContext=true))
              else: newEmptyNode()#No Support as UProp getter/Seter
  
  
  let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)).nimToCppConflictsFreeName()


  #bools are handled differently:
  let actualGetter = 
    if prop.uePropType == "bool": 
      genAst():
        getValueFromBoolProp(prop, obj)
    else:
      genAst(typeNode):
        getPropertyValuePtr[typeNode](prop, obj)[]
  let actualSetter = 
    if prop.uePropType == "bool": 
      genAst():
        setValueInBoolProp(prop, obj, value)
    else:
      genAst(typeNode):
        setPropertyValuePtr[typeNode](prop, obj, value.addr)

  #Notice we generate two set properties one for nim and the other for code gen due to cpp
  #not liking the equal in the ident name
  
  result = 
    genAst(propIdent, ptrName, typeNode, className, actualGetter, actualSetter, propUEName = prop.name, typeNodeAsReturnValue):
      proc `propIdent`* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue {.exportcpp.} =
        let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
        actualGetter
      
      proc `propIdent=`* (obj {.inject.} : ptrName, val {.inject.} :typeNode)  = 
        var value {.inject.} : typeNode = val
        let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
        actualSetter

      proc `set propIdent`* (obj {.inject.} : ptrName, val {.inject.} :typeNode)  {.exportcpp.} = 
        var value {.inject.} : typeNode = val
        let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
        actualSetter
  

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

  

func genParamInFnBodyAsType(funField:UEField) : NimNode = 
  let returnProp = funField.signature.filter(isReturnParam).head()
  #make sure we remove the out flag so we dont emit var on type variables which is not allowed
  var funField = funField

  for s in funField.signature.mitems:
    if  s.isReturnParam:
      s.propFlags = CPF_ReturnParm #remove out flag before the signatureCall, cant do and for some reason. Maybe a bug?
    elif s.isOutParam:
      s.propFlags = CPF_None #remove out flag before the signatureCall, cant do and for some reason. Maybe a bug?

  let paramsInsideFuncDef = nnkTypeSection.newTree([nnkTypeDef.newTree([identWithInject "Params", newEmptyNode(), 
              nnkObjectTy.newTree([
                newEmptyNode(), newEmptyNode(),  
                nnkRecList.newTree(
                  funField.signatureAsNode(identWrapper, isDefaultValueContext=false) &
                  returnProp.map(prop=>
                    @[nnkIdentDefs.newTree([ident("returnValue"), 
                              getTypeNodeFromUProp(prop, isVarContext = false),
                              # ident prop.uePropType, 
                              newEmptyNode()])]).get(@[])
                )])
            ])])

  
  paramsInsideFuncDef

func isStatic*(funField:UEField) : bool = (FUNC_Static in funField.fnFlags)
func getReturnProp*(funField:UEField) : Option[UEField] =  funField.signature.filter(isReturnParam).head()
func doesReturn*(funField:UEField) : bool = funField.getReturnProp().isSome()


func genFormalParamsInFunctionSignature(typeDef : UEType, funField:UEField, firstParamName:string) : NimNode = #returns (obj:UObjectPr, param:Fstring..) : FString 
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


func getGenFuncName(funField : UEField) : string = funField.name.firstToLow().ueNameToNimName
#this is used for both, to generate regular function binds and delegate broadcast/execute functions
#for the most part the same code is used for both
#this is also used for native function implementation but the ast is changed afterwards
#Returns a tuple with the forward declaration and the actual function 
func genFunc*(typeDef : UEType, funField : UEField) : tuple[fw:NimNode, impl:NimNode] = 
  let isStatic = FUNC_Static in funField.fnFlags
  let clsName = typeDef.name.substr(1)

  let formalParams = genFormalParamsInFunctionSignature(typeDef, funField, "self")

  let generateObjForStaticFunCalls = 
    if isStatic: 
      genAst(clsName=newStrLitNode(clsName)): 
        let self {.inject.} = getDefaultObjectFromClassName(clsName)
    else: newEmptyNode()

  
  let processFn = 
    case typeDef.kind:
    of uetDelegate:
      case typeDef.delKind:
        of uedelDynScriptDelegate:
          genAst(): self.processDelegate(param.addr)
        of uedelMulticastDynScriptDelegate:
          genAst(): self.processMulticastDelegate(param.addr)
    else: genAst(clsName=newStrLitNode(clsName)): 
      let fn {.inject, used.} = getClassByName(clsName).findFunctionByName(fnName)
      self.processEvent(fn, param.addr)

  let outParams = 
    nnkStmtList.newTree(
      funField.signature
        .filterIt(it.isOutParam and not it.isReturnParam)
        .mapIt(it.name)
        .mapIt(nnkAsgn.newTree(ident(it.firstToLow().ueNameToNimName), nnkDotExpr.newTree(ident("param"), ident(it.firstToLow().ueNameToNimName))))
    )

  let returnCall = if funField.doesReturn(): 
            genAst(): 
              return param.returnValue
           else: newEmptyNode()
  let paramInsideBodyAsType = genParamInFnBodyAsType(funField)
  let paramObjectConstrCall = nnkObjConstr.newTree(@[ident "Params"] &  #creates Params(param0:param0, param1:param1)
                funField.signature
                  .filter(prop=>not isReturnParam(prop))
                  .map(param=>ident(param.name.firstToLow().ueNameToNimName()))
                  .map(param=>nnkExprColonExpr.newTree(param, param))
              )
  let paramDeclaration = nnkVarSection.newTree(nnkIdentDefs.newTree([identWithInject "param", newEmptyNode(), paramObjectConstrCall]))

  var fnBody = genAst(uFnName=newStrLitNode(funField.actualFunctionName), paramInsideBodyAsType, paramDeclaration, generateObjForStaticFunCalls, processFn, returnCall, outParams):
    paramInsideBodyAsType
    paramDeclaration
    let fnName {.inject, used .} = n uFnName
    generateObjForStaticFunCalls
    processFn
    outParams
    returnCall

  var pragmas = 
    when WithEditor:
      nnkPragma.newTree(
        nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1_"))
        ) #export the func with an underscore to avoid collisions
    else: newEmptyNode()

  # when defined(windows):
  #   pragmas.add(ident("thiscall")) #I Dont think this is necessary
  let forwardDeclaration = 
   nnkProcDef.newTree([
              identPublic funField.getGenFuncName(), 
              newEmptyNode(), newEmptyNode(), 
              formalParams, 
              pragmas, newEmptyNode(),
            ])
  var impl = forwardDeclaration
  impl.add(fnBody)
  (forwardDeclaration,impl)
  


func getFunctionFlags*(fn:NimNode, functionsMetadata:seq[UEMetadata]) : (EFunctionFlags, seq[UEMetadata]) = 
    var flags = FUNC_Native or FUNC_Public
    func hasMeta(meta:string) : bool = fn.pragma.children.toSeq().any(n=> repr(n).toLower()==meta.toLower()) or 
                                        functionsMetadata.any(metadata=>metadata.name.toLower()==meta.toLower())

    var fnMetas = functionsMetadata

    if hasMeta("BlueprintPure"):
        flags = flags | FUNC_BlueprintPure | FUNC_BlueprintCallable
    if hasMeta("BlueprintCallable"):
        flags = flags | FUNC_BlueprintCallable
    if hasMeta("BlueprintImplementableEvent"):
        flags = flags | FUNC_BlueprintEvent | FUNC_BlueprintCallable
    if hasMeta("Static"):
        flags = flags | FUNC_Static
    if not hasMeta("Category"):
        fnMetas.add(makeUEMetadata("Category", "Default"))
    
    (flags, fnMetas)

func makeUEFieldFromNimParamNode*(n:NimNode) : UEField = 
    #make sure there is no var at this point, but CPF_Out

    var nimType = n[1].repr.strip()
    let paramName = n[0].strVal()
    var paramFlags = CPF_Parm
    if nimType.split(" ")[0] == "var":
        paramFlags = paramFlags | CPF_OutParm
        nimType = nimType.split(" ")[1]
    makeFieldAsUPropParam(paramName, nimType, paramFlags)




#converts a NimNode (proc) in to a UField of type Func
#first is the param specify on ufunctions when specified one. Otherwise it will use the first
#parameter of the function
#returns Fn and the FirstParam (which is the class)
proc ufuncFieldFromNimNode*(fn:NimNode, classParam:Option[UEField], functionsMetadata : seq[UEMetadata] = @[]) : (UEField,UEField) =  
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
                        .first(n=>n.kind in [nnkIdent, nnkBracketExpr])
                        .flatMap((n:NimNode)=>(if n.kind==nnkIdent and n.strVal()=="void": none[NimNode]() else: some(n)))
                        .map(n=>makeFieldAsUPropParam("returnValue", n.repr.strip(), CPF_Parm | CPF_ReturnParm))
    let actualParams = classParam.map(n=>fields) #if there is class param, first param would be use as actual param
                                 .get(fields.tail()) & returnParam.map(f => @[f]).get(@[])
    
    
    var flagMetas = getFunctionFlags(fn, functionsMetadata)
    if actualParams.any(isOutParam):
        flagMetas[0] = flagMetas[0] or FUNC_HasOutParms


    let fnField = makeFieldAsUFun(fnName, actualParams, className, flagMetas[0], flagMetas[1])
    (fnField, firstParam)


func genInterfaceConverers*(ueType:UEType) : NimNode =   
  let typeNamePtr = ident ueType.name & "Ptr"
  func genConverter(interName:string) : NimNode = 
    let interfaceName = ident interName
    let interfacePtrName = ident interName & "Ptr"
    let fnName = ident ueType.name & "to" & interName

    genAst(fnName,typeNamePtr, interfaceName, interfacePtrName):
      converter fnName*(self {.inject.} : typeNamePtr): interfacePtrName =  cast[interfacePtrName](self)
  
  nnkStmtList.newTree(ueType.interfaces.mapIt(genConverter(it)))


func genUClassTypeDef(typeDef : UEType, rule : UERule = uerNone, typeExposure: UEExposure) : NimNode =

  let props = nnkStmtList.newTree(
        typeDef.fields
          .filter(prop=>prop.kind==uefProp)
          .map(prop=>genProp(typeDef, prop)))

  let funcs = nnkStmtList.newTree(
          typeDef.fields
             .filter(prop=>prop.kind==uefFunction)
             .map(fun=>genFunc(typeDef, fun).impl))
  
  let typeDecl = 
    if rule == uerCodeGenOnlyFields or typeDef.forwardDeclareOnly or typeDef.metadata.filterIt(it.name.toLower() == NoDeclMetadataKey.toLower()).any(): 
      newEmptyNode()
    else: 
      let ptrName = ident typeDef.name & "Ptr"
      let parent = ident typeDef.parent
      case typeExposure:
      of uexDsl:
        let outputHeader = newLit OutPutHeader
        let typeSection = genAst(name = ident typeDef.name, ptrName, parent, outputHeader):
                    type #The dsl also import types from a header that's generated at compile. This is part of the support for virtual funcs. Test.h is temporal, we are going to use the current module name.h
                      name* {.inject, importcpp, header: "placeholer".} = object of parent #TODO OF BASE CLASS 
                      ptrName* {.inject.} = ptr name
        #Replaces the header pragma vale 'placehodler' from above. For some reason it doesnt want to pick the value directly
        typeSection[0][0][^1][^1][^1] = newLit OutPutHeader 
        typeSection
      of uexExport:
        newEmptyNode()
        #[
        genAst(name = ident typeDef.name, ptrName, parent):
          type 
            name* {.importcpp.} = object of parent #TODO OF BASE CLASS 
            ptrName* = ptr name
            ]#
      of uexImport:
        newEmptyNode()

  result = 
    genAst(typeDecl, props, funcs):
        typeDecl
        props
        funcs

  if typeExposure == uexExport and not typeDef.forwardDeclareOnly: 
    #Generates a type so it's added to the header when using --header
    #TODO dont create them for UStructs
    let exportFn = genAst(fnName= ident "keep"&typeDef.name, typeName=ident typeDef.name):
      proc fnName(fake {.inject.} :typeName) {.exportcpp.} = discard 
    result = nnkStmtList.newTree(result, exportFn)

  result.add genInterfaceConverers(typeDef)

func genImportCFunc*(typeDef : UEType, funField : UEField) : NimNode = 
  let formalParams = genFormalParamsInFunctionSignature(typeDef, funField, "obj")
  var pragmas = nnkPragma.newTree(
          nnkExprColonExpr.newTree(
            ident("importcpp"),
            newStrLitNode("$1_(@)")#Import the cpp func. Not sure if the value will work across all the signature combination
          ),
          nnkExprColonExpr.newTree(
            ident("header"),
            newStrLitNode("UEGenBindings.h")
          )
        )
  result = nnkProcDef.newTree([
              identPublic funField.getGenFuncName(), 
              newEmptyNode(), newEmptyNode(), 
              formalParams, 
              pragmas, newEmptyNode(), newEmptyNode()
            ])

  if  funField.metadata.any(x=>x.name=="Comment"): 
    result = newStmtList(result, newStrLitNode("##"&funField.metadata["Comment"].get()))

proc genDelType*(delType:UEType, exposure:UEExposure) : NimNode = 
  #NOTE delegates are always passed around as reference
  #adds the delegate to the global list of available delegates so we can lookup it when emitting the UCLass
  addDelegateToAvailableList(delType)
  let typeName = ident delType.name
   
  let delBaseType = 
    case delType.delKind 
    of uedelDynScriptDelegate: ident "FScriptDelegate"
    of uedelMulticastDynScriptDelegate: ident "FMulticastScriptDelegate"
  let broadcastFnName = 
    case delType.delKind 
    of uedelDynScriptDelegate: "execute"
    of uedelMulticastDynScriptDelegate: "broadcast"

  let typ = 
    if exposure == uexImport:
      genAst(typeName, delBaseType):
        type
          typeName {. inject, importcpp, header:"UEGenBindings.h".} = object of delBaseType
    else:
      genAst(typeName, delBaseType):
        type
          typeName {. inject, exportcpp.} = object of delBaseType


  let broadcastFunType = UEField(name:broadcastFnName, kind:uefFunction, signature: delType.fields)
  let funcNode = 
    if exposure == uexImport: genImportCFunc(delType, broadcastFunType)
    else: genFunc(delType, broadcastFunType).impl

  result = nnkStmtList.newTree(typ, funcNode)



func getFieldIdent*(prop:UEField) : NimNode = 
  let fieldName = ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1)).nimToCppConflictsFreeName()
  identPublic fieldName

#TODO rename this dont use single letter variables
#TODO REFACTOR THIS. This is not simmetric at all. Either we split everything by it's type exposure or we dont split at all
#The padding function also add noise here. 
func genUStructTypeDef*(typeDef: UEType,  rule : UERule = uerNone, typeExposure:UEExposure) : NimNode = 
  let suffix = "_"
  let typeName = 
    case typeExposure: 
    of uexDsl: identWithInjectPublic typeDef.name
    of uexImport: 
      nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident typeDef.name]),
        nnkPragma.newTree(
          ident "inject",
          nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1" & suffix)),
          nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h"))
        )
      ])
    of uexExport:
      nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident typeDef.name]),
        nnkPragma.newTree(
          ident "inject",
          nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1" & suffix))
        )
      ])

  let fields =
    case typeExposure:
    of uexDsl, uexImport:
      typeDef.fields
            .map(prop => nnkIdentDefs.newTree(
              [getFieldIdent(prop), 
              prop.getTypeNodeFromUProp(isVarContext=false), newEmptyNode()]))

            .foldl(a.add b, nnkRecList.newTree)
    of uexExport: 
      var fields = nnkRecList.newTree()
      var size, offset, padId: int
      for prop in typeDef.fields:
        var id = nnkIdentDefs.newTree(getFieldIdent(prop), prop.getTypeNodeFromUProp(isVarContext=false), newEmptyNode())

        let offsetDelta = prop.offset - offset
        if offsetDelta > 0:
          fields.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(offsetDelta), ident "byte"), newEmptyNode())
          inc padId
          offset += offsetDelta
          size += offsetDelta

        fields.add id
        size = offset + prop.size
        offset += prop.size

      if size < typeDef.size:
        fields.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(typeDef.size - size), ident "byte"), newEmptyNode())
      fields

  if typeDef.superStruct == "":
    result = genAst(typeName, fields):
          type typeName = object
    result[0][^1] = nnkObjectTy.newTree([newEmptyNode(), newEmptyNode(), fields])

  else:
    let superStruct = ident typeDef.superStruct
    result = genAst(typeName, superStruct, fields):
          type typeName = object of superStruct
    result[0][^1][^1] = fields

  

  if typeExposure == uexExport: 
    #Generates a type so it's added to the header when using --header
    #TODO dont create them for UStructs
    let exportFn = genAst(fnName= ident "keep"&typeDef.name, typeName=ident typeDef.name):
      proc fnName(fake {.inject.} :typeName) {.exportcpp.} = discard 
    result = nnkStmtList.newTree(exportFn)
  # debugEcho result.repr
  # debugEcho result.treeRepr


func genUEnumTypeDef*(typeDef:UEType, typeExposure:UEExposure) : NimNode = 
  let typeName = ident(typeDef.name)
  let fields = typeDef.fields
            .map(f => ident f.name)
            .foldl(a.add b, nnkEnumTy.newTree)
  fields.insert(0, newEmptyNode()) #required empty node in enums

  result= genAst(typeName, fields):
        type typeName* {.inject, size:sizeof(uint8), pure.} = enum     
          fields

  result[0][^1] = fields #replaces enum 


  if typeExposure == uexExport: 
    #Generates a type so it's added to the header when using --header
    let exportFn = genAst(fnName= ident "keep"&typeDef.name, typeName=ident typeDef.name):
      proc fnName(fake {.inject.} :typeName) {.exportcpp.} = discard 
    result = nnkStmtList.newTree(exportFn)


func genUStructTypeDefBinding*(ueType: UEType, rule: UERule = uerNone): NimNode =
  var recList = nnkRecList.newTree()
  var size, offset, padId: int
  for prop in ueType.fields:
    var id = nnkIdentDefs.newTree(getFieldIdent(prop), prop.getTypeNodeFromUProp(isVarContext=false), newEmptyNode())

    let offsetDelta = prop.offset - offset
    if offsetDelta > 0:
      recList.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(offsetDelta), ident "byte"), newEmptyNode())
      inc padId
      offset += offsetDelta
      size += offsetDelta

    recList.add id
    size = offset + prop.size
    offset += prop.size

  if size < ueType.size:
    recList.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(ueType.size - size), ident "byte"), newEmptyNode())

  nnkTypeDef.newTree(
    nnkPragmaExpr.newTree([
      nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
      nnkPragma.newTree(
        ident "inject",
        nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1_"))
      )
    ]),
    newEmptyNode(),
    nnkObjectTy.newTree(
      newEmptyNode(), newEmptyNode(), recList
    )
  )


proc genTypeDecl*(typeDef : UEType, rule : UERule = uerNone, typeExposure = uexDsl) : NimNode = 
  case typeDef.kind:
    of uetClass:
      genUClassTypeDef(typeDef, rule, typeExposure)
    of uetStruct:
      genUStructTypeDef(typeDef, rule, typeExposure)
    of uetEnum:
      genUEnumTypeDef(typeDef, typeExposure)
    of uetDelegate:
      genDelType(typeDef, typeExposure)
    of uetInterface:
      newEmptyNode() #Not gen interfaces for now

macro genType*(typeDef : static UEType) : untyped = genTypeDecl(typeDef)

macro uebind*(clsName : static string = "", fn:untyped) : untyped = 
  let clsFieldMb = 
    if clsName!="": some makeFieldAsUProp("obj", clsName) 
    else: none[UEField]()

  var (fnField, firstParam) = uFuncFieldFromNimNode(fn, clsFieldMb, @[])
  if clsFieldMb.isSome:
    fnField.fnFlags = FUNC_Static
  #Generates a fake class form the classField. 
  let typeDefFn = makeUEClass(firstParam.uePropType, parent="", CLASS_None, @[fnField])
  result = genFunc(typeDefFn, fnField).impl
  # echo repr result
  # echo treeRepr fn
  # echo $fnField
  # echo $firstParam

  # newEmptyNode()


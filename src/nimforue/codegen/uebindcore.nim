
import models, modelconstructor, enumops
import std/[strformat, sequtils, macros, options, sugar, strutils, genasts, algorithm, bitops]
import ../utils/[utils, ueutils]
from nuemacrocache import addPropAssignment, isMulticastDelegate, isDelegate, getPropAssignment

when not defined(nuevm):
  import ../unreal/coreuobject/uobjectflags
else:
  import vmtypes, exposed



func getTypeNodeFromUProp*(prop : UEField, isVarContext:bool) : NimNode 

const NimReservedKeywords* = @["object", "method", "type", "interface", "var", "in", "out", "end", "bLock", "from"] 
const NimReservedToCapitalize* =  @["bool", "enum", "else", "new", "template", "continue", "int"]
func ueNameToNimName*(propName:string) : string = #this is mostly for the autogen types
    let reservedKeywords = NimReservedKeywords
    let reservedToCapitalize = NimReservedToCapitalize
    let startsWithUnderscore = propName[0] == '_'
    if propName in reservedKeywords or startsWithUnderscore: &"`{propName}`" 
    elif propName in reservedToCapitalize: propName.capitalizeAscii()
    elif propName == "result": "Result"
    else: propName


func nimToCppConflictsFreeName*(propName:string) : string = 
  let reservedCppKeywords = ["template", "operator", "enum", "struct", 
    "normal", "networkMask", "shadow", "id", "fraction", "bIsCaseSensitive", #they collide on mac with the apple frameworks
    "namespace", "min", "max", "default", "new", "else"]
  let strictReserved = ["class"]
  if propName in strictReserved: &"{propName.capitalizeASCII()}" 
  elif propName in reservedCppKeywords:  propName.firstToUpper() 
  else: propName


func isStatic*(funField:UEField) : bool = 
  bitand(FUNC_Static.int, funField.fnFlags.int) > 0 or "Static" in funField.metadata

func getReturnProp*(funField:UEField) : Option[UEField] =  funField.signature.filter(isReturnParam).head()
func doesReturn*(funField:UEField) : bool = funField.getReturnProp().isSome()
func isPublic*(propField: UEField): bool = bitand(propField.propFlags.int, CPF_NativeAccessSpecifierPublic.int) > 0


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

func identWithInject*(name:string) : NimNode {.compileTime.} = 
  nnkPragmaExpr.newTree([
    ident name,
    nnkPragma.newTree(ident "inject")])

func identWrapper*(name:string) : NimNode = ident(name) #cant use ident as argument
func identPublic*(name:string) : NimNode = nnkPostfix.newTree([ident "*", ident name])

#helper func used in geneFunc and genParamsInsideFunc
#returns for each param a type definition node
#the functions that it receives as param is used with ident/identWithInject/ etc. to make fields public or injected
#isGeneratingType 
func signatureAsNode*(funField:UEField, identFn : string->NimNode, isDefaultValueContext:bool) : seq[NimNode] =  
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
          nnkDotExpr.newTree(ident propType, ident val.replace("Type::", "")) #replce get rid of Namespace.Type.Value
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
        flags = flags | FUNC_BlueprintEvent | FUNC_BlueprintCallable #This is wrong and we shouldnt care about these pragmas at all.
    if hasMeta("Static"):
      when not defined(nuevm): #: illegal conversion from '-1' to '[0..9223372036854775807]'
        flags = flags | FUNC_Static
    if not hasMeta("Category"):
        fnMetas.add(makeUEMetadata("Category", "Default"))
    
    (flags, fnMetas)

func makeUEFieldFromNimParamNode*(typeName: string, n:NimNode) : seq[UEField] = 
    #make sure there is no var at this point, but CPF_Out
    var nimType = n[^2].repr.strip()
    var paramNames: seq[string]
    for p in n[0..^3]:
      case p.kind:
      of nnkPragmaExpr:
        paramNames.add p[0].strVal()
      else:            
        paramNames.add p.strVal()

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
            flags = flags or CPF_OutParm
          flags
          
        else:    
          CPF_Parm
      
    if nimType.split(" ")[0] == "var":        
        paramFlags = paramFlags or CPF_OutParm or CPF_ReferenceParm     
        nimType = nimType.split(" ")[1]
    let defaultValue = 
      case n[^1].kind:
      of nnkEmpty: ""
      of nnkIntLit..nnkInt64Lit: $n[^1].intVal
      of nnkFloatLit..nnkFloat128Lit: $n[^1].floatVal
      of nnkStrLit: n[^1].strVal
      of nnkIdent:
        let typ = n[1].strVal
        if typ == "bool": n[^1].strVal.capitalizeAscii()
        #TODO FStructs here. The support will be limited though 
        else:          
            error &"Invalid default value for param Kind is {n[^1].kind}. Tree:{ repr n }. "
            ""
      else:
        safe:
          error &"Invalid default value for param Kind is {n[^1].kind}. Tree:{ repr n }. "
        ""
    var paramMetadata = newSeq[UEMetadata]()
    if defaultValue != "":
      paramMetadata.add(paramNames.mapIt(makeUEMetadata(CPP_Default_MetadataKeyPrefix & it, defaultValue)))    
    result = paramNames.mapIt(makeFieldAsUPropParam(it, nimType, typeName, paramFlags, paramMetadata))   
    
   
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
                    .flatten()


    #For statics funcs this is also true becase they are only allow
    #in ufunctions macro with the parma.
    let firstParam = classParam.chainNone(()=>fields.head()).getOrRaise("Class not found. Please use the ufunctions macr and specify the type there if you are trying to define a static function. Otherwise, you can also set the type as first argument")
    let className = firstParam.uePropType.removeLastLettersIfPtr()
    
    
    let returnParam = formalParamsNode #for being void it can be empty or void
                        .first(n=>n.kind in [nnkIdent, nnkBracketExpr])
                        .flatMap((n:NimNode)=>(if n.kind==nnkIdent and n.strVal()=="void": none[NimNode]() else: some(n)))
                        .map(n=>makeFieldAsUPropReturnParam("returnValue", n.repr.strip(), typeName, CPF_Parm | CPF_ReturnParm | CPF_OutParm))
    let actualParams = classParam.map(n=>fields) #if there is class param, first param would be use as actual param
                                 .get(fields.tail()) & returnParam.map(f => @[f]).get(@[])
    
    
    var flagMetas = getFunctionFlags(fn, functionsMetadata & fields.mapIt(it.metadata).flatten()) #default param values
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

func getFieldIdent*(prop:UEField) : NimNode = 
  let fieldName = ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1)).nimToCppConflictsFreeName()
  identPublic fieldName


func getFieldIdentWithPCH*(typeDef: UEType, prop:UEField, isImportCpp: bool = false) : NimNode =  
  let fieldName = ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1)).nimToCppConflictsFreeName()    
  if typeDef.isInPCH and isImportCpp:           
    nnkPragmaExpr.newTree(
      identPublic fieldName,
      nnkPragma.newTree(
        nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode(prop.name))))                                    
  else:
    getFieldIdent(prop)

#UEEMit
func fromNinNodeToMetadata*(node : NimNode) : seq[UEMetadata] =
    case node.kind:
    of nnkIdent:
        @[makeUEMetadata(node.strVal())]
    of nnkExprEqExpr:
        let key = node[0].strVal()
        case node[1].kind:
        of nnkIdent, nnkStrLit:
            @[makeUEMetadata(key, node[1].strVal())]
        of nnkTupleConstr: #Meta=(MetaVal1, MetaVal2)
            @[makeUEMetadata(key, node[1][0].strVal()),
              makeUEMetadata(key, node[1][1].strVal())]
        else:
            error("Invalid metadata node " & repr node)
            @[]
    of nnkAsgn:
        @[makeUEMetadata(node[0].strVal(), node[1].strVal())]
    else:
        debugEcho treeRepr node
        error("Invalid metadata node " & repr node)
        @[]

#iterate childrens and returns a sequence fo them
func childrenAsSeq*(node:NimNode) : seq[NimNode] =
    var nodes : seq[NimNode] = @[]
    for n in node:
        nodes.add n
    nodes
    
 

func getMetasForType*(body:NimNode) : seq[UEMetadata] {.compiletime.} = 
    body.toSeq()
        .filterIt(it.kind==nnkPar or it.kind == nnkTupleConstr)
        .mapIt(it.children.toSeq())
        .flatten()
        .filterIt(it.kind!=nnkExprColonExpr)
        .map(fromNinNodeToMetadata)
        .flatten()

#some metas (so far only uprops)
#we need to remove some metas that may be incorrectly added as flags
#The issue is that some flags require some metas to be set as well
#so this is were they are synced
func fromStringAsMetaToFlag(meta:seq[string], preMetas:seq[UEMetadata], ueTypeName:string) : (EPropertyFlags, seq[UEMetadata]) = 
    var flags : EPropertyFlags = CPF_NativeAccessSpecifierPublic
    var metadata : seq[UEMetadata] = preMetas
    
    #TODO THROW ERROR WHEN NON MULTICAST AND USE MC ONLY
    # var flags : EPropertyFlags = CPF_None
    #TODO a lot of flags are mutually exclusive, this is a naive way to go about it
    #TODO all the bodies simetric with funcs and classes (at least the signature is)
    for m in metadata.mapIt(it.name):
        if m == "BlueprintReadOnly":
            flags = flags | CPF_BlueprintVisible | CPF_BlueprintReadOnly
        if m == "BlueprintReadWrite":
            flags = flags | CPF_BlueprintVisible

        if m in ["EditAnywhere", "VisibleAnywhere"]:
          flags = flags | CPF_Edit
        if m == "ExposeOnSpawn":
          flags = flags | CPF_ExposeOnSpawn
        if m == "VisibleAnywhere": 
          flags = flags | CPF_DisableEditOnInstance
        if m == "Transient":
          flags = flags | CPF_Transient
        if m == "BlueprintAssignable":
          flags = flags | CPF_BlueprintAssignable | CPF_BlueprintVisible
        if m == "BlueprintCallable":
          flags = flags | CPF_BlueprintCallable
        if m == "Replicated" or m == "ReplicatedUsing":
          flags = flags | CPF_Net
        if m == "ReplicatedUsing":
          flags = flags | CPF_RepNotify
        if m.toLower() == "config":
                flags = flags | CPF_Config  
        if m.toLower() == InstancedMetadataKey.toLower():
                flags = flags | CPF_ContainsInstancedReference
                metadata.add makeUEMetadata("EditInline")
            #Notice this is only required in the unlikely case that the user wants to use a delegate that is not exposed to Blueprint in any way
        #TODO CPF_BlueprintAuthorityOnly is only for MC
    
    let flagsThatShouldNotBeMeta = ["config", "BlueprintReadOnly", "BlueprintWriteOnly", "BlueprintReadWrite", "EditAnywhere", "VisibleAnywhere", "Transient", "BlueprintAssignable", "BlueprintCallable"]
    for f in flagsThatShouldNotBeMeta:
        metadata = metadata.filterIt(it.name.toLower() != f.toLower())

  

    if not metadata.any(m => m.name == CategoryMetadataKey):
       metadata.add(makeUEMetadata(CategoryMetadataKey, ueTypeName.removeFirstLetter()))

      #Attach accepts a second parameter which is the socket
    if metadata.filterIt(it.name == AttachMetadataKey).len > 1:
        let (attachs, metas) = metadata.partition((m:UEMetadata) => m.name == AttachMetadataKey)
        metadata = metas & @[attachs[0], makeUEMetadata(SocketMetadataKey, attachs[1].value)]
    (flags, metadata)

const ValidUprops* = ["uprop", "uprops", "uproperty", "uproperties"]
const ValidUFuncs* = ["ufunc", "ufuncs", "ufunction", "ufunctions"]

func fromUPropNodeToField(node : NimNode, ueTypeName:string) : seq[UEField] = 

    let validNodesForMetas = [nnkIdent, nnkExprEqExpr]
    let metasAsNodes = node.childrenAsSeq()
                    .filterIt(it.kind in validNodesForMetas or (it.kind == nnkIdent and it.strVal().toLower() notin ValidUprops))
    let ueMetas = metasAsNodes.map(fromNinNodeToMetadata).flatten().tail()
    let metas = metasAsNodes
                    .filterIt(it.kind == nnkIdent)
                    .mapIt(it.strVal())
                    .fromStringAsMetaToFlag(ueMetas, ueTypeName)


    proc nodeToUEField (n: NimNode)  : seq[UEField] = #TODO see how to get the type implementation to discriminate between uProp and  uDelegate
        let fieldNames = 
            case n[0].kind:
            of nnkIdent:
                @[n[0].strVal()]
            of nnkTupleConstr:
                n[0].children.toSeq().filterIt(it.kind == nnkIdent).mapIt(it.strVal())
              
            else:
                error("Invalid node for field " & repr(n) & " " & $ n.kind)
                @[]

        proc makeUEFieldFromFieldName(fieldName:string) : UEField = 
            var fieldName = fieldName
            #stores the assignment but without the first ident on the dot expression as we dont know it yet
            func prepareAssignmentForLaterUsage(propName:string, right:NimNode) : NimNode = #to show intent
                nnkAsgn.newTree(
                    nnkDotExpr.newTree( #left
                        #here goes the var sets when generating the constructor, i.e. self, this what ever the user wants
                        ident propName
                    ), 
                    right
                )
            let assignmentNode = n[1].children.toSeq()
                                    .first(n=>n.kind == nnkAsgn)
                                    .map(n=>prepareAssignmentForLaterUsage(fieldName, n[^1]))

            var propType = if assignmentNode.isSome(): n[1][0][0].repr 
                        else: 
                            case n.kind:
                            of nnkIdent: n[1].repr.strip() #regular prop
                            of nnkCall:          
                                repr(n[^1][0]).strip() #(prop1,.., propn) : type
                            else: 
                                error("Invalid node for field " & repr(n) & " " & $ n.kind)
                                ""
            assignmentNode.run (n:NimNode) => addPropAssignment(ueTypeName, n)
            
            if isMulticastDelegate propType:
                makeFieldAsUPropMulDel(fieldName, propType, ueTypeName, metas[0], metas[1])
            elif isDelegate propType:
                makeFieldAsUPropDel(fieldName, propType, ueTypeName, metas[0], metas[1])
            else:
                makeFieldAsUProp(fieldName, propType, ueTypeName, metas[0], metas[1])
        
        fieldNames.map(makeUEFieldFromFieldName)
    #TODO Metas to flags
    let ueFields = node.childrenAsSeq()
                   .filter(n=>n.kind==nnkStmtList)
                   .head()
                   .map(childrenAsSeq)
                   .get(@[])
                   .map(nodeToUEField)
                   .flatten()
    ueFields


func getUPropsAsFieldsForType*(body:NimNode, ueTypeName:string) : seq[UEField]  = 
    body.toSeq()
        .filter(n=>n.kind == nnkCall and n[0].strVal().toLower() in ValidUProps)
        .map(n=>fromUPropNodeToField(n, ueTypeName))
        .flatten()
        .reversed()


func getPropAssigments*(typeName: string, selfName: string): NimNode =
  #returns a block with self.prop = prop for all uprops block for a given type
    let selfIdent = ident selfName
    #gets the UEType and expands the assignments for the nodes that has cachedNodes implemented
    func insertReferenceToSelfInAssignmentNode(assgnNode:NimNode) : NimNode = 
        if assgnNode[0].len()==1: #if there is any insert it. Otherwise, replace the existing one (user has a defined a custom constructor)
            assgnNode[0].insert(0, selfIdent)
        else:
            assgnNode[0][0] = selfIdent
        assgnNode

    var assignmentsNode = getPropAssignment(typeName).get(newEmptyNode()) #TODO error

    nnkStmtList.newTree(
        assignmentsNode
            .children
            .toSeq()
            .map(insertReferenceToSelfInAssignmentNode)
    ) 
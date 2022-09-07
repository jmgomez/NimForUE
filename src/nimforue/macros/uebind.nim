import std/[options, strutils,sugar, sequtils,strformat,  genasts, macros, importutils]

when defined codegen:
    type FString = string
    proc extractTypeFromGenericInNimFormat*(str, genericType :string) : string = 
        str.replace(genericType, "").replace("[").replace("]", "")

else:
    include ../unreal/definitions
    import ../utils/ueutils

import ../utils/utils
import ../unreal/coreuobject/[uobjectflags]
import ../typegen/[nuemacrocache, models]



proc getParamsTypeDef(fn:NimNode, params:seq[NimNode], retType: NimNode) : NimNode = 
    # nnkTypeSection.newTree(
    #         nnkTypeDef.newTree(
    #         newIdentNode("Params"),
    #         newEmptyNode(),
    #         nnkObjectTy.newTree(
    #             newEmptyNode(),
    #             newEmptyNode(),
    #             nnkRecList.newTree(
    #                 #params
    #                 retType
    #                 )
    #             )
    #         )
    # )
    let typeDefNodeTree = 
        nnkTypeSection.newTree(
            nnkTypeDef.newTree(
                newIdentNode("Params"),
                newEmptyNode(),
                nnkObjectTy.newTree(
                    newEmptyNode(),
                    newEmptyNode(),
                    nnkRecList.newTree()
                )
            )
        )
    
    for p in params:
        if p[1].kind == nnkVarTy: #removes var for the type definition 
            p[1] = p[1][0]
        typeDefNodeTree[0][2][2].add p

    if retType.kind != nnkEmpty and not retType.eqIdent("void"):
        typeDefNodeTree[0][2][2].add nnkIdentDefs.newTree(ident("toReturn"), retType, newEmptyNode())

    
    return typeDefNodeTree
    
func getParamsInstanceDeclNode(fn:NimNode, params:seq[NimNode]) : NimNode =
     #[
          nnkVarSection.newTree(
        nnkIdentDefs.newTree(
          newIdentNode("parms"),
          newEmptyNode(),
          nnkObjConstr.newTree(
            newIdentNode("Params"),
            nnkExprColonExpr.newTree(
              newIdentNode("param1"),
              newIdentNode("param1")
            ),
            nnkExprColonExpr.newTree(
              newIdentNode("param2"),
              newIdentNode("param2")
            )
          )
        )
     ]#
    let typeDeclTree = nnkVarSection.newTree(
            nnkIdentDefs.newTree(
                newIdentNode("params"),
                newEmptyNode(),
                nnkObjConstr.newTree(newIdentNode("Params")
            )
        )
    )
    # initialize the Params' fields
    for p in params:
        typeDeclTree[0][2].add nnkExprColonExpr.newTree(p[0], p[0])
    return typeDeclTree

#TODO Rewrite this using genAst
#Notice the function is capitalized to follow unreal conventions

macro uebind* (fn : untyped) : untyped = 
    expectKind(fn, RoutineNodes)
    #[ Generates the following based on Fn signature
    proc generatedFunc(executor: UObjectPtr, param1:FString, param2:int) : FString =
        type Params = object 
            param1: FString
            param2: int
            toReturn: FString #Output paramaeters 
        var parms = Params(param1: param1, param2: param2)
        var funcName = makeFString("TestMultipleParams")
        callUFuncOn(executor, funcName, parms.addr, parms.toReturn.addr)
        return params.toReturn
    ]#

    let retType = fn.params[0]
    # skip first arg: UObjectPtr
    let paramsNodesDef = fn.params[2..len(fn.params)-1] 
   
    let paramsTypeDefinitionNode = getParamsTypeDef(fn, paramsNodesDef, retType)
    let paramsInstDeclNode = getParamsInstanceDeclNode(fn, paramsNodesDef)
    

    let parmInFuncCallNode = nnkDotExpr.newTree(newIdentNode("params"), newIdentNode("addr"))


    let funcNameDeclNode = nnkVarSection.newTree(
                                nnkIdentDefs.newTree(
                                newIdentNode("fnName"),
                                newIdentNode("FString"),
                                newLit(($name(fn)).capitalizeAscii())
                                )
            
    )
    let callUFuncNode = nnkCall.newTree(newIdentNode("callUFuncOn"), newIdentNode("obj"), 
                                newIdentNode("fnName"), parmInFuncCallNode)

    let rootNode = nnkStmtList.newTree(paramsTypeDefinitionNode, paramsInstDeclNode, funcNameDeclNode, callUFuncNode)
    if retType.kind != nnkEmpty and not retType.eqIdent("void"): #Add return, move from here
        let paramsReturnNode =  nnkReturnStmt.newTree(
            nnkDotExpr.newTree(
                newIdentNode("params"),
                newIdentNode("toReturn")
            )
        )
        rootNode.add(paramsReturnNode)
    fn.body = rootNode
    # echo fn.repr
    fn


#TODO WHEN DOING THE REFACTOR OF THE MACRO CONSIDER UNIFY IT WITH UEBIND
macro uebindstatic* (className: string, fn : untyped) : untyped = 
    expectKind(fn, RoutineNodes)
    #[ Generates the following based on Fn signature
    proc generatedFunc(param1:FString, param2:int) : FString =
        type Params = object 
            param1: FString
            param2: int
            toReturn: FString #Output paramaeters 
        var parms = Params(param1: param1, param2: param2)
        var funcName = makeFString("TestMultipleParams")
        callUFuncOn(executor, funcName, parms.addr, parms.toReturn.addr)
        return params.toReturn
    ]#
    let instCls = genAst(className):
                    let cls {.inject.} = getClassByName(className)

    let retType = fn.params[0]
    # skip first arg and return type (NOTICE THIS IS DIFFERENT WITH THE UEBIND obj Instnace MACRO)
    let paramsNodesDef = fn.params[1..len(fn.params)-1] 
   
    let paramsTypeDefinitionNode = getParamsTypeDef(fn, paramsNodesDef, retType)
    let paramsInstDeclNode = getParamsInstanceDeclNode(fn, paramsNodesDef)
    

    let parmInFuncCallNode = nnkDotExpr.newTree(newIdentNode("params"), newIdentNode("addr"))


    let funcNameDeclNode = nnkVarSection.newTree(
                                nnkIdentDefs.newTree(
                                newIdentNode("fnName"),
                                newIdentNode("FString"),
                                newLit(($name(fn)).capitalizeAscii())
                                )
            
    )
    let callUFuncNode = nnkCall.newTree(newIdentNode("callUFuncOn"), newIdentNode("cls"), 
                                newIdentNode("fnName"), parmInFuncCallNode)

    let rootNode = nnkStmtList.newTree(paramsTypeDefinitionNode, paramsInstDeclNode, funcNameDeclNode, callUFuncNode)
    if retType.kind != nnkEmpty and not retType.eqIdent("void"): #Add return, move from here
        let paramsReturnNode =  nnkReturnStmt.newTree(
            nnkDotExpr.newTree(
                newIdentNode("params"),
                newIdentNode("toReturn")
            )
        )
        rootNode.add(paramsReturnNode)
    fn.body = rootNode
    fn

        

func isReturnParam*(field:UEField) : bool = (CPF_ReturnParm in field.propFlags)
func isOutParam*(field:UEField) : bool = (CPF_OutParm in field.propFlags)


#Converts a UEField type into a NimNode (useful when dealing with generics)
func getTypeNodeFromUProp*(prop : UEField) : NimNode = 
    #naive check on generic types:
    case prop.kind:
        of uefProp:
            let typeNode =  if not prop.isGeneric: ident prop.uePropType
                elif prop.uePropType.countSubStr("[") == 2:
                    let outerGeneric = prop.uePropType.split("[")[0]
                    let innerGeneric = prop.uePropType.split("[")[1].split("[")[0]
                    let innerTypesStr = prop.uePropType.extractTypeFromGenericInNimFormat(outerGeneric, innerGeneric)
                    let innerTypes = innerTypesStr.split(",").map(innerType => ident(innerType.strip()))
                    nnkBracketExpr.newTree(ident outerGeneric, 
                                nnkBracketExpr.newTree((ident innerGeneric) & innerTypes))
                else:
                    let genericType = prop.uePropType.split("[")[0]
                    let innerTypesStr =  prop.uePropType.extractTypeFromGenericInNimFormat(genericType)
                    let innerTypes = innerTypesStr.split(",").map(innerType => ident(innerType.strip()))
                    nnkBracketExpr.newTree((ident genericType) & innerTypes)
            if prop.isOutParam:
                nnkVarTy.newTree typeNode
            else:
                typeNode
            # debugEcho repr typeNode


        else:
            newEmptyNode()

# func getTypeNodeFromUProp*(ueTypeProp : string) : NimNode = getTypeNodeFromUProp(UEField(kind:uefProp, uePropType:ueTypeProp))
   


func getTypeNodeForReturn(prop: UEField, typeNode : NimNode) : NimNode = 
    if prop.shouldBeReturnedAsVar():
        return nnkVarTy.newTree(typeNode)
    typeNode


func identWithInjectAnd(name:string, pragmas:seq[string]) : NimNode = 
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

func identWithInject*(name:string) : NimNode = 
    nnkPragmaExpr.newTree([
        ident name,
        nnkPragma.newTree(ident "inject")])

func identWrapper*(name:string) : NimNode = ident(name) #cant use ident as argument
func identPublic*(name:string) : NimNode = nnkPostfix.newTree([ident "*", ident name])



func genProp(typeDef : UEType, prop : UEField) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
  
    let className = typeDef.name.substr(1)

    let typeNode = case prop.kind:
                    of uefProp: getTypeNodeFromUProp(prop)
                    else: newEmptyNode() #No Support 
    let typeNodeAsReturnValue = case prop.kind:
                            of uefProp: prop.getTypeNodeForReturn(typeNode)
                            else: newEmptyNode()#No Support as UProp getter/Seter
    
    
    let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)) 

    # debugEcho treeRepr typeNodeAsReturnValue
    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, typeNodeAsReturnValue):
            proc propIdent* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue =
                let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
                getPropertyValuePtr[typeNode](prop, obj)[]
            
            proc `propIdent=`* (obj {.inject.} : ptrName, val {.inject.} :typeNode) = 
                var value {.inject.} : typeNode = val
                let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
                setPropertyValuePtr[typeNode](prop, obj, value.addr)
   


#helper func used in geneFunc and genParamsInsideFunc
#returns for each param a type definition node
#the functions that it receives as param is used with ident/identWithInject/ etc. to make fields public or injected
#isGeneratingType 
func signatureAsNode(funField:UEField, identFn : string->NimNode) : seq[NimNode] =  
    case funField.kind:
    of uefFunction: 
       return funField.signature
            .filter(prop=>not isReturnParam(prop))
            .map(param=>
                [identFn(param.name.firstToLow()), param.getTypeNodeFromUProp(), newEmptyNode()])
            .map(n=>nnkIdentDefs.newTree(n))
    else:
        error("funField: not a func")

func genParamInFnBodyAsType(funField:UEField) : NimNode = 
    let returnProp = funField.signature.filter(isReturnParam).head()
    #make sure we remove the out flag so we dont emit var on type variables which is not allowed
    var i = 0
    var funField = funField
    while i<len funField.signature:
        if  funField.signature[i].isOutParam:
            funField.signature[i].propFlags = CPF_None #remove out flag before the signatureCall, cant do and for some reason. Maybe a bug?
        inc i

    let paramsInsideFuncDef = nnkTypeSection.newTree([nnkTypeDef.newTree([identWithInject "Params", newEmptyNode(), 
                            nnkObjectTy.newTree([
                                newEmptyNode(), newEmptyNode(),  
                                nnkRecList.newTree(
                                    funField.signatureAsNode(identWrapper) &
                                    returnProp.map(prop=>
                                        @[nnkIdentDefs.newTree([ident("toReturn"), 
                                                            ident prop.uePropType, 
                                                            newEmptyNode()])]).get(@[])
                                )])
                        ])])

    
    paramsInsideFuncDef

func isStatic*(funField:UEField) : bool = (FUNC_Static in funField.fnFlags)
func getReturnProp*(funField:UEField) : Option[UEField] =  funField.signature.filter(isReturnParam).head()
func doesReturn*(funField:UEField) : bool = funField.getReturnProp().isSome()

func genParamInFunctionSignature(typeDef : UEType, funField:UEField, firstParamName:string) : NimNode = #returns (obj:UObjectPr, param:Fstring..) : FString 
#notice the first part has to be introduced. see the final part of genFunc
    let ptrName = ident typeDef.name & (if typeDef.kind == uetDelegate: "" else: "Ptr") #Delegate dont use pointers

    let returnType =    if funField.doesReturn():
                            ident funField.getReturnProp().get().uePropType
                        else:
                            ident "void"


    let objType = if typeDef.kind == uetDelegate:
                        nnkVarTy.newTree(ptrName)
                    else:
                        ptrName
    nnkFormalParams.newTree(
                    @[returnType] &
                    (if funField.isStatic(): @[] 
                    else: @[nnkIdentDefs.newTree([identWithInject firstParamName, objType, newEmptyNode()])]) &  
                    funField.signatureAsNode(identWithInject))

#this is used for both, to generate regular function binds and delegate broadcast/execute functions
#for the most part the same code is used for both
#this is also used for native function implementation but the ast is changed afterwards
func genFunc*(typeDef : UEType, funField : UEField) : NimNode = 
    

    let ptrName = ident typeDef.name & (if typeDef.kind == uetDelegate: "" else: "Ptr") #Delegate dont use pointers
    let isStatic = FUNC_Static in funField.fnFlags
    let clsName = typeDef.name.substr(1)

    let fnParams = genParamInFunctionSignature(typeDef, funField, "obj")
    # let pragmas = nnkPragma.newTree([ident "inject"])
    let generateObjForStaticFunCalls = 
        if isStatic: 
            genAst(clsName=newStrLitNode(clsName)): 
                let obj {.inject.} = getDefaultObjectFromClassName(clsName)
        else: newEmptyNode()

    
    let callUFuncOn = 
        case typeDef.kind:
        of uetDelegate:
            case typeDef.delKind:
                of uedelDynScriptDelegate:
                    genAst(): obj.processDelegate(param.addr)
                of uedelMulticastDynScriptDelegate:
                    genAst(): obj.processMulticastDelegate(param.addr)
        else: genAst(): callUFuncOn(obj, fnName, param.addr)



    let returnCall = if funField.doesReturn(): 
                        genAst(): 
                            return param.toReturn 
                     else: newEmptyNode()
    let paramInsideBodyAsType = genParamInFnBodyAsType(funField)
    let paramObjectConstrCall = nnkObjConstr.newTree(@[ident "Params"] &  #creates Params(param0:param0, param1:param1)
                                funField.signature
                                    .filter(prop=>not isReturnParam(prop))
                                    .map(param=>ident(param.name.firstToLow()))
                                    .map(param=>nnkExprColonExpr.newTree(param, param))
                            )
    let paramDeclaration = nnkVarSection.newTree(nnkIdentDefs.newTree([identWithInject "param", newEmptyNode(), paramObjectConstrCall]))
    
    var fnBody = genAst(uFnName=newStrLitNode(funField.name), paramInsideBodyAsType, paramDeclaration, generateObjForStaticFunCalls, callUFuncOn, returnCall):
        paramInsideBodyAsType
        paramDeclaration
        var fnName {.inject, used .} : FString = uFnName
        generateObjForStaticFunCalls
        callUFuncOn
        returnCall
        

    
    # return newEmptyNode()

    result = nnkProcDef.newTree([
                            identPublic funField.name.firstToLow(), 
                            newEmptyNode(), newEmptyNode(), 
                            fnParams, 
                            newEmptyNode(), newEmptyNode(),
                            fnBody
                        ])

    

    # debugEcho repr result
    # debugEcho treeRepr result




func genUClassTypeDef(typeDef : UEType) : NimNode =
    let ptrName = ident typeDef.name & "Ptr"
    let parent = ident typeDef.parent
    let props = nnkStmtList.newTree(
                typeDef.fields
                    .filter(prop=>prop.kind==uefProp)
                    .map(prop=>genProp(typeDef, prop)))

    let funcs = nnkStmtList.newTree(
                    typeDef.fields
                       .filter(prop=>prop.kind==uefFunction)
                       .map(fun=>genFunc(typeDef, fun)))
    
    result = 
        genAst(name = ident typeDef.name, ptrName, parent, props, funcs):
                type 
                    name* {.inject.} = object of parent #TODO OF BASE CLASS 
                    ptrName* {.inject.} = ptr name
                props
                funcs
    # if result.repr.contains("AActorDsl"):
    #     debugEcho result.repr

func genUStructTypeDef(typeDef: UEType) : NimNode =   
    let typeName = identWithInjectPublic typeDef.name
    #TODO Needs to handle TArray/Etc. like it does above with classes
    let fields = typeDef.fields
                        .map(prop => nnkIdentDefs.newTree(
                            [identPublic toLower($prop.name[0])&prop.name.substr(1), 
                             prop.getTypeNodeFromUProp(), newEmptyNode()]))
                        .foldl(a.add b, nnkRecList.newTree)
#   let fields = typeDef.fields
#                         .map(prop => nnkIdentDefs.newTree(
#                             [identPublic toLower($prop.name[0])&prop.name.substr(1), 
#                              ident prop.uePropType, newEmptyNode()]))
#                         .foldl(a.add b, nnkRecList.newTree)

    result = genAst(typeName, fields):
                type typeName = object
    result[0][^1] = nnkObjectTy.newTree([newEmptyNode(), newEmptyNode(), fields])
    # debugEcho result.repr
    # debugEcho result.treeRepr

func genUEnumTypeDef(typeDef:UEType) : NimNode = 
    let typeName = ident(typeDef.name)
    let fields = typeDef.fields
                        .map(f => ident f.name)
                        .foldl(a.add b, nnkEnumTy.newTree)
    fields.insert(0, newEmptyNode()) #required empty node in enums

    result = genAst(typeName, fields):
                type typeName* {.inject, size:sizeof(uint8).} = enum         
                    fields
    
    result[0][^1] = fields #replaces enum 


proc genDelType(delType:UEType) : NimNode = 
    #NOTE delegates are always passed around as reference
    #adds the delegate to the global list of available delegates so we can lookup it when emitting the UCLass
    addDelegateToAvailableList(delType)
    let typeName = identWithInjectPublic delType.name
   
    let delBaseType = 
        case delType.delKind 
        of uedelDynScriptDelegate: ident "FScriptDelegate"
        of uedelMulticastDynScriptDelegate: ident "FMulticastScriptDelegate"
    let broadcastFnName = 
        case delType.delKind 
        of uedelDynScriptDelegate: "execute"
        of uedelMulticastDynScriptDelegate: "broadcast"

    let typ = genAst(typeName, delBaseType):
            type
                typeName = object of delBaseType
    let broadcastFunType = UEField(name:broadcastFnName, kind:uefFunction, signature: delType.fields)
    let funcNode = genFunc(delType, broadcastFunType) 
    result = nnkStmtList.newTree(typ, funcNode)
   
    
    # debugEcho repr result
    # debugEcho treeRepr result
    

proc genTypeDecl*(typeDef : UEType) : NimNode = 
    case typeDef.kind:
        of uetClass:
            genUClassTypeDef(typeDef)
        of uetStruct:
            genUStructTypeDef(typeDef)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate:
            genDelType(typeDef)

proc genModuleDecl*(moduleDef:UEModule) : NimNode = 
    nnkStmtList.newTree(moduleDef.types.map(genTypeDecl))
    
#notice this is only for testing ATM the final shape probably wont be like this
macro genUFun*(className : static string, funField : static UEField) : untyped =
    let ueType = UEType(name:className, kind:uetClass) #Notice it only looks for the name and the kind (delegates)
    genFunc(ueType, funField)
        
macro genType*(typeDef : static UEType) : untyped = genTypeDecl(typeDef)
    


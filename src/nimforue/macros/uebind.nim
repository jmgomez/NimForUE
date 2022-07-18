{.experimental: "caseStmtMacros".}
include ../unreal/definitions
import std/[options, strutils,sugar, sequtils,strformat,  genasts, macros, importutils]
import ../utils/[ueutils, utils]
import ../unreal/coreuobject/[uobjectflags]
import ../typegen/models

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



    

#  IdentDefs
#             Ident "regularProperty"
#             Ident "int32"
#             Empty
#           IdentDefs
#             Ident "genericProp"
#             BracketExpr
#               Ident "TArray"
#               Ident "FString"

func getTypeNodeFromUProp(prop : UEField) : NimNode = 
    #naive check on generic types:
    case prop.kind:
        of uefProp:
            let supportedGenericTypes = ["TArray", "TSubclassOf", "TSoftObjectPtr", "TMap"]
            if not prop.isGeneric:
                return ident prop.uePropType
            let genericType = prop.uePropType.split("[")[0]
            let innerTypesStr =  prop.uePropType.extractTypeFromGenericInNimFormat(genericType)
            let innerTypes = innerTypesStr.split(",").map(innerType => ident(innerType.strip()))
            let bracketsNode = nnkBracketExpr.newTree((ident genericType) & innerTypes)
            return bracketsNode
        else:
            newEmptyNode()




func getTypeNodeForReturn(prop: UEField, typeNode : NimNode) : NimNode = 
    if prop.shouldBeReturnedAsVar():
        return nnkVarTy.newTree(typeNode)
    typeNode

#[
    Generates a new delegate type based on the Name and DelegateType
    - [ ] Generates a broadcast/execute function for that type based on the Signature of the Delegate
        - [x] Almost there have to work on the signature.
        - [ ] Generalize it enough so it can work FScriptDelegates (first refactor UEProperty so all the info is there)

    - [ ] The getter and setter should use that function (this is already done?)

    - [ ] Generates and add dynamic/bind functio based on the signature
]#

func identWithInjectAnd(name:string, pragmas:seq[string]) : NimNode = 
    nnkPragmaExpr.newTree(
        [
            ident name, 
            nnkPragma.newTree((@["inject"] & pragmas).map( x => ident x))
        ]
        )
func identWithInjectPublic(name:string) : NimNode = 
    nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident name]),
        nnkPragma.newTree(ident "inject")])

func identWithInject(name:string) : NimNode = 
    nnkPragmaExpr.newTree([
        ident name,
        nnkPragma.newTree(ident "inject")])

func identWrapper(name:string) : NimNode = ident(name) #cant use ident as argument
func identPublic(name:string) : NimNode = nnkPostfix.newTree([ident "*", ident name])

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
                let prop {.inject.} = getClassByName(className).getFPropertyByName propUEName
                getPropertyValuePtr[typeNode](prop, obj)[]
            
            proc `propIdent=`* (obj {.inject.} : ptrName, val {.inject.} :typeNode) = 
                var value {.inject.} : typeNode = val
                let prop {.inject.} = getClassByName(className).getFPropertyByName propUEName
                setPropertyValuePtr[typeNode](prop, obj, value.addr)
   
        

func isReturnParam(field:UEField) : bool = (CPF_ReturnParm in field.propFlags)

#this is used for both, to generate regular function binds and delegate broadcast/execute functions
#for the most part the same code is used for both
func genFunc(typeDef : UEType, funField : UEField) : NimNode = 
    let ptrName = ident typeDef.name & (if typeDef.kind == uetDelegate: "" else: "Ptr") #Delegate dont use pointers
    let isStatic = FUNC_Static in funField.fnFlags
    let clsName = typeDef.name.substr(1)

    let funReturns = funField.signature
                                .filter(isReturnParam)
                                .head()
                                .isSome()
    
    let signatureAsNode = (identFn : string->NimNode) => 
                                funField.signature
                                        # .tap((param:UEField) => (debugEcho fmt"Name: {param.name} flag Value: {$uint64(param.propFlags)} is return: {isReturnParam(param)}"))
                                        .filter(prop=>not isReturnParam(prop))
                                        .map(param=>[identFn(param.name.firstToLow()), ident param.uePropType, newEmptyNode()])
                                        .map(n=>nnkIdentDefs.newTree(n))

    let returnProp = funField.signature.filter(isReturnParam).head()


    let returnType =    if funReturns:
                            #edges cases here
                            ident returnProp.get().uePropType
                        else:
                            ident "void"
    

    let fnParams = nnkFormalParams.newTree(
                        @[returnType] &
                        (if isStatic: @[] 
                        else: @[nnkIdentDefs.newTree([identWithInject "obj", ptrName, newEmptyNode()])]) &  
                        signatureAsNode(identWithInject))
    # let pragmas = nnkPragma.newTree([ident "inject"])
    let generateObjForStaticFunCalls = 
        if isStatic: 
            genAst(clsName=newStrLitNode(clsName)): 
                let obj {.inject.} = getDefaultObjectFromClassName(clsName)
        else: newEmptyNode()

    let paramsInsideFuncDef = nnkTypeSection.newTree([nnkTypeDef.newTree([identWithInject "Params", newEmptyNode(), 
                                nnkObjectTy.newTree([
                                    newEmptyNode(), newEmptyNode(),  
                                    nnkRecList.newTree(
                                        signatureAsNode(identWrapper) &
                                        
                                        returnProp.map(prop=>
                                            @[nnkIdentDefs.newTree([ident("toReturn"), 
                                                                ident prop.uePropType, 
                                                                newEmptyNode()])]).get(@[])
                                    )])
                            ])])

    let paramObjectConstrCall = nnkObjConstr.newTree(@[ident "Params"] &  #creates Params(param0:param0, param1:param1)
                                funField.signature
                                    .filter(prop=>not isReturnParam(prop))
                                    .map(param=>ident(param.name.firstToLow()))
                                    .map(param=>nnkExprColonExpr.newTree(param, param))
                            )

    let paramDeclaration = nnkVarSection.newTree(nnkIdentDefs.newTree([identWithInject "param", newEmptyNode(), paramObjectConstrCall]))
    
    let callUFuncOn = 
        case typeDef.kind:
        of uetDelegate:
            case typeDef.delKind:
                of uedelDynScriptDelegate:
                    genAst(): obj.processDelegate(param.addr)
                of uedelMulticastDynScriptDelegate:
                    genAst(): obj.processMulticastDelegate(param.addr)
        else: genAst(): callUFuncOn(obj, fnName, param.addr)



    let returnCall = if funReturns: 
                        genAst(): 
                            return param.toReturn 
                     else: newEmptyNode()

    var fnBody = genAst(uFnName=newStrLitNode(funField.name), paramsInsideFuncDef, paramDeclaration, generateObjForStaticFunCalls, callUFuncOn, returnCall):
        paramsInsideFuncDef
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




proc genUClassTypeDef(typeDef : UEType) : NimNode =
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


func genDelType(delType:UEType) : NimNode = 
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
                type typeName = object of delBaseType
    let broadcastFunType = UEField(name:broadcastFnName, kind:uefFunction, signature: delType.fields)
    let funcNode = genFunc(delType, broadcastFunType) 
    result = nnkStmtList.newTree(typ, funcNode)
    debugEcho repr result
    

func genTypeDecl*(typeDef : UEType) : NimNode = 
    case typeDef.kind:
        of uetClass:
            genUClassTypeDef(typeDef)
        of uetStruct:
            genUStructTypeDef(typeDef)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate:
            genDelType(typeDef)
        
macro genType*(typeDef : static UEType) : untyped = genTypeDecl(typeDef)
    



# macro genDelegate*(field:static UEField) : untyped = 
#     result = genDelegateType(field).get()
#     echo result.repr


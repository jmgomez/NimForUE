{.experimental: "caseStmtMacros".}

import std/[options, strutils,sugar, sequtils, genasts, macros]
import ../utils/sequtils as sequtils2

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
    # echo fn.repr
    fn



# macro bindprop(body:untyped) : untyped =
#     echo treeRepr body
#     result = body


macro bindprop(body:untyped) : untyped = 
    # body
    echo treeRepr(body)
    result = body
    
type FuncTest = object 
    name : string 


proc genFun(funcDef : FuncTest) : NimNode = 
    result = 
        genAst(name = ident funcDef.name):
            proc name (param: int, param2: int) : void  = discard 2
    

type
    UETypeKind* = enum
        uClass
    
    UEProperty* = object
        name* : string
        kind* : string #Do a close set of types

    UEType* = object 
        name* : string 
        parent* : string
        kind* : UETypeKind
        properties* : seq[UEProperty]

#  IdentDefs
#             Ident "regularProperty"
#             Ident "int32"
#             Empty
#           IdentDefs
#             Ident "genericProp"
#             BracketExpr
#               Ident "TArray"
#               Ident "FString"

func getTypeNodeFromProp(prop : UEProperty) : NimNode = 
    #naive check on generic types:
    let supportedGenericTypes = ["TArray", "TSubclassOf", "TSoftObjectPtr", "TMap"]
    let genType = supportedGenericTypes.filter(genType => genType in prop.kind).head()
    if not genType.isSome():
        return ident prop.kind
    let genericType = genType.get()

    let innerTypesStr = prop.kind.replace(genericType, "").replace("[").replace("]", "")
    let innerTypes = innerTypesStr.split(",").map(innerType => ident(innerType.strip()))
    let bracketsNode = nnkBracketExpr.newTree((ident genericType) & innerTypes)
    bracketsNode

func getTypeNodeForReturn(prop: UEProperty, typeNode : NimNode) : NimNode = 
    let shouldBeReturnedAsRef = ["TMap"]
    let genType = shouldBeReturnedAsRef.filter(genType => genType in prop.kind).head()
    if not genType.isSome():
        return typeNode
    nnkVarTy.newTree(typeNode)



proc genProp(typeDef : UEType, prop : UEProperty) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
    let className = typeDef.name.substr(1)
    let typeNode = getTypeNodeFromProp(prop)
    let typeNodeAsReturnValue = getTypeNodeForReturn(prop, typeNode)
    var propName = prop.name 
    propName[0] = propName[0].toLowerAscii()
    let propIdent = ident propName
    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, typeNodeAsReturnValue):
            proc propIdent (obj {.inject.} : ptrName ) : typeNodeAsReturnValue =
                let prop {.inject.} = getClassByName(className).getFPropertyByName propUEName
                getPropertyValuePtr[typeNode](prop, obj)[]
            
            proc `propIdent=` (obj {.inject.} : ptrName, val {.inject.} :typeNode) = 
                var value {.inject.} : typeNode = val
                let prop {.inject.} = getClassByName(className).getFPropertyByName propUEName
                setPropertyValuePtr[typeNode](prop, obj, value.addr)





proc genUETypeDef(typeDef : UEType) : NimNode =
    let ptrName = ident typeDef.name & "Ptr"
    let parent = ident typedef.parent
    let props = nnkStmtList.newTree(typeDef.properties.map(prop=>genProp(typeDef, prop)))
    result = 
        genAst(name = ident typeDef.name, ptrName, parent, props):
                type 
                    name {.inject.} = object of parent #TODO OF BASE CLASS 
                    ptrName {.inject.} = ptr name
                props


macro genType*(typeDef : static UEType) : untyped = 
    result = genUETypeDef(typeDef)
    # echo result.repr


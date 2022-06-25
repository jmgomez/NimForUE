{.experimental: "caseStmtMacros".}

import std/[options, strutils,sugar, sequtils, genasts, macros]
import ../utils/utils
import ../unreal/coreuobject/[uobject, uobjectflags]
include ../unreal/definitions

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
    echo fn.repr
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

    UEFieldKind* = enum
        uefProp, #this covers FString, int, TArray, etc. 
        uefDelegate,
        uefFunction

    UEDelegateKind* = enum
        uedelDynScriptDelegate,
        uedelMulticastDynScriptDelegate

    UEField* = object
        name* : string

        case kind*: UEFieldKind
            of uefProp:
                uePropType* : string #Do a close set of types? No, just do a close set on the MetaType. i.e Struct, TArray, Delegates (they complicate things)
                isGeneric* : bool
                returnAsVar* : bool #if it should append var on the return type when generating the getter
                propFlags*:EPropertyFlags

            of uefDelegate:
                delegateSignature*: seq[string] #this could be set as FScriptDelegate[String,..] but it's probably clearer this way
                delKind*: UEDelegateKind
                #delFlags? Specific propFlags

            of uefFunction:
                #note cant use option type. If it has a returnParm it will be the first param that has CPF_ReturnParm
                signature* : seq[UEField]
                fnFlags* : EFunctionFlags
              
               

    UEType* = object 
        name* : string 
        parent* : string
        kind* : UETypeKind
        fields* : seq[UEField]

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

            let innerTypesStr = prop.uePropType.replace(genericType, "").replace("[").replace("]", "")
            let innerTypes = innerTypesStr.split(",").map(innerType => ident(innerType.strip()))
            let bracketsNode = nnkBracketExpr.newTree((ident genericType) & innerTypes)
            return bracketsNode
        else:
            newEmptyNode()


func isDelegate(prop : UEField) : bool = prop.kind == uefDelegate


func getTypeNodeForReturn(prop: UEField, typeNode : NimNode) : NimNode = 
    let shouldBeReturnedAsRef = ["TMap"]
    # let genType = shouldBeReturnedAsRef.filter(genType => genType in prop.kind or prop.isDelegate()).head()
    if prop.kind == uefDelegate or prop.returnAsVar:
        return nnkVarTy.newTree(typeNode)
    return typeNode

#[
    Generates a new delegate type based on the Name and DelegateType
    - [ ] Generates a broadcast/execute function for that type based on the Signature of the Delegate
        - [x] Almost there have to work on the signature.
        - [ ] Generalize it enough so it can work FScriptDelegates (first refactor UEProperty so all the info is there)

    - [ ] The getter and setter should use that function (this is already done?)

    - [ ] Generates and add dynamic/bind functio based on the signature
]#

func identWithInject(name:string) : NimNode = nnkPragmaExpr.newTree([ident name,nnkPragma.newTree(ident "inject")])
func identWrapper(name:string) : NimNode = ident(name) #cant use ident as argument

proc genDelegateType(prop : UEField) : Option[NimNode] = 
    if not prop.isDelegate():
        return none[NimNode]()

    let delTypeName = ident "F" & prop.name 

    let signatureAsNode = (identFn : string->NimNode) => prop.delegateSignature
                              .mapi((typeName, idx)=>[identFn("param" & $idx), ident typeName, newEmptyNode()])
                              .map(n=>nnkIdentDefs.newTree(n))
    #i.e. execute/broadcast
    let fnParams = nnkFormalParams.newTree(
                        @[ident "void",  #return type
                        nnkIdentDefs.newTree(
                            [identWithInject "dynDel", (delTypeName), newEmptyNode()]
                            ) 
                        ] & signatureAsNode(identWithInject))
    #
    let paramsInsideBroadcastDef = nnkTypeSection.newTree([nnkTypeDef.newTree([identWithInject "Params", newEmptyNode(), 
                                nnkObjectTy.newTree([newEmptyNode(), newEmptyNode(),  
                                    nnkRecList.newTree(signatureAsNode(identWrapper))])
                            ])])
    let paramObjectConstr = nnkObjConstr.newTree(@[ident "Params"] &  #creates Params(param0:param0, param1:param1)
                                prop.delegateSignature
                                    .mapi((x, idx)=>ident("param" & $idx)) 
                                    .map(param=>nnkExprColonExpr.newTree(param, param))
                            )

    let paramDeclaration = nnkVarSection.newTree(nnkIdentDefs.newTree([identWithInject "param", newEmptyNode(), paramObjectConstr]))

    let broadcastFnName = ident (case prop.delKind:
                            of uedelDynScriptDelegate: "execute"
                            of uedelMulticastDynScriptDelegate: "broadcast")
    
    let processFnName = ident (case prop.delKind:
                            of uedelDynScriptDelegate: "processDelegate"
                            of uedelMulticastDynScriptDelegate: "processMulticastDelegate")

    var broadcastFn = nnkProcDef.newTree([broadcastFnName, newEmptyNode(), newEmptyNode(), fnParams, newEmptyNode(), newEmptyNode()])
    let processDelCall = nnkCall.newTree([
                            nnkDotExpr.newTree([ident "dynDel", processFnName]),
                            nnkDotExpr.newTree([ident "param", ident "addr"])
                        ])

    let broadcastBody = genAst(paramsInsideBroadcastDef, paramDeclaration, processDelCall, delTypeName):
        paramsInsideBroadcastDef
        paramDeclaration
        processDelCall

    broadcastFn.add(broadcastBody)

    let delBaseType = ident (case prop.delKind:
                            of uedelDynScriptDelegate: "FScriptDelegate"
                            of uedelMulticastDynScriptDelegate: "FMulticastScriptDelegate")
    
    var delegate = genAst(delTypeName, delBaseType, broadcastFn, paramDeclaration):
        type delTypeName {.inject.} = object of delBaseType
        broadcastFn 
        
    some delegate

proc genProp(typeDef : UEType, prop : UEField) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
    let delTypesNode = genDelegateType(prop)
    let delTypeIdent = delTypesNode.map(n=>n[0][0][0][0])

    let className = typeDef.name.substr(1)

    let typeNode = case prop.kind:
                    of uefProp: getTypeNodeFromUProp(prop)
                    of uefDelegate: delTypeIdent.get()
                    of uefFunction: newEmptyNode() #No Support 
   
    let typeNodeAsReturnValue = case prop.kind:
                            of uefProp: prop.getTypeNodeForReturn(typeNode)
                            of uefDelegate: nnkVarTy.newTree(typeNode)
                            of uefFunction: newEmptyNode() #No Support as UProp getter/Seter
    
    
    let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)) 

   

    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, typeNodeAsReturnValue):
            proc propIdent (obj {.inject.} : ptrName ) : typeNodeAsReturnValue =
                let prop {.inject.} = getClassByName(className).getFPropertyByName propUEName
                getPropertyValuePtr[typeNode](prop, obj)[]
            
            proc `propIdent=` (obj {.inject.} : ptrName, val {.inject.} :typeNode) = 
                var value {.inject.} : typeNode = val
                let prop {.inject.} = getClassByName(className).getFPropertyByName propUEName
                setPropertyValuePtr[typeNode](prop, obj, value.addr)
    if prop.kind == uefDelegate: 
        result.insert(0, delTypesNode.get())
        
    # echo repr result


proc genUETypeDef(typeDef : UEType) : NimNode =
    let ptrName = ident typeDef.name & "Ptr"
    let parent = ident typeDef.parent
    let props = nnkStmtList.newTree(typeDef.fields.map(prop=>genProp(typeDef, prop)))
    result = 
        genAst(name = ident typeDef.name, ptrName, parent, props):
                type 
                    name {.inject.} = object of parent #TODO OF BASE CLASS 
                    ptrName {.inject.} = ptr name
                props


macro genType*(typeDef : static UEType) : untyped = 
    result = genUETypeDef(typeDef)
    # echo result.repr





import macros
{.experimental: "caseStmtMacros".}

import std/[options, strutils]
# import coreutils
import sequtils
import sugar

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


#example declaration    
# proc testFunction(obj:UObjPtr) : void {.uebind.}
# proc testReturnFunction(obj:UObjPtr) : FString {.uebind.}
# proc testParamsFunction(obj:UObjPtr, oneParam:FString, anotherParam:int) : FString {.uebind.}
#Example usage
# var obj : UObjPtr = cast[UObjPtr] (nil)

# echo obj.testReturnFunction()
# obj.testFunction()

# echo obj.testParamsFunction("test", 3)


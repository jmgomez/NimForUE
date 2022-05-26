import macros
import fusion/matching
{.experimental: "caseStmtMacros".}

import std/[options, strutils]
# import coreutils
import sequtils
import sugar

# import ../unreal/core/containers/[ array]

proc getParamsTypeDef(fn:NimNode, params:seq[NimNode], returnType:Option[string]) : NimNode = 
      # nnkTypeSection.newTree(
    #         nnkTypeDef.newTree(
    #         newIdentNode("Params"),
    #         newEmptyNode(),
    #         nnkObjectTy.newTree(
    #             newEmptyNode(),
    #             newEmptyNode(),
    #             nnkRecList.newTree(
    #                 #HERE
    #                 returnType.map(returnParamNode)
    #                           .getOrDefault(newEmptyNode()) 
    #                 )
    #             )
    #         )
    # )
    
    #This can be better expresed for sure
    let returnParamNode = (ret:string) => 
                            nnkIdentDefs.newTree(newIdentNode("toReturn"), newIdentNode(ret),newEmptyNode())
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
        typeDefNodeTree[0][2][2].add p 
    typeDefNodeTree[0][2][2].add(returnType.map(returnParamNode).get(newEmptyNode()))

   
    return typeDefNodeTree
    
func getParamsInstanceDeclNode(fn:NimNode, returnType:Option[string], paramNames:seq[string]) : NimNode =
    #array strings and them 
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
    let paramNodes =  (paramName:string) => nnkExprColonExpr.newTree(newIdentNode(paramName), newIdentNode(paramName))

    let typeDeclTree = nnkVarSection.newTree(
            nnkIdentDefs.newTree(
            newIdentNode("params"),
            newEmptyNode(),
            nnkObjConstr.newTree(newIdentNode("Params")
            
            )
        )
    )
    for paramName in paramNames:
        typeDeclTree[0][2].add paramNodes(paramName)
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
    echo treeRepr fn
    let rootNode = nnkStmtList.newTree()
    let returnType : Option[string] = if (repr fn.params[0]) == "void": none[string]() else: some(repr fn.params[0])

    let paramsNodesDef = fn.params[2..len(fn.params)-1]
    let paramsNames : seq[string]= paramsNodesDef.map(p=>(repr p[0]))
   
    let paramsTypeDefinitionNode = getParamsTypeDef(fn, paramsNodesDef, returnType)
    let paramsInstDeclNode = getParamsInstanceDeclNode(fn, returnType, paramsNames)
    

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

    rootNode.add(paramsTypeDefinitionNode)
    rootNode.add(paramsInstDeclNode)
    rootNode.add(funcNameDeclNode)
    rootNode.add(callUFuncNode)
    if returnType.isSome(): #Add return, move from here
        let paramsReturnNode =  nnkReturnStmt.newTree(
            nnkDotExpr.newTree(
            newIdentNode("params"),
            newIdentNode("toReturn")
            )
        )
        rootNode.add(paramsReturnNode)
    fn.body = rootNode
    echo repr fn
    result = fn


# dumpTree:
#     type Test = seq[string]

#example declaration    
# proc testFunction(obj:UObjPtr) : void {.uebind.}
# proc testReturnFunction(obj:UObjPtr) : FString {.uebind.}
# proc testParamsFunction(obj:UObjPtr, oneParam:FString, anotherParam:int) : FString {.uebind.}
#Example usage
# var obj : UObjPtr = cast[UObjPtr] (nil)

# echo obj.testReturnFunction()
# obj.testFunction()

# echo obj.testParamsFunction("test", 3)


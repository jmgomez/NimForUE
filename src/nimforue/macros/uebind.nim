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

func isReturnParam*(field:UEField) : bool = (CPF_ReturnParm in field.propFlags)
func isOutParam*(field:UEField) : bool = 
    (CPF_OutParm in field.propFlags)
   

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
    #Notice we generate two set properties one for nim and the other for code gen due to cpp
    #not liking the equal in the ident name
    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, typeNodeAsReturnValue):
            proc `propIdent`* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue {.exportcpp.} =
                let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
                getPropertyValuePtr[typeNode](prop, obj)[]
            
            proc `propIdent=`* (obj {.inject.} : ptrName, val {.inject.} :typeNode)  = 
                var value {.inject.} : typeNode = val
                let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
                setPropertyValuePtr[typeNode](prop, obj, value.addr)

            proc `set propIdent`* (obj {.inject.} : ptrName, val {.inject.} :typeNode) {.exportcpp.} = 
                var value {.inject.} : typeNode = val
                let prop {.inject.} = getClassByName(className).getFPropertyByName(propUEName)
                setPropertyValuePtr[typeNode](prop, obj, value.addr)
    

func ueNameToNimName(propName:string) : string = #this is mostly for the autogen types
        let reservedKeywords = ["object", "method", "type"] 
        if propName in reservedKeywords: 
            &"`{propName}`" 
        else: propName
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
                [identFn(param.name.firstToLow().ueNameToNimName()), param.getTypeNodeFromUProp(), newEmptyNode()])
            .map(n=>nnkIdentDefs.newTree(n))
    else:
        error("funField: not a func")

func genParamInFnBodyAsType(funField:UEField) : NimNode = 
    let returnProp = funField.signature.filter(isReturnParam).head()
    #make sure we remove the out flag so we dont emit var on type variables which is not allowed
    var i = 0
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
                                    funField.signatureAsNode(identWrapper) &
                                    returnProp.map(prop=>
                                        @[nnkIdentDefs.newTree([ident("returnValue"), 
                                                            ident prop.uePropType, 
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

    let formalParams = genFormalParamsInFunctionSignature(typeDef, funField, "obj")

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

    var fnBody = genAst(uFnName=newStrLitNode(funField.name), paramInsideBodyAsType, paramDeclaration, generateObjForStaticFunCalls, callUFuncOn, returnCall):
        paramInsideBodyAsType
        paramDeclaration
        var fnName {.inject, used .} : FString = uFnName
        generateObjForStaticFunCalls
        callUFuncOn
        returnCall

    var pragmas = nnkPragma.newTree(ident("exportcpp")) # export the function as cpp
    when defined(windows):
        pragmas.add(ident("thiscall"))

    result = nnkProcDef.newTree([
                            identPublic funField.name.firstToLow(), 
                            newEmptyNode(), newEmptyNode(), 
                            formalParams, 
                            pragmas, newEmptyNode(),
                            fnBody
                        ])

    

    # debugEcho repr result
    # debugEcho treeRepr result




func genUClassTypeDef(typeDef : UEType, rule : UERule = uerNone) : NimNode =
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
    
    let typeDecl = if rule == uerCodeGenOnlyFields: newEmptyNode()
                   else: genAst(name = ident typeDef.name, ptrName, parent, props, funcs):
                    type 
                        name* {.inject, exportcpp.} = object of parent #TODO OF BASE CLASS 
                        ptrName* {.inject.} = ptr name
    
    result = 
        genAst(typeDecl, parent, props, funcs):
                typeDecl
                props
                funcs

        # genAst(name = ident typeDef.name, ptrName, parent, props, funcs):
        #         type 
        #             name* {.inject.} = object of parent #TODO OF BASE CLASS 
        #             ptrName* {.inject.} = ptr name
        #         props
        #         funcss

    #if result.repr.contains("UMyClassToTest"):
    #    debugEcho result.repr



func genUStructTypeDef(typeDef: UEType, importcpp=false) : NimNode = 
    let cppPragma = if importcpp: "importcpp" else: "exportcpp"
    let typeName = identWithInjectPublicAnd(typeDef.name, cppPragma)
    #TODO Needs to handle TArray/Etc. like it does above with classes
    let fields = typeDef.fields
                        .map(prop => nnkIdentDefs.newTree(
                            [identPublic ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1)), 
                             prop.getTypeNodeFromUProp(), newEmptyNode()]))
                        .foldl(a.add b, nnkRecList.newTree)


    result = genAst(typeName, fields):
                type typeName = object
    
    result[0][^1] = nnkObjectTy.newTree([newEmptyNode(), newEmptyNode(), fields])
    # debugEcho result.repr
    # debugEcho result.treeRepr

func genUEnumTypeDef(typeDef:UEType, importcpp=false) : NimNode = 
    let typeName = ident(typeDef.name)
    let fields = typeDef.fields
                        .map(f => ident f.name)
                        .foldl(a.add b, nnkEnumTy.newTree)
    fields.insert(0, newEmptyNode()) #required empty node in enums

    result= if importcpp:
                genAst(typeName, fields):
                    type typeName* {.inject, size:sizeof(uint8), pure, importcpp.} = enum         
                        fields
            else:
                genAst(typeName, fields):
                    type typeName* {.inject, size:sizeof(uint8), pure, exportcpp.} = enum         
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

#

func genImportCFunc*(typeDef : UEType, funField : UEField) : NimNode = 
    
    let ptrName = ident typeDef.name & (if typeDef.kind == uetDelegate: "" else: "Ptr") #Delegate dont use pointers
    let isStatic = FUNC_Static in funField.fnFlags
    let clsName = typeDef.name.substr(1)

    let formalParams = genFormalParamsInFunctionSignature(typeDef, funField, "obj")
    
    var pragmas = nnkPragma.newTree(
                    nnkExprColonExpr.newTree(
                        ident("importcpp"),
                        newStrLitNode("$1(@)")#Import the cpp func. Not sure if the value will work across all the signature combination
                    ),
                    nnkExprColonExpr.newTree(
                        ident("header"),#notice the header is temp.
                        newStrLitNode("UEGenBindings.h")
                    )
                )
                    
    result = nnkProcDef.newTree([
                            identPublic funField.name.firstToLow(), 
                            newEmptyNode(), newEmptyNode(), 
                            formalParams, 
                            pragmas, newEmptyNode(), newEmptyNode()
                          
                        ])


func genImportCProp(typeDef : UEType, prop : UEField) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
  
    let className = typeDef.name.substr(1)

    let typeNode = case prop.kind:
                    of uefProp: getTypeNodeFromUProp(prop)
                    else: newEmptyNode() #No Support 
    let typeNodeAsReturnValue = case prop.kind:
                            of uefProp: prop.getTypeNodeForReturn(typeNode)
                            else: newEmptyNode()#No Support as UProp getter/Seter
    
    
    let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)) 

    let setPropertyName = newStrLitNode(&"set{prop.name.firstToLow()}(@)")
    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, setPropertyName, typeNodeAsReturnValue):
            proc `propIdent`* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue {. importcpp:"$1(@)", header:"UEGenBindings.h" .}
            proc `propIdent=`*(obj {.inject.} : ptrName, val {.inject.} : typeNodeAsReturnValue) : void {. importcpp: setPropertyName, header:"UEGenBindings.h" .}
          
    
    
func genUClassImportCTypeDef(typeDef : UEType, rule : UERule = uerNone) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
    let parent = ident typeDef.parent
    let props = nnkStmtList.newTree(
                typeDef.fields
                    .filter(prop=>prop.kind==uefProp)
                    .map(prop=>genImportCProp(typeDef, prop)))

    let funcs = nnkStmtList.newTree(
                    typeDef.fields
                       .filter(prop=>prop.kind==uefFunction)
                       .map(fun=>genImportCFunc(typeDef, fun)))
    
    let typeDecl = if rule == uerCodeGenOnlyFields: newEmptyNode()
                   else: genAst(name = ident typeDef.name, ptrName, parent, props, funcs):
                    type  #notice the header is temp.
                        name* {.inject, importcpp, header:"UEGenBindings.h" .} = object of parent #TODO OF BASE CLASS 
                        ptrName* {.inject.} = ptr name
    
    result = 
        genAst(typeDecl, parent, props, funcs):
                typeDecl
                props
                funcs



proc genImportCTypeDecl*(typeDef : UEType, rule : UERule = uerNone) : NimNode =
    case typeDef.kind:
        of uetClass: 
            genUClassImportCTypeDef(typeDef, rule)
        of uetStruct:
            genUStructTypeDef(typeDef, importcpp=true)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate: #No exporting dynamic delegates. Not sure if they make sense at all. 
            genDelType(typeDef)


proc genTypeDecl*(typeDef : UEType, rule : UERule = uerNone) : NimNode = 
    case typeDef.kind:
        of uetClass:
            genUClassTypeDef(typeDef, rule)
        of uetStruct:
            genUStructTypeDef(typeDef)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate:
            genDelType(typeDef)



proc genModuleDecl*(moduleDef:UEModule) : NimNode = 
    result = nnkStmtList.newTree()
    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        result.add genTypeDecl(typeDef, rules)
        
proc genImportCModuleDecl*(moduleDef:UEModule) : NimNode =
    result = nnkStmtList.newTree()
    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        result.add genImportCTypeDecl(typeDef, rules)


    
#notice this is only for testing ATM the final shape probably wont be like this
macro genUFun*(className : static string, funField : static UEField) : untyped =
    let ueType = UEType(name:className, kind:uetClass) #Notice it only looks for the name and the kind (delegates)
    genFunc(ueType, funField)
        
macro genType*(typeDef : static UEType) : untyped = genTypeDecl(typeDef)
    


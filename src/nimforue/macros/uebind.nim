import std/[options, osproc, strutils,sugar, sequtils,strformat,  genasts, macros, importutils, os]

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

func nimToCppConflictsFreeName(propName:string) : string = 
    let reservedCppKeywords = ["template", "operator"]
    if propName in reservedCppKeywords: propName.firstToUpper() else: propName

func ueNameToNimName(propName:string) : string = #this is mostly for the autogen types
        let reservedKeywords = ["object", "method", "type", "interface", "var", "in", "out", "end", "bLock", "from", "enum"] 
        if propName in reservedKeywords: &"`{propName}`" 
        elif propName == "result": "Result"
        else: propName

func genProp(typeDef : UEType, prop : UEField) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
  
    let className = typeDef.name.substr(1)

    let typeNode = case prop.kind:
                    of uefProp: getTypeNodeFromUProp(prop)
                    else: newEmptyNode() #No Support 
    let typeNodeAsReturnValue = case prop.kind:
                            of uefProp: prop.getTypeNodeForReturn(typeNode)
                            else: newEmptyNode()#No Support as UProp getter/Seter
    
    
    let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)).nimToCppConflictsFreeName()

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

func genUClassTypeDefBinding(t: UEType, r: UERule = uerNone): seq[NimNode] =
    if r == uerCodeGenOnlyFields: 
        @[]
    else:
        @[
            # type Type* {.importcpp.} = object of Parent
            nnkTypeDef.newTree(
                nnkPragmaExpr.newTree(
                    nnkPostFix.newTree(ident "*", ident t.name),
                    nnkPragma.newTree(
                        nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")),
                        nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
                    )
                ),
                newEmptyNode(),
                nnkObjectTy.newTree(
                    newEmptyNode(), 
                    nnkOfInherit.newTree(ident t.parent),
                    newEmptyNode()
                )
            ),
            # ptr type TypePtr* = ptr Type
            nnkTypeDef.newTree(
                nnkPostFix.newTree(ident "*", ident t.name & "Ptr"),
                newEmptyNode(),
                nnkPtrTy.newTree(ident t.name)
            )
        ]

func genUClassImportTypeDefBinding(t: UEType, r: UERule = uerNone): seq[NimNode] =
    if r == uerCodeGenOnlyFields: 
        @[]
    else:
        @[
            # type Type* {.importcpp.} = object of Parent
            nnkTypeDef.newTree(
                nnkPragmaExpr.newTree(
                    nnkPostFix.newTree(ident "*", ident t.name),
                    nnkPragma.newTree(
                        nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")),
                        ident "inheritable",
                        nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenClassDefs.h"))
                    )
                ),
                newEmptyNode(),
                nnkObjectTy.newTree(
                    newEmptyNode(), 
                    nnkOfInherit.newTree(ident t.parent),
                    newEmptyNode()
                )
            ),
            # ptr type TypePtr* = ptr Type
            nnkTypeDef.newTree(
                nnkPostFix.newTree(ident "*", ident t.name & "Ptr"),
                newEmptyNode(),
                nnkPtrTy.newTree(ident t.name)
            )
        ]

func genUClassTypeDef(typeDef : UEType, rule : UERule = uerNone, typeExposure: UEExposure) : NimNode =
    let props = nnkStmtList.newTree(
                typeDef.fields
                    .filter(prop=>prop.kind==uefProp)
                    .map(prop=>genProp(typeDef, prop)))

    let funcs = nnkStmtList.newTree(
                    typeDef.fields
                       .filter(prop=>prop.kind==uefFunction)
                       .map(fun=>genFunc(typeDef, fun)))
    
    let typeDecl = 
        if rule == uerCodeGenOnlyFields: 
            newEmptyNode()
        else: 
            let ptrName = ident typeDef.name & "Ptr"
            let parent = ident typeDef.parent
            case typeExposure:
            of uexDsl:
                genAst(name = ident typeDef.name, ptrName, parent):
                    type 
                        name* {.inject, exportcpp.} = object of parent #TODO OF BASE CLASS 
                        ptrName* {.inject.} = ptr name
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

    if typeExposure == uexExport: 
        #Generates a type so it's added to the header when using --header
        #TODO dont create them for UStructs
        let exportFn = genAst(fnName= ident "keep"&typeDef.name, typeName=ident typeDef.name):
            proc fnName(fake {.inject.} :typeName) {.exportcpp.} = discard 
        result = nnkStmtList.newTree(result, exportFn)

    #if result.repr.contains("UMyClassToTest"):
    #    debugEcho result.repr

func getFieldIdent(prop:UEField) : NimNode = 
    let fieldName = ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1))
    identPublic fieldName

func genUStructTypeDefBinding(t: UEType, r: UERule = uerNone): NimNode =
    var recList = nnkRecList.newTree()
    var size, offset, padId: int
    for prop in t.fields:
        var id = nnkIdentDefs.newTree(getFieldIdent(prop), prop.getTypeNodeFromUProp(), newEmptyNode())

        let offsetDelta = prop.offset - offset
        if offsetDelta > 0:
            recList.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(offsetDelta), ident "byte"), newEmptyNode())
            inc padId
            offset += offsetDelta
            size += offsetDelta

        recList.add id
        size = offset + prop.size
        offset += prop.size

    if size < t.size:
        recList.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(t.size - size), ident "byte"), newEmptyNode())

    nnkTypeDef.newTree(
        nnkPragmaExpr.newTree([
            nnkPostfix.newTree([ident "*", ident t.name]),
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

func genUStructImportCTypeDefBinding(t: UEType): NimNode =
    var recList = t.fields
        .map(prop => nnkIdentDefs.newTree(
                getFieldIdent(prop), 
                prop.getTypeNodeFromUProp(), 
                newEmptyNode()
            )
        )
        .foldl(a.add b, nnkRecList.newTree)
    nnkTypeDef.newTree(
        nnkPragmaExpr.newTree([
            nnkPostfix.newTree([ident "*", ident t.name]),
            nnkPragma.newTree(
                ident "inject",
                nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1_")),
                nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h"))
            )
        ]),
        newEmptyNode(),
        nnkObjectTy.newTree(
            newEmptyNode(), newEmptyNode(), recList
        )
    )

func genUStructTypeDef(typeDef: UEType,  rule : UERule = uerNone, typeExposure:UEExposure) : NimNode = 
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


#[
    #TODO Needs to handle TArray/Etc. like it does above with classes
    let fields = typeDef.fields
                        .map(prop => nnkIdentDefs.newTree(
                            [getFieldIdent(prop), 
                            prop.getTypeNodeFromUProp(), newEmptyNode()]))

                        .foldl(a.add b, nnkRecList.newTree)
                        ]#
    let fields =
        case typeExposure:
        of uexDsl, uexImport:
            typeDef.fields
                        .map(prop => nnkIdentDefs.newTree(
                            [getFieldIdent(prop), 
                            prop.getTypeNodeFromUProp(), newEmptyNode()]))

                        .foldl(a.add b, nnkRecList.newTree)
        of uexExport:
            var fields = nnkRecList.newTree()
            var size, offset, padId: int
            for prop in typeDef.fields:
                var id = nnkIdentDefs.newTree(getFieldIdent(prop), prop.getTypeNodeFromUProp(), newEmptyNode())

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

    result = genAst(typeName, fields):
                type typeName = object
    
    result[0][^1] = nnkObjectTy.newTree([newEmptyNode(), newEmptyNode(), fields])

    if typeExposure == uexExport: 
        #Generates a type so it's added to the header when using --header
        #TODO dont create them for UStructs
        let exportFn = genAst(fnName= ident "keep"&typeDef.name, typeName=ident typeDef.name):
            proc fnName(fake {.inject.} :typeName) {.exportcpp.} = discard 
        result = nnkStmtList.newTree(exportFn)
    # debugEcho result.repr
    # debugEcho result.treeRepr


func genUEnumTypeDefBinding(t: UEType): NimNode =
    let enumTy = t.fields
                        .map(f => ident f.name)
                        .foldl(a.add b, nnkEnumTy.newTree)
    enumTy.insert(0, newEmptyNode()) #required empty node in enums
    nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            nnkPostFix.newTree(ident "*", ident t.name),
            nnkPragma.newTree(nnkExprColonExpr.newTree(ident "size", nnkCall.newTree(ident "sizeof", ident "uint8")), ident "pure")
        ),
        newEmptyNode(),
        enumTy
    )

func genUEnumTypeDef(typeDef:UEType) : NimNode = 
    let typeName = ident(typeDef.name)
    let fields = typeDef.fields
                        .map(f => ident f.name)
                        .foldl(a.add b, nnkEnumTy.newTree)
    fields.insert(0, newEmptyNode()) #required empty node in enums

    result= genAst(typeName, fields):
                type typeName* {.inject, size:sizeof(uint8), pure.} = enum         
                    fields
    
    result[0][^1] = fields #replaces enum 


    
    # debugEcho repr result
    # debugEcho treeRepr result

#

func genImportCFunc*(typeDef : UEType, funField : UEField) : NimNode = 
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

proc genDelType(delType:UEType, exposure:UEExposure) : NimNode = 
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
        else: genFunc(delType, broadcastFunType) 

    result = nnkStmtList.newTree(typ, funcNode)

func genImportCProp(typeDef : UEType, prop : UEField) : NimNode = 
    let ptrName = ident typeDef.name & "Ptr"
  
    let className = typeDef.name.substr(1)

    let typeNode = case prop.kind:
                    of uefProp: getTypeNodeFromUProp(prop)
                    else: newEmptyNode() #No Support 
    let typeNodeAsReturnValue = case prop.kind:
                            of uefProp: prop.getTypeNodeForReturn(typeNode)
                            else: newEmptyNode()#No Support as UProp getter/Seter
    
    
    let propIdent = ident (prop.name[0].toLowerAscii() & prop.name.substr(1)).nimToCppConflictsFreeName()

    let setPropertyName = newStrLitNode(&"set{prop.name.firstToLow()}(@)")
    result = 
        genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, setPropertyName, typeNodeAsReturnValue):
            proc `propIdent`* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue {. importcpp:"$1(@)", header:"UEGenBindings.h" .}
            proc `propIdent=`*(obj {.inject.} : ptrName, val {.inject.} : typeNode) : void {. importcpp: setPropertyName, header:"UEGenBindings.h" .}
          
    
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
    
    #[
    let typeDecl = if rule == uerCodeGenOnlyFields: newEmptyNode()
                   else: genAst(name = ident typeDef.name, ptrName, parent, props, funcs):
                    type  #notice the header is temp.
                        name* {.inject, importcpp.} = object of parent #TODO OF BASE CLASS 
                        ptrName* {.inject.} = ptr name
    ]# 
    result = 
        genAst(props, funcs):
            props
            funcs



proc genImportCTypeDecl*(typeDef : UEType, rule : UERule = uerNone) : NimNode =
    case typeDef.kind:
        of uetClass: 
            genUClassImportCTypeDef(typeDef, rule)
        of uetStruct:
            genUStructTypeDef(typeDef, rule, uexImport)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate: #No exporting dynamic delegates. Not sure if they make sense at all. 
            genDelType(typeDef, uexImport)


proc genTypeDecl*(typeDef : UEType, rule : UERule = uerNone, typeExposure = uexDsl) : NimNode = 
    case typeDef.kind:
        of uetClass:
            genUClassTypeDef(typeDef, rule, typeExposure)
        of uetStruct:
            genUStructTypeDef(typeDef, rule, typeExposure)
        of uetEnum:
            genUEnumTypeDef(typeDef)
        of uetDelegate:
            genDelType(typeDef, typeExposure)



proc genModuleDecl*(moduleDef:UEModule) : NimNode = 
    result = nnkStmtList.newTree()

    var typeSection = nnkTypeSection.newTree()
    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
        of uetClass:
            typeSection.add genUClassTypeDefBinding(typedef, rules)
        of uetStruct:
            typeSection.add genUStructTypeDefBinding(typedef, rules)
        of uetEnum:
            typeSection.add genUEnumTypeDefBinding(typedef)
        else: continue
    result.add typeSection

    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
        of uetClass, uetStruct:
            result.add genTypeDecl(typeDef, rules, uexExport)
        of uetDelegate: 
            result.add genDelType(typeDef, uexExport)
        else: continue

proc genImportCModuleDecl*(moduleDef:UEModule) : NimNode =
    result = nnkStmtList.newTree()

    var typeSection = nnkTypeSection.newTree()
    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
            of uetClass: 
                typeSection.add genUClassImportTypeDefBinding(typeDef, rules)
            of uetStruct:
                typeSection.add genUStructImportCTypeDefBinding(typedef)
            of uetEnum:
                typeSection.add genUEnumTypeDefBinding(typedef)
            else:
                continue
    result.add typeSection

    for typeDef in moduleDef.types:
        let rules = moduleDef.getAllMatchingRulesForType(typeDef)
        case typeDef.kind:
        of uetClass:
            result.add genImportCTypeDecl(typeDef, rules)
        of uetDelegate: 
            result.add genDelType(typeDef, uexImport)
        else:
            continue



proc genModuleRepr*(moduleDef: UEModule, isImporting: bool): string =
    let moduleNode = if isImporting: genImportCModuleDecl(moduleDef) else: genModuleDecl(moduleDef)
    let preludePath = "include " & (if isImporting: "" else: "../") & "../prelude\n"

    preludePath & 
        #"{.experimental:\"codereordering\".}\n" &
        moduleDef.dependencies.mapIt("import " & it.toLower()).join("\n") &
        repr(moduleNode)
            .multiReplace(
        ("{.inject.}", ""),
        ("{.inject, ", "{."),
        ("<", "["),
        (">", "]"), #Changes Gen. Some types has two levels of inherantce in cpp, that we dont really need to support
        ("::Type", ""), #Enum namespaces EEnumName::Type
        ("::Mode", ""), #Enum namespaces EEnumName::Type
        ("::", "."), #Enum namespace
        ("__DelegateSignature", ""))
    
#notice this is only for testing ATM the final shape probably wont be like this
macro genUFun*(className : static string, funField : static UEField) : untyped =
    let ueType = UEType(name:className, kind:uetClass) #Notice it only looks for the name and the kind (delegates)
    genFunc(ueType, funField)
        
macro genType*(typeDef : static UEType) : untyped = genTypeDecl(typeDef)

proc genHeaders*(moduleDef: UEModule,  headersPath: string) = 
    #There is one main header that pulls the rest.
    #Every other header is in the module paths
    let validCppParents = ["UObject", "AActor", "UInterface", "UActorComponent", "UDeveloperSettings"]#TODO this should be introduced as param

    let getParentName = (uet:UEType) => uet.parent & 
        (if uet.parent in validCppParents or uerCodeGenOnlyFields == getAllMatchingRulesForType(moduleDef, uet): "" else: "_")

    let classDefs = moduleDef.types
                        .filterIt(it.kind == uetClass and uerCodeGenOnlyFields != getAllMatchingRulesForType(moduleDef, it))
                        .mapIt(&"class {it.name}_ : public {getParentName(it)}{{}};\n")
                        .join()
   
    let headerName = (name:string) => &"{name.firstToUpper()}.h"
    let includeHeader = (name:string) => &"#include \"{headerName(name)}\" \n"
    let headerPath = headersPath / "Modules" / headerName(moduleDef.name)
    let deps = moduleDef
                .dependencies
                .map(includeHeader)
                .join()
    let headerContent = &"""
#pragma once
#include "UEDeps.h"
{deps}
{classDefs}
"""
    writeFile(headerPath, headerContent)
    #Main header
    let headersAsDeps = 
        walkDir( headersPath / "Modules")
        .toSeq()
        .filterIt(it[0] == pcFile and it[1].endsWith(".h"))
        .mapIt(it[1].split("\\")[^1].replace(".h", ""))
        .mapIt("Modules/" & it)
        .map(includeHeader)
        .join()

    let mainHeaderPath = headersPath / "UEGenClassDefs.h"
    let headerAsDep = includeHeader(moduleDef.name)
    let mainHeaderContent = &"""
#pragma once
#include "UEDeps.h"
{headersAsDeps}
"""
    # if headerAsDep notin mainHeaderContent:
    writeFile(mainHeaderPath, mainHeaderContent)
    
macro genBindings*(moduleDef: static UEModule, exportPath: static string, importPath: static string, headersPath: static string) =
    proc genCode(filePath: string, preludePath: string, moduleDef: UEModule, moduleNode: NimNode) =
        let code = 
            preludePath & 
            #"{.experimental:\"codereordering\".}\n" &
            moduleDef.dependencies.mapIt("import " & it.toLower()).join("\n") &
            repr(moduleNode)
                .multiReplace(
            ("{.inject.}", ""),
            ("{.inject, ", "{."),
            ("<", "["),
            (">", "]"), #Changes Gen. Some types has two levels of inherantce in cpp, that we dont really need to support
            ("::Type", ""), #Enum namespaces EEnumName::Type
            ("::Mode", ""), #Enum namespaces EEnumName::TypeB
            ("::", "."), #Enum namespace

            ("__DelegateSignature", ""))
        writeFile(filePath, code)

    genCode(exportPath, "include ../../prelude\n", moduleDef, genModuleDecl(moduleDef))
    genCode(importPath, "include ../prelude\n", moduleDef, genImportCModuleDecl(moduleDef))

    genHeaders(moduleDef, headersPath)
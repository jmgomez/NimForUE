import std/[options, strutils, sugar, sequtils, strformat,  genasts, macros, importutils, algorithm]
include ../unreal/definitions
import ../utils/[utils, ueutils]
import ../unreal/core/containers/[unrealstring, array, map, set]
import ../unreal/coreuobject/[uobjectflags]
import nuemacrocache, models, modelconstructor, projectinstrospect, uebindcore
import modulerules
# import ../../buildscripts/nimforueconfig #probably nimforueconfig should be removed from buildscripts

  # macro ex*(a:untyped):untyped = a
func genPropsAsRecList*(uet: UEType, rule: UERule = uerNone, isImporting: bool): NimNode 

func genProp(typeDef : UEType, prop : UEField, typeExposure: UEExposure = uexDsl) : NimNode = 
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
  var actualSetter = 
    if prop.uePropType == "bool": 
      genAst():
        setValueInBoolProp(prop, obj, val)
    else:
      genAst(typeNode):
        setPropertyValuePtr[typeNode](prop, obj, val.addr)
  
  if prop.isFieldNotify:
    let notifyNode =  
      genAst(name = newLit prop.name):
        obj.broadcastFieldValueChanged(n name)
    actualSetter = nnkStmtList.newTree(actualSetter, notifyNode)

  if CPF_BlueprintAssignable in prop.propFlags and typeExposure != uexDsl:
    result = 
      genAst(propIdent, ptrName, typeNode, className, propUEName = prop.name, typeNodeAsReturnValue):
        proc `propIdent`*(obj {.inject.}: ptrName): (UObjectPtr, FMulticastDelegatePropertyPtr) = 
          let prop {.inject.}  = obj.getClass.getFPropertyByName(propUEName).castField[:FMulticastDelegateProperty]()
          (obj, prop)
  else:
    result = 
      genAst(propIdent, ptrName, typeNode, className, actualGetter, actualSetter, propUEName = prop.name, typeNodeAsReturnValue):
        proc `propIdent`* (obj {.inject.}: ptrName) : typeNodeAsReturnValue {.exportcpp.} =
          let prop {.inject.} = obj.getClass.getFPropertyByName(propUEName)
          actualGetter
        
        proc `propIdent=`* (obj {.inject.} : ptrName, val {.inject.} :typeNode)  = 
          let prop {.inject.} = obj.getClass.getFPropertyByName(propUEName)
          actualSetter

        proc `set propIdent` (obj {.inject.} : ptrName, val {.inject.} :typeNode)  {.exportcpp.} = 
          let prop {.inject.} = obj.getClass.getFPropertyByName(propUEName)
          actualSetter
  #TODO why the heck this code is repeated? Test Dynamic delegates before deleting
  result = 
    genAst(propIdent, ptrName, typeNode, className, actualGetter, actualSetter, propUEName = prop.name, typeNodeAsReturnValue):
      proc `propIdent`* (obj {.inject.} : ptrName ) : typeNodeAsReturnValue {.exportcpp.} =
        let prop {.inject.} = obj.getClass.getFPropertyByName(propUEName)
        actualGetter
      
      proc `propIdent=`* (obj {.inject.} : ptrName, val {.inject.} :typeNode)  = 
        let prop {.inject.} = obj.getClass.getFPropertyByName(propUEName)
        actualSetter

      proc `set propIdent` (obj {.inject.} : ptrName, val {.inject.} :typeNode)  {.exportcpp.} = 
        let prop {.inject.} = obj.getClass.getFPropertyByName(propUEName)
        actualSetter
  
func genParamInFnBodyAsType(funField:UEField) : NimNode = 
  let returnProp = funField.signature.filter(isReturnParam).head()
  #make sure we remove the out flag so we dont emit var on type variables which is not allowed
  var funField = funField

  for s in funField.signature.mitems:
    if  s.isReturnParam:
      s.propFlags = CPF_ReturnParm #remove out flag before the signatureCall, cant do and for some reason. Maybe a bug?
    elif s.isOutParam:
      s.propFlags = CPF_None #remove out flag before the signatureCall, cant do and for some reason. Maybe a bug?

  var typeFields = funField.signatureAsNode(identWrapper, isDefaultValueContext=false)
  # need to cast enums to uint8 because Unreal uses TEnumAsByte
  for f in typeFields:
    if f.kind == nnkIdentDefs and f[1].kind == nnkIdent and f[1].strVal()[0] == 'E':
      f[1] = ident "uint8"

  let paramsInsideFuncDef = nnkTypeSection.newTree([nnkTypeDef.newTree([identWithInject "Params", newEmptyNode(), 
              nnkObjectTy.newTree([
                newEmptyNode(), newEmptyNode(),  
                nnkRecList.newTree(
                  typeFields &
                  returnProp.map(prop=>
                    @[nnkIdentDefs.newTree([ident("returnValue"), 
                              getTypeNodeFromUProp(prop, isVarContext = false),
                              # ident prop.uePropType, 
                              newEmptyNode()])]).get(@[])
                )])
            ])])

  paramsInsideFuncDef

func getGenFuncName(funField : UEField) : string = funField.name.firstToLow().ueNameToNimName
#this is used for both, to generate regular function binds and delegate broadcast/execute functions
#for the most part the same code is used for both
#this is also used for native function implementation but the ast is changed afterwards
#Returns a tuple with the forward declaration and the actual function 
func genFunc*(typeDef : UEType, funField : UEField, typeExposure: UEExposure = uexDsl) : tuple[fw:NimNode, impl:NimNode] = 
  let isStatic = FUNC_Static in funField.fnFlags
  let isSuper = funField.name == "super"
  let clsName = typeDef.name.substr(1)

  let formalParams = genFormalParamsInFunctionSignature(typeDef, funField, "self")

  let generateObjForStaticFunCalls = 
    if isStatic: 
      genAst(clsName=newStrLitNode(clsName)): 
        let self {.inject.} = bindingdeps.getDefaultObjectFromClassName(clsName)
    else: newEmptyNode()

  let processFn = 
    case typeDef.kind:
    of uetDelegate:
      case typeDef.delKind:
        of uedelDynScriptDelegate:
          genAst(): self.processDelegate(param.addr)
        of uedelMulticastDynScriptDelegate:
          genAst(): self.processMulticastDelegate(param.addr)
    else: genAst(clsName=newStrLitNode(clsName), isSuper = newLit isSuper): 
      var cls {.inject.} = uobject.getClass(ueCast[UObject](self))
      when isSuper:
        cls = getClassByName(clsName).getSuperClass()
      let fn {.inject, used.} = uobject.getFunctionByNameWithPrefixes(cls, fnName)
      self.processEvent(fn, param.addr)

  # need to cast back from uint8 to the Enum type because UE uses TEnumAsByte
  func constructOutParam(uef: UEField): NimNode =
    let outName = ident(uef.name.firstToLow().ueNameToNimName)
    if uef.uePropType[0] == 'E':
      nnkAsgn.newTree( outName,
        nnkCast.newTree(ident uef.uePropType, nnkDotExpr.newTree(ident "param", outName))
      )
    else:
      nnkAsgn.newTree(outName, nnkDotExpr.newTree(ident "param", outName))

  let outParams = 
    nnkStmtList.newTree(
      funField.signature
        .filterIt(it.isOutParam and not it.isReturnParam)
        .map(constructOutParam)
    )

  let returnCall = if funField.doesReturn(): 
    let returnProp = funField.getReturnProp().get()
    if returnProp.uePropType[0] == 'E': # need to cast back to enum from uint8 because UE uses TEnumAsByte
      genAst(enumType = ident returnProp.uePropType): 
        return cast[enumType](param.returnValue)
    else:
      genAst(): 
        return param.returnValue
    else: newEmptyNode()

  let paramInsideBodyAsType = genParamInFnBodyAsType(funField)

  func constructFieldForObject(uef: UEField): NimNode =
    let param = ident uef.name.firstToLow().ueNameToNimName()
    if uef.uePropType[0] == 'E': # check if enum cast to uint8 because UE uses TEnumAsByte
      nnkExprColonExpr.newTree(param, nnkCast.newTree(ident "uint8", param))
    else:
      nnkExprColonExpr.newTree(param, param)

  let paramObjectConstrCall = nnkObjConstr.newTree(@[ident "Params"] &  #creates Params(param0:param0, param1:param1)
                funField.signature
                  .filter(prop=>not isReturnParam(prop))
                  .map(param=>constructFieldForObject(param))
              )
  let paramDeclaration = nnkVarSection.newTree(nnkIdentDefs.newTree([identWithInject "param", newEmptyNode(), paramObjectConstrCall]))

  var fnBody = genAst(uFnName=newStrLitNode(funField.actualFunctionName), paramInsideBodyAsType, paramDeclaration, generateObjForStaticFunCalls, processFn, returnCall, outParams):
    paramInsideBodyAsType
    paramDeclaration
    let fnName {.inject, used .} = f uFnName
    generateObjForStaticFunCalls
    processFn
    outParams
    returnCall

  var pragmas = 
    if isSuper:
      nnkPragma.newTree(
        nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode(clsName&"_"&funField.actualFunctionName&"_$1_"))
        ) #export the func with clsName and function to avoid super_ collision
    else:
      nnkPragma.newTree(
        nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1_"))
        ) #export the func with an underscore to avoid collisions

    # when WithEditor:
    # else: newEmptyNode()
  # if typeExposure == uexExport:
  #   # debugEcho treeRepr pragmas
  #   pragmas.add ident "dynlib"

  # when defined(windows):
  #   pragmas.add(ident("thiscall")) #I Dont think this is necessary
  let forwardDeclaration = 
   nnkProcDef.newTree([
              (if isSuper: ident funField.getGenFuncName() #super is local
              else: identPublic funField.getGenFuncName()),
              newEmptyNode(), newEmptyNode(), 
              formalParams, 
              pragmas, newEmptyNode(),
            ])

  var impl = forwardDeclaration.copyNimTree()
  forwardDeclaration.add newEmptyNode()
  impl.add(fnBody)
  (forwardDeclaration,impl)


func genInterfaceConverers*(ueType:UEType, typeExposure: UEExposure) : NimNode =   
  let typeNamePtr = ident ueType.name & "Ptr"
  func genConverter(interName:string): NimNode = 
    let interfaceName = ident interName
    let interfacePtrName = ident interName & "Ptr"
    let fnName = ident ueType.name & "to" & interName
    result =       
      genAst(fnName,typeNamePtr, interfaceName, interfacePtrName):      
        when not declared(fnName):
          converter fnName*(self {.inject.} : typeNamePtr): interfacePtrName =  cast[interfacePtrName](self)
    # if typeExposure in [uexExport, uexImport]:
    #   debugEcho treeRepr result
    #   debugEcho repr result
    #   result[^1][0].pragma.add ident "dynlib"
  
  nnkStmtList.newTree(ueType.interfaces.mapIt(genConverter(it)))

func getClassTemplate*(typeDef: UEType, fromBindings: bool = false) : string =  
  var cppInterfaces = typeDef.interfaces.filterIt(it[0] == 'I').mapIt("public " & it).join(", ")
  if cppInterfaces != "":
    cppInterfaces = ", " & cppInterfaces  
  let defaultCtor = if fromBindings and not typeDef.hasObjInitCtor: "$1()=default;" else: ""
  let fieldNotifies = generateFieldNotify(typeDef).get(("", ""))

  # see manual codegenDecl pragma for $1,$3
  &"""
struct $1 : public $3{cppInterfaces} {{
  typedef $3 Super;
  typedef $1 ThisClass;
  {defaultCtor}
  virtual ~$1(){{
    UE_LOG(LogTemp, Log, TEXT("Destroying NimForUEClass: $1"));
  }};
  $1(FVTableHelper& Helper) : $3(Helper) {{}}
  $2  
  {fieldNotifies[0]}
}};
"""
#Eventually this types should generate its own file so it's easier to copy paste them to the EngineTypes. In the mean time they generate getter/setters
func isInPCHAndManuallyImported*(uet: UEType): bool = uet.isInPCH and uet.name in ManuallyImportedClasses

func isNonPublicPropInNonCommonModule(uet: UEType, prop: UEField): bool = 
  not uet.isInCommon and not prop.isPublic()

func shouldGenGetterSetters*(uet: UEType, prop: UEField, isUserType: bool): bool = 
  prop.kind == uefProp and (isUserType or uet.isInPCHAndManuallyImported or uet.isNonPublicPropInNonCommonModule(prop))


func getStructTraits(typeDef: UEType): seq[string] =  
  for m in typeDef.metadata:
    if m.name == "WithNetSerializer":
      result.add("WithNetSerializer = true")
    if m.name == "WithSerializer":
      result.add("WithSerializer = true")
    if m.name == "WithNetSharedSerialization":
      result.add("WithNetSharedSerialization = true")
    #TODO add the other traits and make sure the type correctly implements them        

func getStructTemplate*(typeDef: UEType): string =  
  var base = ""
  if typeDef.superStruct != "": 
    base = " : public $3"

  let traits = getStructTraits(typeDef)
  var structOpsTraits = ""
  if traits.len > 0:    
    structOpsTraits = &"""
template<>
struct TStructOpsTypeTraits<{typeDef.name}> : public TStructOpsTypeTraitsBase2<{typeDef.name}>
{{
	enum
	{{
      { traits.join(",\n") }
	}};
}};

"""

  let tBaseStructure = 
    if "WithGet" in typeDef.metadata:
      &"""
        template<> struct TBaseStructure<{typeDef.name}> 
        {{
            static UScriptStruct* Get(){{

            static UScriptStruct* ScriptStruct = nullptr;
            return ScriptStruct;
          }}
        }};
      """
    else: ""


  &"""
  struct $1 {base} {{
    $2  
  }};
  {structOpsTraits}
  {tBaseStructure}
"""
import std/algorithm
func genUClassTypeDef(typeDef : UEType, rule : UERule = uerNone, typeExposure: UEExposure,  lineInfo: Option[LineInfo]) : NimNode =
  #Props as getters/setters (dont calculate for uexDsl, we emit them as fields)
  var props = newEmptyNode()

  if typeExposure != uexDsl:
    props = nnkStmtList.newTree(
        typeDef.fields.reversed
        .filter(prop=>shouldGenGetterSetters(typeDef, prop, typeExposure == uexDsl)) 
        .map(prop=>genProp(typeDef, prop, typeExposure)))

  let funcs = nnkStmtList.newTree(
    typeDef.fields
      .filter(prop=>prop.kind==uefFunction)
      .map(fun=>genFunc(typeDef, fun, typeExposure).impl))

  let fields =
    if typeExposure == uexDsl and typeDef.fields.len > 0:
      typeDef.fields.reversed
        .map(prop => 
          nnkIdentDefs.newTree(
            getFieldIdent(prop),
            prop.getTypeNodeFromUProp(isVarContext=false),             
            newEmptyNode()))
        .foldl(a.add b, nnkRecList.newTree)
    else:
      newEmptyNode()

  let typeDecl = 
    if rule == uerCodeGenOnlyFields or typeDef.forwardDeclareOnly or 
      typeDef.metadata.filterIt(it.name.toLower() == NoDeclMetadataKey.toLower()).any(): 
        newEmptyNode()
    else: 
      case typeExposure:
      of uexDsl:
        let pragmas = 
            nnkPragmaExpr.newTree(
              nnkPostFix.newTree(ident "*", ident typeDef.name),
              nnkPragma.newTree(ident "exportc", ident "inheritable",
                nnkExprColonExpr.newTree(ident "codegenDecl", 
                  newLit getClassTemplate(typeDef))
              )
            )
        let typ = 
          nnkTypeDef.newTree(
            pragmas,
            newEmptyNode(),
            nnkObjectTy.newTree(
              newEmptyNode(),
              nnkOfInherit.newTree(ident typeDef.parent),
              fields
            )
          )
        let typPtr = 
          nnkTypeDef.newTree(
              nnkPostFix.newTree(ident "*", ident typedef.name & "Ptr"),
              newEmptyNode(),
              nnkPtrTy.newTree(ident typeDef.name)
          )
        if lineInfo.isSome:
          #Targets the ident node that holds the name
          typ[0][0][1].setLineInfo(lineInfo.get())
          typPtr[0][1].setLineInfo(lineInfo.get())
        let typeSection = nnkTypeSection.newTree(typ, typPtr)
        typeSection
      of uexExport:
        newEmptyNode()       
      of uexImport:
        newEmptyNode()

  # if typeExposure == uexDsl:
  #   result = 
  #     genAst(typeDecl, funcs):
  #           typeDecl          
  #           funcs
  # else:
  result = 
    genAst(typeDecl, props, funcs):
        typeDecl
        props
        funcs

  result.add genInterfaceConverers(typeDef, typeExposure)

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
  let typeName = identPublic delType.name
   
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
    else: genFunc(delType, broadcastFunType, exposure).impl

  result = nnkStmtList.newTree(typ, funcNode)



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

func genUStructTypeDef*(typeDef: UEType,  rule: UERule = uerNone, typeExposure: UEExposure): NimNode = 
  let suffix = "_"
  let typeName = 
    case typeExposure: 
    of uexDsl: 
        nnkPragmaExpr.newTree(
          nnkPostFix.newTree(ident "*", ident typeDef.name),
          nnkPragma.newTree(
            ident "pure",
            ident "exportc", 
            ident "byCopy", 
            ident "inheritable",
            nnkExprColonExpr.newTree(ident "codegenDecl", 
              newLit getStructTemplate(typeDef))
          )
        )
    of uexImport: 
      nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident typeDef.name]),
        nnkPragma.newTree(
          ident "inject",
          nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode("$1" & suffix)),
          nnkExprColonExpr.newTree(ident "header", newStrLitNode("UEGenBindings.h"))
        )
      ])
    of uexExport: #Note this path is not used. TODO Remove
      let importExportPragma =
        if typeDef.isInPCH:
          ident "importcpp"
        else:
          nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1" & suffix))
          
      nnkPragmaExpr.newTree([
        nnkPostfix.newTree([ident "*", ident typeDef.name]),
        nnkPragma.newTree(
          ident "inject",
          importExportPragma
        )
      ]) 

  let fields =
    case typeExposure:
    of uexDsl, uexImport:
      typeDef.fields
        .map(prop => 
          nnkIdentDefs.newTree(
            getFieldIdentWithPCH(typeDef, prop),
            prop.getTypeNodeFromUProp(isVarContext=false),             
            newEmptyNode()))
        .foldl(a.add b, nnkRecList.newTree)
    of uexExport: 
      if typeDef.isInPCH:
         typeDef.fields
          .map(prop => 
            nnkIdentDefs.newTree(
              getFieldIdentWithPCH(typeDef, prop),
              prop.getTypeNodeFromUProp(isVarContext=false),             
              newEmptyNode()))
          .foldl(a.add b, nnkRecList.newTree)
      else:
        var fields = nnkRecList.newTree()
        var size, offset, padId: int
        for prop in typeDef.fields:
          let fieldName = ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1)).nimToCppConflictsFreeName()    
          var propIden = nnkIdentDefs.newTree(
            nnkPragmaExpr.newTree(
              ident fieldName,
              nnkPragma.newTree(
                ident "inject",
                nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode(prop.name)),
              )
            ), 
            prop.getTypeNodeFromUProp(isVarContext=false), 
            newEmptyNode())

          let offsetDelta = prop.offset - offset
          if offsetDelta > 0:
            fields.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(offsetDelta), ident "byte"), newEmptyNode())
            inc padId
            offset += offsetDelta
            size += offsetDelta

          fields.add propIden
          size = offset + prop.size
          offset += prop.size

        if size < typeDef.size:
          fields.add nnkIdentDefs.newTree(ident("pad_" & $padId), nnkBracketExpr.newTree(ident "array", newIntLitNode(typeDef.size - size), ident "byte"), newEmptyNode())
        fields

  if typeDef.superStruct == "":
    result = genAst(typeName, fields, typenamePtr = ident typeDef.name & "Ptr"):
          type 
            typeName = object

    result[0][^1] = nnkObjectTy.newTree([newEmptyNode(), newEmptyNode(), fields])    
  else:
    let superStruct = ident typeDef.superStruct
    result = genAst(typeName, superStruct, fields, typenamePtr = ident typeDef.name & "Ptr"):
          type 
            typeName = object of superStruct

    result[0][^1][^1] = fields

  if typeExposure == uexExport:  
    result = newEmptyNode() #exportc since Nim 2.0 exports the type so nothing to do here. 


func genUEnumTypeDef*(typeDef: UEType, typeExposure: UEExposure) : NimNode = 
  let typeName = ident(typeDef.name)
  let fields = typeDef.fields
            .map(f => ident f.name)
            .foldl(a.add b, nnkEnumTy.newTree)
  fields.insert(0, newEmptyNode()) #required empty node in enums

  result = genAst(typeName, fields):
        type typeName* {.inject, size:sizeof(uint8), pure.} = enum     
          fields

  result[0][^1] = fields #replaces enum 

  if typeDef.isInPCH:
    result[0][0][1].add nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode(typeDef.cppEnumName))
  
  if typeExposure == uexExport: 
    result = newEmptyNode() #exportc since Nim 2.0 exports the type so nothing to do here. 

func genPropsAsRecList*(uet: UEType, rule: UERule = uerNone, isImporting: bool) : NimNode =
  var genPad = not uet.isInPCH #Only non PCH types need padding
  var recList = nnkRecList.newTree()
  var size, offset, padId: int
  if genPad and uet.kind == uetClass:
    offset = uet.parentSize #TODO FStructs doenst have inheritance applied yet, so they can start at 0

  for prop in uet.fields.filterIt(it.kind == uefProp):
    let fieldName = ueNameToNimName(toLower($prop.name[0])&prop.name.substr(1)).nimToCppConflictsFreeName()    
    let propIden = 
      if uet.isInPCH:
        nnkIdentDefs.newTree(
          nnkPragmaExpr.newTree(
            (if prop.isPublic: identPublic fieldName else: ident fieldName),
            nnkPragma.newTree(
              nnkExprColonExpr.newTree(ident "importcpp", newStrLitNode(prop.name)),
            )
          ), 
          prop.getTypeNodeFromUProp(isVarContext=false), 
          newEmptyNode())
        else: 
          nnkIdentDefs.newTree(getFieldIdent(prop), prop.getTypeNodeFromUProp(isVarContext=false), newEmptyNode())

    # if isImporting: continue

    let offsetDelta = prop.offset - offset
    if offsetDelta > 0 and genPad:
      recList.add nnkIdentDefs.newTree(ident(&"pad_{uet.name}_{padId}"), nnkBracketExpr.newTree(ident "array", newIntLitNode(offsetDelta), ident "byte"), newEmptyNode())
      inc padId
      offset += offsetDelta
      size += offsetDelta

    recList.add propIden
    size = offset + prop.size
    offset += prop.size

  if size < uet.size and genPad:
    recList.add nnkIdentDefs.newTree(ident(&"pad_{uet.name}_{padId}"), nnkBracketExpr.newTree(ident "array", newIntLitNode(uet.size - size), ident "byte"), newEmptyNode())
  recList

func genUStructTypeDefBinding*(ueType: UEType, rule: UERule = uerNone): NimNode =  
  let recList = genPropsAsRecList(ueType, rule, false)
  let importExportPragma =
    if ueType.isInPCH:
      nnkPragma.newTree(ident "importcpp", ident "bycopy")
    else:
      nnkExprColonExpr.newTree(ident "exportcpp", newStrLitNode("$1" & "_"))

  nnkTypeDef.newTree(
    nnkPragmaExpr.newTree([
      nnkPostfix.newTree([ident "*", ident ueType.name.nimToCppConflictsFreeName()]),
      nnkPragma.newTree(
        ident "inject",        
        importExportPragma
      )
    ]),
    newEmptyNode(),
    nnkObjectTy.newTree(
      newEmptyNode(), newEmptyNode(), recList
    )
  )


proc genTypeDecl*(typeDef : UEType, rule : UERule = uerNone, typeExposure = uexDsl,  lineInfo: Option[LineInfo] = none(LineInfo)) : NimNode = 
  case typeDef.kind:
    of uetClass:
      genUClassTypeDef(typeDef, rule, typeExposure, lineInfo)
    of uetStruct:
      genUStructTypeDef(typeDef, rule, typeExposure)
    of uetEnum:
      genUEnumTypeDef(typeDef, typeExposure)
    of uetDelegate:
      genDelType(typeDef, typeExposure)
    of uetInterface:
      newEmptyNode() #Not gen interfaces for now

macro genType*(typeDef : static UEType) : untyped = genTypeDecl(typeDef)
proc ueBindImpl(clsName : string, fn: NimNode) : NimNode = 
  let clsFieldMb = 
    if clsName!="": some makeFieldAsUProp("obj", clsName, clsName) 
    else: none[UEField]()

  var (fnField, firstParam) = uFuncFieldFromNimNode(fn, clsFieldMb, clsName, @[])
  if clsFieldMb.isSome:
    fnField.fnFlags = FUNC_Static
  #Generates a fake class form the classField. 
  let typeDefFn = makeUEClass(firstParam.uePropType, parent="", CLASS_None, @[fnField])
  result = genFunc(typeDefFn, fnField).impl

macro uebind*(fn:untyped) : untyped = ueBindImpl("", fn)
macro uebindStatic*(clsName : static string = "", fn:untyped) : untyped = ueBindImpl(clsName, fn)

func genCppStructField(typeName: string, field:UEField): NimNode = 
  #Notice this only work for PCH types as it uses the name. 
  let typNode = ident typeName
  let propNameNode = ident field.name.firstToLow()
  let propTypeNode = field.getTypeNodeFromUProp(isVarContext=false) #It may be a var context, but we are not using it for now
  let importcppSet = newLit(&"(#.{field.name})")
  genAst(propNameNode, propTypeNode, typNode, importcppSet):
    proc `propNameNode`*(self: typNode): propTypeNode {.importcpp:"(#.#)".}
    proc `propNameNode=`*(self: typNode, val: propTypeNode) {.importcpp: importcppSet.}

macro ueBindProp*(cls:typedesc, propName:untyped, typ:typedesc) = 
  ### example usage: ueBindProp(UInstancedStaticMeshComponent, PerInstanceSMCustomData, TArray[float32])
  ### Note for now, FStruct types must be PCH types (we will take care of this later, but for now, it's a limitation). 
  #We shoudlnt encounter it as types fields are bound already anyways. 
  #Same with most PCH types, except those manually bound
  let typeName = cls.strVal()
  let utk = if typeName[0] in ['A', 'U']: uetClass else: uetStruct
  let ueType = UEType(name: typeName.removeLastLettersIfPtr(), kind: utk)
  let ueProp = UEField(name: propName.strVal(), uePropType: repr typ, kind: uefProp)
  if utk == uetClass:
   result = genProp(ueType, ueProp, uexDsl)
  else:
    result = genCppStructField(typeName, ueProp)    
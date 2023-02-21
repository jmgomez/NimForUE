include ../unreal/prelude
import std/[times, strformat, tables, json, bitops, jsonUtils, strutils, options, sugar, algorithm, sequtils, hashes, typetraits]
import fproperty
import models
import modelconstructor #For some odd reason (a cycle in the mod probably) if this is not included but imported the make* arent visible here?
export models
import emitter
import ../codegen/modulerules
import ../codegen/modelconstructor
import headerparser
const fnPrefixes = @["", "Receive", "K2_", "BP_"]



func isTArray(prop: FPropertyPtr): bool = not castField[FArrayProperty](prop).isNil()
func isTMap(prop: FPropertyPtr): bool = not castField[FMapProperty](prop).isNil()
func isTSet(prop: FPropertyPtr): bool = not castField[FSetProperty](prop).isNil()
func isStruct(prop: FPropertyPtr): bool = not castField[FStructProperty](prop).isNil()
func isInterface(prop: FPropertyPtr): bool = not castField[FInterfaceProperty](prop).isNil()
func isTEnum(prop: FPropertyPtr): bool = "TEnumAsByte" in prop.getName()
func isTFieldPath(prop: FPropertyPtr): bool = not castField[FFieldPathProperty](prop).isNil()
func isTObjectPtr(prop: string): bool = return "TObjectPtr" in prop
func isTObjectPtr(prop: FPropertyPtr): bool = return "TObjectPtr" in prop.getName()
func isDynDel(prop: FPropertyPtr): bool = not castField[FDelegateProperty](prop).isNil()
func isMulticastDel(prop: FPropertyPtr): bool = not castField[FMulticastDelegateProperty](prop).isNil()
#TODO Dels
func cleanTObjectPtr(prop:string) : string = 
    if prop.extractOuterGenericInNimFormat() == "TObjectPtr":
        return prop.extractInnerGenericInNimFormat() & "Ptr"
    else:
        return prop

func cleanTEnum(prop:string) : string = 
    if prop.extractOuterGenericInNimFormat() == "TEnumAsByte":
        return prop.extractInnerGenericInNimFormat()
    else:
        return prop

func getNimTypeAsStr(prop: FPropertyPtr, outer: UObjectPtr): string = #The expected type is something that UEField can understand
  
  func cleanCppType(cppType: string): string =
    #Do multireplacehere
    let cppType =
      cppType.replace("<", "[")
              .replace(">", "]")
              .replace("*", "Ptr")
    if cppType == "float": return "float32"
    if cppType == "double": return "float64"
    if cppType == "uint8" and prop.getName().startsWith("b"): return "bool"
    return cppType.cleanTObjectPtr().cleanTEnum()
    

  if prop.isTArray():
    let innerProp = castField[FArrayProperty](prop).getInnerProp()
    return fmt"TArray[{innerProp.getNimTypeAsStr(outer)}]"


  if prop.isTSet():
    var elementProp = castField[FSetProperty](prop).getElementProp().getCPPType()
    return fmt"TSet[{elementProp.cleanCppType()}]"

  if prop.isTMap(): #better pattern here, i.e. option chain
    let mapProp = castField[FMapProperty](prop)
    var keyType = mapProp.getKeyProp().getCPPType()
    var valueType = mapProp.getValueProp().getCPPType()
    return fmt"TMap[{keyType.cleanCppType()}, {valueType.cleanCppType()}]"

  
  # if prop.isTFieldPath(): #they are not really supported. We just support them to interop in the bindings. Should be straighforward to add support for them
  #   let innerField = castField[FFieldPathProperty](prop).getPropertyClass()
  #   let innerProp = castField[FProperty](innerField.getDefaultObject())
  #   if innerProp.isNotNil() and not innerProp.isStruct():
  #     return &"TFieldPath[{innerProp.getNimTypeAsStr(outer)}]"
  #   else:
  #     return cleanCppType(prop.getCPPType())



  try:
    # UE_Log &"Will get cpp type for prop {prop.getName()} NameCpp: {prop.getNameCPP()} and outer {outer.getName()}"

    let cppType = prop.getCPPType() #TODO review this. Hiphothesis it should not reach this point in the hotreload if the struct has the pointer to the prev ue type and therefore it shouldnt crash

    if cppType == "double": return "float64"
    if cppType == "float": return "float32"


    if prop.isInterface():
      let class = castField[FInterfaceProperty](prop).getInterfaceClass()
      return fmt"TScriptInterface[U{class.getName()}]"
    
    
  

    let nimType = cppType.cleanCppType()

    # UE_Warn prop.getTypeName() #private?
    return nimType
  except:
    raise newException(Exception, fmt"Unsupported type {prop.getName()}")


func getUnrealTypeFromNameAsUObject[T : UObject](name: FString): Option[UObjectPtr] =
  #ScriptStruct, Classes
  result = tryUECast[UObject](getUTypeByName[T](name))
  # UE_Log &"Name: {name} result: {result}"

# func tryGetUTypeByName[T](name: FString): Option[ptr T] =
#   #ScriptStruct, Classes
#   tryUECast[T](getUTypeByName[T](name))


func isBPExposed(ufun: UFunctionPtr): bool = FUNC_BlueprintCallable in ufun.functionFlags

func isBPExposed(str: UFieldPtr): bool = str.hasMetadata("BlueprintType")

func isBPExposed(str: UScriptStructPtr): bool = str.hasMetadata("BlueprintType")

func isBPExposed(cls: UClassPtr): bool =
  ueCast[UInterface](cls).isNotNil() or
  cls.hasMetadata("BlueprintType") or
  cls.hasMetadata("BlueprintSpawnableComponent") or
      (cast[uint32](CLASS_MinimalAPI) and cast[uint32](cls.classFlags)) != 0 or
      (cast[uint32](CLASS_Interface) and cast[uint32](cls.classFlags)) != 0 or
      (cast[uint32](CLASS_Abstract) and cast[uint32](cls.classFlags)) != 0 or
      cls.getFuncsFromClass()
        .filter(isBPExposed)
        .any()


proc isBPExposed(prop: FPropertyPtr, outer: UObjectPtr): bool =
  var typeName = prop.getNimTypeAsStr(outer)
  if typeName.contains("TObjectPtr"):
    typeName = typeName.extractTypeFromGenericInNimFormat("TObjectPtr")
  typeName = typeName.removeFirstLetter()
  let pkg = outer.getPackage()
  let isTypeExposed = tryGetUETypeByName[UClass](pkg, typeName).map(isBPExposed)
    .chainNone(()=>tryGetUETypeByName[UScriptStruct](pkg, typeName).map(isBPExposed))
    .chainNone(()=>tryGetUETypeByName[UFunction](pkg, prop.getNimTypeAsStr(outer)).map(isBPExposed))
    .get(true) #we assume it is by default

  let flags = prop.getPropertyFlags()
  (CPF_BlueprintVisible in flags or CPF_Parm in flags) and
  isTypeExposed

func isBPExposed(uenum: UEnumPtr): bool = true
func isBPExposed(uInterface: UInterfacePtr): bool = 
  UE_Log &"Is BP Exposed {uInterface.getName()}"
  UE_Log &"{uInterface}"
  true


func isNimTypeInAffectedTypes(nimType: string, affectedTypes: seq[string]): bool =
  let isAffected =
    affectedTypes
    .any(typ =>
        typ.removeLastLettersIfPtr() == nimType.removeLastLettersIfPtr() or
        typ == nimType.extractTypeFromGenericInNimFormat("TObjectPtr") or
        typ == nimType.extractTypeFromGenericInNimFormat("TArray") or
        typ == nimType.extractTypeFromGenericInNimFormat("TSubclassOf") or
        typ == nimType.extractTypeFromGenericInNimFormat("TScriptInterface") or
        typ in nimType.extractKeyValueFromMapProp()

      )

  # UE_Log &"Is affected {nimType} {isAffected}"
  isAffected


#Function that receives a FProperty and returns a Type as string
proc toUEField*(prop: FPropertyPtr, outer: UStructPtr, rules: seq[UEImportRule] = @[]): Option[UEField] = #The expected type is something that UEField can understand
  let name = prop.getName()

  var nimType = prop.getNimTypeAsStr(outer)
  if "TEnumAsByte" in nimType:
    nimType = nimType.extractTypeFromGenericInNimFormat("TEnumAsByte")
  if "TObjectPtr" in nimType:
    let objType = nimType.extractTypeFromGenericInNimFormat("TObjectPtr")
    nimType = nimType.replace(&"TObjectPtr[{objType}]", objType & "Ptr")

  if "TMap" in nimType:
    let key = nimType.extractKeyValueFromMapProp()[0]
    let supported = @["FGuid", "FString", "FName", "FLinearColor", "FGameplayTag", "FKey", "FVector"]
    if key notin supported and key[0] == 'F':
      UE_Log &"TMap with F prefix {nimType} is not supported yet. Ignoring {name} in {outer.getName()}"
      return none(UEField)
  if "TFieldPath" in nimType:
    return none(UEField )

  #There is an issue with this type that needs further researching
  if "TArray[FPolyglotTextData]" == nimType.strip():
    return none(UEField)

  for rule in rules:
    if rule.target == uerTField and rule.rule == uerIgnore and
        (name in rule.affectedTypes or isNimTypeInAffectedTypes(nimType, rule.affectedTypes)):
        return none(UEField)

  let importRule = rules.getRuleAffectingType(nimType, uerInnerClassDelegate)
  if importRule.isSome():
    # UE_Error &"Delegate {nimType} is affected by uerInnedClassDelegate"
    #the outer of this delegate should be the same outer as the property
    #notice these delegates are not ment to be used in your our type (the name wouldnt match, it can be fixed but doesnt make sense)
    let outerName = outer.getPrefixCpp() & outer.getName()
    let isEmpty = not importRule.get().onlyFor.any()
    if isEmpty or outerName in importRule.get().onlyFor:
      nimType = getFuncDelegateNimName(nimType, outerName)

  let outerFn = tryUECast[UFunction](outer)
  var defaultValue : string  = ""
  if outerFn.isSome(): #the default values for the params are on the metadata of the function
    let ufun = outerFn.get()
    let supportedTypes = ["bool", "FString", "float32", "float64", "int32", "int", "FName", "FLinearColor", "FVector", "FVector2D", "FRotator"]
    let isSupportedDefault = nimType in supportedTypes or @["E", "A", "U"].filterIt(nimType.startsWith(it)).any()
    if ufun.hasMetadata(CPP_Default_MetadataKeyPrefix & prop.getName()) and isSupportedDefault: 
      defaultValue = ufun.getMetadata(CPP_Default_MetadataKeyPrefix & prop.getName()).get("")
      # UE_Log &"Default value for {prop.getName()} is {defaultValue} and the type is {nimType} and the flags are {prop.getPropertyFlags()}"
      

  
  if (prop.isBpExposed(outer) or uerImportBlueprintOnly notin rules or outerFn.isSome()):
    var field = makeFieldAsUProp(name, nimType, prop.getPropertyFlags(), @[], prop.getSize(), prop.getOffset())
    field.defaultParamValue = defaultValue
    return some field
  else:
    none(UEField)




func toUEField*(ufun: UFunctionPtr, rules: seq[UEImportRule] = @[]): seq[UEField] =

  let paramsMb = getFPropsFromUStruct(ufun).map(x=>toUEField(x, ufun, rules))
  let params = paramsMb.sequence()
  let allParamsExposedToBp = len(params) == len(paramsMb)
  let class = ueCast[UClass](ufun.getOuter())
  let className = class.getPrefixCpp() & class.getName()
  let actualName: string = uFun.getName()
  var fnNameNim = actualName.removePrefixes(fnPrefixes)
  #checks if there is another funciton within the class with the same name to avoid collisions
  if class.findFunctionByName(n fnNameNim).isNotNil():
    fnNameNim = actualName
  if fnNameNim.toLower() == "get": #UE uses a lot of singletons. To avoid collision we do getClass()
    fnNameNim = fnNameNim & className
  if uFun.hasMetadata(ScriptMethodMetadataKey):
    let tempName = uFun.getMetadata(ScriptMethodMetadataKey).get(fnNameNim)
    if tempName.len > 1: #There are empty names
      fnNameNim = tempName


  for rule in rules:
    if actualName in rule.affectedTypes and rule.target == uerTField and rule.rule == uerIgnore: #TODO extract
      UE_Log &"Ignoring {actualName} because it is in the ignore list"
      return  newSeq[UEField]()




  func createFunField(params:seq[UEField]) : UEField = 
    # {.cast(nosideEffect).}:
      # UE_Warn &"Creating function {fnNameNim} with params {params}"
    let funMetadata = ufun.getMetadataMap().ueMetaToNueMeta()
    var fnField = makeFieldAsUFun(fnNameNim, params, className, ufun.functionFlags, funMetadata)
    fnField.actualFunctionName = actualName
    fnField

  func getConstRefDefaultParams() : seq[UEField] = 
        params
          .filterIt(it.isConstRefParam() and 
            ufun.hasMetadata(CPP_Default_MetadataKeyPrefix & it.name))

  var funFields : seq[UEField] = @[]
  funFields.add createFunField(params)
  let refTermParamNames = getConstRefDefaultParams()
  
  if refTermParamNames.any():
    let refTermParamName = refTermParamNames[0] #Only one is supported at the meantime if more are found this can be easily extended
    let paramsWithoutRefTerm = params.filterIt(it.name != refTermParamName.name)
    funFields.add createFunField(paramsWithoutRefTerm)


  
  if ((ufun.isBpExposed()) or uerImportBlueprintOnly notin rules):
    funFields
  else:
    # UE_Error &"Function {ufun.getName()} is not exposed to blueprint"
    newSeq[UEField]()

func tryParseJson[T](jsonStr: string): Option[T] =
  {.cast(noSideEffect).}:
    try:
      some parseJson(jsonStr).jsonTo(T)
    except:
      UE_Error &"Crashed parsing json for with json {jsonStr}"
      none[T]()

func getFirstBpExposedParent(parent: UClassPtr): UClassPtr =
  if parent.isBpExposed():
    UE_Log &"Parent {parent.getName()} is exposed"
    parent
  else:    
    UE_Log &"Parent {parent} is NOT exposed"

    getFirstBpExposedParent(parent.getSuperClass())





func toUEType*(iface: UInterfacePtr, rules: seq[UEImportRule] = @[], pchIncludes:seq[string]= @[]): Option[UEType] =
  #interfaces are not supported yet. They are only take into account for checking deps of a module
  let name = "U" & iface.getName()
  UE_Log &"Found interface {name}"
  some UEType(name: name, kind: uetInterface) #TODO gather function signatures

func toUEType*(cls: UClassPtr, rules: seq[UEImportRule] = @[], pchIncludes:seq[string]= @[]): Option[UEType] =
  let storedUEType = 
    cls.getMetadata(UETypeMetadataKey)
       .flatMap((x:FString)=>tryParseJson[UEType](x))

  if storedUEType.isSome(): return storedUEType

  let fields =  getFuncsFromClass(cls)
                  .map(fn=>toUEField(fn, rules)).flatten() &
                getFPropsFromUStruct(cls)
                  .map(prop=>toUEField(prop, cls, rules))
                  .sequence()


  let name = cls.getPrefixCpp() & cls.getName()
  var parent = someNil cls.getSuperClass()
  #BP non exposed parentes are downgraded to exposed parents 
  parent = parent
    .map(p => (if uerImportBlueprintOnly in rules: getFirstBpExposedParent(p) else: p))

  let parentName = parent.map(p=>p.getPrefixCpp() & p.getName()).get("")


  let namePrefixed = cls.getPrefixCpp() & cls.getName()
  let shouldBeIgnored = (name: string, rule: UEImportRule) => name in rule.affectedTypes and rule.target == uertType and rule.rule == uerIgnore
  for rule in rules:
    if shouldBeIgnored(name, rule) or (parentName != "" and shouldBeIgnored(parentName, rule)):
      UE_Log &"Ignoring {name} because it is in the ignore list"
      return none(UEType)
  
  var isInPCH = false
  var isParentInPCH = false
  let moduleRelativePath = cls.getModuleRelativePath()
  if moduleRelativePath.isSome():
    isInPCH = isModuleRelativePathInHeaders(cls.getModuleName(), moduleRelativePath.get(), pchIncludes)
  let parentModuleRelativePath = parent.flatMap((p:UClassPtr)=>getModuleRelativePath(p))
  if parentModuleRelativePath.isSome():
    let p = parent.get()
    isParentInPCH = isModuleRelativePathInHeaders(p.getModuleName(), parentModuleRelativePath.get(), pchIncludes)

  if cls.isBpExposed() or uerImportBlueprintOnly notin rules:
    some UEType(name: name, kind: uetClass, parent: parentName, 
      isInPCH: isInPCH, isParentInPCH: isParentInPCH, moduleRelativePath:moduleRelativePath.get(""),
      fields: fields, interfaces: cls.interfaces.mapIt("U" & $it.class.getName()))
  else:
    # UE_Warn &"Class {name} is not exposed to BP"
    none(UEType)


func toUEType*(str: UScriptStructPtr, rules: seq[UEImportRule] = @[], pchIncludes:seq[string]= @[]): Option[UEType] =
  #same as above
  let storedUEType = 
    str.getMetadata(UETypeMetadataKey)
       .flatMap((x:FString)=>tryParseJson[UEType](x))
  
  if storedUEType.isSome(): return storedUEType

  let name = str.getPrefixCpp() & str.getName()

  let fields = getFPropsFromUStruct(str)
    .map(x=>toUEField(x, str, rules))
    .sequence()

  let metadata = str.getMetaDataMap()
    .toTable()
    .pairs
    .toSeq()
    .mapIt(makeUEMetadata($it[0], it[1]))

  for rule in rules:
    if name in rule.affectedTypes and rule.rule == uerIgnore:
      return none(UEType)

  # let parent = str.getSuperClass()
  # let parentName = parent.getPrefixCpp() & parent.getName()
  if str.isBpExposed() or uerImportBlueprintOnly notin rules:
    var size, alignment: int32
    if str.hasStructOps():
      size = str.getSize()
      alignment = str.getAlignment()
    else:
      UE_Warn &"The struct {str} does not have StructOps therefore we cant calculate the size and alignment"

    var isInPCH = false
    let moduleRelativePath = str.getModuleRelativePath()
    if moduleRelativePath.isSome():
      isInPCH = isModuleRelativePathInHeaders(str.getModuleName(), moduleRelativePath.get(), pchIncludes)

    some UEType(name: name, kind: uetStruct, fields: fields, 
          isInPCH: isInPCH, moduleRelativePath: moduleRelativePath.get(""),
          metadata: metadata, size: size, alignment: alignment)
  else:
    # UE_Warn &"Struct {name} is not exposed to BP"
    none(UEType)


func toUEType*(del: UDelegateFunctionPtr, rules: seq[UEImportRule] = @[], pchIncludes:seq[string]= @[]): Option[UEType] =
  let storedUEType = 
    del.getMetadata(UETypeMetadataKey)
       .flatMap((x:FString)=>tryParseJson[UEType](x))

  if storedUEType.isSome(): return storedUEType

  var name = del.getPrefixCpp() & del.getName()

  let fields = getFPropsFromUStruct(del)
    .map(x=>toUEField(x, del, rules))
    .sequence()

  let nameWithoutSuffix = name.replace(DelegateFuncSuffix, "")
  for rule in rules:
    if nameWithoutSuffix in rule.affectedTypes and rule.rule == uerIgnore:
      UE_Warn &"Ignoring {name} because it is in the ignore list"
      return none(UEType)

  #TODO is defaulting to MulticastDelegate this may be wrong when trying to autogen the types
  #Maybe I can just cast it?
  # none(UEType)
  let kind = if FUNC_MulticastDelegate in del.functionFlags: uedelMulticastDynScriptDelegate else: uedelDynScriptDelegate
    #Handle class inner delegates:
  let outer = tryUECast[UClass](del.getOuter())
  let outerName = outer.map(cls => $(cls.getPrefixCpp() & cls.getName())).get("")
  let importRule = rules.getRuleAffectingType(nameWithoutSuffix, uerInnerClassDelegate)
  if importRule.isSome():
    let isEmpty = not importRule.get().onlyFor.any()
    if isEmpty or outerName in importRule.get().onlyFor:
      name = getFuncDelegateNimName(name, outerName)

  some UEType(name: name, kind: uetDelegate, delKind: kind, fields: fields.reversed(), outerClassName: outerName)
  # else:
  #     UE_Log &"Delegate {name} is not exposed to BP"
  #     none(UEType)

func toUEType*(uenum: UEnumPtr, rules: seq[UEImportRule] = @[],  pchIncludes:seq[string]= @[]): Option[UEType] = #notice we have to specify the type because we use specific functions here. All types are Nim base types
    # let fields = getFPropsFromUStruct(enum).map(toUEField)
  let storedUEType = 
    uenum.getMetadata(UETypeMetadataKey)
       .flatMap((x:FString)=>tryParseJson[UEType](x))

  if storedUEType.isSome(): return storedUEType

  let name = uenum.getName()
  var fields = newSeq[UEField]()
  for fieldName in uenum.getEnums():
    if fieldName.toLowerAscii() in fields.mapIt(it.name.toLowerAscii()):
      # UE_Warn &"Skipping enum value {fieldName} in {name} because it collides with another field."
      continue

    fields.add(makeFieldASUEnum(fieldName.removePref("_")))

  for rule in rules:
    if name in rule.affectedTypes and rule.rule == uerIgnore:
      return none(UEType)

  if uenum.isBpExposed():
    some UEType(name: name, kind: uetEnum, fields: fields)
  else:
    UE_Warn &"Enum {name} is not exposed to BP"
    none(UEType)

func convertToUEType[T](obj: UObjectPtr, rules: seq[UEImportRule] = @[], pchIncludes:seq[string]): Option[UEType] =
  tryUECast[T](obj).flatMap((val: ptr T)=>toUEType(val, rules, pchIncludes))

proc getUETypeFrom*(obj: UObjectPtr, rules: seq[UEImportRule] = @[], pchIncludes:seq[string]): Option[UEType] =
  if obj.getFlags() & RF_ClassDefaultObject == RF_ClassDefaultObject:
    return none[UEType]()
  
  convertToUEType[UClass](obj, rules, pchIncludes)
    .chainNone(()=>convertToUEType[UScriptStruct](obj, rules, pchIncludes))
    .chainNone(()=>convertToUEType[UInterface](obj, rules, pchIncludes))
    .chainNone(()=>convertToUEType[UEnum](obj, rules, pchIncludes))
    .chainNone(()=>convertToUEType[UDelegateFunction](obj, rules, pchIncludes))

func getFPropertiesFrom*(ueType: UEType): seq[FPropertyPtr] =
  case ueType.kind:
  of uetClass:
    let outer = getUTypeByName[UClass](ueType.name.removeFirstLetter())
    if outer.isNil(): return @[] #Deprecated classes are the only thing that can return nil.

    let props = outer.getFPropsFromUStruct() &
                outer.getFuncsParamsFromClass()
    # for p in props:
    #     UE_Log p.getCppType()
    props

  of uetStruct, uetDelegate:
    tryGetUTypeByName[UStruct](ueType.name.removeFirstLetter())
      .map((str: UStructPtr)=>str.getFPropsFromUStruct())
      .get(@[])

  of uetEnum: @[]
  of uetInterface: @[]



func extractSubmodule* (path, packageName:string) : Option[string] = 
  path
    .split("/")
    .filterIt(it notin ["Public", "Classes", "Private"] and not it.endsWith(".h"))
    .mapIt(if it == "": packageName else: it) #TODO change empty by modulename once I figure if they belong together
    # .join()
    .head()
    
proc getSubmodulesForTypes*(packageName:string, types:seq[UEType]): TableRef[string, seq[UEType]] = 
  var subModTable = newTable[string, seq[UEType]]()
  for typ in types:
    let subMod = 
      case typ.kind:
      of uetClass, uetStruct:
        &"{packageName}/{typ.moduleRelativePath.extractSubmodule(packageName).get(packageName)}"
      of uetDelegate: &"{packageName}/Delegates"
      of uetEnum: &"{packageName}/Enums"
      of uetInterface: &"{packageName}/Interfaces"

    if subMod notin subModTable:
      subModTable[subMod] = newSeq[UEType]()
    subModTable[subMod].add typ
  subModTable

proc typeToModule*(propType: string): Option[string] =
  #notice types are static
  let attemptToExtractGenTypes = propType.extractInnerGenericInNimFormat()
  # UE_Log &"Extracted {attemptToExtractGenTypes} from {propType}"
  if attemptToExtractGenTypes.isGeneric(): #If it's a wrapper of one of the above types  
    # UE_Log &"Found generic type {propType} from {propType}"   
    return attemptToExtractGenTypes.typeToModule()

  getUnrealTypeFromNameAsUObject[UStruct](attemptToExtractGenTypes.removeFirstLetter().removeLastLettersIfPtr())
    # .chainNone(()=>getUnrealTypeFromName[UInterface]((propType.extractTypeFromGenericInNimFormat("TScriptInterface").removeFirstLetter())))
    .chainNone(()=>getUnrealTypeFromNameAsUObject[UEnum](propType.extractTypeFromGenericInNimFormat("TEnumAsByte")))
    .chainNone(()=>getUnrealTypeFromNameAsUObject[UStruct](propType))
    .map((obj: UObjectPtr) => $obj.getModuleName())


proc typeToSubModule*(propType: string): Option[string] =
  #notice types are static
  let attemptToExtractGenTypes = propType.extractInnerGenericInNimFormat()
  # UE_Log &"Extracted {attemptToExtractGenTypes} from {propType}"
  if attemptToExtractGenTypes.isGeneric(): #If it's a wrapper of one of the above types  
    # UE_Log &"Found generic type {propType} from {propType}"   
    return attemptToExtractGenTypes.typeToModule()
  
  let moduleName = #Tries to get the module from the relative path if not it fallbascks to the package name
    someNil(getUTypeByName[UStruct](attemptToExtractGenTypes.removeFirstLetter().removeLastLettersIfPtr()))
      .map((str:UStructPtr)=>getModuleRelativePath(str)
        .flatMap((path:string) =>
          extractSubmodule(path, str.getModuleName()).map((subMod:string)=> &"{str.getModuleName()}/{subMod}")
        )).flatten()

      
        
      
  result = moduleName
  if result.isNone():
    #Enums doesnt seem to have a moduleRelativePath
    result = someNil(getUTypeByName[UEnum](propType.extractTypeFromGenericInNimFormat("TEnumAsByte")))
              .map((obj: UEnumPtr) => &"{obj.getModuleName()}/Enums") #Cant infer the moduleRelativePath from enums
  
  if result.isSome() and "CoreUObject" in result.get:
    result = some("CoreUObject")

#returns all modules neccesary to reference the UEType
func getModuleNames*(ueType: UEType, excludeMods:seq[string]= @[]): seq[string] =
  #only uStructs based for now
  let typesToSkip = @["uint8", "uint16", "uint32", "uint64",
                      "int", "int8", "int16", "int32", "int64",
                      "float", "float32", "double",
                      "bool", "FString", "TArray"
    ]
  func filterType(typeName: string): bool = typeName notin typesToSkip

  let depsFromProps =
    ueType
      .getFPropertiesFrom()
      .mapIt(getNimTypeAsStr(it, nil))

  let interfaces = 
    case ueType.kind:
    of uetClass:
      let cls = getUTypeByName[UClass](ueType.name.removeFirstLetter())
      if cls.isNil(): @[]
      else: #class interfaces
        cls.interfaces.mapIt("U" & $it.class.getName())
    else: @[]

  let funcParamTypes = 
    case ueType.kind:
    of uetClass:
      let cls = getUTypeByName[UClass](ueType.name.removeFirstLetter())
      if cls.isNil(): @[]
      else: #class func
        cls.getFuncsParamsFromClass()
          .mapIt(getNimTypeAsStr(it, nil))
    else: @[]
  
  let otherDeps =
    case ueType.kind:
    of uetClass: ueType.parent
    else: ueType.name
  let fieldsMissedProps =
    ueType
      .fields
      .filterIt(it.kind == uefProp and it.uePropType notin depsFromProps)
      .mapIt(it.uePropType)
  (depsFromProps & otherDeps & fieldsMissedProps & interfaces & funcParamTypes)
    # .mapIt(getInnerCppGenericType($it.getCppType()))
    .filter(filterType)
    .map(getNameOfUENamespacedEnum)
    .map(typeToSubModule) 
    # .map(typeToModule) 
    .sequence()
    .deduplicate()
    .filterIt(it notin excludeMods)

func getModuleHeader*(module: UEModule): seq[string] =
  module.types
    .filterIt(it.kind == uetStruct)
    .mapIt(it.metadata["ModuleRelativePath"])
    .sequence()
    .mapIt(&"""#include "{it}" """)


proc getUETypeByNameFromUE(name:string, rules:seq[UEImportRule], pchIncludes:seq[string]= @[]) : Option[UEType] = 
  let obj = getUnrealTypeFromNameAsUObject[UStruct](name.removeFirstLetter().removeLastLettersIfPtr())
              .chainNone(()=>getUnrealTypeFromNameAsUObject[UEnum](name.extractTypeFromGenericInNimFormat("TEnumAsByte")))
              .chainNone(()=>getUnrealTypeFromNameAsUObject[UInterface](name.extractTypeFromGenericInNimFormat("TScriptInterface").removeFirstLetter()))
              .chainNone(()=>getUnrealTypeFromNameAsUObject[UStruct](name))
              
  result = obj.map(it=>getUETypeFrom(it, rules, pchIncludes)).flatten()
  


proc getForcedTypes*(moduleName:string, rules: seq[UEImportRule]): seq[UEType] =
  result = rules
      .filterIt(it.rule == uerForce)
      .mapIt(it.affectedTypes)
      .foldl(a & b, newSeq[string]())
      .mapIt(getUETypeByNameFromUE(it, rules))
      .sequence()
  if result.any():
    UE_Log &"Forced types for {moduleName}: {result} and {rules.filterIt(it.rule == uerForce)}"
  
  


proc getDepsFromTypes*(name: string, types : seq[UEType], excludeDeps: seq[string]) : seq[string] = 
  types
    .mapIt(it.getModuleNames(@["CoreUObject", name]))
    .foldl(a & b, newSeq[string]())
    .deduplicate()
    .filterIt(it != name and it notin excludeDeps)

# proc toUEModule*(pkg: UPackagePtr, rules: seq[UEImportRule], excludeDeps: seq[string], includeDeps: seq[string], pchIncludes:seq[string]= @[]): seq[UEModule] =
#   UE_Log &"Generating module for {pkg.getShortName()} pchIncludes: {pchIncludes.len}"
#   let allObjs = pkg.getAllObjectsFromPackage[:UObject]()
#   var name = pkg.getShortName()

#   let initialTypes = allObjs.toSeq()
#     .map((obj: UObjectPtr) => getUETypeFrom(obj, rules, pchIncludes))
#     .sequence()
  

#   let moduleExcludeDeps = rules.filterIt(it.rule == uerExcludeDeps).mapIt(it.affectedTypes).foldl(a & b, newSeq[string]())
#   var excludeDeps = excludeDeps & moduleExcludeDeps
#   var types = (initialTypes & getForcedTypes(name, rules)).deduplicate()
#   let excludeFromModuleNames = @["CoreUObject", name]
#   let deps = getDepsFromTypes(name, types, excludeDeps)
#   #TODO Per module add them to a virtual module
#   let excludedTypes = types.filterIt(it.getModuleNames(excludeFromModuleNames).any(modName => modName in excludeDeps))
#   for t in excludedTypes:
#     UE_Warn &"Module: + {name} Excluding {t.name} from {name} because it depends on {t.getModuleNames(excludeFromModuleNames)}"

#   types = types.filterIt(it notin excludedTypes)



#   #Virtual modules.
#   var virtModules = newSeq[UEModule]()
#   for r in rules:
#     if r.rule == uerVirtualModule:
#       let r = r
#       let (virtualModuleTypes, types) = types.partition((x: UEType) => x.name in r.affectedTypes)
#       virtModules.add UEModule(name: r.moduleName, types: virtualModuleTypes, isVirtual: true, dependencies: deps & name,  rules: rules)
#   #Types that causes cycles are also part of the virtual modules. TODO this code assume excludeDeps is cycles + coreuobject
#   for cycleMod in excludeDeps.filterIt(it != "CoreUObject"):
#     let cycleMod = cycleMod
#     let (cycleTypes, types) = initialTypes.partition((x: UEType) => cycleMod in x.getModuleNames(excludeFromModuleNames))
#     let cycleName = &"{name}_{cycleMod}"
#     # UE_Error &"Module: + {name} Adding {cycleName} to {name} because it depends on {cycleMod} and {cycleTypes} is excluded"
#     if cycleTypes.len > 0: #if it doesnt have types it shouldnt be a added
#       virtModules.add UEModule(name: cycleName, types: cycleTypes, isVirtual: true, dependencies: deps & name & cycleMod, rules: rules)

#   var module = makeUEModule(name, types, rules, deps)
#   module.hash = $hash($module.toJson())
#   module & virtModules

proc toUEModule*(pkg: UPackagePtr, rules: seq[UEImportRule], excludeDeps: seq[string], includeDeps: seq[string], pchIncludes:seq[string]= @[]): seq[UEModule] =
  UE_Log &"Generating module for {pkg.getShortName()} pchIncludes: {pchIncludes.len}"
  let allObjs = pkg.getAllObjectsFromPackage[:UObject]()
  var name = pkg.getShortName()

  let initialTypes = allObjs.toSeq()
    .map((obj: UObjectPtr) => getUETypeFrom(obj, rules, pchIncludes))
    .sequence()
  
  let submodulesTable = getSubmodulesForTypes(pkg.getShortName(), initialTypes)
  var submodules : seq[UEModule] = @[]
  for subModuleName, submoduleTypes in submodulesTable:
    # let deps = getDepsFromTypes(subModuleName, submoduleTypes, @[])
    var module = makeUEModule(subModuleName, submoduleTypes, rules)
    module.hash = $hash($module.toJson())
    submodules.add module
  return submodules


  # let moduleExcludeDeps = rules.filterIt(it.rule == uerExcludeDeps).mapIt(it.affectedTypes).foldl(a & b, newSeq[string]())
  # var excludeDeps = excludeDeps & moduleExcludeDeps
  # var types = (initialTypes & getForcedTypes(name, rules)).deduplicate()
  # let excludeFromModuleNames = @["CoreUObject", name]
  # let deps = getDepsFromTypes(name, types, excludeDeps)
  # #TODO Per module add them to a virtual module
  # let excludedTypes = types.filterIt(it.getModuleNames(excludeFromModuleNames).any(modName => modName in excludeDeps))
  # for t in excludedTypes:
  #   UE_Warn &"Module: + {name} Excluding {t.name} from {name} because it depends on {t.getModuleNames(excludeFromModuleNames)}"

  # types = types.filterIt(it notin excludedTypes)



  # #Virtual modules.
  # var virtModules = newSeq[UEModule]()
  # for r in rules:
  #   if r.rule == uerVirtualModule:
  #     let r = r
  #     let (virtualModuleTypes, types) = types.partition((x: UEType) => x.name in r.affectedTypes)
  #     virtModules.add UEModule(name: r.moduleName, types: virtualModuleTypes, isVirtual: true, dependencies: deps & name,  rules: rules)
  # #Types that causes cycles are also part of the virtual modules. TODO this code assume excludeDeps is cycles + coreuobject
  # for cycleMod in excludeDeps.filterIt(it != "CoreUObject"):
  #   let cycleMod = cycleMod
  #   let (cycleTypes, types) = initialTypes.partition((x: UEType) => cycleMod in x.getModuleNames(excludeFromModuleNames))
  #   let cycleName = &"{name}_{cycleMod}"
  #   # UE_Error &"Module: + {name} Adding {cycleName} to {name} because it depends on {cycleMod} and {cycleTypes} is excluded"
  #   if cycleTypes.len > 0: #if it doesnt have types it shouldnt be a added
  #     virtModules.add UEModule(name: cycleName, types: cycleTypes, isVirtual: true, dependencies: deps & name & cycleMod, rules: rules)

  # var module = makeUEModule(name, types, rules, deps)
  # module.hash = $hash($module.toJson())
  # module & virtModules


proc emitFProperty*(propField: UEField, outer: UStructPtr): FPropertyPtr =
  assert propField.kind == uefProp

  let prop: FPropertyPtr = newFProperty(makeFieldVariant outer, propField)
  prop.setPropertyFlags(propField.propFlags or prop.getPropertyFlags())
  when WithEditor:
    for metadata in propField.metadata:
      prop.setMetadata(metadata.name, $metadata.value)
  outer.addCppProperty(prop)
  prop


#this functions should only being use when trying to resolve
#the nim name in unreal on the emit, when the actual name is not set already.
#it is also taking into consideration when converting from ue to nim via UClass->UEType
func findFunctionByNameWithPrefixes*(cls: UClassPtr, name: string): Option[UFunctionPtr] =
  for name in [name, name.capitalizeAscii()]:
    for prefix in fnPrefixes:
      let fnName = prefix & name
      # assert not cls.isNil()
      if cls.isNil():
        return none[UFunctionPtr]()
      let fun = cls.findFunctionByName(makeFName(fnName))
      if not fun.isNil():
        return some fun

  none[UFunctionPtr]()

#note at some point class can be resolved from the UEField?
proc emitUFunction*(fnField: UEField, ueType:UEType, cls: UClassPtr, fnImpl: Option[UFunctionNativeSignature]): UFunctionPtr =
  let superCls = someNil(cls.getSuperClass())
  let superFn = superCls.flatmap((scls: UClassPtr)=>scls.findFunctionByNameWithPrefixes(fnField.name))

  #if we are overriden a function we use the name with the prefix
  #notice this only works with BlueprintEvent so check that too.
  var fnName = superFn.map(fn=>fn.getName().makeFName()).get(fnField.name.makeFName())

  #we need to see if any of the implemented interfaces have the function
  # let isAnInterfaceFn = ueType.interfaces.mapIt(getClassByName(it.removeFirstLetter()).findFunctionByNameWithPrefixes(fnField.name)).sequence().any()
  # if isAnInterfaceFn:
  #   UE_Warn &"Interface function: {fnName} in {cls.getName().makeFName()}"
  #   if not ($fnName).startsWith("BP_"):
  #     fnName = makeFName("BP_" & ($fnName).capitalizeAscii())

  const objFlags = RF_Public | RF_Transient | RF_MarkAsRootSet | RF_MarkAsNative
  var fn = newUObject[UNimFunction](cls, fnName, objFlags)
  fn.functionFlags = EFunctionFlags(fnField.fnFlags)

  if superFn.isSome():
    let sFn = superFn.get()
    fn.functionFlags = (fn.functionFlags | (sFn.functionFlags & (FUNC_FuncInherit | FUNC_Public | FUNC_Protected | FUNC_Private | FUNC_BlueprintPure | FUNC_HasOutParms)))
    when WithEditor:
      copyMetadata(sFn, fn)
      fn.setMetadata("ToolTip", fn.getMetadata("ToolTip").get()&" vNim")
    setSuperStruct(fn, sFn)


  fn.Next = cls.Children
  cls.Children = fn

  for field in fnField.signature.reversed():
    let fprop = field.emitFProperty(fn)
  
  if superFn.isNone():
    when WithEditor:
      for metadata in fnField.metadata:
        fn.setMetadata(metadata.name, $metadata.value)

  cls.addFunctionToFunctionMap(fn, fnName)
  if fnImpl.isSome(): #blueprint implementable events doesnt have a function implementation
    fn.setNativeFunc(makeFNativeFuncPtr(fnImpl.get()))
  fn.staticLink(true)
  fn.sourceHash = $hash(fnField.sourceHash)
  # fn.parmsSize = uprops.foldl(a + b.getSize(), 0) doesnt seem this is necessary
  fn


proc isNotNil[T](x: ptr T): bool = not x.isNil()
proc isNimClassBase(cls: UClassPtr): bool = cls.isNimClass()



proc initComponents*(initializer: var FObjectInitializer, actor:AActorPtr, actorCls:UClassPtr) {.cdecl.} = 
  #get a chance to init the parent
  let parentCls = actorCls.getSuperClass()
  if parentCls.isNimClass() or parentCls.isBpClass():
    initComponents(initializer, actor, parentCls)

  # #Check defaults
  for objProp in getAllPropsWithMetaData[FObjectPtrProperty](actorCls, DefaultComponentMetadataKey):
      let compCls = objProp.getPropertyClass()
      var defaultComp = ueCast[UActorComponent](initializer.createDefaultSubobject(actor, objProp.getName().firstToUpper().makeFName(), compCls, compCls, true, false))
      setPropertyValuePtr[UActorComponentPtr](objProp, actor, defaultComp.addr)
 
  #Root component
  for objProp in actorCls.getAllPropsWithMetaData[:FObjectPtrProperty](RootComponentMetadataKey):
      let comp = ueCast[USceneComponent](getPropertyValuePtr[USceneComponentPtr](objProp, actor)[])
      if comp.isNotNil():
        let prevRoot = actor.getRootComponent()
        discard actor.setRootComponent(comp)
        if prevRoot.isNotNil():
          prevRoot.setupAttachment(comp)
  #Handles attachments
  for objProp in actorCls.getAllPropsOf[:FObjectPtrProperty]():
        let comp = ueCast[USceneComponent](getPropertyValuePtr[USceneComponentPtr](objProp, actor)[])
        UE_Log &"Comp: {comp} {objProp}"
        if comp.isNotNil():
          if objProp.hasMetadata(AttachMetadataKey):
              #Tries to find it both, camelCase and PascalCase. Probably we should push PascalCase to UE
              var attachToCompProp = actor.getClass().getFPropertyByName(objProp.getMetadata(AttachMetadataKey).get())
              if attachToCompProp.isNil():
                attachToCompProp = actor.getClass().getFPropertyByName(objProp.getMetadata(AttachMetadataKey).get().capitalizeASCII)
              
              let attachToComp = ueCast[USceneComponent](getPropertyValuePtr[USceneComponentPtr](attachToCompProp, actor)[])
              if objProp.hasMetadata(SocketMetadataKey):
                comp.setupAttachment(attachToComp, n(objProp.getMetadata(SocketMetadataKey).get()))
              else:
                comp.setupAttachment(attachToComp)

          else:
              UE_Warn &"No attach metadata for {comp.getName()}"
              if comp != actor.getRootComponent():
                comp.setupAttachment(actor.getRootComponent())


  if actor.getRootComponent().isNil():
      discard actor.setRootComponent(initializer.createDefaultSubobject[:USceneComponent](n"DefaultSceneRoot"))
#This always be appened at the default constructor at the beggining
proc callSuperConstructor*(initializer: var FObjectInitializer) {.cdecl.} =
  let obj = initializer.getObj() #NEXT test line by line until it breaks
  let cls = obj.getClass()
  var cppCls = cls.getFirstCppClass()
  cppCls.classConstructor(initializer)
 
  let actor = tryUECast[AActor](obj)
  if actor.isSome():
    initComponents(initializer, actor.get(), cls)


#This needs to be appended after the default constructor so comps can be init
proc postConstructor*(initializer: var FObjectInitializer) {.cdecl.} =
  let obj = initializer.getObj()
  let cls = obj.getClass()
 
 
  
proc defaultConstructor*(initializer: var FObjectInitializer) {.cdecl, deprecated.} =
  callSuperConstructor(initializer)
  postConstructor(initializer)


# when WithEditor:
#   proc setGIsUCCMakeStandaloneHeaderGenerator*(value: bool) {.importcpp: "(GIsUCCMakeStandaloneHeaderGenerator =#)".}
# else:
proc setGIsUCCMakeStandaloneHeaderGenerator*(value: static bool) = 
    when value:
      {.emit:""" ;
#define GIsUCCMakeStandaloneHeaderGenerator true
""".}
    else:
      {.emit:""";
      
#define GIsUCCMakeStandaloneHeaderGenerator false

""".}

proc emitUClass*[T](ueType: UEType, package: UPackagePtr, fnTable: seq[FnEmitter], clsConstructor: UClassConstructor, vtableConstructor:VTableConstructor): UFieldPtr =
  const objClsFlags = (RF_Public | RF_Standalone | RF_MarkAsRootSet)
 
  let newCls = newUObject[UClass](package, makeFName(ueType.name.removeFirstLetter()), cast[EObjectFlags](objClsFlags))
  newCls.setClassConstructor(clsConstructor)

  let parentCls = someNil(getClassByName(ueType.parent.removeFirstLetter()))
  let parent = parentCls
    .getOrRaise(&"Parent class {ueType.parent} not found fosr {ueType.name}")

  assetCreated(newCls)

  newCls.propertyLink = parent.propertyLink
  newCls.classWithin = parent.classWithin
  newCls.classConfigName = parent.classConfigName

  newCls.setSuperStruct(parent)
  newCls.classVTableHelperCtorCaller = vtableConstructor

  # use explicit casting between uint32 and enum to avoid range checking bug https://github.com/nim-lang/Nim/issues/20024
  newCls.classFlags = cast[EClassFlags](ueType.clsFlags.uint32 and parent.classFlags.uint32)
  newCls.classCastFlags = parent.classCastFlags

  
  when WithEditor:
      
    copyMetadata(parent, newCls)
  
    newCls.markAsNimClass()

    for metadata in ueType.metadata:
      UE_Log &"Setting metadata {metadata.name} to {metadata.value}"
      newCls.setMetadata(metadata.name, $metadata.value)


  UE_Log &"THE UE TYPE {ueType}" 
  for field in ueType.fields:

    UE_Log "Emmiting field: " & field.name & " of kind: " & $field.kind 
    case field.kind:
    of uefProp: discard field.emitFProperty(newCls)
    of uefFunction:
      # UE_Log fmt"Emitting function {field.name} in class {newCls.getName()}" #notice each module emits its own functions  
      discard emitUFunction(field, ueType, newCls, getNativeFuncImplPtrFromUEField(getGlobalEmitter(), field))
    else:
      UE_Error("Unsupported field kind: " & $field.kind)

  for iface in ueType.interfaces:
    let ifaceCls = getClassByName(iface.removeFirstLetter())
    if ifaceCls.isNotNil():
      UE_Log &"Adding interface {ifaceCls.getName()} to {newCls.getName()}"
      let implementedInterface = makeFImplementedInterface(ifaceCls, 0, true)
      newCls.interfaces.add(implementedInterface)



  newCls.staticLink(true)
  newCls.classFlags =  cast[EClassFlags](newCls.classFlags.uint32 or CLASS_Intrinsic.uint32)

  setGIsUCCMakeStandaloneHeaderGenerator(true)
  newCls.bindType()
  setGIsUCCMakeStandaloneHeaderGenerator(false)
  newCls.assembleReferenceTokenStream()
  
  when WithEditor:
    newCls.setMetadata(UETypeMetadataKey, $ueType.toJson())



  discard newCls.getDefaultObject() #forces the creation of the cdo. the LC reinstancer needs it created before the object gets nulled out
    # broadcastAsset(newCls) Dont think this is needed since the notification will be done in the boundary of the plugin
  if newCls.isChildOf[:UEngineSubsystem]():
    UE_Warn &"Activating engine subsystem {newCls.getName()}"
    #initi the subystem. Doesnt seem that we need to deactivated it but there is an inverse.
    #Need to test if it's neccesary with non engine subsystems
    activateExternalSubsystem(newCls)

  newCls



#	explicit UStruct(UStruct* InSuperStruct, SIZE_T ParamsSize = 0, SIZE_T Alignment = 0);
# UScriptStruct* NewStruct = new(EC_InternalUseOnlyConstructor, Outer, UTF8_TO_TCHAR(Params.NameUTF8), Params.ObjectFlags) UScriptStruct(FObjectInitializer(), Super, StructOps, (EStructFlags)Params.StructFlags, Params.SizeOf, Params.AlignOf);
# UScriptStruct(FObjectInitializer(), Super, StructOps, (EStructFlags)Params.StructFlags, Params.SizeOf, Params.AlignOf)
proc newScriptStruct[T](package: UPackagePtr, name:FString, flags:EObjectFlags, super:UScriptStructPtr, size:int32, align:int32, fake:T) : UNimScriptStructPtr {.importcpp: 
  "new(EC_InternalUseOnlyConstructor, #, *#, #) UNimScriptStruct(FObjectInitializer(), #, (new UScriptStruct::TCppStructOps<'7>()), (EStructFlags)0, #, #)".}


proc emitUStruct*[T](ueType: UEType, package: UPackagePtr): UFieldPtr =
  UE_Log &"Struct emited {ueType.name}"
  const objClsFlags = (RF_Public | RF_Standalone | RF_MarkAsRootSet)
  var superStruct : UScriptStructPtr
  if ueType.superStruct.len > 0:
    let parent = someNil(getUTypeByName[UScriptStruct](ueType.superStruct.removeFirstLetter()))
    superStruct = parent.getOrRaise(&"Parent struct {ueType.superStruct} not found for {ueType.name}")
  
  # let scriptStruct = newUObject[UNimScriptStruct](package, makeFName(ueType.name.removeFirstLetter()), objClsFlags)
  #SuperStructs not supported but this is the way to support them
  let scriptStruct = newScriptStruct[T](package, f ueType.name.removeFirstLetter(), objClsFlags, superStruct, sizeof(T).int32, alignof(T).int32, T())

  for metadata in ueType.metadata:
    scriptStruct.setMetadata(metadata.name, $metadata.value)

  scriptStruct.assetCreated()
  
  for field in ueType.fields:
    discard field.emitFProperty(scriptStruct)

  setCppStructOpFor[T](scriptStruct, nil)
  UE_Log &"Struct emited {scriptStruct.getName()}"
  setGIsUCCMakeStandaloneHeaderGenerator(true)
  scriptStruct.bindType()
  scriptStruct.staticLink(true)
  setGIsUCCMakeStandaloneHeaderGenerator(false)

  scriptStruct.setMetadata(UETypeMetadataKey, $ueType.toJson())
  UE_Log &"Ssale?"
  scriptStruct

proc emitUStruct*[T](ueType: UEType, package: string): UFieldPtr =
  let package = getPackageByName(package)
  if package.isnil():
    raise newException(Exception, "Package not found!")
  emitUStruct[T](ueType, package)

proc emitUEnum*(enumType: UEType, package: UPackagePtr): UFieldPtr =
  let name = enumType.name.makeFName()
  const objFlags = RF_Public | RF_Transient | RF_MarkAsNative
  let uenum = newUObject[UNimEnum](package, name, objFlags)
  for metadata in enumType.metadata:
    uenum.setMetadata(metadata.name, $metadata.value)
  let enumFields = makeTArray[TPair[FName, int64]]()
  for field in enumType.fields.pairs:
    let fieldName = field.val.name.makeFName()
    enumFields.add(makeTPair(fieldName, field.key.int64))
    # uenum.setMetadata("DisplayName", "Whatever"&field.val.name)) TODO the display name seems to be stored into a metadata prop that isnt the one we usually use
  discard uenum.setEnums(enumFields)
  uenum.setMetadata(UETypeMetadataKey, $enumType.toJson())

  uenum

proc emitUDelegate*(delType: UEType, package: UPackagePtr): UFieldPtr =
  let fnName = (delType.name.removeFirstLetter() & DelegateFuncSuffix).makeFName()
  const objFlags = RF_Public | RF_Transient | RF_MarkAsNative
  var fn = newUObject[UDelegateFunction](package, fnName, objFlags)
  fn.functionFlags = FUNC_MulticastDelegate or FUNC_Delegate
  for field in delType.fields.reversed():
    let fprop = field.emitFProperty(fn)
    # UE_Warn "Has Return " & $ (CPF_ReturnParm in fprop.getPropertyFlags())

  fn.staticLink(true)
  fn.setMetadata(UETypeMetadataKey, $delType.toJson())
  fn



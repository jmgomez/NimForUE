
include ../unreal/prelude
import std/[times,strformat, strutils, options, sugar, algorithm, sequtils]
import models

const propObjFlags = RF_Public | RF_Transient | RF_MarkAsNative

#Forward declare
proc newFProperty*(owner : FFieldVariant, propField:UEField, optPropType="", optName="",  propFlags=CPF_None) : FPropertyPtr 

func newUStructBasedFProperty(owner : FFieldVariant, propType:string, name:FName, propFlags=CPF_None) : Option[FPropertyPtr] = 
    const flags = propObjFlags
         #It holds a complex type, like a struct or a class
    type EObjectMetaProp = enum
        emObjPtr, emClass, emTSubclassOf, emTSoftObjectPtr, emTSoftClassPtr, emScriptStruct, emTObjectPtr#, TSoftClassPtr = "TSoftClassPtr"
    
    var eMeta = if propType.contains("TSubclassOf"): emTSubclassOf
                elif propType.contains("TSoftObjectPtr"): emTSoftObjectPtr
                elif propType.contains("TSoftClassPtr"): emTSoftClassPtr
                elif propType.contains("TObjectPtr"): emTObjectPtr
                elif propType == ("UClass"): emClass
                else: emObjPtr #defaults to emObjPtr but it can be scriptStruct since the name it's the same(will worth to do an or?)
                
    let className = case eMeta 
        of emTSubclassOf: propType.extractTypeFromGenericInNimFormat("TSubclassOf").removeFirstLetter() 
        of emTSoftObjectPtr: propType.extractTypeFromGenericInNimFormat("TSoftObjectPtr").removeFirstLetter() 
        of emTSoftClassPtr: propType.extractTypeFromGenericInNimFormat("TSoftClassPtr").removeFirstLetter() 
        of emTObjectPtr: propType.extractTypeFromGenericInNimFormat("TObjectPtr").removeFirstLetter() 
        of emObjPtr, emClass, emScriptStruct: propType.removeFirstLetter().removeLastLettersIfPtr()

    UE_Log "Looking for ustruct.." & className 
    let ustruct = getUStructByName className
    if ustruct.isnil(): return none[FPropertyPtr]()
    #we still dont know if it's a script struct
    let cls = ueCast[UClass](ustruct)
    let scriptStruct = ueCast[UScriptStruct](ustruct)
    if not scriptStruct.isNil():
        eMeta = emScriptStruct   
        UE_Log "Found ScriptStruct " & propType & " creating Prop"
    else:
        UE_Log "Found Class " & propType & " creating Prop"

    some case eMeta:
    of emClass, emTSubclassOf:
        UE_Error &"ENTRA EN CLAS PARA CREAR PROPIEDAD {propType} {name} class name is {className}"
        #check if it's a component here
        let clsProp = newFClassProperty(owner, name, flags)
        clsProp.setPropertyMetaClass(cls)
        clsProp
    of emTSoftClassPtr:
        let clsProp = newFSoftClassProperty(owner, name, flags)
        clsProp.setPropertyMetaClass(cls)
        clsProp
    of emObjPtr, emTObjectPtr:
        let isComponent = isChildOf[UActorComponent](cls)
        let objProp = newFObjectPtrProperty(owner, name, flags)
        objProp.setPropertyClass(cls)
        if isComponent: 
            objProp.setPropertyFlags(CPF_InstancedReference or CPF_NativeAccessSpecifierPublic or CPF_ExportObject)


        objProp
    of emTSoftObjectPtr:
        let softObjProp = newFSoftObjectProperty(owner, name, flags)
        softObjProp.setPropertyClass(cls)
        softObjProp
    of emScriptStruct:
        let structProp = newFStructProperty(owner, name, flags)
        structProp.setScriptStruct(scriptStruct)
        structProp


func newDelegateBasedProperty(owner : FFieldVariant, propType:string, name:FName) : Option[FPropertyPtr] = 
    #Try to find it as Delegate
    const flags = propObjFlags
    UE_Log "Not a struct based prorperty. Trying as delegate.." & propType
    let delegateName = propType.removeFirstLetter() & DelegateFuncSuffix
    
    someNil(getUTypeByName[UDelegateFunction] delegateName)
        .map(func (delegate:UDelegateFunctionPtr) : FPropertyPtr = 
                let isMulticast = FUNC_MulticastDelegate in delegate.functionFlags
                if isMulticast:
                    UE_Log fmt("Found {propType}  as  MulticastDelegate. Creating prop")
                    let delegateProp = newFMulticastInlineDelegateProperty(owner, name, flags)
                    delegateProp.setSignatureFunction(delegate)
                    delegateProp
                else:
                    UE_Log fmt("Found {propType}  as  Delegate. Creating prop")
                    let delegateProp = newFDelegateProperty(owner, name, flags)
                    delegateProp.setSignatureFunction(delegate)
                    delegateProp
            )
    
func newEnumBasedProperty(owner : FFieldVariant, propType:string, name:FName) : Option[FPropertyPtr] = 
    #Try to find it as Enum
    const flags = propObjFlags
    UE_Log "Not a delegate based prorperty. Trying as enum.." & propType
    let enumProp = propType.extractTypeFromGenericInNimFormat("TEnumAsByte")
    someNil(getUTypeByName[UEnum](enumProp))
        .map(func (ueEnum:UEnumPtr) : FPropertyPtr = 
                UE_Log "Found " & enumProp & " as Enum. Creating prop"
                let enumProp = newFEnumProperty(owner, name, flags)
                enumProp.setEnum(ueEnum)
                #Assuming that Enums are exposed via TEnumAsByte or they are uint8. Revisit in the future (only bp exposed enums meets that)
                let underlayingProp : FPropertyPtr = newFByteProperty(makeFieldVariant(enumProp), n"UnderlayingEnumProp", flags)
                enumProp.addCppProperty(underlayingProp)
                enumProp
            )

#Not sure why this is needed but you cant return some derivedPtr and expect an Option?
func someFProp(prop : FPropertyPtr) : Option[FPropertyPtr] = some prop

proc newContainerProperty(owner : FFieldVariant, propField:UEField, propType:string, name:FName, propFlags=CPF_None) : Option[FPropertyPtr] = 
    if propType.contains("TArray"):
        let arrayProp = newFArrayProperty(owner, name, propObjFlags)
        arrayProp.setPropertyFlags(CPF_ZeroConstructor)

        let innerType = propType.extractTypeFromGenericInNimFormat("TArray")
        let innerProp = newFProperty(makeFieldVariant(arrayProp), propField, optPropType=innerType, optName= $name & "_Inner")
        
        arrayProp.setInnerProp(innerProp)
        return someFProp(arrayProp)

    if propType.contains("TSet"):
        let setProp = newFSetProperty(owner, name, propObjFlags)
        let elementPropType = propType.extractTypeFromGenericInNimFormat("TSet")
        let elementProp = newFProperty(makeFieldVariant(setProp), propField, optPropType=elementPropType, optName="ElementProp",  propFlags=CPF_HasGetValueTypeHash)
        setProp.addCppProperty(elementProp)
        return someFProp setProp
            
    if propType.contains("TMap"):
        let mapProp = newFMapProperty(owner, name, propObjFlags)
        let innerTypes = propType.extractKeyValueFromMapProp()
        let key = newFProperty(makeFieldVariant(mapProp), propField, optPropType=innerTypes[0], optName= $name&"_Key", propFlags=CPF_HasGetValueTypeHash) 
        let value = newFProperty(makeFieldVariant(mapProp), propField, optPropType=innerTypes[1], optName= $name&"_Value")

        mapProp.addCppProperty(key)
        mapProp.addCppProperty(value)
        return someFProp mapProp

    return none[FPropertyPtr]()
    
proc newBasicProperty(owner : FFieldVariant, propField:UEField, propType:string, name:FName, propFlags=CPF_None) : Option[FPropertyPtr] = 
    if propType == "FString": 
        someFProp newFStrProperty(owner, name, propObjFlags)
    elif propType == "bool": 
        let boolProp = newFBoolProperty(owner, name, propObjFlags)
        boolProp.setBoolSize(sizeof(bool).uint32, isNativeBool=true)
        someFProp boolProp
    elif propType == "int8": 
        someFProp newFInt8Property(owner, name, propObjFlags)
    elif propType == "int16": 
        someFProp newFInt16Property(owner, name, propObjFlags)
    elif propType == "int32": 
        someFProp newFIntProperty(owner, name, propObjFlags)
    elif propType in ["int64", "int"]: 
        someFProp newFInt64Property(owner, name, propObjFlags)
    elif propType == "byte": 
        someFProp newFByteProperty(owner, name, propObjFlags)
    elif propType == "uint16": 
        someFProp newFUInt16Property(owner, name, propObjFlags)
    elif propType == "uint32": 
        someFProp newFUInt32Property(owner, name, propObjFlags)
    elif propType == "uint64": 
        someFProp newFUint64Property(owner, name, propObjFlags)
    elif propType == "float32": 
        someFProp newFFloatProperty(owner, name, propObjFlags)
    elif propType in ["float", "float64"]: 
        someFProp newFDoubleProperty(owner, name, propObjFlags)
    elif propType == "FName": 
        someFProp newFNameProperty(owner, name, propObjFlags)
    else:
        none[FPropertyPtr]()

func isBasicProperty*(nimTypeName: string) : bool =      
    nimTypeName in [
        "FString", "bool", "int8", "int16", "int32", "int64", "int", 
        "byte", "uint16", "uint32", "uint64", "float32", "float", "float64", 
        "FName"
    ]



func isContainer(nimTypeName:string) : bool = 
    let containers = @["TArray", "TSet", "TMap"]
    containers.any(c=>c in nimTypeName)



proc newFProperty*(owner : FFieldVariant, propField:UEField, optPropType="", optName="",  propFlags=CPF_None) : FPropertyPtr = 
    let 
        #is optX is passed, priotize it since it comes from newContainerProperty
        propType = optPropType.nonEmptyOr(propField.uePropType)
        name = optName.nonEmptyOr(propField.name).makeFName()

    const flags = propObjFlags
    UE_Log "Creating new property: " & $name & " of type: " & propType
    let prop : FPropertyPtr = 
        if isBasicProperty(propType): newBasicProperty(owner, propField, propType, name).get()
        elif isContainer(propType) and owner.isUObject() : newContainerProperty(owner, propField, propType, name).get()
        else: #ustruct based?
            newUStructBasedFProperty(owner, propType, name, propFlags)
                .chainNone(()=>newDelegateBasedProperty(owner, propType, name))
                .chainNone(()=>newEnumBasedProperty(owner, propType, name))
                .getOrRaise("FProperty not covered in the types for " & propType, Exception)
                    
        
    prop.setPropertyFlags(prop.getPropertyFlags() or propFlags) #in case custom fprop require custom flags (see TMAP)
    prop
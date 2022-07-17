
include ../unreal/prelude
import std/[times,strformat, strutils, options, sugar, algorithm, sequtils]
import models


func newUStructBasedFProperty(outer : UStructPtr, propType:string, name:FName, propFlags=CPF_None) : Option[FPropertyPtr] = 
    let flags = RF_NoFlags #OBJECT FLAGS
 #It holds a complex type, like a struct or a class
    type EObjectMetaProp = enum
        emObjPtr, emClass, emTSubclassOf, emTSoftObjectPtr, emTSoftClassPtr, emScriptStruct#, TSoftClassPtr = "TSoftClassPtr"
    
    var eMeta = if propType.contains("TSubclassOf"): emTSubclassOf
                elif propType.contains("TSoftObjectPtr"): emTSoftObjectPtr
                elif propType.contains("TSoftClassPtr"): emTSoftClassPtr
                elif propType == ("UClass"): emClass
                else: emObjPtr #defaults to emObjPtr but it can be scriptStruct since the name it's the same(will worth to do an or?)
                

    let className = case eMeta 
        of emTSubclassOf: propType.extractTypeFromGenericInNimFormat("TSubclassOf").removeFirstLetter() 
        of emTSoftObjectPtr: propType.extractTypeFromGenericInNimFormat("TSoftObjectPtr").removeFirstLetter() 
        of emTSoftClassPtr: propType.extractTypeFromGenericInNimFormat("TSoftClassPtr").removeFirstLetter() 
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
        let clsProp = newFClassProperty(makeFieldVariant(outer), name, flags)
        clsProp.setPropertyMetaClass(cls)
        clsProp
    of emTSoftClassPtr:
        let clsProp = newFSoftClassProperty(makeFieldVariant(outer), name, flags)
        clsProp.setPropertyMetaClass(cls)
        clsProp
    of emObjPtr:
        let objProp = newFObjectProperty(makeFieldVariant(outer), name, flags)
        objProp.setPropertyClass(cls)
        objProp
    of emTSoftObjectPtr:
        let softObjProp = newFSoftObjectProperty(makeFieldVariant(outer), name, flags)
        softObjProp.setPropertyClass(cls)
        softObjProp
    of emScriptStruct:
        let structProp = newFStructProperty(makeFieldVariant(outer), name, flags)
        structProp.setScriptStruct(scriptStruct)
        structProp


    

func newFProperty*(outer : UStructPtr, propField:UEField, optPropType="", optName="",  propFlags=CPF_None) : FPropertyPtr = 
    let 
        propType = optPropType.nonEmptyOr(propField.uePropType)
        name = optName.nonEmptyOr(propField.name).makeFName()
        flags = RF_NoFlags #OBJECT FLAGS

    let prop : FPropertyPtr = 
        if propType == "FString": 
            newFStrProperty(makeFieldVariant(outer), name, flags)
        elif propType == "bool": 
            newFBoolProperty(makeFieldVariant(outer), name, flags)
        elif propType == "int8": 
            newFInt8Property(makeFieldVariant(outer), name, flags)
        elif propType == "int16": 
            newFInt16Property(makeFieldVariant(outer), name, flags)
        elif propType == "int32": 
            newFIntProperty(makeFieldVariant(outer), name, flags)
        elif propType in ["int64", "int"]: 
            newFInt64Property(makeFieldVariant(outer), name, flags)
        elif propType == "byte": 
            newFByteProperty(makeFieldVariant(outer), name, flags)
        elif propType == "uint16": 
            newFUInt16Property(makeFieldVariant(outer), name, flags)
        elif propType == "uint32": 
            newFUInt32Property(makeFieldVariant(outer), name, flags)
        elif propType == "uint64": 
            newFUint64Property(makeFieldVariant(outer), name, flags)
        elif propType == "float32": 
            newFFloatProperty(makeFieldVariant(outer), name, flags)
        elif propType in ["float", "float64"]: 
            newFDoubleProperty(makeFieldVariant(outer), name, flags)
        elif propType == "FName": 
            newFNameProperty(makeFieldVariant(outer), name, flags)
        elif propType.contains("TArray"):
            let arrayProp = newFArrayProperty(makeFieldVariant(outer), name, flags)
            let innerType = propType.extractTypeFromGenericInNimFormat("TArray")
            let inner = newFProperty(outer, propField, optPropType=innerType, optName="Inner")
            arrayProp.addCppProperty(inner)
            arrayProp

        elif propType.contains("TMap"):
            let mapProp = newFMapProperty(makeFieldVariant(outer), name, flags)
            let innerTypes = propType.extractKeyValueFromMapProp()
            let key = newFProperty(outer, propField, optPropType=innerTypes[0], optName="Key", propFlags=CPF_HasGetValueTypeHash) 
            let value = newFProperty(outer, propField, optPropType=innerTypes[1], optName="Value")

            mapProp.addCppProperty(key)
            mapProp.addCppProperty(value)
            mapProp
        else: #ustruct based?
            let structBased = newUStructBasedFProperty(outer, propType, name, propFlags)
            if structBased.isSome():
                structBased.get()
            else:
                #Try to find it as Delegate
                UE_Log "Not a struct based prorperty. Trying as delegate.." & propType
                let delegateName = propType.removeFirstLetter() & "__DelegateSignature"
                let delegate = getUTypeByName[UDelegateFunction] delegateName
                if not delegate.isNil():
                    let isMulticast = FUNC_MulticastDelegate in delegate.functionFlags
                    if isMulticast:
                        UE_Log fmt("Found {propType}  as  MulticastDelegate. Creating prop")
                        let delegateProp = newFMulticastInlineDelegateProperty(makeFieldVariant(outer), name, flags)
                        delegateProp.setSignatureFunction(delegate)
                        delegateProp
                    else:
                        UE_Log fmt("Found {propType}  as  MulticastDelegate. Creating prop")
                        let delegateProp = newFDelegateProperty(makeFieldVariant(outer), name, flags)
                        delegateProp.setSignatureFunction(delegate)
                        delegateProp
               
                else:
                    UE_Log "Not a struct based property. Trying as enum .." & propType
                    let ueEnum = getUTypeByName[UEnum](propType) #names arent consistent, for enums it may or not start with the Prefix E
                    if not ueEnum.isNil():
                        UE_Log "Found " & propType & " as Enum. Creating prop"
                        let enumProp = newFEnumProperty(makeFieldVariant(outer), name, flags)
                        enumProp.setEnum(ueEnum)
                        #Assuming that Enums are exposed via TEnumAsByte or they are uint8. Revisit in the future (only bp exposed enums meets that)
                        let underlayingProp : FPropertyPtr = newFByteProperty(makeFieldVariant(enumProp), n"UnderlayingEnumProp", flags)
                        enumProp.addCppProperty(underlayingProp)
                        enumProp
                    else:
                        raise newException(Exception, "FProperty not covered in the types for " & propType )
        
    prop.setPropertyFlags(prop.getPropertyFlags() or propFlags) #in case custom fprop require custom flags (see TMAP)
    prop

include ../unreal/prelude
import std/[times,strformat, strutils, options, sugar, algorithm, sequtils]
import models


func newFProperty*(outer : UStructPtr, propType:string, name:FName, propFlags=CPF_None) : FPropertyPtr = 
    let flags = RF_NoFlags #OBJECT FLAGS

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
            let inner = newFProperty(outer, innerType, n"Inner")
            arrayProp.addCppProperty(inner)
            arrayProp

        elif propType.contains("TMap"):
            let mapProp = newFMapProperty(makeFieldVariant(outer), name, flags)
            let innerTypes = propType.extractKeyValueFromMapProp()
            let key = newFProperty(outer, innerTypes[0], n"Key", CPF_HasGetValueTypeHash) 
            let value = newFProperty(outer, innerTypes[1], n"Value")

            mapProp.addCppProperty(key)
            mapProp.addCppProperty(value)
            mapProp
        else:
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
            if not ustruct.isnil():
                #we still dont know if it's a script struct
                let cls = ueCast[UClass](ustruct)
                let scriptStruct = ueCast[UScriptStruct](ustruct)
                if not scriptStruct.isNil():
                    eMeta = emScriptStruct   
                    UE_Log "Found ScriptStruct " & propType & " creating Prop"
                else:
                    UE_Log "Found Class " & propType & " creating Prop"

                case eMeta:
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
        
            else:
                raise newException(Exception, "FProperty not covered in the types for " & propType )
            
       
    prop.setPropertyFlags(prop.getPropertyFlags() or propFlags)
    prop
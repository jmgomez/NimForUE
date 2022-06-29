include unreal/prelude
import std/[times,strformat, strutils, options, sugar, sequtils]



func isTArray(prop:FPropertyPtr) : bool = not castField[FArrayProperty](prop).isNil()
func isTMap(prop:FPropertyPtr) : bool = not castField[FMapProperty](prop).isNil()
func isTEnum(prop:FPropertyPtr) : bool = "TEnumAsByte" in prop.getName()
func isDynDel(prop:FPropertyPtr) : bool = not castField[FDelegateProperty](prop).isNil()
func isMulticastDel(prop:FPropertyPtr) : bool = not castField[FMulticastDelegateProperty](prop).isNil()
#TODO Dels

func getNimTypeAsStr(prop:FPropertyPtr) : string = #The expected type is something that UEField can understand
    if prop.isTArray(): 
        let innerType = castField[FArrayProperty](prop).getInnerProp().getCPPType()
        return fmt"TArray[{innerType}]"

    if prop.isTMap(): #better pattern here, i.e. option chain
        let mapProp = castField[FMapProperty](prop)
        let keyType = mapProp.getKeyProp().getCPPType()
        let valueType = mapProp.getValueProp().getCPPType()
        return fmt"TMap[{keyType}, {valueType}]"

    let cppType = prop.getCPPType() 

    if prop.isTEnum(): #Not sure if it would be better to just support it on the macro
        return cppType.replace("TEnumAsByte<","")
                      .replace(">", "")


    let nimType = cppType.replace("<", "[")
                         .replace(">", "]")
                         .replace("*", "Ptr")
    
    return nimType


#Function that receives a FProperty and returns a Type as string
func toUEField*(prop:FPropertyPtr) : UEField = #The expected type is something that UEField can understand
    let name = prop.getName()
    let nimType = prop.getNimTypeAsStr()
     
    if prop.isTMap():
        return makeFieldAsUProp(name, nimType, true, true, prop.getPropertyFlags())

    if prop.isDynDel() or prop.isMulticastDel():
        let delType = if prop.isDynDel(): uedelDynScriptDelegate else: uedelMulticastDynScriptDelegate
        let signature = if prop.isDynDel(): 
                            castField[FDelegateProperty](prop).getSignatureFunction() 
                        else: 
                            castField[FMulticastDelegateProperty](prop).getSignatureFunction()
        
        var signatureAsStrs = getFPropsFromUStruct(signature)
                                .map(prop=>getNimTypeAsStr(prop))
        return makeFieldAsDel(name, uedelDynScriptDelegate, signatureAsStrs)


    let isGeneric = nimType.contains("[")
    return makeFieldAsUProp(prop.getName(), nimType, isGeneric, false, prop.getPropertyFlags())


    
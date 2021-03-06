
include ../definitions
import ../Core/Containers/[unrealstring, array, map]
import ../Core/ftext
import nametypes
import std/[genasts, macros, sequtils]

import uobjectflags
export uobjectflags



type 
    
    FField* {. importcpp, inheritable, pure .} = object 
        next*  {.importcpp:"Next".} : ptr FField
    FFieldPtr* = ptr FField 
    FProperty* {. importcpp, inheritable,  header:ueIncludes, pure.} = object of FField 
    FPropertyPtr* = ptr FProperty
    UObject* {.importcpp, inheritable, pure .} = object #TODO Create a macro that takes the header path as parameter?
    UObjectPtr* = ptr UObject #This can be autogenerated by a macro

    UField* {.importcpp, inheritable, pure .} = object of UObject
        Next* : ptr UField #Next Field in the linked list 
    UFieldPtr* = ptr UField 

    UEnum* {.importcpp, inheritable, pure .} = object of UField
    UEnumPtr* = ptr UEnum
   

    UStruct* {.importcpp, inheritable, pure .} = object of UField
        Children* : UFieldPtr # Pointer to start of linked list of child fields */
        childProperties* {.importcpp:"ChildProperties".}: FFieldPtr #  /** Pointer to start of linked list of child fields */
        propertyLink* {.importcpp:"PropertyLink".}: FPropertyPtr #  /** 	/** In memory only: Linked list of properties from most-derived to base */

    UStructPtr* = ptr UStruct 



    UClass* {.importcpp, inheritable, pure .} = object of UStruct
        classWithin* {.importcpp:"ClassWithin".}: UClassPtr #  The required type for the outer of instances of this class */
        classConfigName* {.importcpp:"ClassConfigName".}: FName 
        classFlags* {.importcpp:"ClassFlags".}: EClassFlags
        classCastFlags* {.importcpp:"ClassCastFlags".}: EClassCastFlags
        classConstructor* {.importcpp:"ClassConstructor".}: pointer


    UClassPtr* = ptr UClass

    UScriptStruct* {.importcpp, inheritable, pure .} = object of UStruct
    UScriptStructPtr* = ptr UScriptStruct


    UFunction* {.importcpp, inheritable, pure .} = object of UStruct
        functionFlags* {.importcpp:"FunctionFlags".} : EFunctionFlags
        numParms* {.importcpp:"NumParms".}: uint8
        parmsSize* {.importcpp:"ParmsSize".}: uint16
    UFunctionPtr* = ptr UFunction
    UDelegateFunction* {.importcpp, inheritable, pure .} = object of UFunction
    UDelegateFunctionPtr* = ptr UDelegateFunction





proc castField*[T : FField ](src:FFieldPtr) : ptr T {. importcpp:"CastField<'*0>(#)" .}
proc ueCast*[T : UObject ](src:UObjectPtr) : ptr T {. importcpp:"Cast<'*0>(#)" .}

proc getName*(prop:FFieldPtr) : FString {. importcpp:"#->GetName()" .}

proc getOffsetForUFunction*(prop:FPropertyPtr) : int32 {. importcpp:"#->GetOffset_ForUFunction()".}
proc initializeValueInContainer*(prop:FPropertyPtr, container:pointer) : void {. importcpp:"#->InitializeValue_InContainer(#)".}

proc getSize*(prop:FPropertyPtr) : int32 {. importcpp:"#->GetSize()".}
proc setPropertyFlags*(prop:FPropertyPtr, flags:EPropertyFlags) : void {. importcpp:"#->SetPropertyFlags(#)".}
proc getPropertyFlags*(prop:FPropertyPtr) : EPropertyFlags {. importcpp:"#->GetPropertyFlags()".}
proc getNameCPP*(prop:FPropertyPtr) : FString {.importcpp: "#->GetNameCPP()".}
proc getCPPType*(prop:FPropertyPtr) : FString {.importcpp: "#->GetCPPType()".}
proc getTypeName*(prop:FPropertyPtr) : FString {.importcpp: "#->GetTypeName()".}
proc getOwnerStruct*(str:FPropertyPtr) : UStructPtr {.importcpp:"#->GetOwnerStruct()".}


type FFieldVariant* {.importcpp.} = object
proc makeFieldVariant*(field:FFieldPtr) : FFieldVariant {. importcpp: "'0(#)", constructor.}
proc makeFieldVariant*(obj:UObjectPtr) : FFieldVariant {. importcpp: "'0(#)", constructor.}


macro bindFProperty(propNames : static openarray[string] ) : untyped = 
    proc bindProp(name:string) : NimNode = 
        let constructorName = ident "new"&name
        let ptrName = ident name&"Ptr"

        genAst(name=ident name, ptrName, constructorName):
            type 
                name* {.inject, importcpp.} = object of FProperty
                ptrName* {.inject.} = ptr name

            proc constructorName*(fieldVariant:FFieldVariant, propName:FName, objFlags:EObjectFlags) : ptrName {. importcpp: "new '*0(@)", inject.}
            proc constructorName*(fieldVariant:FFieldVariant, propName:FName, objFlags:EObjectFlags, offset:int32, propFlags:EPropertyFlags) : ptrName {. importcpp: "new '*0(@)", inject.}

    
    nnkStmtList.newTree(propNames.map(bindProp))

bindFProperty([ 
        "FBoolProperty",
        "FInt8Property", "FInt16Property","FIntProperty", "FInt64Property",
        "FByteProperty", "FUInt16Property","FUInt32Property", "FUInt64Property",
        "FStrProperty", "FFloatProperty", "FDoubleProperty", "FNameProperty",
        "FArrayProperty", "FStructProperty", "FObjectProperty", "FClassProperty",
        "FSoftObjectProperty", "FSoftClassProperty", "FEnumProperty", 
        "FMapProperty", "FDelegateProperty", 
        "FMulticastDelegateProperty", #It seems to be abstract. Review Sparse vs Inline
        "FMulticastInlineDelegateProperty",
        
        ])

#TypeClass
type DelegateProp* = FDelegatePropertyPtr | FMulticastInlineDelegatePropertyPtr | FMulticastDelegatePropertyPtr

#Concrete methods
proc setScriptStruct*(prop:FStructPropertyPtr, scriptStruct:UScriptStructPtr) : void {. importcpp: "(#->Struct=#)".}
proc setPropertyClass*(prop:FObjectPropertyPtr | FSoftObjectPropertyPtr, propClass:UClassPtr) : void {. importcpp: "(#->PropertyClass=#)".}
proc setPropertyMetaClass*(prop:FClassPropertyPtr | FSoftClassPropertyPtr, propClass:UClassPtr) : void {. importcpp: "(#->MetaClass=#)".}
proc setEnum*(prop:FEnumPropertyPtr, uenum:UEnumPtr) : void {. importcpp: "(#->SetEnum(#))".}

proc getInnerProp*(arrProp:FArrayPropertyPtr) : FPropertyPtr {.importcpp:"(#->Inner)".}
proc addCppProperty*(arrProp:FArrayPropertyPtr | FMapPropertyPtr | FEnumPropertyPtr, cppProp:FPropertyPtr) : void {. importcpp:"(#->AddCppProperty(#))".}

proc getKeyProp*(arrProp:FMapPropertyPtr) : FPropertyPtr {.importcpp:"(#->KeyProp)".}
proc getValueProp*(arrProp:FMapPropertyPtr) : FPropertyPtr {.importcpp:"(#->ValueProp)".}
proc getSignatureFunction*(delProp:DelegateProp) : UFunctionPtr {.importcpp:"(#->SignatureFunction)".}
proc setSignatureFunction*(delProp:DelegateProp, signature : UFunctionPtr) : void {.importcpp:"(#->SignatureFunction=#)".}




type


    FOutParmRec* {.importcpp.} = object
        property* {.importcpp:"Property".} : FPropertyPtr
        propAddr* {.importcpp:"PropAddr".}: pointer 
        nextOutParm* {.importcpp:"NextOutParm".}: ptr FOutParmRec
        mostRecentProperty* {.importcpp:"MostRecentProperty".}: FPropertyPtr
        
       
    FFrame* {.importcpp .} = object
        code* {.importcpp:"Code".} : ptr uint8
        node* {.importcpp:"Node".} : UFunctionPtr
        locals* {.importcpp:"Locals".} : ptr uint8
        outParms* {.importcpp:"OutParms".} : ptr FOutParmRec
        propertyChainForCompiledIn* {.importcpp:"PropertyChainForCompiledIn".}: FFieldPtr






#UFIELD
proc setMetadata*(field:UFieldPtr|FFieldPtr, key, inValue:FString) : void {.importcpp:"#->SetMetaData(*#, *#)".}
proc bindType*(field:UFieldPtr) : void {. importcpp:"#->Bind()" .} #notice bind is a reserverd keyword in nim

#USTRUCT
proc staticLink*(str:UStructPtr, bRelinkExistingProperties:bool) : void {.importcpp:"#->StaticLink(@)".}

#This belongs to this file due to nim not being able to forward declate types. We may end up merging this file into uobject
proc addCppProperty*(str:UStructPtr, prop:FPropertyPtr) : void {.importcpp:"#->AddCppProperty(@)".}
#     virtual const TCHAR* GetPrefixCPP() const { return TEXT("F"); }
proc getPrefixCpp*(str:UStructPtr) : FString {.importcpp:"FString(#->GetPrefixCPP())".}
proc setSuperStruct*(str, suprStruct :UStructPtr) : void {.importcpp:"#->SetSuperStruct(#)".}

#UCLASS
proc findFunctionByName*(cls : UClassPtr, name:FName) : UFunctionPtr {. importcpp: "#.FindFunctionByName(#)"}
proc addFunctionToFunctionMap*(cls : UClassPtr, fn : UFunctionPtr, name:FName) : void {. importcpp: "#.AddFunctionToFunctionMap(@)"}
proc removeFunctionFromFunctionMap*(cls : UClassPtr, fn : UFunctionPtr) : void {. importcpp: "#.RemoveFunctionFromFunctionMap(@)"}
proc getDefaultObject*(cls:UClassPtr) : UObjectPtr {. importcpp:"#->GetDefaultObject()" .}
proc getSuperClass*(cls:UClassPtr) : UClassPtr {. importcpp:"#->GetSuperClass()" .}
proc assembleReferenceTokenStream*(cls:UClassPtr, bForce = false) : void {. importcpp:"#->AssembleReferenceTokenStream(@)" .}

#UOBJECT
proc getFName*(obj:UObjectPtr) : FName {. importcpp: "#->GetFName()" .}
proc getFlags*(obj:UObjectPtr) : EObjectFlags {. importcpp: "#->GetFlags()" .}
proc setFlags*(obj:UObjectPtr, inFlags : EObjectFlags) : void {. importcpp: "#->SetFlags(#)" .}
proc clearFlags*(obj:UObjectPtr, inFlags : EObjectFlags) : void {. importcpp: "#->ClearFlags(#)" .}

proc getClass*(obj : UObjectPtr) : UClassPtr {. importcpp: "#->GetClass()" .}
proc getOuter*(obj : UObjectPtr) : UObjectPtr {. importcpp: "#->GetOuter()" .}
proc getName*(obj : UObjectPtr) : FString {. importcpp:"#->GetName()" .}
proc conditionalBeginDestroy*(obj:UObjectPtr) : void {. importcpp:"#->ConditionalBeginDestroy()".}
proc processEvent*(obj : UObjectPtr, fn:UFunctionPtr, params:pointer) : void {. importcpp:"#->ProcessEvent(@)" .}

#bool UClass::Rename( const TCHAR* InName, UObject* NewOuter, ERenameFlags Flags )
#notice rename flags is not an enum in cpp we define it here adhoc
type ERenameFlag* = distinct uint32
const REN_None* = ERenameFlag(0x0000)
const REN_DontCreateRedirectors* = ERenameFlag(0x0010)
proc rename*(obj:UObjectPtr, InName:FString, newOuter:UObjectPtr, flags:ERenameFlag) : bool {. importcpp:"#->Rename(*#, #, #)" .}

#FUNC
proc initializeDerivedMembers*(fn:UFunctionPtr) : void {.importcpp:"#->InitializeDerivedMembers()".}
proc getReturnProperty*(fn:UFunctionPtr) : FPropertyPtr {.importcpp:"#->GetReturnProperty()".}



#UENUM
#virtual bool SetEnums(TArray<TPair<FName, int64>>& InNames, ECppForm InCppForm, EEnumFlags InFlags = EEnumFlags::None, bool bAddMaxKeyIfMissing = true) override;

proc setEnums*(uenum:UENumPtr, inName:TArray[TPair[FName, int64]]) : bool {. importcpp:"#->SetEnums(#, UEnum::ECppForm::Regular)" .}



#ITERATOR
type TFieldIterator* [T:UStruct] {.importcpp.} = object
proc makeTFieldIterator*[T](inStruct : UStructPtr, flag:EFieldIterationFlags) : TFieldIterator[T] {. importcpp:"'0(@)" constructor .}

proc next*[T](it:var TFieldIterator[T]) : void {. importcpp:"(++#)" .} 
proc isValid[T](it: TFieldIterator[T]): bool {.importcpp: "((bool)(#))", noSideEffect.}
proc get*[T](it:TFieldIterator[T]) : ptr T {. importcpp:"*#" .} 

iterator items*[T](it:var TFieldIterator[T]) : var TFieldIterator[T] =
    while it.isValid():
        yield it
        it.next()
       

#StepExplicitProperty
proc stepExplicitProperty*(frame:var FFrame, result:pointer, prop:FPropertyPtr) {.importcpp:"#.StepExplicitProperty(@)".}
proc step*(frame:var FFrame, contex:UObjectPtr, result:pointer) {.importcpp:"#.Step(@)".}



iterator items*(ustr: UStructPtr): FFieldPtr =
    var currentProp = ustr.childProperties
    while not currentProp.isNil():
        yield currentProp
        currentProp = currentProp.next
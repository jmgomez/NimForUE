
import std/[json, jsonutils, typetraits, strutils, tables, options]
import runtimefield
import ../unreal/bindings/vm/vmtypes
import corevm
export corevm

proc log*(s:string) : void = discard #overrided



proc uCallInterop(uCall:UECall) : UECallResult = UECallResult() #overrided no need anymore, remove interop

proc uCall*(uCall:UECall) : UECallResult = uCallInterop(uCall) 
  # log "uCall: " & $uCall & " result: " & $result


# proc getClassByNameInterop(className:string) : UClassPtr = nil#UClassPtr(0) #overrided
# proc getClassByName*(className:string) : UClassPtr = getClassByNameInterop(className)

# proc newUObjectInterop(owner : UObjectPtr, cls:UClassPtr) : UObjectPtr = UObjectPtr(0) #overrided


proc deref*[T](val: ptr T) : T = nil #only ints for now

# proc newUObject*[T](owner : UObjectPtr = UObjectPtr(0)) : T = 
#   let cls = getClassByName(T.name.removeFirstLetter.removeLastLettersIfPtr())
#   let obj = newUObjectInterop(owner, cls)
#   cast[T](obj)



#BORROW
# type UEBorrowInfo* = object
#   fnName*: string
#   className* : string
#   ueActualName* : string

#eventually this will be json
proc setupBorrowInterop*(borrowInfo:string) = discard #override
proc setupBorrow*(borrowInfo:UEBorrowInfo) = setupBorrowInterop($borrowInfo.toJson())


#TODO this functions may be automatically generated down the road
proc makeFName*(str:string) : FName = default(FName)



#TODO move this to uebind core
# const CLASS_Inherit* = (CLASS_Transient | CLASS_Optional | CLASS_DefaultConfig | CLASS_Config | CLASS_PerObjectConfig | CLASS_ConfigDoNotCheckDefaults | CLASS_NotPlaceable | CLASS_Const | CLASS_HasInstancedReference | CLASS_Deprecated | CLASS_DefaultToInstanced | CLASS_GlobalUserConfig | CLASS_ProjectUserConfig | CLASS_NeedsDeferredDependencyLoading)
# const CLASS_ScriptInherit* = CLASS_Inherit | CLASS_EditInlineNew | CLASS_CollapseCategories 
# # #* Struct flags that are automatically inherited */
# const STRUCT_Inherit        = STRUCT_HasInstancedReference | STRUCT_Atomic
# # #* Flags that are always computed, never loaded or done with code generation */
# const STRUCT_ComputedFlags    = STRUCT_NetDeltaSerializeNative | STRUCT_NetSerializeNative | STRUCT_SerializeNative | STRUCT_PostSerializeNative | STRUCT_CopyNative | STRUCT_IsPlainOldData | STRUCT_NoDestructor | STRUCT_ZeroConstructor | STRUCT_IdenticalNative | STRUCT_AddStructReferencedObjects | STRUCT_ExportTextItemNative | STRUCT_ImportTextItemNative | STRUCT_SerializeFromMismatchedTag | STRUCT_PostScriptConstruct | STRUCT_NetSharedSerialization
# const FUNC_FuncInherit*       = (FUNC_Exec | FUNC_Event | FUNC_BlueprintCallable | FUNC_BlueprintEvent | FUNC_BlueprintAuthorityOnly | FUNC_BlueprintCosmetic | FUNC_Const)
# const FUNC_FuncOverrideMatch* = (FUNC_Exec | FUNC_Final | FUNC_Static | FUNC_Public | FUNC_Protected | FUNC_Private)
# const FUNC_NetFuncFlags*      = (FUNC_Net | FUNC_NetReliable | FUNC_NetServer | FUNC_NetClient | FUNC_NetMulticast)
# const FUNC_AccessSpecifiers*  = (FUNC_Public | FUNC_Private | FUNC_Protected)

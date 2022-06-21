
import ../Core/Containers/unrealstring
import nametypes
import bitops

include ../definitions

type 
    EObjectFlag* {.importcpp: "EObjectFlags", size:sizeof(int32).} = enum
        # if you change any the bit of any of the RF_Load flags, then you will need legacy serialization
        RF_NoFlags = 0x00000000, #< No flags, used to avoid a cast=
        # This first group of flags mostly has to do with what kind of object it is. Other than transient, these are the persistent object flags.
        # The garbage collector also tends to look at these.
        RF_Public =0x00000001, #< Object is visible outside its package.
        RF_Standalone        =0x00000002,  #< Keep object around for editing even if unreferenced.
        RF_MarkAsNative        =0x00000004,  #< Object (UField) will be marked as native on construction (DO NOT USE THIS FLAG in HasAnyFlags() etc)
        RF_Transactional      =0x00000008,  #< Object is transactional.
        RF_ClassDefaultObject    =0x00000010,  #< This object is its class's default object
        RF_ArchetypeObject      =0x00000020,  #< This object is a template for another object - treat like a class default object
        RF_Transient        =0x00000040,  #< Don't save object.

        # This group of flags is primarily concerned with garbage collection.
        RF_MarkAsRootSet      =0x00000080,  #< Object will be marked as root set on construction and not be garbage collected, even if unreferenced (DO NOT USE THIS FLAG in HasAnyFlags() etc)
        RF_TagGarbageTemp      =0x00000100,  #< This is a temp user flag for various utilities that need to use the garbage collector. The garbage collector itself does not interpret it.

        # The group of flags tracks the stages of the lifetime of a uobject
        RF_NeedInitialization    =0x00000200,  #< This object has not completed its initialization process. Cleared when ~FObjectInitializer completes
        RF_NeedLoad =0x00000400,  #< During load, indicates object needs loading.
        RF_KeepForCooker      =0x00000800,  #< Keep this object during garbage collection because it's still being used by the cooker
        RF_NeedPostLoad        =0x00001000,  #< Object needs to be postloaded.
        RF_NeedPostLoadSubobjects  =0x00002000,  #< During load, indicates that the object still needs to instance subobjects and fixup serialized component references
        RF_NewerVersionExists    =0x00004000,  #< Object has been consigned to oblivion due to its owner package being reloaded, and a newer version currently exists
        RF_BeginDestroyed      =0x00008000,  #< BeginDestroy has been called on the object.
        RF_FinishDestroyed      =0x00010000,  #< FinishDestroy has been called on the object.

        # Misc. Flags
        RF_BeingRegenerated      =0x00020000,  #< Flagged on UObjects that are used to create UClasses (e.g. Blueprints) while they are regenerating their UClass on load (See FLinkerLoad::CreateExport()), as well as UClass objects in the midst of being created
        RF_DefaultSubObject      =0x00040000,  #< Flagged on subobjects that are defaults
        RF_WasLoaded =0x00080000,  #< Flagged on UObjects that were loaded
        RF_TextExportTransient    =0x00100000,  #< Do not export object to text form (e.g. copy/paste). Generally used for sub-objects that can be regenerated from data in their parent object.
        RF_LoadCompleted      =0x00200000,  #< Object has been completely serialized by linkerload at least once. DO NOT USE THIS FLAG, It should be replaced with RF_WasLoaded.
        RF_InheritableComponentTemplate = 0x00400000, #< Archetype of the object can be in its super class
        RF_DuplicateTransient    =0x00800000,  #< Object should not be included in any type of duplication (copy/paste, binary duplication, etc.)
        RF_StrongRefOnFrame      =0x01000000,  #< References to this object from persistent function frame are handled as strong ones.
        RF_NonPIEDuplicateTransient  =0x02000000,  #< Object should not be included for duplication unless it's being duplicated for a PIE session
        RF_Dynamic = 0x04000000, #UE_DEPRECATED(5.0, "RF_Dynamic should no longer be used. It is no longer being set by engine code.") #< Field Only. Dynamic field - doesn't get constructed during static initialization, can be constructed multiple times  # @todo: BP2CPP_remove
        RF_WillBeLoaded        =0x08000000,  #< This object was constructed during load and will be loaded shortly
        RF_HasExternalPackage    =0x10000000,  #< This object has an external package assigned and should look it up when getting the outermost package


        # RF_Garbage and RF_PendingKill are mirrored in EInternalObjectFlags because checking the internal flags is much faster for the Garbage Collector
        # while checking the object flags is much faster outside of it where the Object pointer is already available and most likely cached.
        # RF_PendingKill is mirrored in EInternalObjectFlags because checking the internal flags is much faster for the Garbage Collector
        # while checking the object flags is much faster outside of it where the Object pointer is already available and most likely cached.

        RF_PendingKill = 0x20000000, #UE_DEPRECATED(5.0, "RF_PendingKill should not be used directly. Make sure references to objects are released using one of the existing engine callbacks or use weak object pointers.") = 0x20000000,  #< Objects that are pending destruction (invalid for gameplay but valid objects). This flag is mirrored in EInternalObjectFlags as PendingKill for performance
        RF_Garbage  = 0x40000000, #UE_DEPRECATED(5.0, "RF_Garbage should not be used directly. Use MarkAsGarbage and ClearGarbage instead.") =0x40000000,  #< Garbage from logical point of view and should not be referenced. This flag is mirrored in EInternalObjectFlags as Garbage for performance
        RF_AllocatedInSharedPage  =0x80000000,  #< Allocated from a ref-counted page shared with other UObjects

    

    UObject* {.importcpp, inheritable, pure .} = object #TODO Create a macro that takes the header path as parameter?
    UObjectPtr* = ptr UObject #This can be autogenerated by a macro

    UField* {.importcpp, inheritable, pure .} = object of UObject
        Next* : ptr UField
    UFieldPtr* = ptr UField 

    UStruct* {.importcpp, inheritable, pure .} = object of UField
        Children* : UFieldPtr

    UStructPtr* = ptr UStruct 

    UClass* {.importcpp, inheritable, pure .} = object of UStruct
    UClassPtr* = ptr UClass

    UScriptStruct* {.importcpp, inheritable, pure .} = object of UStruct
    UScriptStructPtr* = ptr UScriptStruct

    EFunctionFlag* {.importcpp:"EFunctionFlags", size:sizeof(uint32).} = enum 
        # Function flags.
        FUNC_None = 0x00000000,
        FUNC_Fina = 0x00000001,  # Function is final (prebindable, non-overridable function).
        FUNC_RequiredAPI      = 0x00000002,  # Indicates this function is DLL exported/imported.
        FUNC_BlueprintAuthorityOnly= 0x00000004,   # Function will only run if the object has network authority
        FUNC_BlueprintCosmetic  = 0x00000008,   # Function is cosmetic in nature and should not be invoked on dedicated servers
        # FUNC_        = 0x00000010,   # unused.
        # FUNC_        = 0x00000020,   # unused.
        FUNC_Net        = 0x00000040,   # Function is network-replicated.
        FUNC_NetReliable    = 0x00000080,   # Function should be sent reliably on the network.
        FUNC_NetRequest      = 0x00000100,  # Function is sent to a net service
        FUNC_Exec        = 0x00000200,  # Executable from command line.
        FUNC_Native        = 0x00000400,  # Native function.
        FUNC_Event        = 0x00000800,   # Event function.
        FUNC_NetResponse    = 0x00001000,   # Function response from a net service
        FUNC_Static        = 0x00002000,   # Static function.
        FUNC_NetMulticast    = 0x00004000,  # Function is networked multicast Server -> All Clients
        FUNC_UbergraphFunction  = 0x00008000,   # Function is used as the merge 'ubergraph' for a blueprint, only assigned when using the persistent 'ubergraph' frame
        FUNC_MulticastDelegate  = 0x00010000,  # Function is a multi-cast delegate signature (also requires FUNC_Delegate to be set!)
        FUNC_Public        = 0x00020000,  # Function is accessible in all classes (if overridden, parameters must remain unchanged).
        FUNC_Private      = 0x00040000,  # Function is accessible only in the class it is defined in (cannot be overridden, but function name may be reused in subclasses.  IOW: if overridden, parameters don't need to match, and Super.Func() cannot be accessed since it's private.)
        FUNC_Protected      = 0x00080000,  # Function is accessible only in the class it is defined in and subclasses (if overridden, parameters much remain unchanged).
        FUNC_Delegate      = 0x00100000,  # Function is delegate signature (either single-cast or multi-cast, depending on whether FUNC_MulticastDelegate is set.)
        FUNC_NetServer      = 0x00200000,  # Function is executed on servers (set by replication code if passes check)
        FUNC_HasOutParms    = 0x00400000,  # function has out (pass by reference) parameters
        FUNC_HasDefaults    = 0x00800000,  # function has structs that contain defaults
        FUNC_NetClient      = 0x01000000,  # function is executed on clients
        FUNC_DLLImport      = 0x02000000,  # function is imported from a DLL
        FUNC_BlueprintCallable  = 0x04000000,  # function can be called from blueprint code
        FUNC_BlueprintEvent    = 0x08000000,  # function can be overridden/implemented from a blueprint
        FUNC_BlueprintPure    = 0x10000000,  # function can be called from blueprint code, and is also pure (produces no side effects). If you set this, you should set FUNC_BlueprintCallable as well.
        FUNC_EditorOnly      = 0x20000000,  # function can only be called from an editor scrippt.
        FUNC_Const        = 0x40000000,  # function can be called from blueprint code, and only reads state (never writes state)
        FUNC_NetValidate    = 0x80000000,  # function must supply a _Validate implementation
        FUNC_AllFlags    = 0xFFFFFFFF
    
   



    UFunction* {.importcpp, inheritable, pure .} = object of UStruct
        functionFlags* {.importcpp:"FunctionFlags".} : EFunctionFlag
        
    UFunctionPtr* = ptr UFunction

    FFrame* {.importcpp .} = object
        Code : ptr uint8
    
 #TODO MAKE THIS A MACRO
proc `or`(a, b : EFunctionFlag) : EFunctionFlag = 
    proc toNum(f: EFunctionFlag): uint32 = cast[uint32](f)
    proc toFunctionFlags(v: uint32): EFunctionFlag = cast[EFunctionFlag](v)
    return toFunctionFlags(bitor(toNum(a),toNum(b)))
proc staticLink*(str:UStructPtr, bRelinkExistingProperties:bool) : void {.importcpp:"#->StaticLink(#)".}
    
    # FUNC_Public | FUNC_BlueprintCallable | FUNC_BlueprintEvent

proc getClass*(obj : UObjectPtr) : UClassPtr {. importcpp: "#->GetClass()" .}
proc getName*(obj : UObjectPtr) : FString {. importcpp:"#->GetName()" .}
proc processEvent*(obj : UObjectPtr, fn:UFunctionPtr, params:pointer) : void {. importcpp:"#->ProcessEvent(@)" .}

proc findFunctionByName*(cls : UClassPtr, name:FName) : UFunctionPtr {. importcpp: "#.FindFunctionByName(#)"}
proc addFunctionToFunctionMap*(cls : UClassPtr, fn : UFunctionPtr, name:FName) : void {. importcpp: "#.AddFunctionToFunctionMap(@)"}
proc removeFunctionFromFunctionMap*(cls : UClassPtr, fn : UFunctionPtr) : void {. importcpp: "#.RemoveFunctionFromFunctionMap(@)"}


proc getFName*(obj:UObjectPtr) : FName {. importcpp: "#->GetFName()" .}

# proc staticClass*(_: typedesc[UObject]) : UClassPtr {. importcpp: "#::StaticClass()" .}

#CamelCase
#camelCase





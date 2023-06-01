
# include ../unreal/prelude
import ../unreal/coreuobject/[uobject, package]
import models
import std/[sugar, tables, options, sequtils]
import ../unreal/nimforue/[nimforuebindings]
import ../utils/[utils, ueutils]




type 
  CtorInfo* = object #stores the constuctor information for a class.
    fn*: UClassConstructor
    hash*: string
    className*: string
    vTableConstructor*: VTableConstructor
    updateVTableForType*: proc(prevCls:UClassPtr)


type 
    EmitterInfo* = object 
        uStructPointer* : UFieldPtr
        ueType* : UEType
        generator* : UPackagePtr->UFieldPtr
        
    FnEmitter* = object #Holds the FunctionPointerImplementation of a UEField of kind Function
        fnPtr* : UFunctionNativeSignature
        ueField* : UEField

    UEEmitter* = object 
        emitters* : OrderedTable[string, EmitterInfo] #typename
        # types* : seq[UEType]
        # fnTable* : Table[UEField, Option[UFunctionNativeSignature]] 
        fnTable* : seq[FnEmitter]

        clsConstructorTable* : Table[string, CtorInfo]
       
        setStructOpsWrapperTable* : Table[string, UNimScriptStructPtr->void]

    UEEmitterPtr* = ptr UEEmitter

proc getNativeFuncImplPtrFromUEField*(emitter: UEEmitterPtr, ueField: UEField): Option[UFunctionNativeSignature] =
    for ef in emitter.fnTable:
        if ef.ueField == ueField:
            return some(ef.fnPtr)
    return none(UFunctionNativeSignature)


proc `$`*(emitter : UEEmitterPtr) : string = 
    if emitter.isNil:
        return " emitter is nil"
    result = $emitter.emitters.values.toSeq()

proc initEmitter() : UEEmitterPtr = 
    var ueEmitter : UEEmitterPtr = cast[UEEmitterPtr](alloc(sizeof(UEEmitter)))
    var init = UEEmitter()
    copyMem(ueEmitter, addr init, sizeof(UEEmitter))
    return ueEmitter

#emitters are stored in guest, but they wont be. Each module will control its own emitter.
#guest though will be in charce of reinstance the types (since it can only happens in editor)
# var emitters : Table[string, UEEmitterPtr] = initTable[string, UEEmitterPtr]()

# when defined(guest):
#     proc getGameEmitter*() : UEEmitterPtr {.exportc, cdecl, dynlib.} =
#         if "game" notin emitters:
#             emitters["game"] = initEmitter()
#             UE_Error "Init game emitter in guest"
#         UE_Log $emitters["game"]
#         emitters["game"]
# else:
#     import ../../buildscripts/buildscripts
#     import std/[dynlib, os, sequtils, sugar]

#     proc getGameEmitter*() : UEEmitterPtr = 
#         UE_Warn "asking game emitter in game before dll call"
#         UE_Log getStackTrace()
#         type 
#           GetGameEmitter = proc () : UEEmitterPtr {.gcsafe, cdecl.}
#         let libDir = PluginDir / "Binaries"/"nim"/"ue"
#         let guestPath = getLastLibPath(libDir, "nimforue")      
#         let lib = loadLib(guestPath.get())
#         let getEmitter = cast[GetGameEmitter](lib.symAddr("getGameEmitter"))
#         if getEmitter.isNil:
#           UE_Error "Could not find getGameEmitter in guest lib"
#           assert getEmitter.isNotNil()
#         getEmitter() 

# proc getGlobalEmitter*() : UEEmitterPtr = 
#     when defined(guest):
#         if "guest" notin emitters:            
#             emitters["guest"] = initEmitter()
#         emitters["guest"]
#     else:
#         getGameEmitter()
var emitter : UEEmitterPtr 
proc getGlobalEmitter*() : UEEmitterPtr = 
    if emitter.isNil:
        emitter = initEmitter()
    emitter

when not defined(guest): #called from ue
    proc getGlobalEmitterPtr*() : UEEmitterPtr {.exportc, cdecl, dynlib.} = 
        getGlobalEmitter()


proc addEmitterInfo*(ueField:UEField, fnImpl:Option[UFunctionNativeSignature]) : void =              
    # var emitter =  ueEmitter.emitters[ueField.typeName]
    getGlobalEmitter().emitters[ueField.typeName].ueType.fields.add ueField
    UE_Log "Adding emitter info for " & $ueField
    UE_Warn $getGlobalEmitter().emitters[ueField.typeName]

    if fnImpl.isSome:
      getGlobalEmitter().fnTable.add FnEmitter(fnPtr: fnImpl.get(), ueField: ueField)
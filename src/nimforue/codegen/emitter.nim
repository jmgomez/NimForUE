
# include ../unreal/prelude
import ../unreal/coreuobject/[uobject, package]
import models
import std/[sugar, tables, options, sequtils]
import ../unreal/nimforue/[nimforuebindings]
import ../utils/[utils, ueutils]
 


type UFunctionNativeSignature* = proc (context:UObjectPtr, stack:var FFrame,  result: pointer) : void {. cdecl .}


type 
  CtorInfo* = object #stores the constuctor information for a class.
    fn*: UClassConstructor
    hash*: string
    className*: string
    # vTableConstructor*: VTableConstructor
    # updateVTableForType*: proc(prevCls:UClassPtr)


type 
    EmitterInfo* = object 
        uStructPointer* : UFieldPtr
        ueType* : UEType
        generator* : UPackagePtr->UFieldPtr
        
    FnEmitter* = object #Holds the FunctionPointerImplementation of a UEField of kind Function
        fnPtr* : UFunctionNativeSignature
        ueField* : UEField

    UEEmitterRaw* = object 
        emitters* : seq[EmitterInfo]
        # types* : seq[UEType]
        # fnTable* : Table[UEField, Option[UFunctionNativeSignature]] 
        fnTable* : seq[FnEmitter]

        clsConstructorTable* : Table[string, CtorInfo]
       
        setStructOpsWrapperTable* : Table[string, UNimScriptStructPtr->void]
    UEEmitter* = ref UEEmitterRaw
    UEEmitterPtr* = ptr UEEmitterRaw


proc getNativeFuncImplPtrFromUEField*(emitter: UEEmitter, ueField: UEField): Option[UFunctionNativeSignature] =
    for ef in emitter.fnTable:
        if ef.ueField == ueField:
            return some(ef.fnPtr)
    return none(UFunctionNativeSignature)

proc `$`*(emitter : UEEmitter | UEEmitterPtr) : string = 
    result = $emitter.emitters

var ueEmitter* {.compileTime.} = UEEmitterRaw() 

proc getGlobalEmitter*() : UEEmitter = 
    result = cast[UEEmitter](addr ueEmitter)

proc addEmitterInfo*(ueField:UEField, fnImpl:Option[UFunctionNativeSignature]) : void =  
    var emitter =  ueEmitter.emitters.first(e=>e.ueType.name == ueField.className).get()
    emitter.ueType.fields.add ueField
    if fnImpl.isSome:
      ueEmitter.fnTable.add FnEmitter(fnPtr: fnImpl.get(), ueField: ueField)

    ueEmitter.emitters = ueEmitter.emitters.replaceFirst((e:EmitterInfo)=>e.ueType.name == ueField.className, emitter)


proc getEmmitedTypes*(emitter: UEEmitterRaw) : seq[UEType] = 
    emitter.emitters.map(e=>e.ueType)

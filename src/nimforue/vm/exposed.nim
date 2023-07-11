
import std/[json, jsonutils, typetraits, strutils, tables, options]
import runtimefield
import ../unreal/bindings/vm/vmtypes
import corevm
export corevm

proc log*(s:string) : void = discard #overrided



proc uCallInterop(uCall:UECall) : UECallResult = UECallResult() #overrided no need anymore, remove interop

proc uCall*(uCall:UECall) : UECallResult = uCallInterop(uCall) 
  # log "uCall: " & $uCall & " result: " & $result
func ueCast*[T: UObject](src:UObjectPtr): ptr T = 
  #TODO check the type exists.
  cast[ptr T](src)

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


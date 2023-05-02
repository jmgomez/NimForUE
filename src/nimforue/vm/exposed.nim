
import std/[json, jsonutils, typetraits, strutils, tables, options]
import runtimefield
import ../unreal/bindings/vm/enginetypes


proc log*(s:string) : void = discard #overrided
#TODO move shared types to shared.nim
type
  # AActorPtr* = distinct(int)
  # FVector* = object
  #   x*,y*,z*:float
  # FLinearColor* = object
  #   r*,g*,b*,a*:float
  AMyActorPtr* =  distinct(int)
  # UClassPtr* = distinct(int)
  # UObjectPtr* = distinct(int)


# converter myActorToActor*(actor:AMyActorPtr) : AActorPtr = AActorPtr(int(actor))
# converter toInt(obj:UObjectPtr) : int = UObjectPtr(obj)
# converter toUObject*(actor:AActorPtr) : UObjectPtr = UObjectPtr(int(actor))
# converter toUObject*(actor:AMyActorPtr) : UObjectPtr = UObjectPtr(int(actor))
# converter toUObject*(actor:UClassPtr) : UObjectPtr = UObjectPtr(int(actor))

# proc isNil*(obj:UObjectPtr) : bool = obj == nullptr

proc getActorByName*(actor:AActorPtr, name:string) : AActorPtr = nil#AActorPtr(0) #overrided

proc getWorldContext*() : AActorPtr = nil# AActorPtr(0) #overrided

# discard m.getActorByName("test")

proc getActor*() : AActorPtr = nil# AActorPtr(0) #overrided
proc getName*(obj:int) : string = "overriden" #overrided
proc getNameWrapper*(obj:UObjectPtr) : string = getName(cast[int](obj))


proc uCallInterop(uCall:UECall) : Option[RuntimeField] = none(RuntimeField) #overrided no need anymore, remove interop

proc uCall*(uCall:UECall) : Option[RuntimeField] = 
  result = uCallInterop(uCall)
  # log "uCall: " & $uCall & " result: " & $result


proc getClassByNameInterop(className:string) : UClassPtr = nil#UClassPtr(0) #overrided
proc getClassByName*(className:string) : UClassPtr = getClassByNameInterop(className)

# proc newUObjectInterop(owner : UObjectPtr, cls:UClassPtr) : UObjectPtr = UObjectPtr(0) #overrided


# type 
#   SomeObject* = object
#     a : int 
#   SomeObjectPtr* = ptr SomeObject

# proc getSomeObjectPtr*() : SomeObjectPtr = nil 


proc castIntToPtr*[T](address:int) : ptr T = nil


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




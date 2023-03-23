
import std/[json, jsonutils, typetraits, strutils, tables, options]
import runtimefield
proc log*(s:string) : void = discard #overrided
#TODO move shared types to shared.nim
type
  AActorPtr* = distinct(int)
  FVector* = object
    x*,y*,z*:float
  FLinearColor* = object
    r*,g*,b*,a*:float
  AMyActorPtr* =  distinct(int)
  UClassPtr* = distinct(int)
  UObjectPtr* = distinct(int)


converter myActorToActor*(actor:AMyActorPtr) : AActorPtr = AActorPtr(int(actor))

converter toUObject*(actor:AActorPtr) : UObjectPtr = UObjectPtr(int(actor))
converter toUObject*(actor:AMyActorPtr) : UObjectPtr = UObjectPtr(int(actor))
converter toUObject*(actor:UClassPtr) : UObjectPtr = UObjectPtr(int(actor))

proc isNil*(actor:UObjectPtr) : bool = int(actor) == 0

proc getActorByName*(actor:AActorPtr, name:string) : AActorPtr = AActorPtr(0) #overrided

proc getWorldContext*() : AActorPtr = AActorPtr(0) #overrided

let m = AMyActorPtr(0)
discard m.getActorByName("test")

proc getActor*() : AActorPtr = AActorPtr(0) #overrided
proc getName*(obj:UObjectPtr) : string = "overriden" #overrided



proc uCallInterop(uCall:UECall) : Option[RuntimeField] = none(RuntimeField) #overrided no need anymore, remove interop

proc uCall*(uCall:UECall) : Option[RuntimeField] = 
  result = uCallInterop(uCall)
  # log "uCall: " & $uCall & " result: " & $result


proc getClassByNameInterop(className:string) : UClassPtr = UClassPtr(0) #overrided
proc getClassByName*(className:string) : UClassPtr = getClassByNameInterop(className)

proc newUObjectInterop(owner : UObjectPtr, cls:UClassPtr) : UObjectPtr = UObjectPtr(0) #overrided



proc newUObject*[T](owner : UObjectPtr = UObjectPtr(0)) : T = 
  let cls = getClassByName(T.name.removeFirstLetter.removeLastLettersIfPtr())
  let obj = newUObjectInterop(owner, cls)
  cast[T](obj)



#BORROW
type UEBorrowInfo* = object
  fnName*: string
  className* : string
  ueActualName* : string

#eventually this will be json
proc setupBorrowInterop*(borrowInfo:string) = discard #override
proc setupBorrow*(borrowInfo:UEBorrowInfo) = setupBorrowInterop($borrowInfo.toJson())




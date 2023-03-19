
import std/[json, jsonutils, typetraits, strutils, tables]
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
type 
  UEFunc* = object 
    name* : string
    className* : string
   
  UECall* = object
    fn* : UEFunc 
    self* : int
    value* : JsonNode 

proc makeUEFunc*(name, className : string) : UEFunc = 
  result.name = name
  result.className = className

converter myActorToActor*(actor:AMyActorPtr) : AActorPtr = AActorPtr(int(actor))

converter toUObject*(actor:AActorPtr) : UObjectPtr = UObjectPtr(int(actor))
converter toUObject*(actor:AMyActorPtr) : UObjectPtr = UObjectPtr(int(actor))
converter toUObject*(actor:UClassPtr) : UObjectPtr = UObjectPtr(int(actor))

proc isNil*(actor:AActorPtr) : bool = int(actor) == 0

proc getActorByName*(actor:AActorPtr, name:string) : AActorPtr = AActorPtr(0) #overrided

proc getWorldContext*() : AActorPtr = AActorPtr(0) #overrided

let m = AMyActorPtr(0)
discard m.getActorByName("test")

proc getActor*() : AActorPtr = AActorPtr(0) #overrided
proc getName*(obj:UObjectPtr) : string = "overriden" #overrided



proc uCallInterop(uCall:string) : string = "result" #overrided


proc uCall*(uCall:UECall) : JsonNode = uCallInterop($uCall.toJson()).parseJson()


proc getClassByNameInterop(className:string) : UClassPtr = UClassPtr(0) #overrided
proc getClassByName*(className:string) : UClassPtr = getClassByNameInterop(className)

proc newUObjectInterop(owner : UObjectPtr, cls:UClassPtr) : UObjectPtr = UObjectPtr(0) #overrided

func removeFirstLetter*(str: string): string =
  if str.len() > 0: str.substr(1)
  else: str

proc removeLastLettersIfPtr*(str:string) : string = 
    if str.endsWith("Ptr"): str.substr(0, str.len()-4) else: str


proc newUObject*[T](owner : UObjectPtr = UObjectPtr(0)) : T = 
  let cls = getClassByName(T.name.removeFirstLetter.removeLastLettersIfPtr())
  let obj = newUObjectInterop(owner, cls)
  cast[T](obj)



#BORROW
type UEBorrowInfo* = object
  vmFnName*: string
  className* : string

#eventually this will be json
proc setupBorrowInterop*(borrowInfo:string) = discard #override
proc setupBorrow*(borrowInfo:UEBorrowInfo) = setupBorrowInterop($borrowInfo.toJson())

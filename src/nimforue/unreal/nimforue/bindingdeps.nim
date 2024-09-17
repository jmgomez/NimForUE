include ../definitions
import ../coreuobject/[uobject, uobjectglobals, package, unrealtype, nametypes]
import ../core/containers/[unrealstring, array, map]
import ../../utils/[utils]
import std/[typetraits, strutils, options, strformat, sequtils, sugar, tables]


type
  UReflectionHelpers* {.importcpp.} = object of UObject #Tedious because there are a lot of functions inside.
  UReflectionHelpersPtr* = ptr UReflectionHelpers


proc getDefaultObjectFromClassName*(clsName:FString) : UObjectPtr = 
  let cls = getClassByName(clsName)
  if cls.isNotNil:
    result = cls.getDefaultObject()

proc getFPropertyByName*(struct:UStructPtr, propName:FString) : FPropertyPtr = 
  var fieldIterator = makeTFieldIterator[FProperty](struct, IncludeSuper)
  for it in fieldIterator: 
    let prop = it.get()     
    if prop.getName.toLower == propName.toLower:
      return prop
    # log &"[getFPropertyByName]: Finding {propName} Tried: {prop.getName()}"


proc getPropertyValuePtr*[T](property:FPropertyPtr, container : pointer) : ptr T {.importcpp: "GetPropertyValuePtr<'*0>(@)".}
proc setPropertyValuePtr*[T](property:FPropertyPtr, container : pointer, value : ptr T) : void {.importcpp: "SetPropertyValuePtr<'*3>(@)".}
proc setPropertyValue*[T](property:FPropertyPtr, container : pointer, value : T) : void {.importcpp: "SetPropertyValue<'3>(@)".}




proc getValueFromBoolProp*(prop:FPropertyPtr, obj:UObjectPtr): bool {.inline.} =
  castField[FBoolProperty](prop).getPropertyValue(prop.containerPtrToValuePtr(obj))
proc setValueInBoolProp*(prop:FPropertyPtr, obj:UObjectPtr, val: bool) {.inline.} =
  castField[FBoolProperty](prop).setPropertyValue(prop.containerPtrToValuePtr(obj), val)

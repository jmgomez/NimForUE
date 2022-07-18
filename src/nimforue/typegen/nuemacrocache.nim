include ../unreal/definitions
import ../utils/utils
import std/[times,strformat,json, strutils, options, sugar, sequtils, macros, macrocache, tables]
import ../unreal/core/containers/unrealstring
import ../unreal/coreuobject/[package, uobject]
import ../typegen/models


const mcMulDelegates = CacheSeq"multicastDelegates"
const mcDelegates = CacheSeq"delegates"

func contains(t: CacheSeq, node:NimNode) : bool = 
    for n in t:
        if n == node: return true
    return false

func addDelegateToAvailableList*(del : UEType) =
    case del.delKind:
        of uedelDynScriptDelegate: mcMulDelegates.add(newLit del.name)
        of uedelMulticastDynScriptDelegate: mcDelegates.add(newLit del.name)

func isMulticastDelegate*(typeName:string) : bool = newLit(typeName) in mcMulDelegates

func isDelegate*(typeName:string) : bool = newLit(typeName) in mcDelegates


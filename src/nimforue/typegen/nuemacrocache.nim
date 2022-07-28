include ../unreal/definitions
import ../utils/utils
import std/[times,strformat,json, strutils, options, sugar, sequtils, macros, macrocache, tables]
import ../unreal/core/containers/unrealstring
import ../unreal/coreuobject/[package, uobject]
import ../typegen/models


const mcMulDelegates = CacheSeq"multicastDelegates"
const mcDelegates = CacheSeq"delegates"



func contains(cs: CacheSeq, node:NimNode) : bool = 
    for n in cs:
        if n == node: return true
    return false

func hasKey[T](ct:CacheTable, name:T) : bool = 
    for key, val in ct:
        if key == name: return true
    return false


func addDelegateToAvailableList*(del : UEType) =
    case del.delKind:
        of uedelDynScriptDelegate: mcMulDelegates.add(newLit del.name)
        of uedelMulticastDynScriptDelegate: mcDelegates.add(newLit del.name)

func isMulticastDelegate*(typeName:string) : bool = newLit(typeName) in mcMulDelegates

func isDelegate*(typeName:string) : bool = newLit(typeName) in mcDelegates


const mcPropAssigmentsTable = CacheTable"propAssigmentsTable"

#they are store as a StmTList of Assgn Nodes. 
#with the left value as DotExpr which is not set at the time of creation
#so it has to be set on the usage (the uClass constructor)
func addPropAssigment*(typeName:string, assigmentNode:NimNode) = 
    debugEcho typeName
    if mcPropAssigmentsTable.hasKey(typeName):
        mcPropAssigmentsTable[typeName].add assigmentNode
    else:
        mcPropAssigmentsTable[typeName] = nnkStmtList.newTree assigmentNode

func getPropAssigment*(typeName:string) : Option[NimNode] =
    if mcPropAssigmentsTable.hasKey(typeName):
        some mcPropAssigmentsTable[typeName]
    else: none[NimNode]()


func uClassNeedsConstructor*(typeName:string) : bool = 
    mcPropAssigmentsTable.hasKey(typeName)
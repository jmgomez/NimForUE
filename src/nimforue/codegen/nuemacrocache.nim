
import std/[strformat,json, jsonutils, strutils, options, macros, macrocache, tables]
import ../codegen/models


const mcMulDelegates = CacheSeq"multicastDelegates"
const mcDelegates = CacheSeq"delegates"

const mcVMTypes = CacheSeq"vmTypes"

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


const mcPropAssignmentsTable = CacheTable"propAssignmentsTable"

#they are store as a StmTList of Assgn Nodes. 
#with the left value as DotExpr which is not set at the time of creation
#so it has to be set on the usage (the uClass constructor)
func addPropAssignment*(typeName:string, assignmentNode:NimNode) = 
    if mcPropAssignmentsTable.hasKey(typeName):
        mcPropAssignmentsTable[typeName].add assignmentNode
    else:
        mcPropAssignmentsTable[typeName] = nnkStmtList.newTree assignmentNode

func getPropAssignment*(typeName:string) : Option[NimNode] =
    if mcPropAssignmentsTable.hasKey(typeName):
        some mcPropAssignmentsTable[typeName]
    else: none[NimNode]()


func doesClassNeedsConstructor*(typeName:string) : bool = 
    mcPropAssignmentsTable.hasKey(typeName)


proc addVMType*(typeName:UEType) = 
    mcVMTypes.add(newStrLitNode $typeName.toJson())

proc getVMTypes*() : seq[UEType] =     
    for uet in mcVMTypes:
      result.add parseJson(uet.strVal).jsonTo(UEType)
    

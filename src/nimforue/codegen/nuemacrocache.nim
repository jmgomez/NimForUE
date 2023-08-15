
import std/[strformat,json, jsonutils, strutils, options, macros, macrocache, tables]
import ../codegen/models


const mcMulDelegates = CacheSeq"multicastDelegates"
const mcDelegates = CacheSeq"delegates"

const mcVMTypes = CacheSeq"vmTypes"
const mcVMUFuncs = CacheSeq"vmUFuncs" #since ufuncs are detached from types we keep track them here. 

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

proc addVMUFunc*(ufun:UEField) = 
    mcVMUFuncs.add(newStrLitNode $ufun.toJson())
    #stores a seq of funcs. So each type has a key with them all. 
    # if mcVMUFuncs.hasKey(ufun.typeName):      
    #     var fns = mcVMUFuncs[ufun.typeName].repr.parseJson.jsonTo(seq[UEField])
    #     fns.add ufun
    #     mcVMUFuncs[ufun.typeName] = newStrLitNode $fns.toJson()
    # else:
    #     mcVMUFuncs[ufun.typeName] = nnkStmtList.newTree newStrLitNode $(@[ufun].toJson())
    

proc getVMTypes*(needsFields: bool = true) : seq[UEType] =     
    for uet in mcVMTypes:
      result.add parseJson(uet.strVal).jsonTo(UEType)
    if not needsFields: return result
    
    var fns: seq[UEField]
    for uef in mcVMUFuncs:
      fns.add parseJson(uef.strVal).jsonTo(UEField)
      
    for uet in result.mitems:
      if uet.kind == uetClass: #I know this sucks, but do you know what sucks more? Nim's macrocache API.
        for fn in fns:
          if fn.typeName == uet.name:
            uet.fields.add(fn)
        
      
    

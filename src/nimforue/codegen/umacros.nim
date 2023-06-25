import std/[sequtils, macros, genasts, sugar, json, jsonutils]
import uebindcore, models, modelconstructor

import ../utils/[ueutils,utils]

when defined(nuevm):
  import vmtypes #todo maybe move this to somewhere else so it's in the path without messing vm.nim compilation
  import ../vm/[vmmacros, runtimefield, exposed]  
  include guest
else:
  import ueemit, nuemacrocache

# import ueemit

macro uEnum*(name:untyped, body : untyped): untyped =       
    let name = name.strVal()
    let metas = getMetasForType(body)
    let fields = body.toSeq().filter(n=>n.kind in [nnkIdent, nnkTupleConstr])
                    .mapIt((if it.kind == nnkIdent: @[it] else: it.children.toSeq()))
                    .foldl(a & b)
                    .mapIt(it.strVal())
                    .mapIt(makeFieldASUEnum(it, name))

    let ueType = makeUEEnum(name, fields, metas)    
    when defined nuevm:
      let types = @[ueType]    
      emitType($(types.toJson()))    
      result = nnkTypeSection.newTree  
      result.add genUEnumTypeDefBinding(ueType, ctVM)
    else:
      addVMType ueType 
      result = emitUEnum(ueType)

 
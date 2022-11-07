include ../unreal/prelude
import std / [strformat]
import std / [macros, genasts, sequtils, strutils]

import ../typegen/models

template makeStrProc(T: typedesc) =
  proc `$`*(t: T): string {.inject.} =
    $T & system.`$`t

makeStrProc UEMetaData
makeStrProc UEField
makeStrProc UEType
makeStrProc UEImportRule
makeStrProc UEModule
makeStrProc UEProject

#example usage with the VM


# import compiler / [ast, nimeval, llstream, types]

# makeStrProc(UEMetadata)
# makeStrProc(UEField)
# makeStrProc(UEType)

# var uemetadata = UEMetadata(name: "fieldmeta", value: false)
# var uefield = UEField(name: "field", metadata: @[uemetadata], kind: uefEnumVal)
# var uetype = UEType(name: "type", fields: @[uefield], metadata: @[uemetadata], kind: uetStruct)

# echo $ueType

# var i = createInterpreter("main.nims", [findNimStdLib()])

# var input = "var o* {.test.} = " & $ueType

# var script = &"""
# import test
# export code
# import models

# {input}

# """
# UE_Log script
# try:
#   i.evalScript(llstreamopen(script))
# except:
#   let msg = getCurrentExceptionMsg()
  

# var codeSym = i.selectUniqueSymbol("code")
# if codeSym.isNil:
#   quit("could not find code symbol, did you export it?")

# var code = i.getGlobalValue(codeSym)
# if code.isNil:
#   quit("could not get code value")

# UE_Log "code: --- "
# UE_Log code.strVal


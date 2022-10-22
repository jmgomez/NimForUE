include ../unreal/prelude
import std / [strformat]
import std / [macros, genasts]

import ../typegen/models

# This macro makes a proc(v: T): string for use with emitting to the VM
#macro makeStrProc*(t: typedesc): untyped

proc getField(f: NimNode, output:NimNode): NimNode =
  #echo f.treeRepr
  case f.kind:
  of nnkIdentDefs:
    let fname = f[0].strval
    genAst(output, fname = f[0].strval & ": ", fident = ident f[0].strval):
      output.add fname
      output.addQuoted v.fident
      output.add ", "
    
  of nnkRecCase:
    var stmts = nnkStmtList.newTree()
    let kindName = f[0][0].repr
    let kindIdent = ident kindName
    let kindType = ident(f[0][1].repr)
    let kindStmt = genAst(output, kindName = kindName & ": ", kindIdent):
        output.add kindName
        output.addQuoted v.kindIdent
        output.add ", "
    stmts.add kindStmt

    var caseStmt = nnkCaseStmt.newTree(nnkDotExpr.newTree(ident("v"), kindIdent))
    for o in f[1 .. ^1]:
      var oStmts = nnkStmtList.newTree()
      var ofBranch = nnkOfBranch.newTree(o[0], oStmts)
      caseStmt.add ofBranch
      if o[1].len > 0:
        for i in o[1]: #RecList of IdentDefs
          case i[1].kind:
          of nnkSym:
            let ftypeStr = i[1].strval()
            let headStmt = genAst(output, fname = i[0].strVal & ": ", fident = ident i[0].strval):
              output.add fname
              output.addQuoted v.fident
            oStmts.add headStmt
            if ftypeStr != "string":
              let convStmt = genAst(output, ftypeStr):
                output.add "."&ftypeStr
              oStmts.add convStmt
            let tailStmt = genAst(output):
              output.add ", "
            oStmts.add tailStmt
          else:
            let oStmt = genAst(output, fname = i[0].strVal & ": ", fident = ident i[0].strval):
              output.add fname
              output.addQuoted v.fident
              output.add ", "
            oStmts.add oStmt
      else:
        oStmts.add nnkDiscardStmt.newTree(newEmptyNode())
    stmts.add caseStmt

    stmts
  else:
    error("Unknown field kind: " & f.kind.repr)
    newLit ""


macro makeStrProc*(t: typedesc): untyped =
  # generates a proc `$`(v: t): string
  let timpl = t.getTypeImpl[1].getTypeImpl()
  #echo timpl.treeRepr
  var strproc = nnkProcDef.newTree(
      nnkPostfix.newTree(
        ident("*"),
        nnkAccQuoted.newTree(ident("$"))), 
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        ident "string",
        nnkIdentDefs.newTree( ident "v", ident t.strval, newEmptyNode())
      ),
    newEmptyNode(),
    newEmptyNode())

  let output = ident "output"
  var head = genAst(output, typeName = t.strVal & "("):
    var output = typeName

  let fields = case timpl.kind:
    of nnkObjectTy:
      let tfields = timpl[2]
      # handle fields
      var stmts = nnkStmtList.newTree
      for f in tfields:
        stmts.add getField(f, output)
      stmts
    else:
      error("unsupported " & $timpl.kind)
      newEmptyNode()

  var tail = genAst(output):
    output.add(")")
    output

  strproc.add(nnkStmtList.newTree(head, fields, tail))
  #echo strproc.repr
  strproc


makeStrProc(UEMetadata)
makeStrProc(UEField)
makeStrProc(UEType)
makeStrProc(UEImportRule)
makeStrProc(UEModule)
makeStrProc(UEProject)


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


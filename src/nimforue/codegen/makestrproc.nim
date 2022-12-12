import std / [strformat]
import std / [macros, genasts]

# This macro makes a proc(v: T): string for use with emitting to the VM
#macro makeStrProc*(t: typedesc): untyped
proc processIdentDef(i: NimNode, output:NimNode): NimNode = 
  case i[1].kind:
  of nnkSym:
    let ftypeStr = i[1].strval()
    if ftypeStr == "string":
      genAst(output, fname = i[0].strVal & ": ", fident = ident i[0].strval):
        output.add fname
        output.addQuoted v.fident
    else: # convert value to type for integers/enum, need to explicitly call `$` on enums or it'll be empty
      genAst(output, fname = i[0].strVal & ": ", fident = ident i[0].strval, ftypeStr):
        output.add fname
        output.add $v.fident
        output.add "."&ftypeStr
  else:
    genAst(output, fname = i[0].strVal & ": ", fident = ident i[0].strval):
      output.add fname
      output.addQuoted v.fident

template processRecList(recList: NimNode, output: untyped) =
  if recList.len > 0:
    # add comma after kind for non empty branches
    oStmts.add genAst(output) do:
      output.add ", "
    for i in recList: #RecList of IdentDefs
      oStmts.add processIdentDef(i, output)
      if i != recList[^1]:
        let tailStmt = genAst(output):
          output.add ", "
        oStmts.add tailStmt
  else:
    oStmts.add nnkDiscardStmt.newTree(newEmptyNode())

proc getField(f: NimNode, output:NimNode): NimNode =
  #echo f.treeRepr
  case f.kind:
  of nnkIdentDefs:
    processIdentDef(f, output)
  of nnkRecCase:
    var stmts = nnkStmtList.newTree()
    let kindName = f[0][0].repr
    let kindIdent = ident kindName
    let kindType = ident(f[0][1].repr)
    let kindStmt = genAst(output, kindName = kindName & ": ", kindIdent):
        output.add kindName
        output.addQuoted v.kindIdent
    stmts.add kindStmt

    var caseStmt = nnkCaseStmt.newTree(nnkDotExpr.newTree(ident("v"), kindIdent))
    var lastOfBranchIndex = f.len - 1
    if f[^1].kind == nnkElse:
      dec lastOfBranchIndex
    for o in f[1 .. lastOfBranchIndex]:
      var oStmts = nnkStmtList.newTree()
      var ofBranch = nnkOfBranch.newTree(o[0], oStmts)
      caseStmt.add ofBranch
      processRecList(o[1], output)

    if f[^1].kind == nnkElse:
      var oStmts = nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))
      var elseBranch = nnkElse.newTree(oStmts)
      caseStmt.add elseBranch
      for i in f[^1]: # is it a RecList?
        if i.kind == nnkRecList:
          processRecList(i, output)
        else:
          discard

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

  let tname = t.strVal & "("
  #var tname = nnkStrLit.newNimNode() # why doesn't this work?!
  #tname.strVal = t.strVal & "("
  let output = ident "output"
  let fields = case timpl.kind:
    of nnkObjectTy:
      let tfields = timpl[2]
      # handle fields
      var stmts = nnkStmtList.newTree
      for f in tfields:
        stmts.add getField(f, output)
        if f != tfields[^1]:
          stmts.add genAst(output) do:
            output.add ", "
      stmts
    else:
      error("unsupported " & $timpl.kind)
      newEmptyNode()
  var body = quote do:
    var `output` = `tname`
    `fields`
    `output`.add ")"
    `output`
  strproc.add body

  #echo strproc.repr
  strproc


#[
# we could use this much simpler form if we didn't use distinct for the enum vals
template makeStrProc*(T: typedesc) =
  proc `$`*(t: T): string {.inject.} =
    $T & system.`$`t
]#

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


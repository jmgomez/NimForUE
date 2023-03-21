import std/[macros, macrocache, sugar, typetraits, importutils]
import compiler/[renderer, ast, idents]
import assume/typeit

type
  VMParseError* = object of CatchableError ## Error raised when an object cannot be parsed.

proc toVm*[T: enum or bool](a: T): Pnode = newIntNode(nkIntLit, a.BiggestInt)
proc toVm*[T: char](a: T): Pnode = newIntNode(nkUInt8Lit, a.BiggestInt)

proc toVm*[T: int8](a: T): Pnode = newIntNode(nkInt8Lit, a.BiggestInt)
proc toVm*[T: int16](a: T): Pnode = newIntNode(nkInt16Lit, a.BiggestInt)
proc toVm*[T: int32](a: T): Pnode = newIntNode(nkInt32Lit, a.BiggestInt)
proc toVm*[T: int64](a: T): Pnode = newIntNode(nkint64Lit, a.BiggestInt)
proc toVm*[T: int](a: T): Pnode = newIntNode(nkIntLit, a.BiggestInt)

proc toVm*[T: uint8](a: T): Pnode = newIntNode(nkuInt8Lit, a.BiggestInt)
proc toVm*[T: uint16](a: T): Pnode = newIntNode(nkuInt16Lit, a.BiggestInt)
proc toVm*[T: uint32](a: T): Pnode = newIntNode(nkuInt32Lit, a.BiggestInt)
proc toVm*[T: uint64](a: T): Pnode = newIntNode(nkuint64Lit, a.BiggestInt)
proc toVm*[T: uint](a: T): Pnode = newIntNode(nkuIntLit, a.BiggestInt)

proc toVm*[T: float32](a: T): Pnode = newFloatNode(nkFloat32Lit, BiggestFloat(a))
proc toVm*[T: float64](a: T): Pnode = newFloatNode(nkFloat64Lit, BiggestFloat(a))
proc toVm*[T: string](a: T): PNode = newStrNode(nkStrLit, a)
proc toVm*[T: proc](a: T): PNode = newNode(nkNilLit)

proc toVm*[T](s: set[T]): PNode =
  result = newNode(nkCurly)
  let count = high(T).ord - low(T).ord
  result.sons.setLen(count)
  for val in s:
    let offset = val.ord - low(T).ord
    result[offset] = toVm(val)

proc toVm*[T: openArray](obj: T): PNode
proc toVm*[T: tuple](obj: T): PNode
proc toVm*[T: object](obj: T): PNode
proc toVm*[T: ref](obj: T): PNode
proc toVm*[T: distinct](a: T): PNode = toVm(distinctBase(T, true)(a))


template raiseParseError(t: typedesc): untyped =
  raise newException(VMParseError, "Cannot convert to: " & $t)

proc extractType(typ: NimNode): NimNode =
  let impl = typ.getTypeInst
  impl[^1]

const intLits = {nkCharLit..nkUInt64Lit}
proc fromVm*(t: typedesc[SomeOrdinal or char], node: PNode): t =
  if node.kind in intLits:
    t(node.intVal)
  else:
    raiseParseError(t)

proc fromVm*(t: typedesc[SomeFloat], node: PNode): t =
  if node.kind in nkFloatLiterals:
    t(node.floatVal)
  else:
    raiseParseError(t)

proc fromVm*(t: typedesc[string], node: PNode): string =
  if node.kind in {nkStrLit, nkTripleStrLit, nkRStrLit}:
    node.strVal
  else:
    raiseParseError(t)

proc fromVm*[T](t: typedesc[set[T]], node: Pnode): t =
  if node.kind == nkCurly:
    for val in node:
      if val != nil:
        case val.kind
        of nkRange:
          for x in fromVm(T, val[0])..fromVm(T, val[1]):
            result.incl x
        else:
          result.incl fromVm(T, val)
  else:
    raiseParseError(set[T])

proc fromVm*(t: typedesc[proc]): typeof(t) = nil

proc fromVm*[T: object](obj: typedesc[T], vmNode: PNode): T
proc fromVm*[T: tuple](obj: typedesc[T], vmNode: Pnode): T
proc fromVm*[T: ref object](obj: typedesc[T], vmNode: PNode): T
proc fromVm*[T: ref(not object)](obj: typedesc[T], vmNode: PNode): T

proc fromVm*[T: proc](obj: typedesc[T], vmNode: PNode): T = nil

proc fromVm*[T: distinct](obj: typedesc[T], vmNode: PNode): T = T(fromVm(distinctBase(T, true), vmNode))

proc fromVm*[T](obj: typedesc[seq[T]], vmNode: Pnode): seq[T] =
  if vmNode.kind in {nkBracket, nkBracketExpr}:
    result.setLen(vmNode.sons.len)
    for i, x in vmNode.sons:
      result[i] = fromVm(T, x)
  else:
    raiseParseError(seq[T])

proc fromVm*[Idx, T](obj: typedesc[array[Idx, T]], vmNode: Pnode): obj =
  if vmNode.kind in {nkBracket, nkBracketExpr}:
    for i, x in vmNode:
      result[Idx(i - obj.low.ord)] = fromVm(T, x)
  else:
    raiseParseError(array[Idx, T])

proc fromVm*[T: tuple](obj: typedesc[T], vmNode: Pnode): T =
  if vmNode.kind == nkTupleConstr:
    var index = 0
    for x in result.fields:
      x = fromVm(typeof(x), vmNode[index])
      inc index
  else:
    raiseParseError(T)

proc hasRecCase(n: NimNode): bool =
  for son in n:
    if son.kind == nnkRecCase:
      return true

proc baseSym(n: NimNode): NimNode =
  if n.kind == nnkSym:
    n
  else:
    n.basename

proc addFields(n: NimNode, fields: var seq[NimNode]) =
  case n.kind
  of nnkRecCase:
    fields.add n[0][0].baseSym
  of nnkIdentDefs:
    for def in n[0..^3]:
      fields.add def.baseSym
  else:
    discard

proc parseObject(body, vmNode, baseType: NimNode, offset: var int, fields: var seq[
    NimNode]): NimNode =
  ## Emits the VmNode -> Object constructor so the function can be called

  template stmtlistAdd(body: NimNode) =
    if result.kind == nnkNilLit:
      result = body
    elif result.kind != nnkStmtList:
      result = newStmtList(result, body)
    else:
      result.add body

  template addConstr(n: NimNode) =
    if not n.hasRecCase:
      let colons = collect(newSeq):
        for x in fields:
          let desymd = ident($x)
          nnkExprColonExpr.newTree(desymd, desymd)
      if result.kind == nnkNilLit:
        result = newStmtList()
      let constr = nnkObjConstr.newTree(baseType)
      constr.add colons
      stmtlistAdd(constr)

  case body.kind
  of nnkRecList:
    for defs in body:
      defs.addFields(fields)
    for defs in body:
      stmtlistAdd parseObject(defs, vmNode, baseType, offset, fields)
    if body.len == 0 or body[0].kind notin {nnkNilLit, nnkDiscardStmt}:
      addConstr(body)
  of nnkIdentDefs:
    let typ = body[^2]
    for def in body[0..^3]:
      let name = ident($def.baseSym)
      stmtlistAdd quote do:
        let `name` = fromVm(typeof(`typ`), `vmNode`[`offset`][1])
      inc offset
  of nnkRecCase:
    let
      descrimName = ident($body[0][0].baseSym)
      typ = body[0][1]
    stmtlistAdd quote do:
      let `descrimName` = fromVm(typeof(`typ`), `vmNode`[`offset`][1])

    inc offset
    let caseStmt = nnkCaseStmt.newTree(descrimName)
    let preFieldSize = fields.len
    for subDefs in body[1..^1]:
      caseStmt.add parseObject(subDefs, vmNode, baseType, offset, fields)
    stmtlistAdd caseStmt
    fields.setLen(preFieldSize)
  of nnkOfBranch, nnkElifBranch:
    let
      conditions = body[0]
      preFieldSize = fields.len
      ofBody = parseObject(body[1], vmNode, baseType, offset, fields)
    stmtlistAdd body.kind.newTree(conditions, ofBody)
    fields.setLen(preFieldSize)
  of nnkElse:
    let preFieldSize = fields.len
    stmtlistAdd nnkElse.newTree(parseObject(body[0], vmNode, baseType, offset, fields))
    fields.setLen(preFieldSize)
  of nnkNilLit, nnkDiscardStmt:
    result = newStmtList()
    addConstr(result)
  of nnkRecWhen:
    if body[0][0].kind == nnkIdent and body[0][0].eqIdent"false":
      result = newEmptyNode()
    else:
      error("Nimscripter cannot support objects that use when statments. A proc that uses this object is the issue.", body)
  else: discard

proc parseObject(body, vmNode, baseType: NimNode, offset: var int): NimNode =
  var fields: seq[NimNode]
  result = parseObject(body, vmNode, baseType, offset, fields)

proc replaceGenerics(n: NimNode, genTyp: seq[(NimNode, NimNode)]) =
  ## Replaces all instances of a typeclass with a generic type,
  ## used in generated headers for the VM.
  for i in 0 ..< n.len:
    var x = n[i]
    if x.kind in {nnkSym, nnkIdent}:
      for (name, typ) in genTyp:
        if x.eqIdent(name):
          n[i] = typ
    else:
      replaceGenerics(x, genTyp)

macro fromVmImpl[T: object](obj: typedesc[T], vmNode: PNode): untyped =
  let
    typ = newCall(ident"typeof", obj)
    recList = block:
      let extracted = obj.extractType
      if extracted.len > 0:
        let
          impl = extracted[0].getImpl
          recList = extracted[0].getImpl[^1][^1].copyNimTree
          genParams = collect(newSeq):
            for i, x in impl[1]:
              (x, extracted[i + 1])
        recList.replaceGenerics(genParams)
        recList
      else:
        extracted.getImpl[^1][^1]
  var offset = 1
  result = newStmtList(newCall(bindSym"privateAccess", typ)):
    parseObject(recList, vmNode, typ, offset)
  if result[^1].kind == nnkNilLit:
    result = quote do:
      default(`obj`)

proc getRefRecList(n: NimNode): NimNode =
  if n.len > 0:
    let
      impl = n[0].getImpl
      recList = n[0].getImpl[^1][^1].copyNimTree
      genParams = collect(newSeq):
        for i, x in impl[1]:
          (x, n[i + 1])
    recList.replaceGenerics(genParams)
    result = recList
  else:
    let recList = n.getImpl[^1][^1]
    if recList.kind == nnkSym:
      result = recList.getTypeImpl[^1]
    else:
      result = recList[^1]

macro fromVmImpl[T: ref object](obj: typedesc[T], vmNode: PNode): untyped =
  let
    typ = extractType(obj)
    recList = getRefRecList(typ)
    typConv = newCall(ident"typeof", typ)
  var offset = 1
  result = newStmtList(newCall(bindSym"privateAccess", typConv)):
    parseObject(recList, vmNode, typ, offset)
  if result[^1].kind != nnkNilLit:
    # In the case we dont have fields we dont want the `parseObject` logic
    result = quote do:
      if `vmNode`.kind == nkNilLit:
        typeof(`obj`)(nil)
      else:
        `result`
  else:
    result = quote do:
      if `vmNode`.kind == nkNilLit:
        typeof(`obj`)(nil)
      else:
        `obj`()

proc fromVm*[T: object](obj: typedesc[T], vmNode: PNode): T =
  if vmNode.kind == nkObjConstr:
    fromVmImpl(obj, vmnode)
  else:
    raiseParseError(T)

proc fromVm*[T: ref object](obj: typedesc[T], vmNode: PNode): T =
  if vmNode.kind in {nkObjConstr, nkNilLit}:
    fromVmImpl(obj, vmnode)
  else:
    raiseParseError(T)

proc fromVm*[T: ref(not object)](obj: typedesc[T], vmNode: PNode): T =
  if vmNode.kind != nkNilLit:
    new result
    result[] = fromVm(typeof(result[]), vmNode)

proc toVm*[T: openArray](obj: T): PNode =
  result = newNode(nkBracketExpr)
  for x in obj:
    result.add toVm(x)

proc toVm*[T: tuple](obj: T): PNode =
  result = newNode(nkTupleConstr)
  for x in obj.fields:
    result.add toVm(x)

proc toVm*[T: object](obj: T): PNode =
  result = newNode(nkObjConstr)
  result.add newNode(nkEmpty)
  typeit(obj, {titAllFields}):
    result.add newNode(nkEmpty)
  var i = 1
  typeIt(obj, {titAllFields, titDeclaredOrder}):
    if it.isAccessible:
      result[i] = newNode(nkExprColonExpr)
      result[i].add newNode(nkEmpty)
      result[i].add toVm(it)
    inc i

proc toVm*[T: ref](obj: T): PNode =
  if obj.isNil:
    newNode(nkNilLit)
  else:
    toVM(obj[])
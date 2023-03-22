import std/macros except sameType

import spec

type
  titOption* = enum          ## type iteration options
    titNoParents = "ignore parent types via inheritance"
    titNoRefs    = "ignore reference types"
    titNoAliases = "fully resolve type aliases"
    titDistincts = "treat distinct types as opaque"
    titAllFields = "iterates over all fields"
    titDeclaredOrder = "iterates fields in order of declaration"

  Mode = enum Types, Values, Accessible  ## felt cute might delete later idk

  Context = object           ## just carries options around
    mode: Mode
    options: set[titOption]

proc iterate(c: Context; o, tipe, body: NimNode): NimNode

proc invoke(c: Context; body, input: NimNode): NimNode =
  ## called to output the user's supplied body with the `it` ident swapped

  # define a filter that swaps an `it` identifier with the input node
  proc swapIt(n: NimNode): NimNode =
    if n.kind == nnkIdent and n.strVal == "it":
      return input

  # the result is the provided block with the `it` swapped
  nnkBlockStmt.newTree newEmptyNode():
    filter desym:
      filter(swapIt, body)

template guardRefs(c: Context; tipe: NimNode; body: untyped): untyped =
  ## a guard against ref type output according to user's options
  if titNoRefs notin c.options or tipe.kind != nnkRefTy:
    body
  else:
    newEmptyNode()

proc eachField(c: Context; o, tipe, body: NimNode): NimNode
proc canAccessField(o, tipe, field, conds: NimNode): NimNode

proc allFieldCaseImpl(c: Context; node, o, tipe, body: NimNode): NimNode =
  result = newStmtList()
  for branch in node[1 .. ^1]:                # skip discriminator
    case branch.kind
    of nnkOfBranch:
      result.add: # add all fields to the statement
        c.eachField(o, branch.last, body)
    of nnkElse:
      result.add: # Add else fields
        c.eachField(o, branch.last, body)
    else:
      result.add:
        node.errorAst "unrecognized ast"

proc safeFieldCaseImpl(c: Context; node, o, tipe, body: NimNode): NimNode =
  # add a case statement to invoke the proper branches.
  result = nnkCaseStmt.newTree(o.dot node[0][0])
  for branch in node[1 .. ^1]:                # skip discriminator
    let clone = copyNimNode branch
    case branch.kind
    of nnkOfBranch:
      for expr in branch[0 .. ^2]:
        clone.add expr
      clone.add:
        c.eachField(o, branch.last, body)
    of nnkElse:
      clone.add:
        c.eachField(o, branch.last, body)
    else:
      result.add:
        node.errorAst "unrecognized ast"
    result.add clone

proc eachField(c: Context; o, tipe, body: NimNode): NimNode =
  ## invoke for each field in `tipe`
  result = newStmtList()
  for index, node in tipe.pairs:
    case node.kind

    # normal object field list
    of nnkRecList:
      result.add:
        c.eachField(o, node, body)

    # single definition
    of nnkIdentDefs:
      result.add:
        c.guardRefs node[1]:
          c.invoke body: o.dot node[0]

    # variant object
    of nnkRecCase:
      case c.mode
      of Types:
        result.add:
          o.errorAst "variant objects may not be iterated"
      of Values:
        # invoke the discriminator first, and then
        let kind = node[0][0]
        if titDeclaredOrder in c.options:
          result.add:
            c.invoke body: o.dot kind
        else:
          result.insert 0:
            c.invoke body: o.dot kind
        if titAllFields in c.options:
          result.add allFieldCaseImpl(c, node, o, tipe, body)
        else:
          result.add safeFieldCaseImpl(c, node, o, tipe, body)
      of Accessible: assert false
    else:
      # it's a tuple; invoke on each field by index
      result.add:
        c.invoke body: o.sq index

proc canAccessField(o, tipe, field, conds: NimNode): NimNode =
  ## iterates over the `tipe` returning the required conditions
  ## to be true for safe access of `field`
  template setResult(val: NimNode) =
    if result.kind == nnkNilLit:
      result = val

  for index, node in tipe.pairs:
    case node.kind

    # normal object field list
    of nnkRecList:
      setResult canAccessField(o, node, field, conds)

    # single definition
    of nnkIdentDefs:
      for x in node[0..^3]:
        if x == field:
          setResult conds

    # variant object
    of nnkRecCase:
      let kind = node[0][0]
      if kind == field:
        setResult conds
      var branchConds: seq[NimNode]
      for branch in node[1 .. ^1]:
        case branch.kind
        of nnkOfBranch:
          var cond = conds.copyNimTree()
          for expr in branch[0 .. ^2]:
            # Add all conditions for this branch
            cond = # Old conditions go on left to cull statements early
              case expr.kind
              of nnkCurly: # It's a set check if value is in set
                infix(cond, "and", newCall("contains", expr, o.dot kind))
              of nnkRange:
                let rangee = infix(expr[0], "..", expr[1]) # Convert the range type to slice
                infix(cond, "and", newCall("contains", rangee, o.dot kind))
              else: # if it's a single value compare
                infix(cond, "and", infix(o.dot kind, "==", expr))

          setResult canAccessField(o, branch[^1], field, cond)
          branchConds.add cond

        of nnkElse:
          let accessCond = block: 
            # Grab all branches and or them to together,
            # then invert them ie: `not(a or b)`
            var res =
              if branchConds.len > 0:
                branchConds[0]
              else:
                conds
            for i, x in branchConds.pairs:
              if i > 0:
                res = infix(res, "or", x)
            res = prefix(res, "not")
            infix(conds, "and", res)

          setResult canAccessField(o, node[^1], field, accessCond)
        else: discard
    else: discard

proc forTuple(c: Context; o, tipe, body: NimNode): NimNode =
  ## invoke for each field in `tipe`
  c.eachField(o, tipe, body)

proc forObject(c: Context; o, tipe, body: NimNode): NimNode =
  ## invoke for each field in `tipe`
  result = newStmtList()

  template addResult(val: NimNode) = 
    if c.mode == Accessible:
      if result.kind in {nnkNilLit, nnkStmtList}:
        # Only replace if nil or stmtlist,
        # this allows the multiple inherited fields to work
        result = val
    else:
      result.add val

  case tipe.kind
  of nnkEmpty:
    discard
  of nnkOfInherit:
    if titNoParents notin c.options:
      # we need to traverse the parent object type's fields
      addResult:
        c.forObject(o, getTypeImpl tipe.last, body)
  of nnkRefTy:
    # unwrap a ref type modifier
    addResult:
      c.guardRefs getTypeImpl tipe.last:
        c.forObject(o, getTypeImpl tipe.last, body)
  of nnkObjectTy:
    # first see about traversing the parent object's fields
    addResult:
      c.forObject(o, tipe[1], body)

    # now we can traverse the records in this object
    let records = tipe[2]
    case records.kind
    of nnkEmpty:
      discard
    of nnkRecList:
      case c.mode
      of Types, Values:
        result.add:
          c.eachField(o, records, body)
      of Accessible:
        let res = canAccessField(o, records, body, newLit(true)) # Nim Vm bug
        addResult(res)

    else:
      result.add:
        tipe.errorAst "unrecognized object type ast"
  else:
    # creepy ast
    result.add:
      tipe.errorAst "unrecognized object type ast"

macro typeIt*(o: typed; options: static[set[titOption]];
              body: untyped): untyped =

  ## Iterate over the symbol, `o`.

  ## If it's a value, `it` in the body will represent that value if it's a
  ## simple type, or the component parts of the value if it has a complex
  ## type.

  ## If it's a type, `it` in the body will represent the type if it's a
  ## simple type, or the component parts of the type if it's a complex
  ## type.

  template iteration(m: Mode; obj, tipe: untyped): untyped =
    ## convenience
    var c = Context(mode: m, options: options)
    c.iterate(obj, tipe, body)

  let tipe = getTypeImpl o
  case tipe.kind
  of nnkSym, nnkTupleTy, nnkObjectTy, nnkTupleConstr, nnkObjConstr:
    # the input is a value
    Values.iteration(o, getTypeImpl tipe)
  of nnkRefTy:
    # let iterate unwrap a reference value
    Values.iteration(o, tipe)
  of nnkBracketExpr:
    # the input is a type
    Types.iteration(o, getTypeImpl tipe.last)
  of nnkDistinctTy:
    if titDistincts in options:
      # leave distincts opaque
      Types.iteration(o, getTypeImpl tipe[0])  # Types is good enough
    else:
      # unwrap distincts
      case o.kind
      of nnkConv:                                  # obviously, a value
        if o.len != 2:
          o.errorAst "unrecognized conversion ast"
        else:
          Values.iteration(o[1], getTypeImpl o[0])
      else:
        Types.iteration(o.last, o.last)            # must be a type
  else:
    # i dunno wtf the input is
    o.errorAst "unexpected " & $tipe.kind

macro isAccessible*(o: typed;): untyped =
  ## Given a statement whether a field is safe.
  ## This is a runtime check and emits expression for all discriminators for a given field.
  ## For non discriminated fields returns `true`.
  if o.kind notin {nnkCheckedFieldExpr, nnkDotExpr}:
    error("'isAccessible only works with field dot expressions.", o)
  else:
    var
      obj = o[0]
      field = o[1]
    case o.kind
    of nnkCheckedFieldExpr:
      field = obj[1]
      obj = obj[0]
    else: discard

    let tipe = getTypeImpl obj
    var c = Context(mode: Accessible)
    result = c.iterate(obj, tipe, field)

proc iterate(c: Context; o, tipe, body: NimNode): NimNode =
  ## entry point for iteration
  case tipe.kind
  of nnkDistinctTy:
    if titDistincts in c.options:
      # treat distincts as opaque
      c.invoke body: o
    else:
      # unwrap a distinct
      case c.mode
      of Types, Values:
        let target =
          if c.mode == Types:
            desym tipe.last   # nim bug: must desym
          else:
            newCall(tipe.last, o)
        newCall(bindSym"typeIt", target, newLit c.options, body)
      of Accessible:
        let target = newCall(tipe.last, o)
        newCall(bindSym"isAccessible", target, body)
  of nnkObjectTy, nnkObjConstr:
    # looks like an object
    c.forObject(o, tipe, body)
  of nnkTupleTy, nnkTupleConstr:
    # looks like a tuple
    c.forTuple(o, o, body)
  of nnkRefTy:
    c.guardRefs tipe:
      case c.mode
      of Types, Accessible:       # "deref" the type
        c.iterate(getTypeImpl o, getTypeImpl tipe.last, body)
      of Values:      # deref the value
        c.iterate(newCall(ident"[]", o), getTypeImpl tipe.last, body)
  else:
    # looks like a primitive
    case c.mode
    of Types:
      var (o, tipe) = (o, tipe)
      if titNoAliases in c.options:
        while not sameType(o, tipe):
          o = tipe
          tipe = getType tipe
      c.guardRefs tipe:
        c.invoke body: desym o    # nim bug: must desym
    of Values:
      c.guardRefs tipe:
        c.invoke body: o
    of Accessible:
      o.errorAst("bad ast, ambiguous what to do here")

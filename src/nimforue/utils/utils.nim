import std/[options, strutils, sequtils, sugar, tables, json, jsonutils, macros, genasts, typetraits, strformat]
#NOTE Do not include UE Types here

type Criteria[T] = proc (t:T) : bool {.noSideEffect.}
const PathSeparator* = when defined(windows): "\\" else: "/"

type
  Traversable*[T] = concept 
    iterator items(self: Self): T
    proc len(self: Self): int

#small macros/templates
template measureTime*(name: static string, body: untyped) =
  let starts = times.now()
  body
  let ends = (times.now() - starts)
  let msg = name & " took " & $ends

  log msg

macro offsetOfFromStr*(T: typedesc, name:static string) : untyped = 
  genAst(T, name=ident name):
    offsetOf(T, name)

macro noresult*(prc:untyped) = 
  assert prc.kind == nnkProcDef
  prc.addPragma(ident "asmnostackframe")
  prc.body = 
    genAst(exp=prc.body): 
      let res {.inject.} = exp
      {.emit: "return res;".}
  prc

proc treeRepr*(xs: seq[NimNode]): string = xs.mapIt(treeRepr(it)).join("\n")
proc repr*(xs: seq[NimNode]): string = xs.mapIt(repr(it)).join("\n")

proc parent*(T:typedesc): string = 
  let child = bindSym typeof(T).name
  let parent = child.getImpl()[^1][1]
  case parent.kind:
  of nnkOfInherit:parent[0].strVal()
  else: ""

template toVar*[T](self : ptr T) : var T = cast[var T](self)
template toVar*[T](self : T) : var T = toVar(self.unsafePtr())

template safe*(body:untyped) = 
  {.cast(noSideEffect).}:
    body
    
#seq

func isEmpty*[T](s: seq[T]): bool = s.len == 0

func head*[T](xs: seq[T]): Option[T] =
  if len(xs) == 0:
    return none[T]()
  return some(xs[0])

func tail*[T](xs: seq[T]): seq[T] =
  if len(xs) == 0: @[]
  else: xs[1..^1]

func any*[T](xs: Traversable[T]): bool = len(xs) != 0
func any*[T](xs: Traversable[T], fn: T->bool): bool =
  safe: 
    xs.filter(fn).any()
func all*[T](xs: Traversable[T], fn: T->bool): bool = xs.filter(fn).len() == xs.len()

func firstIndexOf*[T](xs: Traversable[T], fn: proc (t:T) : bool): int =
  var i = 0
  while i < len(xs):
    safe: 
      if fn(xs[i]):
        return i
      inc i
  -1

func first*[T](xs: seq[T], fn: T->bool): Option[T] = xs.filter(fn).head()
func last*[T](xs: seq[T]): Option[T] = 
  if xs.len() == 0: none[T]()
  else: some(xs[^1])

func last*[T](xs: seq[T], fn: T->bool): Option[T] = xs.filter(fn).last()

  


func replaceFirst*[T](xs: var seq[T], fnCriteria: Criteria[T], newValue: T): seq[T] =
  let idx = firstIndexOf(xs, fnCriteria)
  xs[idx] = newValue #throw on purpose if there is no value. Handle it with types?
  xs

func remove*[T](xs:var seq[T], x: T) =
  var i = 0
  while i < len(xs):
    if xs[i] == x:
      xs.delete(i)
      break     
    inc i  

func mapi*[T, U](xs: seq[T], fn: (T, int)->U): seq[U] =
  {.cast(noSideEffect).}:
    var toReturn: seq[U] = newSeq[U](xs.len)
    for i, x in xs:
      toReturn[i] = (fn(x, i))
    toReturn

func skip*[T](xs: seq[T], n: int): seq[T] =
  if n >= len(xs): @[]
  else: xs[n..^1]

func tap*[T](xs: seq[T], fn: (x: T)->void): seq[T] =
  safe:
    for x in xs:
      fn(x)
    xs

proc forEach*[T](xs: seq[T], fn: (x: T)->void): void =
  for x in xs:
    fn(x)


func flatten*[T](xs: seq[seq[T]]): seq[T] = xs.foldl(a & b, newSeq[T]())

func tryGet*[T](xs: Traversable[T], idx: int): Option[T] =
  if idx < 0 or idx >= len(xs): none[T]()
  else: some(xs[idx])

#TODO use concepts to make the general case
func sequence*[T](xs : seq[Option[T]]) : seq[T] = xs.filterIt(it.isSome()).mapIt(it.get())


func partition*[T](xs: seq[T], fn: Criteria): (seq[T], seq[T]) =
  var left: seq[T] = @[]
  var right: seq[T] = @[]
  for x in xs:
    if fn(x):
      left.add(x)
    else:
      right.add(x)
  (left, right)


##GENERAL
func nonDefaultOr*[T](value, orValue: T): T =
  # let default = T()
  if value != default(T): value
  else: orValue


# func bind*[T, U](opt:T, fn : (t : T)->U) : Option[U] =
#     if
#STRING
func spacesToCamelCase*(str: string): string =
  str.split(" ")
    .map(str => ($str[0]).toUpper() & str.substr(1))
    .foldl(a & b, "")

func firstToLow*(str: string): string =
  if str.len() > 0: toLower($str[0]) & str.substr(1)
  else: str

func firstToUpper*(str: string): string =
  if str.len() > 0: toUpper($str[0]) & str.substr(1)
  else: str

func removeFirstLetter*(str: string): string =
  if str.len() > 0: str.substr(1)
  else: str

func removePref*(str: string, prefix: string): string =
  if str.startsWith(prefix): str.substr(prefix.len())
  else: str

func removePrefixes*(str: string, prefixes: seq[string]): string =
  var str = str
  for prefix in prefixes:
    str = str.removePref(prefix)
  str

func removeSuffix*(str: string, suffix: string): string =
  result = str
  result.removeSuffix(suffix)

func nonEmptyOr*(value, orValue: string): string = nonDefaultOr(value, orValue)

func countSubStr*(str:string, subStr:string): int =
  var count = 0
  var i = 0
  while i < str.len():
    if str[i..^1].startsWith(subStr):
      inc count
      i += subStr.len()
    else:
      inc i
  count

  
func sum*[SomeNumber](xs: seq[SomeNumber]): SomeNumber = xs.foldl(a + b, 0)

#OPTION


func getOrCompute*[T, U](opt: Option[T], fn: ()->T): T =
  if opt.isSome(): opt.get() else: fn()

proc getOrRaise*[T](self: Option[T], msg: string, exceptn: typedesc = Exception): T {.inline.} =
  if self.isSome(): self.get()
  else: raise newException(exceptn, msg)


proc chainNone*[T](opt: Option[T], fn: ()->Option[T]): Option[T] =
  if opt.isSome(): opt
  else: fn()

proc run*[T](opt: Option[T], fn: (x: T)->void): void =
  if opt.isSome: fn(opt.get())

func disc*[T](opt: Option[T]): void = discard


func tap*[T](opt: Option[T], fn: (x: T)->void): Option[T] =
  if opt.isSome: some fn(opt.get())
  else: none[T]()


func someNil*[T](val: sink T): Option[T] {.inline.} =
  if val == nil: none[T]()
  else: some val
type
  SomePointer = ref | ptr | pointer | proc

func tryCast*[T: SomePointer](pntr: SomePointer): Option[T] =
  if pntr.isNil():
    return none[T]()
  let casted = cast[T](pntr)
  if casted.isNil(): none[T]()
  else: some(casted)



func tryParseInt*(s: string): Option[int] =
  try:
    return some(s.parseInt())
  except:
    return none(int)

func getWithResult*[T](opt: Option[T], default:T): (T, bool) =
  if opt.isSome(): (opt.get(), true)
  else: (default, false)

#tables
type SomeTable[K, V] = Table[K, V] | TableRef[K, V]

func tryGet*[K, V](self: SomeTable[K, V], key: K): Option[V] {.inline.} =
  if self.contains(key): some(self[key])
  else: none[V]()

func addOrUpdate*[K, V](self: var SomeTable[K, V], key: K, value: V) {.inline.} =
  if key in self:
    self[key] = value
  else:
    self.add(key, value)

#pointers
proc isNotNil*(v : SomePointer) : bool = not v.isNil()
proc unsafePtr*[T](t: T): ptr T {.inline.} =
  cast[ptr T](t.unsafeAddr)

#allocations
proc newCpp*[T](): ptr T {.importcpp:"new '*0()".}
proc newCpp*(T: typedesc): ptr T {.importcpp:"new '*0()".}
proc newCpp*[P](T: typedesc, p:P): ptr T {.importcpp:"new '*0(@)".}
proc newCpp*[P, P2](T: typedesc, p:P, p2:P2): ptr T {.importcpp:"new '*0(@)".}
proc newCpp*[P, P2, P3](T: typedesc, p:P, p2:P2, p3:P3): ptr T {.importcpp:"new '*0(@)".}
proc newCpp*[P, P2, P3, P4](T: typedesc, p:P, p2:P2, p3:P3, p4:P4): ptr T {.importcpp:"new '*0(@)".}

proc deleteInteral[T](val : ptr T ) : void {.importcpp:"delete #".}
proc deleteCpp*[T](val : ptr T ) : void  =
  if val.isNotNil():
    deleteInteral(val)
    # val = nil
proc removeConst*[T](p:ptr T) : ptr T {.importcpp: "const_cast<'0>(#)".}


#JSON
proc tryGetJson*[T](json:JsonNode, key:string) : Option[T] =
  if json.hasKey(key): some(json[key].jsonTo(T))
  else: none[T]()



#comp time utils
proc objectLen*(T: typedesc[object]) : int =  
  for field in default(T).fields:    
    inc result

proc ensureIsMember*(fn: NimNode) = 
  let impl = fn.getImpl
  let isMember = 
    impl.pragma.children.toSeq
    .filterIt(it.kind == nnkExprColonExpr and it[0].strVal in ["member", "virtual"]).len > 0
  if not isMember:
    error &"Only member functions are supported and `{repr fn}` is not a member function", fn

# calls debugEcho with the lineInfo
macro here*(x: varargs[typed, `$`]):untyped {.noSideEffect.} =
   {.cast(noSideEffect), warning[Deprecated]:off.}: # callsite is deprecated, there's no alternative: https://github.com/nim-lang/RFCs/issues/387 
    result = newTree(nnkCommand, ident "debugEcho")
    result.add newStrLitNode("--- " & x[0].lineInfo & " ---\n")
    result.add newStrLitNode("    " & callsite().toStrLit().strVal & " -> \n")
    for c in x:
      result.add c

#importcpp utils
proc get*[T](): ptr T {.importcpp:"(&'*0::Get())".}

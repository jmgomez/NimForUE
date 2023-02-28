import std/[options, strutils, sequtils, sugar, tables, json, jsonutils]
#NOTE Do not include UE Types here

type Criteria[T] = proc (t:T) : bool {.noSideEffect.}
const PathSeparator* = when defined(windows): "\\" else: "/"
#seq

func isEmpty*[T](s: seq[T]): bool = s.len == 0

func head*[T](xs: seq[T]): Option[T] =
  if len(xs) == 0:
    return none[T]()
  return some(xs[0])

func tail*[T](xs: seq[T]): seq[T] =
  if len(xs) == 0: @[]
  else: xs[1..^1]

func any*[T](xs: seq[T]): bool = len(xs) != 0
func any*[T](xs: seq[T], fn: T->bool): bool = xs.filter(fn).any()

func firstIndexOf*[T](xs: seq[T], fn: Criteria[T]): int =
  var i = 0
  while i < len(xs):
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

func mapi*[T, U](xs: seq[T], fn: (T, int)->U): seq[U] =
  var toReturn: seq[U] = @[] #Todo how to reserve memory upfront to avoid reallocations?
  for i, x in xs:
    toReturn.add(fn(x, i))
  toReturn


func tap*[T](xs: seq[T], fn: (x: T)->void): seq[T] =
  for x in xs:
    fn(x)
  xs

func forEach*[T](xs: seq[T], fn: (x: T)->void): void =
  for x in xs:
    fn(x)


func flatten*[T](xs: seq[seq[T]]): seq[T] = xs.foldl(a & b, newSeq[T]())

func tryGet*[T](xs: seq[T], idx: int): Option[T] =
  if idx < 0 or idx >= len(xs): none[T]()
  else: some(xs[idx])

#TODO use concepts to make the general case
func sequence*[T](xs : seq[Option[T]]) : seq[T] = 
  xs.filter((x:Option[T])=>x.isSome()).map((x:Option[T])=>x.get())


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

proc tryGet*[K, V](self: Table[K, V], key: K): Option[V] {.inline.} =
  if self.contains(key): some(self[key])
  else: none[V]()

#pointers
proc isNotNil*(v : SomePointer) : bool = not v.isNil()

#allocations
proc newCpp*[T]() :ptr T {.importcpp:"new '*0()".}
proc deleteInteral[T](val : ptr T ) : void {.importcpp:"delete #".}
proc deleteCpp*[T](val : ptr T ) : void  =
  if val.isNotNil():
    deleteInteral(val)
    # val = nil



#JSON
proc tryGetJson*[T](json:JsonNode, key:string) : Option[T] =
  if json.hasKey(key): some(json[key].jsonTo(T))
  else: none[T]()
import std/[options, strutils, sequtils, sugar, tables]
#NOTE Do not include UE Types here


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

func firstIndexOf*[T](xs: seq[T], fn: T->bool): int =
  var i = 0
  while i < len(xs):
    if fn(xs[i]):
      return i
    inc i
  -1

func first*[T](xs: seq[T], fn: T->bool): Option[T] = xs.filter(fn).head()


func replaceFirst*[T](xs: var seq[T], fnCriteria: T -> bool, newValue: T): seq[T] =
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


#OPTION
func getOrCompute*[T, U](opt: Option[T], fn: ()->T): T =
  if opt.isSome(): opt.get() else: fn()

proc getOrRaise*[T](self: Option[T], msg: string, exceptn: typedesc = Exception): T {.inline.} =
  if self.isSome(): self.get()
  else: raise newException(exceptn, msg)


func chainNone*[T](opt: Option[T], fn: ()->Option[T]): Option[T] =
  if opt.isSome(): opt
  else: fn()

func run*[T](opt: Option[T], fn: (x: T)->void): void =
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

#tables

proc tryGet*[K, V](self: Table[K, V], key: K): Option[V] {.inline.} =
  if self.contains(key): some(self[key])
  else: none[V]()

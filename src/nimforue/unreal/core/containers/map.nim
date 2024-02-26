include ../../definitions
import std/[sequtils, tables]

import array
type 
    TPair*[K, V] {.importcpp:"TPair" .} = object
        key* {.importcpp:"Key".}: K
        value* {.importcpp:"Value".}: V

    TMap*[K, V] {.importcpp: "TMap"} = object



proc makeTPair*[K, V](k:K, v:V) : TPair[K, V] {.importcpp: "TPair<'1, '2>(@)", constructor .}

proc makeTMapPriv*[K, V](k: typedesc[K], v: typedesc[V]) : TMap[K, V] {.importcpp: "TMap<'*1, '*2>()", constructor, cdecl.}

# proc makeTMapPriv[K, V](k:K, v:V) : TMap[K, V] {.importcpp: "MakeTMap<'*0, '*1>(@)" .}
proc makeTMap*[K, V]() : TMap[K, V] = makeTMapPriv(K, V)

proc add*[K, V](map : TMap[K, V], pair:TPair[K, V]) : void  {.importcpp: "#.Add(@)", .}
proc add*[K, V](map : TMap[K, V], k:K, v:V) : void  {.importcpp: "#.Add(@)", .}
proc remove*[K, V](map : TMap[K, V], k:K) : void  {.importcpp: "#.Remove(@)", .}

func num*[K, V](map:TMap[K, V]): int32 {.importcpp: "#.Num()" }
func len*[K, V](arr:TMap[K, V]): int = arr.num()

func contains*[K, V](map:TMap[K, V], key:K): bool 
func hasKey*[K, V](map:TMap[K, V], key:K): bool {.importcpp: "#.Contains(#)" }
func empty*[K, V](map:TMap[K, V], expectedElems: int32 = 0) {.importcpp: "#.Empty(#)" }
func clear*[K, V](map:TMap[K, V]) {.inline.} = map.empty()

proc `[]`*[K, V](map:TMap[K, V], key: K): var V {. importcpp: "#[#]",  noSideEffect.}
proc update*[K, V](map:TMap[K, V], key: K, val : V)  {. importcpp: "#[#]=#",  }
proc `[]=`*[K, V](map:TMap[K, V], key: K, val : V) {.importcpp: "#[#]=#".}

#TODO Keys(), Values() and Iterators (no need to bind the Cpp ones)

proc getKeys*[K, V](map:TMap[K, V], outKeys:var TArray[K]) : void {.importcpp: "#.GetKeys(#)", .}
proc generateValueArray*[K, V](map:TMap[K, V], outValues:var TArray[V]) : void {.importcpp: "#.GenerateValueArray(#)", .}

proc keys*[K, V](map:TMap[K, V]): TArray[K] = 
    var arr = makeTArray[K]()
    getKeys(map, arr)
    arr
proc values*[K, V](map:TMap[K, V]): TArray[V] = 
    var arr = makeTArray[V]()
    arr.reserve(map.len())
    for k in map.keys():
        arr.add(map[k])
    arr

iterator pairs*[K, V](map: TMap[K, V]): (K, V) =
    for k in map.keys():
        yield (k, map[k])

func contains*[K, V](map:TMap[K, V], key:K): bool  = 
    for k in map.keys():
      if k == key:
       return true

proc toTable*[K, V](map:TMap[K, V]): Table[K, V] = 
    let keys = map.keys()
    var table = initTable[K, V]()
    for k in keys:
        table[k] = map[k]
    table

proc toTMap*[K, V](table:Table[K, V]): TMap[K, V] =
    var map = makeTMap[K, V]()
    for k, v in table.pairs:
        map.add(k, v)
    map

# proc `$`*[K, V](map:TMap[K, V]) : string = $ toTable(map)
proc `$`*[K, V](map:TMap[K, V]) : string =
    if map.num == 0:
        return  "{:}"
    result = "{"
    for key in map.keys():
      if result.len > 1: result.add(", ")
      let val = map[key]
      result.addQuoted(key)
      result.add(": ")
      result.addQuoted(val)
    result.add("}")
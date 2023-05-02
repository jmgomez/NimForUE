include ../../definitions
import std/[sequtils, tables]

import array
type 
    TPair*[K, V] {.importcpp:"TPair",  bycopy .} = object
        key* {.importcpp:"Key".}: K
        value* {.importcpp:"Value".}: V

    TMap*[K, V] {.importcpp: "TMap", bycopy} = object


proc makeTPair*[K, V](k:K, v:V) : TPair[K, V] {.importcpp: "TPair<'1, '2>(@)", constructor .}

proc makeTMapPriv*[K, V](k: typedesc[K], v: typedesc[V]) : TMap[K, V] {.importcpp: "TMap<'*1, '*2>()", constructor, cdecl.}

# proc makeTMapPriv[K, V](k:K, v:V) : TMap[K, V] {.importcpp: "MakeTMap<'*0, '*1>(@)" .}
proc makeTMap*[K, V]() : TMap[K, V] = makeTMapPriv(K, V)

proc add*[K, V](map : TMap[K, V], pair:TPair[K, V]) : void  {.importcpp: "#.Add(@)", .}
proc add*[K, V](map : TMap[K, V], k:K, v:V) : void  {.importcpp: "#.Add(@)", .}
proc remove*[K, V](map : TMap[K, V], k:K) : void  {.importcpp: "#.Remove(@)", .}

proc num*[K, V](arr:TMap[K, V]): int32 {.importcpp: "#.Num()" noSideEffect}
proc len*[K, V](arr:TMap[K, V]): int = arr.num()

proc contains*[K, V](arr:TMap[K, V], key:K): bool {.importcpp: "#.Contains(#)" noSideEffect}
proc hasKey*[K, V](arr:TMap[K, V], key:K): bool {.importcpp: "#.Contains(#)" noSideEffect}


proc `[]`*[K, V](map:TMap[K, V], key: K): var V {. importcpp: "#[#]",  noSideEffect.}
proc `[]=`*[K, V](map:TMap[K, V], key: K, val : V)  {. importcpp: "#[#]=#",  }

#TODO Keys(), Values() and Iterators (no need to bind the Cpp ones)

proc getKeys*[K, V](map:TMap[K, V], outKeys:var TArray[K]) : void {.importcpp: "#.GetKeys(#)", .}
proc generateValueArray*[K, V](map:TMap[K, V], outValues:var TArray[V]) : void {.importcpp: "#.GenerateValueArray(#)", .}

proc keys*[K, V](map:TMap[K, V]): TArray[K] = 
    var arr = makeTArray[K]()
    getKeys(map, arr)
    arr
proc values*[K, V](map:TMap[K, V]): TArray[V] = 
    var arr = makeTArray[V]()
    generateValueArray(map, arr)
    arr

proc toTable*[K, V](map:TMap[K, V]): Table[K, V] = 
    let keys = map.keys().toSeq()
    let values = map.values().toSeq()
    var table = initTable[K, V]()

    for pairs in zip(keys, values):
        let (key, value) = pairs
        table[key] = value
    table

proc toTMap*[K, V](table:var Table[K, V]): TMap[K, V] =
    var map = makeTMap[K, V]()
    for k, v in table.mpairs:
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
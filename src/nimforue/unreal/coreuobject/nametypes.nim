include ../definitions
import ../core/containers/unrealstring
import std/hashes



type 
    FName* {. importcpp .} = object
    EName* {. importcpp, size:sizeof(uint32).} = enum
        ENone = 0 
    FNameEntry* {.importcpp.} = object
    FNameEntryId* {.importcpp.} = object

proc fromUnstableInt*(unstableInt: uint32): FNameEntryId {.importcpp:"FNameEntryId::FromUnstableInt(#)".} 
proc toUnstableInt*(entryId: FNameEntryId): uint32 {.importcpp:"#.ToUnstableInt()".}

proc getEntry*(id: FNameEntryId): ptr FNameEntry {.importcpp:"const_cast<'0>(FName::GetEntry(#))"}
proc getPlainNameString*(entry: ptr FNameEntry): FString {.importcpp:"#->GetPlainNameString()"}
proc getDisplayIndex*(name: FName): FNameEntryId {.importcpp:"#.GetDisplayIndex()".}


proc makeFName*(str: FString) : FName {. importcpp: "FName(#) " constructor.}
proc makeFName(name: EName) : FName {. importcpp: "FName(#) " constructor.}
proc makeFName*(val: int): FName = 
  let entry = fromUnstableInt(val.uint32).getEntry()
  makeFName getPlainNameString(entry)

converter toInt*(name: FName): int = #it's a converter so we dont have to import unnecessery stuff in the vm as it is FName = int
  let entry = getDisplayIndex(name)
  toUnstableInt(entry).int

proc n*(str:FString) : FName {. inline .} = makeFName(str)
proc toFString*(name : FName) : FString {. importcpp: "#.ToString()".}

converter ENameToFName*(ename:EName) : FName = makeFName ename       

proc getNumber*(name : FName) : int32 {. importcpp: "#.GetNumber()".}

proc `$`*(name:FName) : string = $name.toFString()


proc hash*(name: FName): Hash = name.getNumber()
include ../../definitions

import system/[widestrs]
import array

type
  TChar {.importcpp: "TCHAR", nodecl .} = object
  FString* {. exportc, importcpp, nodecl, header: ueIncludes, bycopy.} = object

# when defined(macosx):
#   proc `=destroy`(dst: var FString) = discard
#   type Test = openArray[FString]
#   proc `=destroy`(dst: var Test) = discard

func getCharArray(fstr : FString) : TArray[TChar] {. importcpp: "#.GetCharArray()" .}

func makeFString*(fstr : FString) : FString {.importcpp: "'0'(#)", constructor .}

func makeFString(cstr : WideCString) : FString {.importcpp: "'0(reinterpret_cast<TCHAR*>(#))", constructor .}

func f*(str :string) : FString {.inline.} = 
  {.cast(noSideEffect).}:
    makeFString(newWideCString(str))

func `$`*(fstr: FString): string {.inline.} = 
  if fstr.getCharArray().num() == 0: ""
  else: $cast[WideCString](fstr.getCharArray().getData())

func append*(a, b: FString): FString {.importcpp: "#.Append(#)".}

func equals*(a, b: FString): bool {.importcpp: "#.Equals(#)".}

converter toStr*(fstr :Fstring) : string {.inline.} = $ fstr
converter toFStr*(str :string) : FString {.inline.} = f str 

func `==`*(a, b: FString): bool = a.equals(b)
func `==`*(a:string, b: FString): bool = a.equals(b)
func `==`*(a:FString, b: string): bool = a.equals(b)


func `&`*(a, b: FString): FString = a.append(b)
func `&`*(a:string, b: FString): FString = a.toFStr().append(b)
func `&`*(a:FString, b: string): FString = a.append(b)

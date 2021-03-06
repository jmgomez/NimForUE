include ../../definitions



type
  FString* {. exportc, importcpp, header: ueIncludes, bycopy.} = object

proc makeFString*(cstr : cstring) : FString {.importcpp: "'0(ANSI_TO_TCHAR(#))", constructor,  noSideEffect.}
proc makeFString*(fstr : FString) : FString {.importcpp: "'0'(#)", constructor,  noSideEffect.}
proc toCString*(fstr: FString): cstring {.importcpp: " TCHAR_TO_ANSI(*#)", nodecl, noSideEffect.}

proc `$`*(fstr: FString): string = $ fstr.toCString

proc append*(a, b: FString): FString {.importcpp: "#.Append(#)", noSideEffect.}
proc equals*(a, b: FString): bool {.importcpp: "#.Equals(#)", noSideEffect.}

proc fStringToString*(fstr :FString) : string = $ fstr
proc stringToFString*(str :string) : FString = 
  let cstr : cstring = str
  makeFString(cstr)



#TODO should we be explicit about fstrings?

converter toStr*(fstr :Fstring) : string = $ fstr
converter toFStr*(str :string) : FString =  stringToFString(str)

proc `==`*(a, b: FString): bool = a.equals(b)
proc `==`*(a:string, b: FString): bool = a.equals(b)
proc `==`*(a:FString, b: string): bool = a.equals(b)

include ../../definitions



type
  FString* {. exportc, importcpp, bycopy.} = object

proc makeFString*(cstr : cstring) : FString {.importcpp: "FString(ANSI_TO_TCHAR(#))" noSideEffect.}
proc toCString*(fstr: FString): cstring {.importcpp: " TCHAR_TO_ANSI(*#)", nodecl, noSideEffect.}

proc `$`*(fstr: FString): string = $ fstr.toCString

proc append*(a, b: FString): FString {.importcpp: "#.Append(#)", noSideEffect.}
proc equals*(a, b: FString): bool {.importcpp: "#.Equals(#)", noSideEffect.}

proc fStringToString*(fstr :FString) : string = $ fstr
proc stringToFString*(str :string) : FString = makeFString(str.cstring)



#TODO should we be explicit about fstrings?

proc `==`*(a, b: FString): bool = a.equals(b)

converter toStr*(fstr :Fstring) : string = $ fstr
converter toFStr*(str :string) : FString =  stringToFString(str)
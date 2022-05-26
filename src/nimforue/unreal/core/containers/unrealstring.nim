{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "CoreMinimal.h"
""".}

type
  FString* {. exportc, header: "Containers/UnrealString.h", importcpp: "FString", bycopy.} = object


proc makeFString*(cstr : cstring) : FString {.importcpp: "FString(ANSI_TO_TCHAR(#))" noSideEffect.}
proc toCString*(fstr: FString): cstring {.importcpp: " TCHAR_TO_ANSI(*#)", nodecl, noSideEffect.}

proc `$`*(fstr: FString): string = $ fstr.toCString

proc fStringToString*(fstr :FString) : string = $ fstr
proc stringToFString*(str :string) : FString = makeFString(str.cstring)




#TODO should we be explicit about fstrings?
converter toStr*(fstr :Fstring) : string = $ fstr
converter toFStr*(str :string) : FString =  stringToFString(str)
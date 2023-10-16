

#inline T* FindObject( UObject* Outer, const TCHAR* Name, bool ExactClass=false )
import uobject
import nametypes
import ../core/containers/[unrealstring]

import uobject

type 
    FStaticConstructObjectParameters* {.importcpp.} = object
        class* {.importcpp:"Class".}: UClassPtr
        outer* {.importcpp:"Outer".}: UObjectPtr
        name* {.importcpp:"Name".}: FName
        setFlags* {.importcpp:"SetFlags".} : EObjectFlags
        Template* {.importcpp:"Template".}: UObjectPtr
        


proc findObject*[T](outer : UObjectPtr, name : FString): ptr T {.importcpp:"FindObject<'*0>(#, *#)".}

proc makeFStaticConstructObjectParameters*(class : UClassPtr): FStaticConstructObjectParameters {.importcpp:"FStaticConstructObjectParameters(#)", constructor.}

proc makeUniqueObjectName*(outer : UObjectPtr, class : UClassPtr, inbaseName : FName = EName.ENone) : FName {.importcpp:"MakeUniqueObjectName(@)".}

proc loadObject*[T : UObject](outer : UObjectPtr, name : FString, filename : FString = "", loadFlags : uint32 = 0) : ptr T {.importcpp:"LoadObject<'*0>(#, *#, *#, @)".}


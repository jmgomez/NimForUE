

#inline T* FindObject( UObject* Outer, const TCHAR* Name, bool ExactClass=false )
import uobject
import nametypes
import ../core/containers/[unrealstring]

import uobject

type 
    FStaticConstructObjectParameters* {.importcpp.} = object
 # /** The class of the object to create */
        Class* : UClassPtr

        #/** The object to create this object within (the Outer property for the new object will be set to the value specified here). */
        Outer* : UObjectPtr
        #/** The name to give the new object.If no value(NAME_None) is specified, the object will be given a unique name in the form of ClassName_#. */
        Name* : FName

        #/** The ObjectFlags to assign to the new object. some flags can affect the behavior of constructing the object. */
        SetFlags* : EObjectFlags

proc findObject*[T](outer : UObjectPtr, name : FString) : ptr T {.importcpp:"FindObject<'*0>(#, *#)".}

proc makeFStaticConstructObjectParameters*(class : UClassPtr) : FStaticConstructObjectParameters {.importcpp:"FStaticConstructObjectParameters(#)", constructor.}
# proc makeFStaticConstructObjectParameters*(outer : UObjectPtr,class : UClassPtr, name : FName, flags : EObjectFlags) :  FStaticConstructObjectParameters {.inline.} =
#     var params = makeFStaticConstructObjectParameters(class)
#     params.Outer = outer
#     params.Name = name
#     params.SetFlags = flags
#     params


proc makeUniqueObjectName*(outer : UObjectPtr, class : UClassPtr, inbaseName : FName = EName.ENone) : FName {.importcpp:"MakeUniqueObjectName(@)".}

#inline T* LoadObject( UObject* Outer, const TCHAR* Name, const TCHAR* Filename=nullptr, uint32 LoadFlags=LOAD_None, UPackageMap* Sandbox=nullptr, const FLinkerInstancingContext* InstancingContext=nullptr )
#TODO bind ELoadFlags

proc loadObject*[T : UObject](outer : UObjectPtr, name : FString, filename : FString = "", loadFlags : uint32 = 0) : ptr T {.importcpp:"LoadObject<'*0>(#, *#, *#, @)".}


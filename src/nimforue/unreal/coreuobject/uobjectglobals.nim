

#inline T* FindObject( UObject* Outer, const TCHAR* Name, bool ExactClass=false )
import uobject
import ../core/containers/[unrealstring]



proc findObject*[T](outer : UObjectPtr, name : FString) : ptr T {.importcpp:"FindObject<'*0>(#, *#)".}
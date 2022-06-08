
import ../Core/Containers/unrealstring

{.push header: "UObject/UnrealType.h" .}

type 
    FProperty* {. importcpp .} = object
    FPropertyPtr* = ptr FProperty


{.pop.}


#Notice the method lives in FField. Not sure if we will need to export it when doing the autogen
proc getName*(prop:FPropertyPtr) : FString {. importcpp:"#->GetName()" .}
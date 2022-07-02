import uobject
import ../core/containers/[unrealstring]
type 

    UPackage* {.importcpp.} = object of UObject
    UPackagePtr* = ptr UPackage




#ConvertToLongScriptPackageName
# * Helper function for converting short to long script package name (InputCore -> /Script/InputCore)
proc convertToLongScriptPackageName*(inShortName:FString) : FString {.importcpp:"FPackageName::ConvertToLongScriptPackageName(*#)".}
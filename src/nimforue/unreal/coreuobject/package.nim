include ../definitions
import uobject
import ../core/containers/[unrealstring]
type 

    UPackage* {.importcpp, header: ueIncludes  } = object of UObject
    UPackagePtr* = ptr UPackage


func anyPackage*() : UPackagePtr {.importcpp:"(ANY_PACKAGE)".}

#ConvertToLongScriptPackageName
# * Helper function for converting short to long script package name (InputCore -> /Script/InputCore)
proc convertToLongScriptPackageName*(inShortName:FString) : FString {.importcpp:"FPackageName::ConvertToLongScriptPackageName(*#)".}
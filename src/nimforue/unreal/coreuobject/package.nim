include ../definitions
import uobject
import uobjectglobals
import std/[options, strutils]
import ../../utils/utils

import ../core/containers/[unrealstring]
type 

    UPackage* {. importcpp, header: ueIncludes  } = object of UObject
    UPackagePtr* = ptr UPackage

func anyPackage*() : UPackagePtr {.importcpp:"(ANY_PACKAGE)".}
func getTransientPackage*() : UPackagePtr {.importcpp:"GetTransientPackage()".}

#ConvertToLongScriptPackageName
# * Helper function for converting short to long script package name (InputCore -> /Script/InputCore)
proc convertToLongScriptPackageName*(inShortName:FString) : FString {.importcpp:"FPackageName::ConvertToLongScriptPackageName(*#)".}


func getPackageByName*(packageShortName:FString) : UPackagePtr = 
        findObject[UPackage](nil, convertToLongScriptPackageName(packageShortName))

func tryGetPackageByName*(packageName:FString) : Option[UPackagePtr] = 
    someNil(getPackageByName(packageName))

# let nimPackage* = getPackageByName("Nim")


func getShortName*(pkg:UPackagePtr) : FString = pkg.getName().split("/")[^1]
#this belongs to uobject but it's here due to the UPackage dependency
proc getPackage*(obj : UObjectPtr) : UPackagePtr {. importcpp: "#->GetPackage()" .}

proc getModuleName*(obj : UObjectPtr) : FString = obj.getPackage().getShortName()



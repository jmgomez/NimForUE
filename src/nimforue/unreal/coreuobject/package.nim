include ../definitions
import uobject
import uobjectglobals
import std/[options, strutils]
import ../../utils/utils

import ../core/containers/[unrealstring]
type 
  UPackage* {. importcpp  } = object of UObject
  UPackagePtr* = ptr UPackage
  FSavePackageArgs* {.importcpp.} = object
      topLevelFlags* {.importcpp:"TopLevelFlags".}: EObjectFlags
      saveFlags* {.importcpp:"SaveFlags".}: ESaveFlags
      bForceByteSwapping*: bool
  ESaveFlags* {.importcpp.} = enum
    SAVE_NoError = 0x00000000
    SAVE_Error = 0x00000001
    SAVE_FromAutosave = 0x00000002
    SAVE_KeepDirty = 0x00000004

func anyPackage*() : UPackagePtr {.importcpp:"(ANY_PACKAGE)".}
func getTransientPackage*() : UPackagePtr {.importcpp:"GetTransientPackage()".}

func hasAnyPackageFlags*(pkg:UPackagePtr): bool {.importcpp:"#->HasAnyPackageFlags(#)".}
func isEditorOnly*(pkg:UPackagePtr): bool {.importcpp:"#->HasAnyPackageFlags(PKG_EditorOnly)".}

#ConvertToLongScriptPackageName
# * Helper function for converting short to long script package name (InputCore -> /Script/InputCore)
proc convertToLongScriptPackageName*(inShortName:FString) : FString {.importcpp:"FPackageName::ConvertToLongScriptPackageName(*#)".}

proc longPackageNameToFilename*(inLongPackageName:FString, inExtension: FString = "") : FString {.importcpp:"FPackageName::LongPackageNameToFilename(*#, *#)".}

proc getAssetPackageExtension*() : FString {.importcpp:"FPackageName::GetAssetPackageExtension()".}

func getPackageByName*(packageShortName:FString) : UPackagePtr = 
        findObject[UPackage](nil, convertToLongScriptPackageName(packageShortName))

func tryGetPackageByName*(packageName:FString) : Option[UPackagePtr] = 
    someNil(getPackageByName(packageName))

proc createPackage*(packagePath: FString) : UPackagePtr {.importcpp: "CreatePackage(*#)".}
proc fullyLoad*(pkg: UPackagePtr) {.importcpp: "#->FullyLoad()".}
proc markPackageDirty*(pkg: UObjectPtr) {.importcpp: "#->MarkPackageDirty()".}
proc setDirtyFlag*(pkg: UPackagePtr, dirty: bool) {.importcpp: "#->SetDirtyFlag(#)".}


func getShortName*(pkg:UPackagePtr): FString = pkg.getName().split("/")[^1]
#this belongs to uobject but it's here due to the UPackage dependency
proc getPackage*(obj : UObjectPtr) : UPackagePtr {. importcpp: "#->GetPackage()" .}
proc getOutermost*(obj: UObjectPtr): UPackagePtr {.importcpp: "#->GetOutermost()" .}

proc getModuleName*(obj : UObjectPtr): FString = obj.getPackage().getShortName()

func getUETypeByName*[T : UObject](pkg:UPackagePtr, name:FString) : ptr T = 
    let fullName = pkg.getName() & "." & name
    findObject[T](pkg, fullName)

func tryGetUETypeByName*[T : UObject](pkg:UPackagePtr, name:FString) : Option[ptr T] = 
    someNil(getUETypeByName[T](pkg, name))

func setModuleRelativePath*(pkg:UPackagePtr, obj: UObjectPtr, path: FString) {.importcpp:"#->GetMetaData()->SetValue(#, TEXT(\"ModuleRelativePath\"), *#)".}

proc savePackage*(pkg: UPackagePtr, obj: UObjectPtr, packageFileName: FString, saveArgs: FSavePackageArgs): bool {.importcpp: "UPackage::SavePackage(#, #, *#, #)".}

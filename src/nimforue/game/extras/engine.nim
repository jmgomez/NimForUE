
include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter]
import ../codegen/[gencppclass]

import engine/[engine, common, gameframework]



#DATATABLE


proc emptyTable*(self : UDataTablePtr) {.importcpp: "#->EmptyTable()".}
proc getRowNames*(self : UDataTablePtr) : TArray[FName] {.importcpp: "#->GetRowNames()".}
proc removeRow*(self : UDataTablePtr, rowName : FName) {.importcpp: "#->RemoveRow(#)".}
proc addRow*(self : UDataTablePtr, rowName : FName, rowData : FTableRowBase) {.importcpp: "#->AddRow(@)".}
#FString UDataTable::GetTableAsJSON(const EDataTableExportFlags InDTExportFlags) const
proc getTableAsJson*(self : UDataTablePtr) : FString {.importcpp: "#->GetTableAsJSON()".}



#Meshes

proc setMaterial*(self : UStaticMeshComponentPtr, elementIndex : int32, material : UMaterialInterfacePtr) {.importcpp: "#->SetMaterial(#, #)".}
proc setMaterialByName*(self : UStaticMeshComponentPtr, materialSlotName : FName, material : UMaterialInterfacePtr) {.importcpp: "#->SetMaterialByName(#, #)".}
proc getNumMaterials*(self : UStaticMeshComponentPtr) : int32 {.importcpp: "#->GetNumMaterials()".}
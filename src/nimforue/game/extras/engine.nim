
include ../unreal/prelude
import ../unreal/core/containers/containers
import ../codegen/[ueemit, emitter]
# import ../codegen/[gencppclass]

import engine/common
import engine/gameframework
import engine/engine



#DATATABLE


proc emptyTable*(self : UDataTablePtr) {.importcpp: "#->EmptyTable()".}
proc getRowNames*(self : UDataTablePtr) : TArray[FName] {.importcpp: "#->GetRowNames()".}
proc removeRow*(self : UDataTablePtr, rowName : FName) {.importcpp: "#->RemoveRow(#)".}
proc addRow*(self : UDataTablePtr, rowName : FName, rowData : FTableRowBase) {.importcpp: "#->AddRow(@)".}
#FString UDataTable::GetTableAsJSON(const EDataTableExportFlags InDTExportFlags) const
proc getTableAsJson*(self : UDataTablePtr) : FString {.importcpp: "#->GetTableAsJSON()".}
#pragma once


struct FNimHotReload {
	TMap<UScriptStruct*, UScriptStruct*> StructsToReinstance = {};
	TMap<UClass*, UClass*> ClassesToReinstance = {};
	bool bShouldHotReload;
};

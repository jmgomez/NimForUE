#pragma once


struct FNimHotReload {
	TMap<UScriptStruct*, UScriptStruct*> StructsToReinstance = {};
	TMap<UClass*, UClass*> ClassesToReinstance = {};
	TMap<UDelegateFunction*, UDelegateFunction*> DelegatesToReinstance = {}; //This is just for updating blueprint nodes
	bool bShouldHotReload;
};

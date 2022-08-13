#pragma once


struct FNimHotReload {
	TMap<UScriptStruct*, UScriptStruct*> StructsToReinstance = {};
	TMap<UClass*, UClass*> ClassesToReinstance = {};
	TMap<UDelegateFunction*, UDelegateFunction*> DelegatesToReinstance = {}; //This is just for updating blueprint nodes
	TMap<UEnum*, UEnum*> EnumsToReinstance = {};
	//These should be Sets but it isnt bind yet. TODO to change once they bind
	TArray<UScriptStruct*> NewStructs = {};
	TArray<UClass*> NewClasses = {};
	TArray<UDelegateFunction*> NewDelegateFunctions = {};
	TArray<UEnum*> NewEnums = {};
	TArray<UScriptStruct*> DeletedStructs = {};
	TArray<UClass*> DeletedClasses = {};
	TArray<UDelegateFunction*> DeletedDelegateFunctions = {};
	TArray<UEnum*> DeletedEnums = {};
	
	bool bShouldHotReload;

	
};

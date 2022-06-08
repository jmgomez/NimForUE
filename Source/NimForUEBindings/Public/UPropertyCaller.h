#pragma once


static void* GetFPropertyValue(FProperty* Property,  void* Container) {
	void* ToReturn = nullptr;
	if(FStrProperty* StrProperty = CastField<FStrProperty>(Property)) {
		return StrProperty->GetPropertyValuePtr_InContainer(Container);
	}
	if(FIntProperty* IntProperty = CastField<FIntProperty>(Property)) {
		return IntProperty->GetPropertyValuePtr_InContainer(Container);
	}
	if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Property)) {
		return FloatProperty->GetPropertyValuePtr_InContainer(Container);
	}
	// if(FBoolProperty* BoolProperty = CastField<FBoolProperty>(Property)) {
	// 	bool Value = BoolProperty->GetPropertyValue_InContainer(Container);
	// 	bool* ReturnResultBool = (bool*) ReturnResult;
	// 	*ReturnResultBool = Value;
	// 	return;
	// }
	
	if(FArrayProperty* ArrayProp = CastField<FArrayProperty>(Property)) {
		return ArrayProp->GetPropertyValuePtr_InContainer(Container);
	}

	if(FObjectProperty* ObjProp = CastField<FObjectProperty>(Property)) {
		return ObjProp->GetPropertyValuePtr_InContainer(Container);
	}
	return nullptr;
	//
	// if(ToReturn != nullptr)
	// 	FMemory::Memcpy(ReturnResult, ToReturn, Property->GetSize());
	// FMemory::Memmove(ReturnResult, ToReturn, Property->GetSize());
}

static void SetFPropertyValue(FProperty* Property,  void* Container, void* ValuePtr) {
	if(FStrProperty* StrProperty = CastField<FStrProperty>(Property)) {
		FString* StrVal = static_cast<FString*>(ValuePtr);
		StrProperty->SetPropertyValue_InContainer(Container, *StrVal);
	}
	
	if(FIntProperty* IntProperty = CastField<FIntProperty>(Property)) {
		int32* IntVal = static_cast<int32*>(ValuePtr);
		return IntProperty->SetPropertyValue_InContainer(Container, *IntVal);
	}
	
	// if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Property)) {
	// 	return FloatProperty->GetPropertyValuePtr_InContainer(Container);
	// }
	// // if(FBoolProperty* BoolProperty = CastField<FBoolProperty>(Property)) {
	// // 	bool Value = BoolProperty->GetPropertyValue_InContainer(Container);
	// // 	bool* ReturnResultBool = (bool*) ReturnResult;
	// // 	*ReturnResultBool = Value;
	// // 	return;
	// // }
	//
	// if(FArrayProperty* ArrayProp = CastField<FArrayProperty>(Property)) {
	// 	return ArrayProp->GetPropertyValuePtr_InContainer(Container);
	// }
	//
	// if(FObjectProperty* ObjProp = CastField<FObjectProperty>(Property)) {
	// 	return ObjProp->GetPropertyValuePtr_InContainer(Container);
	// }
	// return nullptr;
	//
	// if(ToReturn != nullptr)
	// 	FMemory::Memcpy(ReturnResult, ToReturn, Property->GetSize());
	// FMemory::Memmove(ReturnResult, ToReturn, Property->GetSize());
}

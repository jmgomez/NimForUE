#pragma once



template<typename T>
static void* GetPropertyValuePtr(FProperty* Property, void* Container) {
	return (Property->ContainerPtrToValuePtr<T>(Container));
}
static void* GetFPropertyValue(FProperty* Property,  void* Container) {
	void* ToReturn = nullptr;
	if(FStrProperty* StrProperty = CastField<FStrProperty>(Property)) {
		return GetPropertyValuePtr<FString>(Property, Container);
		// return StrProperty->GetPropertyValuePtr_InContainer(Container);
		return nullptr;
	}
	if(FIntProperty* IntProperty = CastField<FIntProperty>(Property)) {
		return GetPropertyValuePtr<int>(Property, Container);
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



//
// static void SetPropertyValuePtr<void>(FProperty* Property, void* Container, void* ValuePtr) {
// 	// *Property->ContainerPtrToValuePtr<T>(Container) = *ValuePtr;
// }
template<typename T>
static void SetPropertyValuePtr(FProperty* Property, void* Container, T* ValuePtr) {
	// if constexpr(std::is_same<T, void>::value) return;
	TProperty<T, FProperty>* Prop = reinterpret_cast<TProperty<T, FProperty>*>(Property);
	Prop->SetPropertyValue_InContainer(Container, *ValuePtr);
	
}

static void SetPropertyValuePtr(FProperty* Property, void* Container, void* ValuePtr) {
	
	
}


static void SetFPropertyValue(FProperty* Property,  void* Container, void* ValuePtr) {
	if(FStrProperty* StrProperty = CastField<FStrProperty>(Property)) {
		// SetPropertyValuePtr<FString>(Property, Container, ValuePtr);
		// return;
		FString* StrVal = static_cast<FString*>(ValuePtr);
		// StrProperty->SetPropertyValue_InContainer(Container, *StrVal);
		SetPropertyValuePtr<FString>(Property, Container, StrVal);
	}
	//
	if(FIntProperty* IntProperty = CastField<FIntProperty>(Property)) {
		// SetPropertyValuePtr<int32>(Property, Container, ValuePtr);
		//
		int32* IntVal = static_cast<int32*>(ValuePtr);
		return IntProperty->SetPropertyValue_InContainer(Container, *IntVal);
	}
	//
	// if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Property)) {
	// 	return FloatProperty->GetPropertyValuePtr_InContainer(Container);
	// }
	// if(FBoolProperty* BoolProperty = CastField<FBoolProperty>(Property)) {
	// 	bool Value = BoolProperty->GetPropertyValue_InContainer(Container);
	// 	bool* ReturnResultBool = (bool*) ReturnResult;
	// 	*ReturnResultBool = Value;
	// 	return;
	// }
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
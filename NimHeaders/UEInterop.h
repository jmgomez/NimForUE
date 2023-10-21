#pragma once
template<typename T>
static T* GetPropertyValuePtr(FProperty* Property, void* Container) {
	if (Property == nullptr) return nullptr;
	return (Property->ContainerPtrToValuePtr<T>(Container));
};

template<typename T>
static void SetPropertyValuePtr(FProperty* Property, void* Container, T* ValuePtr) {	
	TProperty<T, FProperty>* Prop = reinterpret_cast<TProperty<T, FProperty>*>(Property);
	Prop->SetPropertyValue_InContainer(Container, *ValuePtr);
	
};
template<typename T>
static void SetPropertyValue(FProperty* Property, void* Container, T ValuePtr) {	
	TProperty<T, FProperty>* Prop = reinterpret_cast<TProperty<T, FProperty>*>(Property);
	Prop->SetPropertyValue_InContainer(Container, ValuePtr);
	
};
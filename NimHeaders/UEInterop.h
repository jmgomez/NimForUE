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

template <typename PropertyBaseClass>
class TPropertyWithSetterAndGetterNim : public PropertyBaseClass //This needs to be in sync with TPropertyWithSetterAndGetter
{
public:
	TPropertyWithSetterAndGetterNim(FFieldVariant InOwner, FName PropName, EObjectFlags ObjFlags)
		: PropertyBaseClass(InOwner, PropName, ObjFlags)
	{
	}

	virtual bool HasSetter() const override
	{
		return !!SetterFunc;
	}

	virtual bool HasGetter() const override
	{
		return !!GetterFunc;
	}

	virtual bool HasSetterOrGetter() const override
	{
		return !!SetterFunc || !!GetterFunc;
	}

	virtual void CallSetter(void* Container, const void* InValue) const override
	{
		// checkf(SetterFunc, TEXT("Calling a setter on %s but the property has no setter defined."), *PropertyBaseClass::GetFullName());
		if (HasSetter())
			SetterFunc(Container, InValue);
	}

	virtual void CallGetter(const void* Container, void* OutValue) const override
	{
		// checkf(GetterFunc, TEXT("Calling a getter on %s but the property has no getter defined."), *PropertyBaseClass::GetFullName());
		if (HasGetter())
			GetterFunc(Container, OutValue);
	}
	void SetSetterFunc(SetterFuncPtr InSetterFunc)
	{
		SetterFunc = InSetterFunc;
	}
	void SayHello()
	{
		UE_LOG(LogTemp, Warning, TEXT("Hello from TPropertyWithSetterAndGetterNim. The name is `%s`"), *PropertyBaseClass::GetFullName());
		UE_LOG(LogTemp, Warning, TEXT("(update)This name is `%s`"), *this->GetName());
	}

	SetterFuncPtr SetterFunc = nullptr;
	GetterFuncPtr GetterFunc = nullptr;
};

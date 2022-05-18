#pragma once


static void FPropertyGetter(FProperty* Property, void* ReturnResult, void* Container) {
	void* ToReturn = nullptr;
	if(FStrProperty* StrProperty = CastField<FStrProperty>(Property)) {
		ToReturn = StrProperty->GetPropertyValuePtr_InContainer(Container);

	}
	if(FIntProperty* IntProperty = CastField<FIntProperty>(Property)) {
		ToReturn = IntProperty->GetPropertyValuePtr_InContainer(Container);
	}
	if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Property)) {
		ToReturn = FloatProperty->GetPropertyValuePtr_InContainer(Container);
	}
	
	if(FObjectProperty* ObjProp = CastField<FObjectProperty>(Property)) {
		ToReturn = ObjProp->GetPropertyValuePtr_InContainer(Container);
	}

	if(ToReturn != nullptr)
		FMemory::Memcpy(ReturnResult, ToReturn, Property->GetSize());
		// FMemory::Memmove(ReturnResult, ToReturn, Property->GetSize());
}



class UFunctionCaller {
	uint8* Params;
	UFunction* Function;
	//This gets init in the Function call
	uint8* MemoryFrame;
public:
	static void NimForUELog(FString& Msg) {
		UE_LOG(LogTemp, Log, TEXT("From Nim: %s"), *Msg);
	}
	static void CallUFunctionOn(UObject* Executor, FString& FunctionName, void* InParams, void* ReturnResult) {
		UFunctionCaller(Executor->GetClass(), FunctionName, InParams).Invoke(Executor, ReturnResult);
	}
	UFunctionCaller(UFunction* InFunction, void* InParams) {
		Function = InFunction;
		Params = (uint8*)InParams;
	}
	UFunctionCaller(UClass* Class, FString &FunctionName, void* InParams) {
		FunctionName.TrimToNullTerminator();
		Function = Class->FindFunctionByName(FName(FunctionName));
		checkf(Function, TEXT("Cant find function %s in class %s"), *FunctionName, *Class->GetName());
		Params = (uint8*)InParams;
	}
	
	void Invoke(UObject* Executor, void* ReturnResult = nullptr) {
		MemoryFrame = (uint8*)FMemory_Alloca(Function->ParmsSize);
		//Params expect to be in cont memory (struct1, struct2,...)
		FMemory::Memcpy(MemoryFrame, &Params, Function->ParmsSize);
		
		//Initialize any local struct properties with the params
		for (TFieldIterator<FProperty> It(Function); It; ++It){
			FProperty* Prop = *It;
			if(Prop == nullptr) {
				UE_LOG(LogTemp, Error, TEXT("The property is null. This is probably due to the params sent from nim"));
				continue;
			}
			Prop->InitializeValue_InContainer(MemoryFrame); 
			if(Prop->HasAnyPropertyFlags(CPF_Parm) && !Prop->HasAnyPropertyFlags(CPF_ReturnParm | CPF_OutParm)) {
				if(FStrProperty* StrProperty = CastField<FStrProperty>(Prop)) {
					FString* Value = StrProperty->GetPropertyValuePtr_InContainer(Params);
					StrProperty->SetPropertyValue_InContainer(MemoryFrame, *Value);
				}
				if(FIntProperty* IntProperty = CastField<FIntProperty>(Prop)) {
					int* Value = IntProperty->GetPropertyValuePtr_InContainer(Params);
					IntProperty->SetPropertyValue_InContainer(MemoryFrame, *Value);
				}
				if(FFloatProperty* FloatProperty = CastField<FFloatProperty>(Prop)) {
					float* Value = FloatProperty->GetPropertyValuePtr_InContainer(Params);
					FloatProperty->SetPropertyValue_InContainer(MemoryFrame, *Value);
				}
				
				if(FObjectProperty* ObjProp = CastField<FObjectProperty>(Prop)) {
					if(Function->NumParms == 1) {
						ObjProp->SetObjectPropertyValue_InContainer(MemoryFrame, (UObject*)Params);
						continue;
					}
					UObject* Value = ObjProp->GetObjectPropertyValue_InContainer(Params);
					ObjProp->SetObjectPropertyValue_InContainer(MemoryFrame, Value);
				}
			}
		}

		Executor->ProcessEvent( Function, MemoryFrame );

		// // destruct properties on the stack, except for out params since we know we didn't use that memory
		for (TFieldIterator<FProperty> It(Function); It; ++It){
			FProperty* Destruct = *It;
			if (!Destruct->HasAnyPropertyFlags(CPF_OutParm | CPF_ReturnParm)){
				 Destruct->DestroyValue_InContainer(MemoryFrame);
			}
		}

		for (TFieldIterator<FProperty> It(Function); It; ++It) {
			FProperty* OutProp = *It;
			if (OutProp->HasAnyPropertyFlags(CPF_OutParm) & !OutProp->HasAnyPropertyFlags(CPF_ReturnParm)) {
				if(FStrProperty* StrProperty = CastField<FStrProperty>(OutProp)) {
					FString Value = *StrProperty->GetPropertyValuePtr_InContainer(MemoryFrame);
					StrProperty->SetPropertyValue_InContainer(Params, Value);
				}
				
			}
		}

		FProperty* ReturnProp = Function->GetReturnProperty();
		if(ReturnProp) {
			FPropertyGetter(ReturnProp, ReturnResult, MemoryFrame);
			
		}
	}


};


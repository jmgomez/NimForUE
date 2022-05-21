#pragma once

#include "BindObjectTest.generated.h"

UCLASS()
class NIMFORUEBINDINGS_API UBindObjectTest : public UObject {
	GENERATED_BODY()
public:
	UFUNCTION()
	static FString GetHelloTestStaticFunction();

	static UBindObjectTest* NewBindObject();
	
};

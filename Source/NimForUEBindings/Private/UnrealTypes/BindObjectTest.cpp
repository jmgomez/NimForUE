#include "UnrealTypes/BindObjectTest.h"

FString UBindObjectTest::GetHelloTestStaticFunction() {
	return "Hello from C++";
}

UBindObjectTest* UBindObjectTest::NewBindObject() {
	return NewObject<UBindObjectTest>();
}

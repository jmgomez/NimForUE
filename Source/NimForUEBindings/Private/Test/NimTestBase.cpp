#include "Test/NimTestBase.h"

void FNimTestBase::UnregisterAll(bool bShouldUnregisterOnly) {
	for(FString TestName : AllRegisteredNimTests) {
		if(bShouldUnregisterOnly || TestName != OnlyExecute) {
			FAutomationTestFramework::Get().UnregisterAutomationTest(TestName);
		}
	}
	if(bShouldUnregisterOnly) {
		OnlyExecute = "";
	}
}

void FNimTestBase::ReloadTest(bool bIsOnly) {
	if(bIsOnly) {
		UnregisterAll(false);
		OnlyExecute = TestName;
		
	}
	
	if(!bIsOnly && OnlyExecute != "") //If it isnt only and there is already an only to be registered, returns. 
		return;
	
	FAutomationTestFramework::Get().UnregisterAutomationTest(TestName);
	FAutomationTestFramework::Get().RegisterAutomationTest(TestName, this );
	AllRegisteredNimTests.AddUnique(TestName);
	
}

{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UObject/UnrealType.h"
#include "Misc/AutomationTest.h"

#include <typeinfo>
""".}



{.emit:"""



static const uint32 TestFlags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::SmokeFilter;

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldTestFromNim2, "NimForUETest2.ShouldTestFromNim2", TestFlags)
bool ShouldTestFromNim2::RunTest(const FString& Parameters) {
	TestTrue("It's the same", true);
	return true;

};

IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldTestFromNim3, "NimForUETest2.ShouldTestFromNim3", TestFlags)
bool ShouldTestFromNim3::RunTest(const FString& Parameters) {
	TestTrue("It's the same", true);
	return true;

};

void Whatever(){
FAutomationTestFramework::Get().UnregisterAutomationTest( "ShouldTestFromNim3" );
FAutomationTestFramework::Get().RegisterAutomationTest( "ShouldTestFromNim3", &ShouldTestFromNim3AutomationTestInstance );
UE_LOG(LogTemp, Warning, TEXT("Whatever called! test registered again"));
}
//;

""".}



proc hello*() = echo "hello"


# IMPLEMENT_SIMPLE_AUTOMATION_TEST(ShouldTestFromNim2, "NimForUETest2.ShouldTestFromNim2", TestFlags)
# bool ShouldTestFromNim2::RunTest(const FString& Parameters) {
# 	TestTrue("It's the same", true);
# 	return true;

# };

proc whatever() : void {.importcpp:"Whatever".}

whatever();

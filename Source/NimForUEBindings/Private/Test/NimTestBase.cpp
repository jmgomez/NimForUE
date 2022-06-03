#include "Test/NimTestBase.h"



//
// FNimTestBase::~FNimTestBase() {
// 	
// }
//
// FString FNimTestBase::GetTestFullName() const {
// 	return "";
// 	// return FAutomationTestBase::GetTestFullName();
// }
//
// void FNimTestBase::AddError(const FString& InError, int32 StackOffset) {
// 	// FAutomationTestBase::AddError(InError, StackOffset);
// }
//
// void FNimTestBase::AddErrorIfFalse(bool bCondition, const FString& InError, int32 StackOffset) {
// 	// FAutomationTestBase::AddErrorIfFalse(bCondition, InError, StackOffset);
// }
//
// void FNimTestBase::AddErrorS(const FString& InError, const FString& InFilename, int32 InLineNumber) {
// 	// FAutomationTestBase::AddErrorS(InError, InFilename, InLineNumber);
// }
//
// void FNimTestBase::AddWarningS(const FString& InWarning, const FString& InFilename, int32 InLineNumber) {
// 	// FAutomationTestBase::AddWarningS(InWarning, InFilename, InLineNumber);
// }
//
// void FNimTestBase::AddWarning(const FString& InWarning, int32 StackOffset) {
// 	// FAutomationTestBase::AddWarning(InWarning, StackOffset);
// }
//
// void FNimTestBase::AddInfo(const FString& InLogItem, int32 StackOffset) {
// 	// FAutomationTestBase::AddInfo(InLogItem, StackOffset);
// }
//
// void FNimTestBase::AddEvent(const FAutomationEvent& InEvent, int32 StackOffset) {
// 	// FAutomationTestBase::AddEvent(InEvent, StackOffset);
// }
//
// void FNimTestBase::AddAnalyticsItem(const FString& InAnalyticsItem) {
// 	// FAutomationTestBase::AddAnalyticsItem(InAnalyticsItem);
// }
//
// void FNimTestBase::AddTelemetryData(const FString& DataPoint, double Measurement, const FString& Context) {
// 	// FAutomationTestBase::AddTelemetryData(DataPoint, Measurement, Context);
// }
//
// void FNimTestBase::AddTelemetryData(const TMap<FString, double>& ValuePairs, const FString& Context) {
// 	FAutomationTestBase::AddTelemetryData(ValuePairs, Context);
// }
//
// void FNimTestBase::SetTelemetryStorage(const FString& StorageName) {
// 	// FAutomationTestBase::SetTelemetryStorage(StorageName);
// }
//
// bool FNimTestBase::SuppressLogs() {
// 	return false;
// 	// return FAutomationTestBase::SuppressLogs();
// }
//
// bool FNimTestBase::SuppressLogErrors() {
// 	return false;
// 	// return FAutomationTestBase::SuppressLogErrors();
// }
//
// bool FNimTestBase::SuppressLogWarnings() {
// 	return false;
// 	// return FAutomationTestBase::SuppressLogWarnings();
// }
//
// bool FNimTestBase::ElevateLogWarningsToErrors() {
// 	return false;
// 	// return FAutomationTestBase::ElevateLogWarningsToErrors();
// }
//
// FString FNimTestBase::GetTestSourceFileName(const FString& InTestName) const {
// 	return "";
//
// 	// return FAutomationTestBase::GetTestSourceFileName(InTestName);
// }
//
// int32 FNimTestBase::GetTestSourceFileLine(const FString& InTestName) const {
// 	// return FAutomationTestBase::GetTestSourceFileLine(InTestName);
// 	return 0;
// }
//
// FString FNimTestBase::GetTestAssetPath(const FString& Parameter) const {
// 	return "";
//
// 	// return FAutomationTestBase::GetTestAssetPath(Parameter);
// }
//
// FString FNimTestBase::GetTestOpenCommand(const FString& Parameter) const {
// 	return "";
// 	// return FAutomationTestBase::GetTestOpenCommand(Parameter);
// }

// void FNimTestBase::SetTestContext(FString Context) {
// 	// FAutomationTestBase::SetTestContext(Context);
// }
void FNimTestBase::ReloadTest() {
	FAutomationTestFramework::Get().UnregisterAutomationTest(TestName);
	FAutomationTestFramework::Get().RegisterAutomationTest(TestName, this );

}

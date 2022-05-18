#pragma once

#include "Engine.h"
#include "Core.h"

static const uint32 TestFlags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::SmokeFilter;

#define TEST(TestName) \
IMPLEMENT_SIMPLE_AUTOMATION_TEST(TestName, "NimForUE." #TestName, EAutomationTestFlags::EditorContext | EAutomationTestFlags::SmokeFilter \
bool TestName::RunTest(const FString& Parameters) \

import ../unreal/core/containers/unrealstring
import ../unreal/nimforue/nimforuebindings
import macros

{.emit: """/*INCLUDESECTION*/
#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UObject/UnrealType.h"
#include "Misc/AutomationTest.h"
#include "NimBase.h"
#include <typeinfo>
""".}
#TODO remove hooked tests

template ueTest*(name:string, body:untyped) = 
    block:
        var test = makeFNimTestBase(name)
        proc actualTest (test: var FNimTestBase){.cdecl.} =   
            # test.testTrue("whatever", true)
            try:
                body
            except Exception as e:
                let msg = e.msg
                test.testTrue(msg, false)

        test.ActualTest = actualTest
        test.reloadTest()







ueTest "MyTest.Whatever":
    assert len([2]) == 2
ueTest "MyTest.Whatever2":
    assert len([2]) == 1

ueTest "MyTest.AnotherTest":
    assert true


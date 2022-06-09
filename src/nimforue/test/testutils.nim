

template suite* (suitName: static string, body:untyped) = 
    block:
        body
        

#TODO remove hooked tests
template ueTest*(name:string, body:untyped) = 
    block:
        when declared(suiteName):
            var test = makeFNimTestBase(suiteName & "." & name)
        else:
            var test = makeFNimTestBase(name)
        proc actualTest (test: var FNimTestBase){.cdecl.} =   
            try:
                body
            except Exception as e:
                let msg = e.msg
                test.testTrue(msg, false)

        test.ActualTest = actualTest
        test.reloadTest()

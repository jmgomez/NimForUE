
template suite* (name: static string , body:untyped) = 
    when not declared(suiteName):
        var suiteName {.inject.} = name
    else: 
        suiteName = suiteName & "." & name
    body

#TODO remove hooked tests
template ueTest*(name:string, body:untyped) =
    var test = makeFNimTestBase(
        when declared(suiteName):
            suiteName & "." & name
        else: 
            name
        )
    test.ActualTest = proc (test: var FNimTestBase) {.cdecl.} =
        try:
            body
        except Exception as e:
            let msg = e.msg
            test.testTrue(msg, false)
    test.reloadTest()
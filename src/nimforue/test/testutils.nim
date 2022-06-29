import std/[strutils, sequtils, sugar]
import ../utils/utils   

export utils

template suite* (name: string , body:untyped) = 
    block:
        when not declared(suiteName):
            var suiteName {.inject.} = name
        else: 
            suiteName = suiteName & "." & name
        body
    

#TODO remove hooked tests
template internalTest(name:string, isOnly:bool, body:untyped) =
    block:

        let testName =  when declared(suiteName): suiteName & "." & name
                        else: name
        var test = makeFNimTestBase(testName.spacesToCamelCase())
        test.ActualTest = proc (test: var FNimTestBase) {.cdecl.} =
            try:
                body
            except Exception as e:
                let msg = e.msg
                test.testTrue(msg, false)
        test.reloadTest(isOnly)

template ueTest*(name:string, body:untyped) = internalTest(name, false, body)
template ueTestOnly*(name:string, body:untyped) = internalTest(name, true, body)

 


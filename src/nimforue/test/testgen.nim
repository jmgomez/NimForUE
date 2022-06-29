include ../unreal/prelude
import testutils
import testdata
import ../uetypegen
import std/[sequtils]

suite "NimForUE.TypesGen":
    ueTest "Should generate all uprops for a given type":
        #tests that all props in the gen props, matches the manual binding
        let cls = getClassByName("MyClassToTest")
        
        let props = getFPropsFromUStruct(cls).map(toUEField)
        
        assert props.len() == 16#think about something better to test against (the number is fragile, it's the number of uproperties defined in that cpp)

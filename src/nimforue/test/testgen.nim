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





#Add functions bindings to the generation (should be able to use them from the other tests)
    #add the field
    #add the macro that generates it in the form signature (replace uebind)
        # Remove generic check ifeld and get it from the type str.
        # Remove var and get it frmo  a list of types that lives in the function itself 
        # Needs support for static
        # Needs support for var params
        # What else was in uebind that needs to be here?

    #scratchpad the importing function
    #generate the whole class (another test)

    #see what's the best way to have the function outputing to a file (nimscript?)
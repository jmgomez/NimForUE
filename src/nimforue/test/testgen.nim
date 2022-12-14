include ../unreal/prelude
import testutils
import testdata
import ../codegen/[uemeta]
import std/[sequtils, sugar, json, jsonutils]

suite "NimForUE.TypesGen":
    const MyClassToTestNProps = 16
    const MyClassToTestNFuncs = 6
    ueTest "Should generate all uprops for a given type":
        #tests that all props in the gen props, matches the manual binding
        let cls = getClassByName("MyClassToTest")
        
        let props = getFPropsFromUStruct(cls).map(toUEField)
        
        assert props.len() == MyClassToTestNProps#think about something better to test against (the number is fragile, it's the number of uproperties defined in that cpp)

    ueTest "Should generate all ufuncs for a given type":
            #tests that all props in the gen props, matches the manual binding
            let cls = getClassByName("MyClassToTest")
            
            let funcs = getFuncsFromClass(cls).map(toUEField)
        
            UE_Warn("funcs: " & $funcs.len())
            assert funcs.len() == MyClassToTestNFuncs#think about something better to test against (the number is fragile, it's the number of uproperties defined in that cpp)

    ueTest "Should generate a class that matches the manual binding":
        let cls = getClassByName("MyClassToTest")

        let ueClass = cls.toUEType()
        
        assert ueClass.name == "UMyClassToTest"
        assert ueClass.parent == "UObject"

        assert ueClass.fields.len() == MyClassToTestNProps + MyClassToTestNFuncs
        


    ueTest "Should be able to convert back and forth the UETypes to Json":
        let cls = getClassByName("MyClassToTest")

        let ueClass = cls.toUEType()

        let ueClassAsJson : string = $ueClass.toJson()

        let ueClassFromJson = parseJson(ueClassAsJson).jsonTo(UEType)

        assert ueClass.name == "UMyClassToTest"
        assert ueClass.parent == "UObject"

        assert ueClass.fields.len() == ueClassFromJson.fields.len()
        assert ueclass.name == ueClassFromJson.name
        assert ueclass.parent == ueClassFromJson.parent
        





#Add functions bindings to the generation (should be able to use them from the other tests)
        # Needs support for static X
        # Needs support for var params (do a bind a fix it once the ufuncs are parsed)
        # What else was in uebind that needs to be here?

    #generate the whole class (another test)

    #see what's the best way to have the function outputing to a file (nimscript?)

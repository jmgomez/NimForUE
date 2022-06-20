
include ../unreal/prelude
import testutils


suite "NimForUE.Emit":
    uetest "Should be able to find a function to an existing object":
        let cls = getClassByName("EmitObjectTest")

        let fn = cls.findFunctionByName(n"ExistingFunction")

        assert not fn.isNil()

        

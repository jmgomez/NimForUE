include ../../unreal/prelude
import std/[strutils, sugar]
import ../testutils
import ../testdata
import ../../typegen/[models, uetypegen]
import testemitfunction


suite "NimForUE.ClassEmit":
    ueTest "Should emit an UClass":
        
        let package = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUETest"))
        assert not package.isNil()

        let clsFlags =  (CLASS_Inherit | CLASS_ScriptInherit )
        let className = "UNimClassWhateverPropTest"
        let ueVarType = makeUEClass(className, "UObject", clsFlags,
                        @[
                            makeFieldAsUProp("TestField", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                            makeFieldAsUProp("TestFieldOtra", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        ])
        let newCls = ueVarType.toUClass(package)
        
        let fields = getFPropsFromUStruct(newCls)
        
        let searchCls = () => findObject[UClass](package, className.removeFirstLetter())

        assert not searchCls().isNil()        
        assert fields.len() == 2

        newCls.conditionalBeginDestroy()

        assert searchCls().isNil()

        # TODO remove it and check that's removed
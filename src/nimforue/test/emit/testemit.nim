include ../../unreal/prelude
import std/[strutils, sugar, options]
import ../testutils
import ../testdata
import ../../codegen/[models, uemeta]
import testemitfunction
import tables

suite "NimForUE.ClassEmit":
    ueTest "Should emit an UClass and be able to create props on it based on the type definition":
        
        let package = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUETest"))
        assert not package.isNil()

        let clsFlags =  (CLASS_Inherit | CLASS_ScriptInherit )
        let className = "UNimClassWhateverPropTest"
        let ueVarType = makeUEClass(className, "UObject", clsFlags,
                        @[
                            makeFieldAsUProp("TestField", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                            makeFieldAsUProp("TestFieldOtra", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                        ])
        var fnTable : Table[string, Option[UFunctionNativeSignature]]
        let newCls = ueCast[UClass]ueVarType.emitUClass(package, fnTable, none[UClassConstructor]())
        
        let fields = getFPropsFromUStruct(newCls)
        
        let searchCls = () => findObject[UClass](package, className.removeFirstLetter())

        assert not searchCls().isNil()        
        assert fields.len() == 2

        newCls.conditionalBeginDestroy()

        assert searchCls().isNil()

    ueTest "Should emit an USTruct and be able to create props on it based on the type definition":
        
        let package = findObject[UPackage](nil, convertToLongScriptPackageName("NimForUETest"))
        assert not package.isNil()

        let structName = "FMyNimStruct"
        type FMyNimStruct = object
            testField2321 : FString
            testField2 : FString
            testFieldOtra : FString

        let ueType = UEType(name: "FMyNimStruct", kind: uetStruct, fields: 
                            @[
                                makeFieldAsUProp("TestField2321", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                                makeFieldAsUProp("TestField2", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                                makeFieldAsUProp("TestFieldOtra", "FString", CPF_BlueprintVisible | CPF_Edit | CPF_ExposeOnSpawn),
                            ])

        let scriptStruct = ueCast[UScriptStruct]emitUStruct[FMyNimStruct](ueType, package)

        let searchCls = () => findObject[UNimScriptStruct](package, structName.removeFirstLetter())

        let fields = getFPropsFromUStruct(scriptStruct)

        assert not searchCls().isNil()
        assert fields.len() == 3

        scriptStruct.conditionalBeginDestroy()

        assert searchCls().isNil()




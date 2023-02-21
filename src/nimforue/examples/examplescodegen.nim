
include ../unreal/prelude
import std/[strformat, tables, times, options, sugar, json, osproc, strutils, jsonutils,  sequtils, os, strscans]
import ../codegen/uemeta
import ../../buildscripts/nimforueconfig
import ../codegen/[codegentemplate,modulerules, genreflectiondata, headerparser]
import ../codegen/genmodule #not sure if it's worth to process this file just for one function? 


#[
  NimForUEBindings: [examplescodegen.nim:58]: Func: PrintString Flags: FUNC_Final, FUNC_Native, FUNC_Static, FUNC_Public, FUNC_HasDefaults, FUNC_BlueprintCallable, FUNC_AllFlags 
  Metadata: {AdvancedDisplay: 2, CallableWithoutWorldContext: , Category: Development, 
  CPP_Default_bPrintToLog: true, CPP_Default_bPrintToScreen: true, CPP_Default_Duration: 2.000000, CPP_Default_InString: Hello, CPP_Default_Key: None, 
  CPP_Default_TextColor: (R=0.000000,G=0.660000,B=1.000000,A=1.000000), DevelopmentOnly: , 
  
  Keywords: log print, ModuleRelativePath: Classes/Kismet/KismetSystemLibrary.h, WorldContext: WorldCon
textObject}
  
  Params: 
    Prop: WorldContextObject CppType: UObject* Flags: CPF_ConstParm, CPF_Parm, CPF_ZeroConstructor, CPF_NoDestructor, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
    Prop: InString CppType: FString Flags: CPF_Parm, CPF_ZeroConstructor, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
    Prop: bPrintToScreen CppType: bool Flags: CPF_Parm, CPF_ZeroConstructor, CPF_IsPlainOldData, CPF_NoDestructor, CPF_AdvancedDisplay, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {:}
    Prop: bPrintToLog CppType: bool Flags: CPF_Parm, CPF_ZeroConstructor, CPF_IsPlainOldData, CPF_NoDestructor, CPF_AdvancedDisplay, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {:}
    Prop: TextColor CppType: FLinearColor Flags: CPF_Parm, CPF_ZeroConstructor, CPF_IsPlainOldData, CPF_NoDestructor, CPF_AdvancedDisplay, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {:}
    Prop: Duration CppType: float Flags: CPF_Parm, CPF_ZeroConstructor, CPF_IsPlainOldData, CPF_NoDestructor, CPF_AdvancedDisplay, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {:}
    Prop: Key CppType: FName Flags: CPF_ConstParm, CPF_Parm, CPF_ZeroConstructor, CPF_IsPlainOldData, CPF_NoDestructor, CPF_AdvancedDisplay, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
  
]#
#[
  NimForUEBindings: [examplescodegen.nim:58]: Func: InjectInputForAction Flags: FUNC_Native, FUNC_Public, FUNC_HasOutParms, FUNC_BlueprintCallable, FUNC_AllFlags 
  Metadata: {AutoCreateRefTerm: Modifiers,Triggers, Category: Input, ModuleRelativePath: Public/EnhancedInputSubsystemInterface.h}
  
  Params: 
    Prop: Action CppType: UInputAction* Flags: CPF_ConstParm, CPF_Parm, CPF_ZeroConstructor, CPF_NoDestructor, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
    Prop: RawValue CppType: FInputActionValue Flags: CPF_Parm, CPF_NoDestructor, CPF_NativeAccessSpecifierPublic Metadata: {:}
    Prop: Modifiers CppType: TArray Flags: CPF_ConstParm, CPF_Parm, CPF_OutParm, CPF_ZeroConstructor, CPF_ReferenceParm, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
    Prop: Triggers CppType: TArray Flags: CPF_ConstParm, CPF_Parm, CPF_OutParm, CPF_ZeroConstructor, CPF_ReferenceParm, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
  
]#
#[
  NimForUEBindings: [examplescodegen.nim:91]: Func: AddMappingContext Flags: FUNC_BlueprintCosmetic, FUNC_Native, FUNC_Public, FUNC_HasOutParms, FUNC_BlueprintCallable, FUNC_AllFlags 
  Metadata: {AutoCreateRefTerm: Options, Category: Input, CPP_Default_Options: (), ModuleRelativePath: Public/EnhancedInputSubsystemInterface.h}
  
  Params: 
    Prop: MappingContext CppType: UInputMappingContext* Flags: CPF_ConstParm, CPF_Parm, CPF_ZeroConstructor, CPF_NoDestructor, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
    Prop: Priority CppType: int32 Flags: CPF_Parm, CPF_ZeroConstructor, CPF_IsPlainOldData, CPF_NoDestructor, CPF_HasGetValueTypeHash, CPF_NativeAccessSpecifierPublic Metadata: {:}
    Prop: Options CppType: FModifyContextOptions Flags: CPF_ConstParm, CPF_Parm, CPF_OutParm, CPF_ReferenceParm, CPF_NoDestructor, CPF_NativeAccessSpecifierPublic Metadata: {NativeConst: }
  
]#
#[
   {"ECollisionChannel": "ECC_Visibility", 
   "FText": "INVTEXT(\"Hello\")", 
   "bool": "true", 
   "FName": "None", 
   "FRotator": "", "UForceFeedbackAttenuationPtr": "None", 
   "float32": "1.000000", "EBlendMode": "BLEND_Translucent", 
   "EDetachmentRule": "KeepRelative", "AActorPtr": "None", "UFontPtr": "None", 
   "FVector2D": "(X=1.000,Y=1.000)", "AControllerPtr": "None", "FVector": "", 
   "FString": "", "FLinearColor": "(R=1.000000,G=1.000000,B=1.000000,A=1.000000)", 
   "USoundConcurrencyPtr": "None", "ETextureRenderTargetFormat": 
   "RTF_RGBA16f", "EPSCPoolMethod": "None", "USoundAttenuationPtr": "None", "int32": "-1", 
   "EViewTargetBlendFunction": "VTBlend_Linear", 
   "EMontagePlayReturnType": "MontageLength", 
   "TSubclassOf[ULevelStreamingDynamic] ": "None", 
   "EAttachLocation::Type": "KeepRelativeOffset"}
]#
#[
  Doesnt include ref types so those will require an extra pass (they will be generating function overloads anyways)
  Mostly Enums. Hopefully they all start with E
  Lots of pointer, they will be just nil
  bool, floats and strings whould be direct
  FVector, Colors and so can be just a fn call

  FROTATOR
  U/A poitners
  DONE. 
  Expand functions containing const default params
  See first how many are and see it returning the new amount of funcitons in the code gen
  
  InjectInputVectorForAction
]#

#[
  

]#



#[
  Function that Takes an absolute path to a Header and returns a Path to all #include files
  Once this is done we can extract a lookup table if and attemp to generate code base on it
  #Later
  Function that returns all the IncludePaths of the Application. 
  Function that try to find a header paths in the include paths

]#



template measureTime*(name: static string, body: untyped) =
  let starts = now()
  body
  let ends = (now() - starts)
  UE_Log (name & " took " & $ends & "  seconds")



proc NimMain() {.importc.} 

uEnum EInspectType: 
  (BlueprintType)
  Actor
  Class
  Name

# var ueProjectRef : ref UEProject
# proc getProject() : UEProject = 
#   if ueProjectRef.isNil():
#     let ueProject =  genReflectionData(getGameModules(), getAllInstalledPlugins())
#     ueProjectRef = new UEProject
#     ueProjectRef[] = ueProject
#   return ueProjectRef[]



proc getProject() : UEProject = 
  let pluginModules = getAllInstalledPlugins() 
    .mapIt(getAllModuleDepsForPlugin(it).mapIt($it).toSeq())
    .flatten()
  let gameModules = getGameModules()
  let ueModules = @["Engine", "SlateCore", "Slate"]
  # let projectModules = (gameModules & pluginModules & ueModules).deduplicate()
  let projectModules = ueModules #(gameModules & pluginModules & ueModules).deduplicate()

    
  var project = UEProject()
  measureTime "Getting the project":
    project.modules = projectModules.mapIt(tryGetPackageByName(it)).sequence.mapIt(toUEModule(it, @[], @[], @[])).flatten()
    UE_Log &"Project has {project.modules.len} modules"
    # for m in projectModules:
    #   let pkg = tryGetPackageByName(m)
    #   if pkg.isNone():
    #     UE_Error &"Cant find any module with {m} name"
    #     continue
    #   let modules = pkg.get.toUEModule(@[], @[], @[])
    #   for m in modules:
    #     UE_Log &"Module {m.name} has {m.types.len} and this deps {m.dependencies}"
  project

proc getModules(moduleName:string, onlyBp : bool) : seq[UEModule] = 
      let pkg = tryGetPackageByName(moduleName)
      let rules = 
        if onlyBp:  
          @[makeImportedRuleModule(uerImportBlueprintOnly)]
        else: 
          @[]

      pkg.map((pkg:UPackagePtr) => pkg.toUEModule(rules, @[], @[])).get(@[])
#This is just for testing/exploring, it wont be an actor
uClass AActorCodegen of AActor:
  (BlueprintType)
  override:
    proc beginPlay() = 
      UE_Warn "Hello Begin play from actor codegen"
  uprops(EditAnywhere, BlueprintReadWrite, Category=CodegenInspect):
    inspect : EInspectType = Name
    inspectName : FString = "EnhancedInputSubsystemInterface"
    inspectClass : UClassPtr
    inspectActor : AActorPtr
    bOnlyBlueprint : bool 
    bUseIncludesInPCH : bool 
    moduleName : FString
    test : FString
    depsLevel : int32 = 1
  
  ufuncs(): 
    proc getClassFromInspectedType() : UClassPtr = 
      case self.inspect:
        of EInspectType.Actor: 
          return self.inspectActor.getClass()
        of EInspectType.Class: 
          return self.inspectClass
        of EInspectType.Name: 
          return getClassByName(self.inspectName)
    

  
  ufuncs(BlueprintCallable, CallInEditor, Category=CodegenInspect):
    proc dumpClass() = 
      let cls = self.getClassFromInspectedType()
      if cls.isNil():
        UE_Error "Class is null"
        return
      UE_Log $cls
    proc dumpClassAsUEType() = 
      let cls = self.getClassFromInspectedType()
      if cls.isNil():
        UE_Error "Class is null"
        return
      var pchIncludes = newSeq[string]()
      if self.bUseIncludesInPCH:
        pchIncludes = getPCHIncludes()
      let ueType = cls.toUEType(@[], pchIncludes)
      UE_Log $ueType

    proc dumpMetadatas() = 
      let cls = self.getClassFromInspectedType()
      if cls.isNil():
        UE_Error "Class is null"
        return
      var metas = cls.getMetadataMap().toTable() & cls.getFuncsFromClass().mapIt(it.getMetadataMap().toTable()) 
      for prop in cls.getFPropertiesFrom():
        metas = metas & prop.getMetadataMap().toTable()

      for key, value in metas:
        UE_Log &"{key} : {value}"

    proc dumpModuleRelativePath() = 
      let cls = self.getClassFromInspectedType()
      if cls.isNil():
        UE_Error "Class is null"
        return
      UE_Log $cls.getModuleRelativePath()


  uprops(EditAnywhere, BlueprintReadWrite, Category=CodegenFunctionFinder):
    funcName : FString = "PrintString"
  ufuncs(BlueprintCallable, CallInEditor, Category=CodegenFunctionFinder):
    proc logFunction() = 
      let fn = getUTypeByName[UFunction](self.funcName)
      UE_Log $fn
    proc convertToUEField() = 
      let fn = getUTypeByName[UFunction](self.funcName)
      let fnFields = fn.toUEField(@[])
      UE_Log $fnFields


    proc showFunctionDefaultParams() = 
      let fn = getUTypeByName[UFunction](self.funcName)
      if fn.isNil():
        UE_Error "Function is null"
        return
      let fnField = fn.toUEField(@[]).head().get()
      let defaultParams = fnField.getAllParametersWithDefaultValuesFromFunc()
      for p in defaultParams:
        if p.uePropType == "bool":
          let value = fnField.getMetadataValueFromFunc[:bool](p.name)
          UE_Log $p.name & " = " & $value
        else:
          UE_Warn "Type not supported for default value: " & p.uePropType
          UE_Log $p
    
    proc traverseAllFunctionsWithDefParams() = 
      let modules = getModules(self.moduleName, self.bOnlyBlueprint)
      let fns : seq[UEField]= modules.mapIt(it.types.mapIt(it.fields)).flatten().flatten()
      let fnsWithDefaultParams = fns.filterIt(it.kind == uefFunction and it.getAllParametersWithDefaultValuesFromFunc().len() > 0)
      #I should get next a tuple with the param Type. Only type for now
      var params : Table[string, string] 
      for fn in fnsWithDefaultParams:
        for m in fn.metadata:
          if m.name.startsWith CPP_Default_MetadataKeyPrefix:
            let name = m.name.replace(CPP_Default_MetadataKeyPrefix, "")
            for p in fn.signature:
              if p.name == name:
                UE_Log $p.name & " " & $p.uePropType & " " & $m.value
                params[p.uePropType] = m.value
                break
  
      UE_Log "Found " & $fnsWithDefaultParams.len() & " functions with default parameters"
      UE_Log "Found " & $params.len() & " unique parameters type"
      UE_Log $params
    
    proc traverAllFunctionsWithAutoCreateRefTerm() = 
      let modules = getModules(self.moduleName, self.bOnlyBlueprint)
      let fns : seq[UEField]= modules.mapIt(it.types.mapIt(it.fields)).flatten().flatten()
      let fnsWithAutoCreateRefTerm = fns.filterIt(it.kind == uefFunction and it.hasUEMetadata(AutoCreateRefTermMetadataKey))
      for fn in fnsWithAutoCreateRefTerm:
        UE_Log $fn
      UE_Log "Found " & $fnsWithAutoCreateRefTerm.len() & " unique functions with AutoCreateRefTerm type"      

  uprops(EditAnywhere, BlueprintReadWrite, Category=EnumInspector):
    enumName : FString = "EInputEvent"
  
  ufuncs(BlueprintCallable, CallInEditor, Category=EnumInspector):
    proc showEnumAsUEType() = 
      let uenum = getUTypeByName[UEnum](self.enumName)
      if uenum.isNil():
        UE_Error "Enum is null"
        return
      UE_Log $uenum.toUEType()
    proc showEnumMetadata() = 
      let uenum = getUTypeByName[UEnum](self.enumName)
      if uenum.isNil():
        UE_Error "Enum is null"
        return
      UE_Log $uenum.getMetadataMap().toTable()
     

  uprops(EditAnywhere, BlueprintReadWrite):
    delTypeName : FString = "test5"
    structPtrName : FString 
  uprops(EditAnywhere, BlueprintReadWrite, Category = StructInspector):
    structToFind : FString
  
  ufuncs(BlueprintCallable, CallInEditor, Category=StructInspector):
    proc showStruct() = 
      let struct = getUTypeByName[UScriptStruct](self.structToFind)
      if struct.isNil():
        UE_Error "Struct is null"
        return
      let structField = struct.toUEType()
      UE_Log $structField
      UE_Log &"Module Name: {struct.getModuleName()}"

    proc dumpModuleRelativeStructPath() = 
      let struct = getUTypeByName[UScriptStruct](self.structToFind)
      if struct.isNil():
        UE_Error "Struct is null"
        return
      UE_Log $struct.getModuleRelativePath()

  ufuncs(BlueprintCallable, CallInEditor, Category=ActorCodegen):
    proc genReflectionDataOnly() = 
      try:
        let ueProject =  genReflectionData(getGameModules(), getAllInstalledPlugins())
       
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"
    

    proc showAllProjectDepsFromModule() =         
        let deps = getProject().modules.filterIt( self.moduleName in it.dependencies).mapIt(it.name)
        UE_Warn $deps
    


    proc showAllCyclesDepsFromModule() = 
      let ueProject =  getProject() 
      let moduleNames = ueProject.modules.mapIt(it.name)
      for m in ueProject.modules:
        let depOfs = ueProject.modules.filterIt(m.name in it.dependencies).mapIt(it.name)
        let cyclesFirstLevel = m.dependencies.filterIt(it in depOfs)
        if cyclesFirstLevel.any:
          UE_Log "First Level Deps"
          UE_Log &"{m.name} => it's dependencies for {depOfs}"
          UE_Warn &"{m.name} => it's dependencies/cycles for {cyclesFirstLevel}" 
        #Next level
        for depOf in depOfs:
          let depOfsDepOfs = ueProject.modules.filterIt(depOf in it.dependencies).mapIt(it.name)
          let cyclesSecondLevel = m.dependencies.filterIt(it in depOfsDepOfs)
          if cyclesSecondLevel.any:
            UE_Log "Second Level Deps"
            UE_Log &"{m.name} => it's dependencies for {depOfsDepOfs}"
            UE_Warn &"{m.name} => it's dependencies/cycles for {cyclesSecondLevel}"

    proc getFirstLevelCycles() = 
      let ueProject =  getProject()
      let moduleNames = ueProject.modules.mapIt(it.name)
      var cycles = newTable[string, seq[string]]()
      for m in ueProject.modules:
        let depOfs = ueProject.modules.filterIt(m.name in it.dependencies).mapIt(it.name)
        let cyclesFirstLevel = m.dependencies.filterIt(it in depOfs)
        if cyclesFirstLevel.any:
          cycles[m.name] = cyclesFirstLevel

      UE_Warn $cycles
    proc getSecondLevelCycles() = 
      let ueProject = getProject()
      let moduleNames = ueProject.modules.mapIt(it.name)
      var cycles = newTable[string, seq[string]]()
      for m in ueProject.modules:
        let depOfs = ueProject.modules.filterIt(m.name in it.dependencies).mapIt(it.name)
        for depOf in depOfs:
          let depOfsDepOfs = ueProject.modules.filterIt(depOf in it.dependencies).mapIt(it.name)
          let cyclesSecondLevel = m.dependencies.filterIt(it in depOfsDepOfs)
          if cyclesSecondLevel.any:
            cycles[m.name] = cyclesSecondLevel
      UE_Warn $cycles

    proc shouldUniqueModulePaths() = 
      let pkg = tryGetPackageByName(self.moduleName)
      if pkg.isNone():
        UE_Error &"Cant find any module with {self.moduleName} name"
        return
      let modules = pkg.get.toUEModule(@[], @[], @[])



      let paths = modules[0].types.mapIt(it.moduleRelativePath.extractSubmodule(self.moduleName))
                    .sequence.deduplicate()
      UE_Log $paths
      UE_Log $paths.len


    proc showDepsLevel() = 
      let moduleName = self.moduleName
    
      #project can be a poiinter
      proc calculateLevelDeps(moduleName : string, project:UEProject, level=0) : seq[string] =
        let deps = project.modules.first(m=>m.name == moduleName).map(m=>m.dependencies).get(@[])
        if level == 0: return deps
        let depsOfDeps = deps.mapIt(calculateLevelDeps(it, project, level-1)).flatten()
        return (deps & depsOfDeps).deduplicate()
      
      let deps = calculateLevelDeps(moduleName, getProject(), self.depsLevel)
      UE_Warn $deps

    proc getDepsFromPackage() = 
      let pkg = tryGetPackageByName(self.moduleName)
      if pkg.isNone():
        UE_Error &"Cant find any module with {self.moduleName} name"
        return

      let allObjs = pkg.get.getAllObjectsFromPackage[:UObject]()
      let initialTypes = allObjs.toSeq()
      .map((obj: UObjectPtr) => getUETypeFrom(obj, @[], @[]))
      .sequence()

      let submodules = getSubmodulesForTypes(self.moduleName, initialTypes)
      for k in submodules.keys():
        UE_Warn &"{k} => {submodules[k].len}"
        let deps = getDepsFromTypes(k, submodules[k], @[])
        UE_Log &"Deps {deps}"
        #NEXT HACER POSIBLE RETORNAR ENGINEDELEGATE/ENUM FROM THE MODULE DEPS
      # UE_Log $submodules


    proc getModulesAndDepsFromPackage() = 
      let pkg = tryGetPackageByName(self.moduleName)
      if pkg.isNone():
        UE_Error &"Cant find any module with {self.moduleName} name"
        return

      #Show multiple packages
      let modules = pkg.get.toUEModule(@[], @[], @[])
      
      for m in modules:
        UE_Log &"Module {m.name} has {m.types.len} and this deps {m.dependencies}"



    
    proc genReflectionDataAndBindingsAsync() = 
        execBindingGeneration(shouldRunSync=false)    
    proc genReflectionDataAndBindingsSync() = 
      try:
        execBindingGeneration(shouldRunSync=true)                       
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"

    proc showType() = 
      let obj = getUTypeByName[UDelegateFunction]("UMG.ComboBoxKey:OnOpeningEvent"&DelegateFuncSuffix)
      let obj2 = getUTypeByName[UDelegateFunction]("OnOpeningEvent"&DelegateFuncSuffix)
      UE_Warn $obj
      UE_Warn $obj2
      UE_Warn $obj2

    proc showTypeModule() = 
      UE_Log self.inspectName.typeToModule().get("Couldnt find it. Make sure inspect name is set")
      


    proc searchDelByName() = 
      let obj = getUTypeByName[UDelegateFunction](self.delTypeName&DelegateFuncSuffix)
      if obj.isNil(): 
        UE_Error &"Error del is null. Provide a type name"
        return

      UE_Warn $obj
      UE_Warn $obj.getOuter()
    
    proc runFnInAnotherThread() = 
      proc ffiWraper(msg:int) {.cdecl.} = 
        # NimMain()   
        # UE_Log "Hello from another thread" & $msg #This cashes
        # let s = "test string"
        UE_Log "Hello from another thread" 
     
      executeTaskInTaskGraph(2, ffiWraper)   

    proc showModuleDeps() = 
      let pkg = tryGetPackageByName(self.moduleName)
      if pkg.isNone():
        UE_Error &"Cant find any module with {self.moduleName} name"
        return
      let modules = pkg.get.toUEModule(@[], @[], @[])
      if modules.any():
        UE_Log $modules[0].dependencies

    proc showUEModule() = 
      let pkg = tryGetPackageByName(self.moduleName)
      let rules = 
        if self.bOnlyBlueprint:  
          @[makeImportedRuleModule(uerImportBlueprintOnly),  makeImportedRuleType(uerForce, @["FNiagaraPosition"])]
        else: 
          @[]

      let modules = pkg.map((pkg:UPackagePtr) => pkg.toUEModule(rules, @[], @[], getPCHIncludes())).get(@[])
      # UE_Log $modules.head().map(x=>x.types.mapIt(it.name))
      # UE_Log "Len " & $modules.len
      # UE_Log "Types " & $modules.head().map(x=>x.types).get(@[]).len
      let ueProject = UEProject(modules: modules)
      UE_Log "contans deproject to mouse pos: " & $ueProject.modules.filterIt(it.types.filterIt(it.fields.filterIt(it.name.contains("DeprojectMousePositionToWorld")).any()).any()).any()
      # writeFile(PluginDir/"engine.text", $ueProject)
      # UE_Log $ueProject
      UE_Log "PCH Types:" & $modules.mapIt(it.types).flatten.filterIt(it.isInPCH).len
    
    proc showPCHTypes() = 
      let pkg = tryGetPackageByName(self.moduleName)
      let modules = pkg.map((pkg:UPackagePtr) => pkg.toUEModule(@[], @[], @[], getPCHIncludes())).get(@[])
      let ueProject = UEProject(modules: modules)
      let pchTypes = modules.mapIt(it.types).flatten.filterIt(it.isInPCH).mapIt(it.name)
      UE_Log "PCH Types:" & $pchTypes




    proc saveIncludesIntoJson() = 
      let includePaths = getNimForUEConfig().getUEHeadersIncludePaths()
      # UE_Log $includePaths
      let allIncludes = traverseAllIncludes("UEDeps.h", includePaths, @[]).deduplicate()
      let path = PluginDir/"allincludes.json"
      saveIncludesToFile(path, allIncludes)
      UE_Log $allIncludes.len

    proc testClassInIncludes() = 

      let cls = self.getClassFromInspectedType()
      if cls.isNil():
        UE_Error "Class is null"
        return
      UE_Log $cls.getModuleRelativePath()

      #Is module relative path in includes? It will need the module name.
      try:
        let includes = getPCHIncludes()
        let isInHeaders = isModuleRelativePathInHeaders(cls.getModuleName(), cls.getModuleRelativePath().get(), includes)
        UE_Log &"Is {cls.getName()} in PCH?" & $isInHeaders
      except:
        let e : ref Exception = getCurrentException()
        UE_Error &"Error: {e.msg}"
        UE_Error &"Error: {e.getStackTrace()}"
        UE_Error &"Failed to generate reflection data"



    proc saveNewBindings() = 
      let config = getNimForUEConfig()
      createDir(config.bindingsDir)

      #we save the pch types right before we discard the cached modules to avoid race conditions
      
      # savePCHTypes(modCache.values.toSeq)


      #let's change the way we calculate deps.
      #First we need to get all Fields for an UEType
      #Then we need to get all type names for an UEType (field + parent + superstruct). Notice fields here will need to deal with generics
      #Then we need to know if a type name is in a Module. 
      func getAllFieldsFromUEType(uet:UEType) : seq[UEField] = 
        # Returns all fields for delegates, classes and structs. Notice it wont retunr enum fields
        case uet.kind:
        of uetEnum, uetInterface: @[]
        else: uet.fields

      func getAllTypesFromUEField(uef:UEField) : seq[string] = 
        # Returns all types for a field. It will return generic types as they are in Nim.
        case uef.kind:
        of uefProp: @[uef.uePropType]
        of uefFunction: uef.signature.map(getAllTypesFromUEField).flatten()
        of uefEnumVal: @[]
      
      func getNameFromUEPropType(nimType:string) : seq[string] = 
        # Will return the name of the type cleaned. No Ptr, no Generic, no Var, etc.
        var nimType = nimType
        if "var " in nimType:
          nimType = nimType.replace("var ", "").strip()
          
        if nimType.isGeneric:
          if "TMap" in nimType:
            nimType.extractKeyValueFromMapProp().map(getNameFromUEPropType).flatten()
          else:
            getNameFromUEPropType(nimType.extractInnerGenericInNimFormat())
        else:
          @[nimType.removeLastLettersIfPtr()]


      func getCleanedDependencyNamesFromUEType(uet:UEType) : seq[string] = 
        #Consider returning empty for primitive types
        let fields = getAllFieldsFromUEType(uet)
        let extraTypes = 
          case uet.kind:
          of uetClass: uet.parent & uet.interfaces
          of uetStruct: @[uet.superStruct]
          else: @[]
        let types = fields.map(getAllTypesFromUEField).flatten() & extraTypes
        let cleanedTypes = types.map(getNameFromUEPropType).flatten()
        cleanedTypes.deduplicate()
      
      func getCleanedDependencyTypes(uem:UEModule) : seq[string] = 
        let types = uem.types
        let cleanedTypes = types.map(getCleanedDependencyNamesFromUEType).flatten()
        cleanedTypes.deduplicate()

      func getCleanedDefinitionNamesFromUEType(uet:UEType) : seq[string] = 
        #only name?
        @[uet.name]

      func getCleanedDefinitionTypes(uem:UEModule) : seq[string] = 
        let types = uem.types
        let cleanedTypes = types.map(getCleanedDefinitionNamesFromUEType).flatten()
        cleanedTypes.deduplicate()

      func isTypeDefinedInModule(uem:UEModule, typeName:string) : bool = 
        let cleanedTypes = getCleanedDefinitionTypes(uem)
        typeName in cleanedTypes

      func getModuleNameForType(typeDefinitions : Table[string, seq[string]], typeName:string) : Option[string] = 
        for key, value in typeDefinitions.pairs:
          if typeName in value:
            return some(key)
        # let modules = project.modules
        # let module = modules.first(m=>m.isTypeDefinedInModule(typeName)).map(m=>m.name)
        # module
      func getTypeDefinitions(modules:seq[UEModule]) : Table[string, seq[string]] = 
        var typeDefinitions = initTable[string, seq[string]]()
        for module in modules:
          typeDefinitions[module.name] = getCleanedDefinitionTypes(module)
        typeDefinitions

      func depsFromModule(modules:seq[UEModule], uem:UEModule, typeDefs : Table[string, seq[string]]) : seq[string] = 
        uem
          .getCleanedDependencyTypes
          .mapIt(getModuleNameForType(typeDefs, it))
          .sequence
          .deduplicate()
          .filterIt(it != uem.name)

      
      func getFirstLevelCycles(modules:seq[UEModule]) : TableRef[string, seq[string]] = 
        let moduleNames = modules.mapIt(it.name)
        var allCycles = newTable[string, seq[string]]()
        for m in modules:
          let depOfs = modules.filterIt(m.name in it.dependencies).mapIt(it.name)
          let cycles = m.dependencies.filterIt(it in depOfs)
          if cycles.any:
            allCycles[m.name] = cycles

        allCycles
      
      func moveTypeFrom(uet:UEType, source, destiny : var UEModule) = 
        #conceptually move types from source to destiny. 
        #if it's struct moves the whole type and removes it from source
        #if it's class, marks it as forwardDeclare only and do not remove for source. Doesnt copy fields

        let index = source.types.firstIndexOf((typ:UEType)=>typ.name == uet.name)
        case uet.kind:
        of uetStruct:
          source.types.del(index)
          destiny.types.add(uet)
        of uetClass:
          var uet = uet
          uet.forwardDeclareOnly = true
          source.types[index] = uet
          uet.forwardDeclareOnly = false
          uet.fields = @[]
          destiny.types.add(uet) #TODO remove fields
        else: discard #only move structs and classes

      func moveTypesFrom(uets:seq[UEType], source, destiny : var UEModule) =
        for uet in uets:
          moveTypeFrom(uet, source, destiny)
      
      func getDependentTypesFrom(uemDep, uemDefined : UEModule, typeDefinitions : Table[string, seq[string]]) : seq[string] = 
        #Return all types that are defined in uemDefined and are used in uemDep
        let allDefTypes = typeDefinitions[uemDefined.name]
        let allDepTypes = uemDep.getCleanedDependencyTypes()
        let dependentTypes = allDefTypes.filterIt(it in allDepTypes)
        dependentTypes



      #Create a module with all the types or just the types in common:
      

      # Speed up: Collect all types definitions in a first pass DONE

      # Then in a second pass, collect all dependencies DONE

      #Find cycles DONE

      #Move types into a common module to remove cycles
        # 1. Get all types that depends from a given module and move then into another module (ForwardDeclareOnly)
      #Recalculate deps
     
      var typeDefinitions : Table[string, seq[string]] 
      measureTime "Whole Project":
        var project = getProject()
        var modules = newSeq[UEModule]()
        typeDefinitions = getTypeDefinitions(project.modules)

        measureTime "Only Deps":
          for module in project.modules:
            var uem = module
            uem.dependencies = depsFromModule(project.modules, module, typeDefinitions)
            modules.add(uem)
          project.modules = modules


      measureTime "Cycles":
        let cycles = getFirstLevelCycles(project.modules)
        for key, value in cycles.pairs:
          UE_Log key & " -> " & value.join(", ")
        
      var commonModule = UEModule(name:"Engine/Common", types: @[])
      let firstCycle = cycles.pairs.toSeq[0]


      var modDep = project.modules.first(m=>m.name == firstCycle[0]).get()
      var modDef = project.modules.first(m=>m.name == firstCycle[1][0]).get()
      UE_Log &"First Cycle: {modDep.name} -> {modDef.name}"
      UE_Log &"Types from {modDep.name} defined in {modDef.name}"


      let dependentTypesNames = getDependentTypesFrom(modDep, modDef, typeDefinitions)
      let dependentTypes = modDef.types.filterIt(it.name in dependentTypesNames)

      UE_Log &"Dependent Types: {dependentTypesNames}"
      
      moveTypesFrom(dependentTypes, modDef, commonModule)

      UE_Log &"Common module: {commonModule}"

      

      # UE_Log &"Modules to gen: {project.modules.len}"
      # UE_Log &"Modules to gen: {project.modules.mapIt(it.name)}"
      let ueProjectAsStr = $project
      let codeTemplate = """
import ../nimforue/codegen/[models, modulerules]

const project* = $1
"""
      #Folders need to be created here because createDir is not available at compile time
      createDir(config.reflectionDataDir)
      writeFile(config.reflectionDataFilePath, codeTemplate % [ueProjectAsStr])

      for module in project.modules:
        let moduleFolder = module.name.toLower().split("/")[0]
        let actualModule = module.name.toLower().split("/")[^1]
        createDir(config.bindingsDir / "exported" / moduleFolder)
        createDir(config.bindingsDir / moduleFolder)

      
      # return ueProject




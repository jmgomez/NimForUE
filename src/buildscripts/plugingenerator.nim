
import std/[os, strformat, strutils, sequtils]
import buildcommon, buildscripts, nimforueconfig



#[
  The structure of a UE plugin is as follows:
  - PluginName
    - PluginName.uplugin
    - Source
      #Module Structure#
      - ModuleNameFolder
        - Private
          - NimGenerateCodeFolder
            - *.nim.cpp
          - ModuleName.cpp          
        - Public
          - ModuleName.h  
        - ModuleName.Build.cs

]#


const UPluginTemplate = """
{
  "FileVersion": 3,
  "FriendlyName": "$1",
  "Version": 1,
  "VersionName": "1.0",
  "CreatedBy": "NimForUE",
  "EnabledByDefault" : false,
	"CanContainContent" : false,
	"IsBetaVersion" : false,
	"Installed" : false,
	"Modules" :
	[
$2
	]
} 
    
"""
const ModuleTemplateForUPlugin = """
    {
      "Name" : "$1",
      "Type" : "Runtime",
      "LoadingPhase" : "PostDefault",
      "AdditionalDependencies" : []
    }"""


#TODO at some point pase modules to link dinamically here too from game.json. 
const ModuleBuildcsTemplate = """
using System.IO;
using UnrealBuildTool;
 
public class $1 : ModuleRules
{
	public $1(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"InputCore", 
			"Slate", 
			"SlateCore",
			"Engine", 
			"NimForUEBindings",
			"EnhancedInput", 
			"GameplayTags",
			"PCG",
			"GameplayAbilities",
			"PhysicsCore",
			"UnrealEd",
			//"NimForUE", //DUE To reinstance bindigns. So editor only
			
		});
		PrivateDependencyModuleNames.AddRange(new string[] {  });
	
		PublicDefinitions.Add("NIM_INTBITS=64");
		if (Target.Platform == UnrealTargetPlatform.Win64){
			CppStandard = CppStandardVersion.Cpp20;
		} else {
			CppStandard = CppStandardVersion.Cpp17;
		}
		PrivatePCHHeaderFile = "../../NimHeaders/nimgame.h";
		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		PublicIncludePaths.Add(nimHeadersPath);
		bUseUnity = false;
		//The lib is quite big (24MB), it may be better to just pull the files that needs to be compiled
		// var nimMirrorBindings = Path.Combine(PluginDirectory, "Binaries", "nim", "libmaingencppbindings.a");
		var nimMirrorBindings = Path.Combine(PluginDirectory, "Binaries", "nim", "maingencppbindings.lib");
		// PublicAdditionalLibraries.Add(nimMirrorBindings);
	}
}
"""

const ModuleHFileTemplate = """
#pragma once

#include "Modules/ModuleManager.h"

DECLARE_LOG_CATEGORY_EXTERN($1, All, All);

class F$1 : public IModuleInterface
{
	public:

	/* Called when the module is loaded */
	virtual void StartupModule() override;

	/* Called when the module is unloaded */
	virtual void ShutdownModule() override;
};

"""

const ModuleCppFileTemplate = """
#include "../Public/$1.h"
#include "CoreUObject/Public/UObject/UObjectGlobals.h"
DEFINE_LOG_CATEGORY($1);

#define LOCTEXT_NAMESPACE "FGameCorelibEditor"


constexpr char NUEModule[] = "some_module";

extern  "C" void startNue(uint8 calledFrom);
#if WITH_EDITOR

extern  "C" void* getGlobalEmitterPtr();
extern  "C" void reinstanceFromGloabalEmitter(void* globalEmitter);

#endif

void GameNimMain();

void StartNue() {
#if WITH_EDITOR
	FCoreUObjectDelegates::ReloadCompleteDelegate.AddLambda([&](EReloadCompleteReason Reason) {
	 UE_LOG(LogTemp, Log, TEXT("Reinstancing Lib"))
		GameNimMain();
		reinstanceFromGloabalEmitter(getGlobalEmitterPtr());
	});
#endif
	GameNimMain();
	startNue(1);
	// #endif
}



void F$1::StartupModule()
{
  if (std::strcmp(NUEModule, "Bindings") != 0) {
	  StartNue();
  }
}

void F$1::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(F$1, $1)
"""


proc getPluginTemplateFile(name:string, modules:seq[string]) : string =
  let modulesStr = modules.mapIt(ModuleTemplateForUPlugin.format(it)).join(",\n")
  UPluginTemplate.format(name, modulesStr)

proc getModuleBuildCsFile(name:string) : string =
  #Probably bindings needs a different one
  ModuleBuildcsTemplate.format(name)

proc getModuleHFile(name:string) : string =
  ModuleHFileTemplate.format(name)
proc getModuleCppFile(name:string) : string =
  ModuleCppFileTemplate.format(name)

proc generateModule(name:string, sourceDir:string) = 
  let moduleDir = sourceDir / name
  let privateDir = moduleDir / "Private"
  let publicDir = moduleDir / "Public"
  let nimGeneratedCodeDir = privateDir / "NimGeneratedCode"
  let moduleCppFile = privateDir / (name & ".cpp")
  let moduleHFile = publicDir / (name & ".h")
  let moduleBuildCsFile = moduleDir / (name & ".Build.cs")

  createDir(moduleDir)
  createDir(privateDir)
  createDir(publicDir)
  createDir(nimGeneratedCodeDir)
  writeFile(moduleCppFile, getModuleCppFile(name))
  writeFile(moduleHFile, getModuleHFile(name))
  writeFile(moduleBuildCsFile, getModuleBuildCsFile(name))

proc generatePlugin*(name:string) =
  let uePluginDir = parentDir(PluginDir)
  let genPluginDir = uePluginDir / name
  let genPluginSourceDir = genPluginDir / "Source"
  let upluginFilePath = genPluginDir / (name & ".uplugin")
  let modules = @["Game", "Bindings"] #notice we add bindings here.

  createDir(genPluginDir)
  createDir(genPluginSourceDir)
  writeFile(upluginFilePath, getPluginTemplateFile(name, modules))
  for module in modules:
    generateModule(module, genPluginSourceDir)


#[Steps
1. Do the missing cpp file
2. Toggle the module in the project file
3. At this point ubuild should work and compile the plugin
4. Compile bindings into the project.
5. At this point uebuild should work and compile the plugin
6. Compile the game


]#
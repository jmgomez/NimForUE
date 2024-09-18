
import std/[jsonutils, json, os, strformat, strutils, sequtils, tables, hashes]
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
  "EnabledByDefault" : true,
	"CanContainContent" : false,
	"IsBetaVersion" : false,
	"Installed" : false,
	"Modules" :
	[
$3
	]
} 
    
"""
#TODO LoadingPhase should be before to support EarlyTypes (implement the hook first)
const ModuleTemplateForUPlugin = """
    {
      "Name" : "$1",
      "Type" : "Runtime",
      "LoadingPhase" : "PostDefault", 
      "AdditionalDependencies" : ["NimForUE"],
      "PlatformAllowList": ["$2"]


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
			"PCG",  //TODO add only in 5.2
			"GameplayAbilities", //TODO PCG, GameplayTags and GampleyAbilities should be optional modules
			"PhysicsCore",
      "UMG",
      "NavigationSystem",
		
		});
		PrivateDependencyModuleNames.AddRange(new string[] {  });
    if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
			});
      if (Target.Platform == UnrealTargetPlatform.Win64)
				PrivateDependencyModuleNames.Add("LiveCoding");
		}
    
    $2
    var nimGameDir = Path.Combine(this.Target.ProjectFile.Directory.ToString(), "NimForUE");
    if (File.Exists(Path.Combine(nimGameDir, "nuegame.h"))) {
      PublicIncludePaths.Add(nimGameDir);
      PublicDefinitions.Add("NUE_GAME=1");
      System.Console.WriteLine("Found an user custom header nuegame.h Adding it to the PCH");
    }
		PublicDefinitions.Add("NIM_INTBITS=64");
		if (Target.Platform == UnrealTargetPlatform.Win64){
			CppStandard = CppStandardVersion.Cpp20;
		} else {
			CppStandard = CppStandardVersion.Cpp17;
		}
		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		var nimHeadersPath = Path.Combine(PluginDirectory, "..", "NimForUE", "NimHeaders");
    PrivatePCHHeaderFile =  Path.Combine(nimHeadersPath, "nuebase.h");

		PublicIncludePaths.Add(nimHeadersPath);
		bUseUnity = false;
    //TODO not hardcoded and not mac os specific
    //var bindingsLibPath = "/Users/jmgomez/NimTemplate/NimTemplate/Plugins/NimForUE/Binaries/nim/libbindings.a";
		//PublicAdditionalLibraries.Add(bindingsLibPath);
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
#if PLATFORM_WINDOWS && WITH_EDITOR
  #include "ILiveCodingModule.h"
#endif

DEFINE_LOG_CATEGORY($1);

#define LOCTEXT_NAMESPACE "FGameCorelibEditor"

void $2NimMain();
extern  "C" void* reinstanceNextFrame();
extern  "C" void startNue();


void F$1::StartupModule()
{
//# if WITH_EDITOR
  //TODO improve for livecoding
  //But do no start Nim when no editor
//#else
	 $2NimMain();
    startNue();
//#endif
#if PLATFORM_WINDOWS && WITH_EDITOR
  ILiveCodingModule* LiveCodingModule = FModuleManager::GetModulePtr<ILiveCodingModule>("LiveCoding");
  LiveCodingModule->GetOnPatchCompleteDelegate().AddLambda([] {
    $2NimMain();
    reinstanceNextFrame();
  });
#endif
}

void F$1::ShutdownModule()
{
	
}

#undef LOCTEXT_NAMESPACE

IMPLEMENT_MODULE(F$1, $1)
"""

proc nameWithPlatformSuffix(name:string, platformTarget: PlatformTargetKind): string =
  name & capitalizeAscii($platformTarget)

proc platformTargetToUnrealTarget(target: PlatformTargetKind): string = 
  case target
  of ptkWindows: "Win64"
  of ptkAndroid: "Android"
  of ptkIOS: "IOS"
  of ptkMac: "MacOs"
  else: 
    raise newException(Defect, "Invalid platform target")
    

proc getPluginTemplateFile(name:string, modules:seq[string], platformTarget: PlatformTargetKind) : string =
  let modulesStr = modules
    .mapIt(ModuleTemplateForUPlugin.format(
      nameWithPlatformSuffix(it, platformTarget), 
      platformTargetToUnrealTarget(platformTarget)))
    .join(",\n")
  UPluginTemplate.format(name, platformTargetToUnrealTarget(platformTarget), modulesStr)

proc getModuleBuildCsFile(name:string, platformTarget: PlatformTargetKind) : string =
  #Probably bindings needs a different one
  let modName = nameWithPlatformSuffix(name, platformTarget)
  let userPluginModules = getUserGamePlugins({modkDefault, modkRuntime}).values.toSeq.concat
  let extraModules = 
    (getGameUserConfigValue("gameModules", newSeq[string]()) & userPluginModules)
    .mapIt(it.quotes)
  var extraModulesContent = ""
  if extraModules.len > 0:
    extraModulesContent = &"""
    PublicDependencyModuleNames.AddRange(new string[]{{ {extraModules.join(",")} }});
"""

  
  ModuleBuildcsTemplate.format(modName, extraModulesContent)

proc getModuleHFile(name:string, platformTarget: PlatformTargetKind) : string =
  ModuleHFileTemplate.format(nameWithPlatformSuffix(name, platformTarget))

proc getModuleCppFile(name:string, platformTarget: PlatformTargetKind) : string =
  ModuleCppFileTemplate.format(nameWithPlatformSuffix(name, platformTarget), name)




#begin cpp
type CppSourceFile = object
  name, path, content :string    

proc copyCppFilesToModule(cppSrcDir, nimGeneratedCodeDir:string) = 
  #TODO generate a map of what exists and what not so we can detect removals.
  #Notice we need to copy the bindings too. Maybe we can infer somehow only what needs to be copied. 
  #It doesnt really matter though since on the final build they will be optimized out but it may saved us 
  #some seconds on the first build.
  var existingFiles = initTable[string, CppSourceFile]()
  var newFiles = initTable[string, CppSourceFile]()
  let exludeFiles = @["os.nim.cpp", "buildscripts.nim.cpp"]
  for newFile in walkFiles(cppSrcDir / &"*.cpp"):        
    let filename = newFile.extractFilename()   
    when defined(windows):
      if filename.contains("sbindings@simported") or exludeFiles.anyIt(filename.contains(it)):
      #   #"imported bindings arent copied"
        continue
    newFiles[filename] = CppSourceFile(name:filename, path:newFile, content: readFile(newFile))

  for oldFile in walkFiles(nimGeneratedCodeDir / &"*.cpp"):
    let filename = oldFile.extractFilename()
    existingFiles[filename] = CppSourceFile(name:filename, path:oldFile, content: readFile(oldFile))    

  log "Exisiting files: " & $existingFiles.len
  log "New files: " & $newFiles.len
  for newFile in newFiles.values:
    if newFile.name in existingFiles:
      if newFile.content != existingFiles[newFile.name].content:
        copyFile(newFile.path, nimGeneratedCodeDir / newFile.name)
        log "File changed: " & newFile.name
    else:
      copyFile(newFile.path, nimGeneratedCodeDir / newFile.name)
      log "File added: " & newFile.name
      
  for oldFile in existingFiles.values:
    if oldFile.name notin newFiles:
      removeFile(oldFile.path)
      log "File removed: " & oldFile.name
        
    

proc copyCppToModule(name:string, nimGeneratedCodeDir : string, platformTarget: PlatformTargetKind) =   
  let cppSrcDir = PluginDir / getBaseNimCacheDir(name, platformTarget) / "release" #embed debug? 
    # cppSrcDir = PluginDir / &".nimcache/nimforuegame/release"
  copyCppFilesToModule(cppSrcDir, nimGeneratedCodeDir)


proc generateModule*(name, pluginName : string, platformTarget: PlatformTargetKind) = 
  let moduleName = nameWithPlatformSuffix(name, platformTarget)
  let uePluginDir = parentDir(PluginDir)
  let genPluginDir = uePluginDir / pluginName
  let genPluginSourceDir = genPluginDir / "Source"
  let moduleDir = genPluginSourceDir / moduleName
  let privateDir = moduleDir / "Private"
  let publicDir = moduleDir / "Public"
  let nimGeneratedCodeDir = privateDir / "NimGeneratedCode"
  let moduleCppFile = privateDir / (moduleName & ".cpp")
  let moduleHFile = publicDir / (moduleName & ".h")
  let moduleBuildCsFile = moduleDir / (moduleName & ".Build.cs")

  createDir(moduleDir)
  createDir(privateDir)
  createDir(publicDir)
  createDir(nimGeneratedCodeDir)
  writeFile(moduleCppFile, getModuleCppFile(name, platformTarget))
  writeFile(moduleHFile, getModuleHFile(name, platformTarget))
  writeFile(moduleBuildCsFile, getModuleBuildCsFile(name, platformTarget))  
  copyCppToModule(name, nimGeneratedCodeDir, platformTarget)
  log &"Generated module {name} in {nimGeneratedCodeDir}"
  
 #this is a param 

proc cleanGenerateCode*(name, genPluginDir:string) = 
  let moduleDir = genPluginDir / "Source" / name 
  let privateDir = moduleDir / "Private"
  let nimGeneratedCodeDir = privateDir / "NimGeneratedCode"

  removeDir(nimGeneratedCodeDir)
  createDir(nimGeneratedCodeDir)
  echo privateDir / name & ".cpp"
  removeFile(privateDir / name & ".cpp")

proc addPluginToUProject(name: string) = 
  var uprojectJson = getGamePathFromGameDir().readFile.parseJson()
  let plugin = newJObject()
  plugin["Name"] = name.toJson()
  plugin["Enabled"] = true.toJson()
  if uprojectJson["Plugins"].filterIt(it["Name"].getStr == name).len == 0:
    uprojectJson["Plugins"].add(plugin)
  
  getGamePathFromGameDir().writeFile(uprojectJson.pretty)

proc removePluginFromUProject(name: string) = 
  var uprojectJson = getGamePathFromGameDir().readFile.parseJson()
  uprojectJson["Plugins"] = uprojectJson["Plugins"].filterIt(it["Name"].getStr != name).toJson()
  getGamePathFromGameDir().writeFile(uprojectJson.pretty)

proc removePlugin*(name:string) = 
  let uePluginDir = parentDir(PluginDir)
  let genPluginDir = uePluginDir / name
  removeDir(genPluginDir)
  removePluginFromUProject(name)
  log &"Removed plugin {name} in {genPluginDir}"

proc generatePlugin*(name:string, platformTarget: PlatformTargetKind) =
  let uePluginDir = parentDir(PluginDir)
  log &"Generating plugin {name} in {uePluginDir}"
  let genPluginDir = uePluginDir / name
  let genPluginSourceDir = genPluginDir / "Source"
  let upluginFilePath = genPluginDir / (name & ".uplugin")
  let modules = getAllGameLibs().mapIt(it.capitalizeAscii())
  log &"Generating plugin {name} with modules: {modules} in {genPluginDir}"
  try:
    createDir(genPluginDir)
    createDir(genPluginSourceDir)
    writeFile(upluginFilePath, getPluginTemplateFile(name, modules, platformTarget))
    #TODO make sure is not added before first
    addPluginToUProject(name)
    for module in modules:
      generateModule(module, name, platformTarget)
  except Exception as e:
    log getCurrentExceptionMsg()
    log getStackTrace()
    






#[Steps
1.[x] Do the missing cpp file
2. Toggle the module in the project file (not sure if it makes sense since it's autocompiled. Will try to make all scenarios to compile)
3. [x] At this point ubuild should work and compile the plugin
4. Compile bindings into the project.
5. At this point uebuild should work and compile the plugin
6. Compile the game


]#
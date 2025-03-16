using System;
using System.IO;
using System.Runtime.InteropServices;
using UnrealBuildTool;

public class NimForUEBindings : ModuleRules
{
	//WIN ONLY
	[DllImport("kernel32.dll")]
	static extern bool SetDllDirectory(string lpPathName);
	[DllImport("hostnimforue")]
	public static extern IntPtr getGameModules(bool withEditor);
	void AddHostDll() {
		var nimBinPath = Path.Combine(PluginDirectory, "Binaries", "nim", "ue");
		string dynLibPath;
		var isWin = Target.Platform == UnrealTargetPlatform.Win64;
		if (isWin) {
			var dllName = "hostnimforue.dll";
			dynLibPath = Path.Combine(nimBinPath, dllName);
			SetDllDirectory(nimBinPath);
			var libSymbolsName = "hostnimforue.lib";
			RuntimeDependencies.Add(dynLibPath);
			PublicDelayLoadDLLs.Add(dllName);
			PublicAdditionalLibraries.Add(Path.Combine(nimBinPath, libSymbolsName));

		}
		else {
			dynLibPath = Path.Combine(nimBinPath, "libhostnimforue.dylib");
			PublicAdditionalLibraries.Add(dynLibPath);
		}
	}
	public NimForUEBindings(ReadOnlyTargetRules Target) : base(Target) {
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", 
			"CoreUObject", 
			"Engine",
			"Projects",
			"UMG",
			"NavigationSystem",
			//"UnrealEd"
			 "InputCore", 
			 //THE PCH pulls the headers from this module. So the search paths should be in here
			 "EnhancedInput", "GameplayAbilities", "AIModule",
		});
		
		if (Target.bBuildEditor) {
			PublicDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
				"AdvancedPreviewScene"
			});
		}

		AddHostDll();
		var gameModulesStr = "";
		//Only win #TODO fix for macos
		if (Target.Platform == UnrealTargetPlatform.Win64){
			gameModulesStr = Marshal.PtrToStringAnsi(getGameModules(Target.bBuildEditor));
		}
		if (!String.IsNullOrEmpty(gameModulesStr)) {
			var nimGameModules = gameModulesStr.Split(",");
			foreach (var m in nimGameModules) {
				Console.WriteLine("Adding Nim Module:: " + m);
			}
			PublicDependencyModuleNames.AddRange(nimGameModules);
		}
	
		CppStandard = CppStandardVersion.Cpp20;
		
		

		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		PublicDefinitions.Add("NIM_INTBITS=64");
		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		var PCHFile = Path.Combine(nimHeadersPath, "bindingsbase.h");
		PublicIncludePaths.Add(nimHeadersPath);
		PrivatePCHHeaderFile = PCHFile;
		bUseUnity = false;
		
		
	}
}




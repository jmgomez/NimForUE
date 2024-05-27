// Copyright Epic Games, Inc. All Rights Reserved.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using UnrealBuildTool;



public class NimForUE : ModuleRules
{
	//Bind a few methods to set the EngineDir, Platform, etc.
	[DllImport("hostnimforue")]
	public static extern void setWinCompilerSettings(string sdkVersion, string compilerVersion, string toolchainDir);

	[DllImport("hostnimforue")]
	public static extern void setUEConfig(string engineDir, string conf, string platform, bool withEditor);

	[DllImport("hostnimforue")]
	static extern IntPtr getNimBaseHeaderPath();
	
	
	//WIN ONLY
	[DllImport("kernel32.dll")]
	static extern bool SetDllDirectory(string lpPathName);

	public NimForUE(ReadOnlyTargetRules Target) : base(Target) {
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		if (Target.Platform == UnrealTargetPlatform.Win64) {
			CppStandard = CppStandardVersion.Cpp20;
		}
		else {
			CppStandard = CppStandardVersion.Cpp17;
		}

		PublicDefinitions.Add("NIM_INTBITS=64");
		bEnableExceptions = true;
		OptimizeCode = CodeOptimization.InShippingBuildsOnly;
		PublicIncludePathModuleNames.Add("GameplayAbilities");
		Console.WriteLine(EngineDirectory);
		PrivateIncludePaths.Add(GetModuleDirectory("Engine"));
		
		PublicDependencyModuleNames.AddRange(new string[] {
			"GameplayAbilities",
			"Core", "CoreUObject", "Engine", "InputCore", "NavigationSystem",
			"Slate",
			"SlateCore",

		});


		if (Target.bBuildEditor) {
			PrivateDependencyModuleNames.AddRange(new string[] {
				"UnrealEd",
				"NimForUEEditor",
				"EditorStyle",
				"AdvancedPreviewScene",
			});
		}

		PrivateDependencyModuleNames.AddRange(
			new string[] {
				"CoreUObject",
				"Engine",
				"NimForUEBindings",
				"Projects",
			}
		);



		DynamicallyLoadedModuleNames.AddRange(
			new string[] {
				// ... add any modules that your module loads dynamically here ...
			}
		);

		var nimHeadersPath = Path.Combine(PluginDirectory, "NimHeaders");
		var PCHFile = Path.Combine(nimHeadersPath, "nuebase.h");
		PublicIncludePaths.Add(nimHeadersPath);
		PrivatePCHHeaderFile = PCHFile;

		var nimGameDir = Path.Combine(this.Target.ProjectFile.Directory.ToString(), "NimForUE");
		if (File.Exists(Path.Combine(nimGameDir, "nuegame.h"))) {
			PublicIncludePaths.Add(nimGameDir);
			PublicDefinitions.Add("NUE_GAME=1");
			Console.WriteLine("Found an user custom header nuegame.h Adding it to the PCH");
		}


		if (Target.bBuildEditor) {
			AddNimForUEDev();
			// PublicIncludePaths.Add(Marshal.PtrToStringAnsi(getNimBaseHeaderPath()));
			// PublicIncludePaths.Add("/Volumes/Store/Nim/lib");
		}


		bUseUnity = false;
	}

	void NimbleSetup() {
		var processInfo = new ProcessStartInfo();
		processInfo.WorkingDirectory = PluginDirectory;
		Console.WriteLine("Running nimble setup in", PluginDirectory);
		processInfo.FileName = "nimble" + (Target.Platform == UnrealTargetPlatform.Win64 ? ".exe" : ""); 
		processInfo.Arguments = "ok";
		try {
			var process = Process.Start(processInfo);
			process.WaitForExit();
		}
		

		catch (Exception e) {
			Console.WriteLine("There was a problem trying to run nimble.");
			Console.WriteLine(e.Message);
			Console.WriteLine(e.StackTrace);
		}
	}

	//TODO Run buildlibs from here so the correct config/platform is picked when building
	void AddNimForUEDev() { //ONLY FOR WIN/MAC with EDITOR (dev) target
		NimbleSetup(); //Make sure NUE and Host are built
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
		
        setUEConfig(EngineDirectory, Target.Configuration.ToString(), Target.Platform.ToString(), Target.bBuildEditor);

		//PublicDefinitions.Add($"NIM_FOR_UE_LIB_PATH  \"{dynLibPath}\"");
		//TRY?
		try {
			//BuildNim();
			if (Target.Platform == UnrealTargetPlatform.Win64)
				setWinCompilerSettings(Target.WindowsPlatform.WindowsSdkVersion, Target.WindowsPlatform.CompilerVersion, Target.WindowsPlatform.ToolChainDir);
			Console.WriteLine(Target.WindowsPlatform.ToolChainDir);	
			Console.WriteLine(Target.WindowsPlatform.CompilerVersion);	
			//setUEConfig(
		}
		catch (Exception e) {
			Console.WriteLine("There was a problem trying to load Nim. Attention, make sure the EngineDir is set. Otherwise NimForUE wont compile.");
			Console.WriteLine(e.Message);
			Console.WriteLine(e.StackTrace);
			//TODO Print JSON Here
			
		}

	}
	

	void BuildNim(){
		var isWin = Target.Platform == UnrealTargetPlatform.Win64;
		var processInfo = new ProcessStartInfo();
		
		processInfo.WorkingDirectory = Path.Combine(PluginDirectory, "src", "buildscripts");
		if (isWin) {
			processInfo.FileName = "cmd.exe";
			processInfo.Arguments = "/c buildlibs.bat";
		}
		else {
			processInfo.FileName = "sh";
			processInfo.Arguments = "buildlibs.sh";
		}
		//
		var process = Process.Start(processInfo);
		process.WaitForExit();
		}
}

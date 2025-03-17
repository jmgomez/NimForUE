using System;
using System.IO;
using System.Runtime.InteropServices;
using UnrealBuildTool;

public class NimForUEBindings : ModuleRules
{
	// Windows-specific
	[DllImport("kernel32.dll")]
	static extern bool SetDllDirectory(string lpPathName);

	// Store the library handle for macOS
	private static IntPtr macLibHandle = IntPtr.Zero;

	// macOS-specific there is no SetDllDirectory for macos. So we need to use dlopen to load the library and get function pointers
	[DllImport("libdl.dylib")]
	static extern IntPtr dlopen(string path, int mode);

	[DllImport("libdl.dylib")]
	static extern IntPtr dlsym(IntPtr handle, string symbol);

	[DllImport("libdl.dylib")]
	static extern string dlerror();

	// Constants for dlopen
	const int RTLD_LAZY = 1;
	const int RTLD_NOW = 2;
	const int RTLD_GLOBAL = 8;


	[UnmanagedFunctionPointer(CallingConvention.Cdecl)]
	private delegate IntPtr GetGameModulesDelegate(bool withEditor);

	// Function delegates
	private static GetGameModulesDelegate getGameModules_Delegate;

	// Windows imports
	[DllImport("hostnimforue", CallingConvention = CallingConvention.Cdecl)]
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
			// For macOS, use dlopen to load the library and get function pointers
			dynLibPath = Path.Combine(nimBinPath, "libhostnimforue.dylib");
			
			// Load the library
			macLibHandle = dlopen(dynLibPath, RTLD_NOW | RTLD_GLOBAL);
			if (macLibHandle == IntPtr.Zero) {
				string error = dlerror();
				Console.WriteLine($"Error loading library: {error}");
				throw new Exception($"Failed to load library: {error}");
			}
			
			IntPtr getModulesPtr = dlsym(macLibHandle, "getGameModules");
			if (getModulesPtr == IntPtr.Zero) {
				string error = dlerror();
				Console.WriteLine($"Error finding getGameModules: {error}");
			} else {
				getGameModules_Delegate = Marshal.GetDelegateForFunctionPointer<GetGameModulesDelegate>(getModulesPtr);
			}
			
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
		// Get game modules
		IntPtr modulesPtr;
		if (Target.Platform == UnrealTargetPlatform.Win64) {
			modulesPtr = getGameModules(Target.bBuildEditor);
		} else {
			if (getGameModules_Delegate != null) {
				modulesPtr = getGameModules_Delegate(Target.bBuildEditor);
			} else {
				Console.WriteLine("getGameModules delegate is null!");
				modulesPtr = IntPtr.Zero;
			}
		}
		
		if (modulesPtr != IntPtr.Zero) {
			var gameModulesStr = Marshal.PtrToStringAnsi(modulesPtr);
			
			if (!String.IsNullOrEmpty(gameModulesStr)) {
				var nimGameModules = gameModulesStr.Split(",");
				foreach (var m in nimGameModules) {
					Console.WriteLine("Adding Nim Module:: " + m);
				}
				PublicDependencyModuleNames.AddRange(nimGameModules);
			}
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




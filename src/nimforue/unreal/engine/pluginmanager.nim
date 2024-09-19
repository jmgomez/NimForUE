include ../definitions
import std/[strformat]
import ../core/math/vector
import ../coreuobject/[uobject, coreuobject, nametypes, tsoftobjectptr, scriptdelegates]
import ../core/[delegates, templates, net]
import ../core/containers/[unrealstring, array, set]


type
  FModuleManager {.importcpp.} = object
  FModuleStatus {.importcpp.} = object
    name {.importcpp:"Name".}: FString
    bIsLoaded {.importcpp.}: bool
  IPluginManager* {.importcpp.} = object  
  IPlugin* {.importcpp.} = object  
  EHostType* {.importcpp:"EHostType::Type".} = enum
     #Loads on all targets, except programs.
    Runtime,
    #Loads on all targets, except programs and the editor running commandlets.
    RuntimeNoCommandlet,
    #Loads on all targets, including supported programs.
    RuntimeAndProgram,
    # Loads only in cooked games.
    CookedOnly,
    # Only loads in uncooked games.
    UncookedOnly,
    # Deprecated due to ambiguities. Only loads in editor and program targets, but loads in any editor mode (eg. -game, -server).
    # Use UncookedOnly for the same behavior (eg. for editor blueprint nodes needed in uncooked games), or DeveloperTool for modules
    # that can also be loaded in cooked games but should not be shipped (eg. debugging utilities).
    Developer,
    # Loads on any targets where bBuildDeveloperTools is enabled.
    DeveloperTool,
    # Loads only when the editor is starting up.
    Editor,
    # Loads only when the editor is starting up, but not in commandlet mode.
    EditorNoCommandlet,
    # Loads only on editor and program targets
    EditorAndProgram,
    # Only loads on program targets.
    Program,
    # Loads on all targets except dedicated clients.
    ServerOnly,
    # Loads on all targets except dedicated servers.
    ClientOnly,
    # Loads in editor and client but not in commandlets.
    ClientOnlyNoCommandle
  FModuleDescriptor* {.importcpp.} = object
    name* {.importcpp:"Name".}: FName
    typ* {.importcpp:"Type".}: EHostType
  FPluginDescriptor* {.importcpp.} = object  
    modules*{.importcpp:"Modules".}: TArray[FModuleDescriptor]

proc getName*(plugin: TSharedPtr[IPlugin]): FString {.importcpp:"#->GetName()".}
proc getDescriptor*(plugin: TSharedPtr[IPlugin]): var FPluginDescriptor {.importcpp:"#->GetDescriptor()".}
proc getModuleOwnerPlugin*(pluginManager: ptr IPluginManager, moduleName: FName): TSharedPtr[IPlugin] {.importcpp:"#->GetModuleOwnerPlugin(@)".}


proc queryModules*(mm: ptr FModuleManager, outModules {.byref.}: TArray[FModuleStatus]) {.importcpp:"#->QueryModules(#)".}
proc queryModule*(mm: ptr FModuleManager, name: FName, outModule: out FModuleStatus) {.importcpp:"#->QueryModule(@)".}
proc loadModule*(mm: ptr FModuleManager, name: FName): pointer {.importcpp:"#->LoadModule(@)".}

- compile_nimforue.bat
  -- arguments for nim stdlib files in the bat script generated with --genscript in nimble
  -- Remove /Fp and /Yu arguments
 
- config.nims
  -- obj files created by UnrealBuildTool need inclusion for the linker
  -- examples:
   "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\Module.NimForUEBindings.gen.cpp.obj" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\Default.rc2.res" "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h.obj"

-- config.nims
  -- ignore the flags for copylib /Yu /Fp

- definitions.nim
  - add conditional pch support for the emit of headers
  - {.emit: """/*INCLUDESECTION*/
#include "D:\unreal-projects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUEBindings\PCH.NimForUEBindings.h"
//include "G:\Dropbox\GameDev\UnrealProjects\NimForUEDemo\Plugins\NimForUE\Intermediate\Build\Win64\UnrealEditor\Development\NimForUE\PCH.NimForUE.h"
#include "Definitions.NimForUE.h"
//#include "Definitions.NimForUEBindings.h"
#include "UEDeps.h"
//#include "PCH.NimForUE.h"
""".}

- NimForUE.nimble
  -- update the task to modify the bat file
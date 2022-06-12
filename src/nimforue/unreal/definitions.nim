#[This file only contains definitions and headers.
Cant include modules because it's used from the modules itself. 
The file that mixes them is prelude which is not used inside the unreal directory.
]#
{.emit: """/*INCLUDESECTION*/

#include "Definitions.NimForUE.h"
#include "Definitions.NimForUEBindings.h"
#include "UEDeps.h"

""".}



# We need to disable C4101 for MSVC because Unreal headers elevates the warning to an error
# using #pragma warning(error: ...)
# and Nim sometimes generates variables without referencing them, e.g. exception handling.
when defined(vcc):
    {.emit: """
#pragma warning(disable: 4101) 
""".}
 
# CompileArgs: -arm64 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++  -fmessage-length=0 -pipe -fpascal-strings -fexceptions -DPLATFORM_EXCEPTIONS_DISABLED=0 -fasm-blocks -fvisibility-ms-compat -fvisibility-inlines-hidden -Wall -Werror -Wdelete-non-virtual-dtor -Wno-range-loop-analysis   -Wshadow -Wundef -c -arch x86_64 -isysroot "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX12.3.sdk" -mmacosx-version-min=10.15 -O3 -gdwarf-2
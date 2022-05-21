#This module is only used for testing


{.push header: "RequiredProgramMainCPPInclude.h".}

type FEngineLoop* {. importcpp: "FEngineLoop", inheritable, pure .} = object

proc makeFEngineLoop*() : FEngineLoop {.importcpp: "FEngineLoop()" .}

proc preInit*(engineLoop:FEngineLoop) : void {. importcpp: """#.preInit("")""".}

{.pop.}
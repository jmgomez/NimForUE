
#Misc types that lives inside core


type FArchive* {.importcpp .} = object


proc makeFArchive*(): FArchive {.importcpp: "'0()", constructor.}
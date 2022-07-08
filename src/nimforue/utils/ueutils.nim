import std/[options, strutils, sequtils, sugar]



#utils specifics to unreal used accross the project

proc extractTypeFromGenericInNimFormat*(str, genericType :string) : string = 
    str.replace(genericType, "").replace("[").replace("]", "")
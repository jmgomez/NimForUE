import std/[options, strutils, sequtils, sugar]



#utils specifics to unreal used accross the project

proc extractTypeFromGenericInNimFormat*(str, genericType :string) : string = 
    str.replace(genericType, "").replace("[").replace("]", "")

proc extractKeyValueFromMapProp*(str:string) : seq[string] = 
    str.extractTypeFromGenericInNimFormat("TMap").split(",")
       .map(s=>strip(s))
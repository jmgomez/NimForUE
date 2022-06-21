import std/[options, strutils, sequtils, sugar]


proc spacesToCamelCase*(str:string) :string = 
    str.split(" ")
       .map(str => ($str[0]).toUpper() & str.substr(1))
       .foldl(a & b, "")
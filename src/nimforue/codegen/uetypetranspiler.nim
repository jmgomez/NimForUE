# import ../nimforue/codegen/[models]
import ../buildscripts/nimcachebuild
import std/[strutils, strformat, os]



func getHeaderContent() : string = 
  """
  #pragma once
//Header file 
struct MyStructFromCpp {
  int a;
  int b;
  int c;
};

MyStructFromCpp add10ToC(MyStructFromCpp other);


int helloWorldFromCpp();



"""


func getCppContent() : string  = 
  """
//CPP Content 
//# include <iostream>
#include "UETypeTranspiled.h"


int helloWorldFromCpp(){
  return 1200;
 
}
MyStructFromCpp add10ToC(MyStructFromCpp other) {
  MyStructFromCpp structFromCpp;
  structFromCpp.c = 10 + other.c;
  return structFromCpp;
};

"""



let headerDir =  absolutePath("./NimHeaders/")
let headerPath = headerDir / "UETypeTranspiled.h"
let cppDir = "./.uetypetranspiler"
let cppPath = cppDir / "UETypeTranspiled.cpp"
let objDir = "./.nimcache/runuetypetranspiler/"
createDir(cppDir)
writeFile(headerPath, getHeaderContent())
writeFile(cppPath, getCppContent())


echo $buildUETypeTranspiled(headerDir, cppPath, objDir)



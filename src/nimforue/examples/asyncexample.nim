
include unrealprelude

import std/asyncdispatch

uClass AAsyncActorExample of AActor:
  (BlueprintType, Blueprintable)
  ufuncs:
    proc beginPlay() = 
      proc asyncTest() {.async.} =
        self.printString("Hello! First this line should be printed", duration = 4)
        await sleepAsync(1000)
        self.printString "Goodbye! The last line should be printed", duration = 4
      
      asyncCheck asyncTest()
      printString(self, "Thi should be printed second", duration = 4)


      



include nue




proc gameExposeFn() : cint {.cdecl, dynlib, exportc.} = 20

uClass UTestGameCompilation of UObject:
    (BlueprintType, Blueprintable)
    uprop(BlueprintReadWrite):
      test : FString
      test2 : FString
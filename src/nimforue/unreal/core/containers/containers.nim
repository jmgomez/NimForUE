#common containers
import ../delegates
import unrealstring
type 
  FTSTicker* {.importcpp, pure.} = object
  FTickerDelegate* {.importc.}= TDelegateRetOneParam[bool, float32]



proc getCoreTicker*() : ptr FTSTicker {.importcpp: "(FTSTicker*)&FTSTicker::GetCoreTicker()".}


proc addTicker*(ticker:FTSTicker, delegate: FTickerDelegate, delay: float32 = 0.0) : FDelegateHandle {.importcpp: "#.AddTicker(@)".}

# 	FDelegateHandle AddTicker(const TCHAR * InName, float InDelay, TFunction<bool(float)> Function);

# FDelegateHandle AddTicker(const TCHAR * InName, float InDelay, TFunction<bool(float)> Function);

proc addTicker*(ticker:FTSTicker, inName:FString, delay: float32 = 0.0, fn: proc(deltaTime:float32):bool) : FDelegateHandle {.importcpp: "#.AddTicker(*#, @)".}


proc removeTicker*(ticker:FTSTicker, handle:FDelegateHandle) {.importcpp: "#.RemoveTicker(@)".}
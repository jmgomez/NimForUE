#common containers
import ../delegates
import unrealstring
type 
  FTSTicker* {.importcpp, pure.} = object
  FTickerDelegate* {.importc.}= TDelegateRetOneParam[bool, float32]
  FTickerDelegateHandle* {.importc:"FTSTicker::FDelegateHandle".} = object


proc getCoreTicker*() : ptr FTSTicker {.importcpp: "(FTSTicker*)&FTSTicker::GetCoreTicker()".}


proc addTicker*(ticker:FTSTicker, delegate: FTickerDelegate, delay: float32 = 0.0) : FTickerDelegateHandle {.importcpp: "#.AddTicker(@)".}

# 	FDelegateHandle AddTicker(const TCHAR * InName, float InDelay, TFunction<bool(float)> Function);

# FDelegateHandle AddTicker(const TCHAR * InName, float InDelay, TFunction<bool(float)> Function);

proc addTicker*(ticker:FTSTicker, inName:FString, delay: float32 = 0.0, fn: proc(deltaTime:float32):bool) : FTickerDelegateHandle {.importcpp: "#.AddTicker(*#, @)".}


proc removeTicker*(handle:FTickerDelegateHandle) {.importcpp: "FTSTicker::RemoveTicker(#)".}
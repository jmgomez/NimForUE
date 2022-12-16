#common containers
import ../delegates

type 
  FTSTicker* {.importcpp, pure.} = object
  FTickerDelegate = TDelegateRetOneParam[bool, float32]

	# static FTSTicker& GetCoreTicker();

proc getCoreTicker*() : FTSTicker {.importcpp: "FTSTicker::GetCoreTicker()".}


proc addTicker*(delegate: FTickerDelegate, delay: float32 = 0.0) : FDelegateHandle {.importcpp: "AddTicker(@)".}


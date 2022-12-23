type
  ELogVerbosity* {.size: sizeof(uint8).} = enum
    NoLogging = 0,
    Fatal,
    Error,
    Warning,
    Display,
    Log,
    Verbose,
    All,
    NumVerbosity,
    VerbosityMask = 0xf,
    SetColor = 0x40,
    BreakOnLog = 0x80
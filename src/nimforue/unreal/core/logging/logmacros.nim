import ../containers/unrealstring
import std / [macros, strformat, strutils, genAsts]

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

when (NimMajor, NimMinor, NimPatch) >= (1, 9, 1):
  import std/[paths]

macro ueLogImpl*(category: untyped, verbosity: ELogVerbosity, msg: string): untyped =
  result = nnkStmtList.newTree()
  var fstr = genSym(nskLet, "fstr")
  fstr = genSym(nskLet, fstr.repr.replace("_", ""))

  when (NimMajor, NimMinor, NimPatch) >= (1, 9, 1):
    let lo = lineInfoObj(msg)
    let linfo = relativePath(lo.filename.Path, getProjectPath().Path).string & &"({lo.line})"
    let metaAst = genAst(fstr, linfo, msg):
      let fstr = makeFString(linfo & " - " & msg)
  else:
    let metaAst = genAst(fstr, msg):
      let pos = instantiationInfo()
      let linfo = "$1($2) " % [pos.filename, $pos.line]
      let fstr = makeFString(linfo & " " & msg)

  result.add(
    metaAst,
    nnkPragma.newTree(
      nnkExprColonExpr.newTree(ident("emit"), newStrLitNode(&"""UE_LOG({category.strVal}, {verbosity}, TEXT("%s"), *{fstr})"""))
    )
  )

macro declareLogCategory*(category: untyped, defaultVerbosity: ELogVerbosity = Log, compileTimeVerbosity: ELogVerbosity = All): untyped = 
  let loggers = genAst(category) do:
    template `category Log`*(msg: string) =
      ueLogImpl(category, Log, msg)
    template `category Warning`*(msg: string) =
      ueLogImpl(category, Warning, msg)
    template `category Error`*(msg: string) =
      ueLogImpl(category, Error, msg)

  result = nnkStmtList.newTree(
    nnkPragma.newTree(
      nnkExprColonExpr.newTree(ident("emit"), newStrLitNode(&"DECLARE_LOG_CATEGORY_EXTERN({category.strVal}, {defaultVerbosity}, {compileTimeVerbosity});"))
    ),
    loggers
  )

macro defineLogCategory*(category: untyped): untyped = 
  nnkPragma.newTree(
    nnkExprColonExpr.newTree(ident("emit"), newStrLitNode(&"DEFINE_LOG_CATEGORY({category.strVal});"))
  )
when defined(windows):
  import winlean
else:
  {.error: "not supported os".}


{.link:"user32.lib".}

type
  InputType = enum
    itMouse itKeyboard itHardware
  KeyEvent = enum
    keExtendedKey = 0x0001
    keKeyUp = 0x0002
    keUnicode = 0x0004
    keScanCode = 0x0008


  MouseInput {.importc: "MOUSEINPUT".} = object
    dx, dy: clong
    mouseData, dwFlags, time: culong
    dwExtraInfo: int # ULONG_PTR

  KeybdInput {.importc: "KEYBDINPUT".} = object
    wVk, wScan: cint
    dwFlags, time: culong
    dwExtraInfo: int

  HardwareInput {.importc: "HARDWAREINPUT".} = object
    uMsg: clong
    wParamL, wParamH: cint

  InputUnion {.union.} = object
    hi: HardwareInput
    mi: MouseInput
    ki: KeybdInput
  
  Input = object
    `type`: clong
    hwin: InputUnion
  
  LPINPUT {.importc.} = ptr object

converter toLPInput(input : ptr Input) : LPINPUT {.importcpp:"reinterpret_cast<LPINPUT>(#)".}

proc sendInput(total: cint, inp: LPINPUT, size: cint) {.importc: "SendInput", header: "<windows.h>".}

proc initKey(keycode: int): Input =
  result = Input(`type`: itKeyboard.clong)
  var keybd = KeybdInput(wVk: keycode.cint, wScan: 0, time: 0,
    dwExtraInfo: 0, dwFlags: 0)
  result.hwin = InputUnion(ki: keybd)

proc pressKey(input: var Input) =
  input.hwin.ki.dwFlags = keExtendedKey.culong
  sendInput(cint 1, addr input, sizeof(Input).cint)

proc releaseKey(input: var Input) =
  input.hwin.ki.dwFlags = keExtendedKey.culong or keKeyUp.culong
  sendInput(cint 1, addr input, sizeof(Input).cint)

proc pressRelease(input: var Input) =
  input.pressKey
  input.releaseKey

proc pressReleaseKeycode(input: var Input, code: int) =
  input.hwin.ki.wVk = code.cint
  input.pressRelease


type 
  Mutex  = object
    handle: uint
  AccessRights = uint8

proc openMutex*(name: cstring): pointer {.importcpp: "OpenMutexA(MAXIMUM_ALLOWED, 0, #)".}


proc isLiveCodingRunning*(): bool =
  const LiveCodingMutext = r"Global\LiveCoding_E++unreal_sources+5.1Launcher+UE_5.2+Engine+Binaries+Win64+UnrealEditor.exe"
  var mutex = openMutex(LiveCodingMutext)
  not mutex.isNil()
  # result = mutex.handle != 0

proc triggerLiveCoding*(waitMs:int32 = 50) =
  var
    shift = initKey 0xa0 # VK_LSHIFT
    key = initKey 0x48
    ctrl = initKey 0xa2 # VK_LCONTROL
    alt = initKey 0xa4 # VK_LMENU
    F11 = initKey 0x7a # VK_F11

  pressKey ctrl
  pressKey alt
  pressKey F11
  
  sleep(waitMs)

  releaseKey F11
  releaseKey alt
  releaseKey ctrl
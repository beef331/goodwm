import x11/[xlib, x]

const
  Alt* = Mod1Mask
  Super* = Mod4Mask
  Shift* = ShiftMask


type Key* = object
  code*: cuint
  modi*: cuint

func pressed*(key: Key, evt: XKeyPressedEvent): bool =
  key.code == evt.keycode and (evt.state and key.modi) == key.modi

func initKey*(d: PDisplay, key: string, mods: cuint): Key =
  let
    keySym = XStringToKeysym(key.cstring)
    code = XKeysymToKeycode(d, keySym).cuint
  Key(code: code, modi: mods)

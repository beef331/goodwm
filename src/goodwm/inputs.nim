import x11/[xlib, x]
import types
const
  Alt* = Mod1Mask
  Super* = Mod4Mask
  Shift* = ShiftMask

func initKey*(d: PDisplay, key: string, mods: cuint): Key =
  let
    keySym = XStringToKeysym(key.cstring)
    code = XKeysymToKeycode(d, keySym).cuint
  Key(code: code, modi: mods)

func initKey*(code: cuint, mods: cuint): Key = Key(code: code, modi: mods)

func initButton*(btn: range[1..5], modi: cuint): Button = Button(btn: btn, modi: modi)

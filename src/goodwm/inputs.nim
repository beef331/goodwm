import x11/[xlib, x]
import std/strutils
import types
const
  Alt* = Mod1Mask
  Super* = Mod4Mask
  Shift* = ShiftMask
  Control* = ControlMask

func initKey*(d: PDisplay, key: string, mods: cuint): Key =
  let
    keySym = XStringToKeysym(key.cstring)
    code = XKeysymToKeycode(d, keySym).cuint
  Key(code: code, modi: mods)

func initKey*(code: cuint, mods: cuint): Key = Key(code: code, modi: mods)

func initButton*(btn: range[1..5], modi: cuint): Button = Button(btn: btn, modi: modi)

func initShortcut*(evt: KeyEvent): Shortcut =
  Shortcut(kind: function, event: evt)

func initShortcut*(cmd: string): Shortcut =
  var args = cmd.split(" ")
  let cmd = args[0]
  args = args[1..^1]
  Shortcut(kind: command, cmd: cmd, args: args)

func initShortcut*(kind: TargettedShortcuts, ind: int): Shortcut =
  result = Shortcut(kind: kind, targetScreen: ind)

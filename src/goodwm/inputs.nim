import x11/[xlib, x]

const
  Alt* = Mod1Mask
  Super* = Mod4Mask
  Shift* = ShiftMask


type
  Key* = object
    code*: cuint
    modi*: cuint
  Button* = object
    btn*: range[1..5]
    modi*: cuint

func pressed*(key: Key, evt: XKeyPressedEvent): bool =
  key.code == evt.keycode and (evt.state and key.modi) == key.modi

func pressed*(btn: Button, evt: XButtonEvent): bool =
  btn.btn.cuint == evt.button and (btn.modi and evt.state) == btn.modi

func initKey*(d: PDisplay, key: string, mods: cuint): Key =
  let
    keySym = XStringToKeysym(key.cstring)
    code = XKeysymToKeycode(d, keySym).cuint
  Key(code: code, modi: mods)

func initKey*(code: cuint, mods: cuint): Key = Key(code: code, modi: mods)

func initButton*(btn: range[1..5], modi: cuint): Button = Button(btn: btn, modi: modi)

import x11/[xlib]


type Key* = object
    code*: cuint
    modi*: cuint

func pressed*(key: Key, evt: XKeyPressedEvent): bool = 
  key.code == evt.keycode and (evt.state and key.modi) == key.modi
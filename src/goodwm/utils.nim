import std/macros

macro getOwnerName(arg: typed): untyped = newLit $arg.owner
macro printIt(name: string, args: typed): untyped =
  result = newCall("echo", name)
  for arg in args:
    result.add arg

when not defined(release):
  template debugInfo*(args: varargs[typed, `$`]) =
    proc injectedName () = discard
    printIt (getOwnerName(injectedName) & ": "), args
else:
  template debugInfo*(args: varargs[typed, `$`]) = discard


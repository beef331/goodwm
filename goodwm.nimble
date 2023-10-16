# Package

version       = "0.0.1"
author        = "Jason"
description   = "Medicore Window Manager"
license       = "MIT"
srcDir        = "src"
bin           = @["goodwm"]



# Dependencies

requires "nim >= 1.1.1"
requires "x11"
requires "vmath"
requires "bumpy"
requires "slicerator"
requires "pixie"
requires "sdl2_nim >= 2.0.14.1"
requires "toml_serialization >= 0.2.0"
requires "notify >= 0.1.5"

task demo, "Makes and tests the binary":
  exec "nimble build -d:debug"
  try:
    exec "killall Xephyr"
  except: discard
  exec "bash Xephyr :5 -softCursor -screen 1280x720 & sleep 1; DISPLAY=:5 ./goodwm"

task demor, "Makes and tests the binary":
  exec "nimble build -d:danger"
  exec "bash -c 'Xephyr :5 -softCursor -screen 1280x720 & sleep 1; DISPLAY=:5 ./goodwm'"

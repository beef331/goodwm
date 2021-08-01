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

task demo, "Makes and tests the binary":
  exec "nimble build"
  exec "Xephyr :5 -screen 1280x720 & sleep 1; DISPLAY=:5 ./goodwm"
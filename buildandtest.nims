#!/usr/bin/env nim
mode = ScriptMode.Silent

exec "nim c ./goodwm.nim"
exec "Xephyr :5 & sleep 1; DISPLAY=:5 ./goodwm"
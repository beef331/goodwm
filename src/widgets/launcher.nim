import ../widget
import ../config
import nimgl/imgui
import ../widgetEvents
import os
import strutils

type
    Launcher = ref object of Widget

let
    name = "Launcher"

proc draw(fontSize,bwidth,bheight:float32)=

    let width = igCalcTextSize(name).x
    igSameLine(bwidth/2 - width)
    if(igButton(name)): discard execShellCmd("rofi -show run")

proc newLauncher*():Launcher = Launcher(draw : draw)
 
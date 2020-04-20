import ../widget
import ../config
import nimgl/imgui
import ../widgetEvents
import os

type
    Launcher = ref object of Widget

proc draw(fontSize,bwidth,bheight:float32)=
    
    igSameLine(0,0)
    var size = igCalcTextSize("Launcher")
    igSetCursorPosX(bwidth/2 - size.x/2)
    igSetCursorPosY(bheight/2 - size.y/2)
    if(igButton("Launcher")): discard execShellCmd("rofi -show run")
    igSameLine(0,0)

proc newLauncher*():Launcher = Launcher(draw : draw)
 
import ../widget
import ../config
import nimgl/imgui
import ../widgetEvents
import osproc
import strutils
import strformat

type
    VolumeSlider = ref object of Widget

let 
    getVolCommand = "pulsemixer --get-volume"
    setVolCommand = "pulsemixer --set-volume"
var 
    vol : int32

proc draw(fontSize,bwidth,bheight:float32)=
    vol = parseInt(execProcess(getVolCommand).split(" ")[0]).int32

    var style = igGetStyle()


    igSameLine(0,0)

    igSetCursorPosX(bwidth * 0.6)
    igSetCursorPosY(0)
    if(igSliderInt("", addr vol,0, 100)):
        discard execProcess(fmt"{setVolCommand} {vol}")
    igSameLine(0,0)

proc newVolumeSlider*():VolumeSlider = VolumeSlider(draw : draw)
 
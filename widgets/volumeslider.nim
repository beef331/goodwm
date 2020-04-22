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

    igPushItemWidth(100)
    if(igSliderInt("", addr vol,0, 100,format = "Vol:%d%%")):
        discard execProcess(fmt"{setVolCommand} {vol}")

proc newVolumeSlider*():VolumeSlider = VolumeSlider(draw : draw)
 
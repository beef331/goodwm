import ../widget
import ../config
import nimgl/imgui
import times
import osproc

type
    TimeWidget = ref object of Widget

var 
    lastT : float
    delay : float = 1
    time : string

proc draw(fontSize,bwidth,bheight:float32)=
    igSameLine(0,0)
    if(cpuTime()-lastT >= delay):
        lastT = cpuTime()
        time = execProcess("date +'%a %b %d,%l:%M%P%t'")
    let offset = igCalcTextSize(time).x
    igSetCursorPosX(bwidth - offset)
    igSetCursorPosY(0)
    igText(time)
    

proc newTimeWidget*():TimeWidget = TimeWidget(draw : draw)
 
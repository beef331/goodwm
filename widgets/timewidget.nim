import ../widget
import ../config
import nimgl/imgui
import times
import osproc
import strutils

type
    TimeWidget = ref object of Widget

var 
    lastT : float = 0
    delay : float = 1
    time : string

proc draw(fontSize,bwidth,bheight:float32)=

    if(epochTime()-lastT >= delay):
        lastT = epochTime()
        time = execProcess("date +'%a %b %d,%l:%M%P%t'")
    let width = igCalcTextSize(time).x
    let remaining = igGetContentRegionAvail().x
    let label = repeat(' ',int((remaining - width)/igCalcTextSize(" ").x)) & time
    igText(label)
    

proc newTimeWidget*():TimeWidget = TimeWidget(draw : draw)
 
import ../widget
import ../config
import nimgl/imgui
import times
import osproc

type
    TimeWidget = ref object of Widget

proc draw(fontSize,bwidth,bheight:float32)=
    igSameLine(0,0)

    let str = execProcess("date +'%a %b %d,%l:%M%P%t'")
    let offset = igCalcTextSize(str).x
    igSetCursorPosX(bwidth - offset)
    igSetCursorPosY(0)
    igText(str)
    

proc newTimeWidget*():TimeWidget = TimeWidget(draw : draw)
 
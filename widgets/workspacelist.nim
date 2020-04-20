import ../widget
import ../config
import nimgl/imgui
import ../widgetEvents

type
    WorkspaceList = ref object of Widget

proc draw(fontSize,bwidth,bheight:float32)=
    
    igSameLine(0,0)
    igSetCursorPosX(0)
    igSetCursorPosY(0)
    for x in 0..<workspaceSymbols.len:
        if(igButton(workspaceSymbols[x],ImVec2(x:fontsize,y:bheight))): invokeGoToWorkspace(x)
        igSameLine(0,0)

proc newWorkspaceList*():WorkspaceList = WorkspaceList(draw : draw)
 
import tables
import os
type
    Action* = enum
        MoveLeft,MoveRight,CloseWindow,Launcher
    Layout* = enum
        LeftAlternating,LeftSpiral,Horizontal,Vertical

var
    keycodeAction = initTable[cuint,Action]()
    actionProc = initTable[Action,proc()]()
    screenLayout = initTable[int,Layout]()


proc addAction*(a:Action,p : proc())=
    actionProc.add(a,p)

proc doKeycodeAction*(key : cuint)=
    if(keycodeAction.contains(key) and actionProc.contains(keycodeAction[key])):
        actionProc[keycodeAction[key]]()

proc getScreenLayout*(screen : int):Layout = 
    if(screenLayout.contains(screen)): return screenLayout[screen]
    return Horizontal


proc loadConfig()=
    keycodeAction.add(113,MoveLeft)
    keycodeAction.add(114,MoveRight)
    keycodeAction.add(111,Launcher)
    addAction(Launcher,proc()= discard execShellCmd("rofi -combi-modi window,drun -show combi -modi combi"))

    screenLayout.add(0,LeftAlternating)
    screenLayout.add(1,Horizontal)

loadConfig()
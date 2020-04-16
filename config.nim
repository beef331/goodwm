import tables
type
    Action* = enum
        MoveLeft,MoveRight,CloseWindow,Command




var
    keycodeAction = initTable[cuint,Action]()
    actionProc = initTable[Action,proc()]()

proc loadConfig()=
    keycodeAction.add(113,MoveLeft)
    keycodeAction.add(114,MoveRight)

proc addAction*(a:Action,p : proc())=
    actionProc.add(a,p)

proc doKeycodeAction*(key : cuint)=
    if(keycodeAction.contains(key) and actionProc.contains(keycodeAction[key])):
        actionProc[keycodeAction[key]]()
loadConfig()
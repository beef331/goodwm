import tables
import os
import osproc
import x11/x
import x11/xlib

type
    #These are for WM actions customizabillity
    Action* = enum
        MoveLeft,
        MoveRight,
        CloseWindow,
        MoveToWorkspace,
        MoveScreenLeft,
        MoveScreenRight,
        FocusScreenRight,
        FocusScreenLeft,
        FocusRight,
        FocusLeft,
        MakeMain
    Layout* = enum
        LeftAlternating,LeftSpiral,Horizontal,Vertical
    KeyConfig* = ref object
        modifiers* : cint
        keycode* : cuint
        action* : proc()


var
    actionToConfigs = initTable[Action,KeyConfig]()
    keyConfigs : seq[KeyConfig]
    screenLayout = initTable[int,Layout]()

const workspaceSymbols* = @["1","2","3","4","5","6","7","8","9"]

proc newKeyConfig*(keycode : cuint,mods:cint,action : proc()): KeyConfig=
    return KeyConfig(keycode:keycode,modifiers:mods,action:action)

proc addInput*(a: KeyConfig)=
    keyConfigs.add(a)

proc doKeycodeAction*(key : cuint,mods : cint)=
    for x in keyConfigs:
        if(x.keycode == key and x.modifiers == mods):
            if(x.action != nil):
                x.action()
                return

proc getActionConfig*(a : Action): KeyConfig = 
    if(actionToConfigs.contains(a)): result = actionToConfigs[a] else: result = nil

proc getScreenLayout*(screen : int):Layout = 
    if(screenLayout.contains(screen)): return screenLayout[screen]
    return Horizontal


proc loadConfig* (display : PDisplay)=
    var launcherCode = XKeysymToKeycode(display, XStringToKeysym("d")).cuint
    var launcherCfg = newKeyConfig(launcherCode,Mod4Mask,proc()= discard execShellCmd("rofi -show run"))
    addInput(launcherCfg)

    var moveLeft = newKeyConfig(113,Mod4Mask or ShiftMask,nil)
    var moveRight = newKeyConfig(114,Mod4Mask or ShiftMask,nil)
    var focusLeft = newKeyConfig(113,Mod4Mask,nil)
    var focusRight = newKeyConfig(114,Mod4Mask,nil)
    var moveScreenFocusRight = newKeyConfig(113,Mod4Mask or ControlMask or ShiftMask,nil)
    var moveScreenFocusLeft = newKeyConfig(114,Mod4Mask or ControlMask or ShiftMask,nil)
    var makeMain = newKeyConfig(58,ControlMask or Mod4Mask,nil)
    var moveScreenRight = newKeyConfig(113,Mod4Mask or ControlMask,nil)
    var moveScreenLeft = newKeyConfig(114,Mod4Mask or ControlMask,nil)
    var closeWindow = newKeyConfig(24,Mod4Mask or ShiftMask,nil)


    addInput(moveLeft)
    addInput(moveRight)
    addInput(focusLeft)
    addInput(focusRight)
    addInput(makeMain)
    addInput(moveScreenRight)
    addInput(moveScreenLeft)
    addInput(closeWindow)
    addInput(moveScreenFocusLeft)
    addInput(moveScreenFocusRight)

    actionToConfigs.add(MoveLeft,moveLeft)
    actionToConfigs.add(MoveRight,moveRight)
    actionToConfigs.add(FocusLeft,focusLeft)
    actionToConfigs.add(FocusRight,focusRight)
    actionToConfigs.add(MakeMain,makeMain)
    actionToConfigs.add(MoveScreenRight,moveScreenRight)
    actionToConfigs.add(MoveScreenLeft, moveScreenLeft)
    actionToConfigs.add(CloseWindow,closeWindow)
    actionToConfigs.add(FocusScreenLeft,moveScreenFocusLeft)
    actionToConfigs.add(FocusScreenRight,moveScreenFocusRight)



    screenLayout.add(0,LeftAlternating)
    screenLayout.add(1,Vertical)

proc keyConfs* : seq[KeyConfig] = keyConfigs


proc runScript*()=
    discard execShellCmd("nim ~/goodwm/init.nims")


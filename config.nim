import tables
import os
import osproc
import x11/x
import x11/keysym
import x11/xlib
import json
import strutils
import tables
import strformat

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
        MakeMain,
        MakeFullScreen,
        MakeFloating,
        ReloadConfig,
        NoAction
    Layout* = enum
        LeftAlternating,
        RightAlternating,
        #Probably wont have this one 
        LeftSpiral,
        Horizontal,
        LeftMaster,
        RightMaster,
        Vertical

    KeyConfig* = ref object
        modifiers* : cint
        keycode* : cuint
        desc* : string
        action* : proc()


var
    actionToConfigs = initTable[Action,KeyConfig]()
    keyConfigs : seq[KeyConfig]
    screenLayout = initTable[int,Layout]()
    borderSize* : cint = 3
    

const workspaceSymbols* = @["1","2","3","4","5","6","7","8","9"]
const configPath = "/home/jason/goodwm/goodwm.json"

const modStringToModVal = {"Shift": ShiftMask,"Control" : ControlMask, "Alt" : Mod1Mask, "Super" : Mod4Mask, "Caps" : LockMask}.toTable
const keyToXKeys = {"left" : XK_Left, "right": XK_Right, "up" : XK_Up, "down" : XK_down}.toTable
 
proc newKeyConfig*(keycode : cuint,mods:cint,action : proc()): KeyConfig=
    return KeyConfig(keycode:keycode,modifiers:mods,action:action)

proc newKeyConfig(node : JsonNode,display : PDisplay): (Action,KeyConfig)=
    if(node.contains("command") and node.contains("key")):
            var config = KeyConfig()
            try:
                let action = parseEnum[Action](node["command"].getStr())
                result[0] = action
            except:
                result[0] = NoAction
                config.action = proc() = discard execShellCmd(node["command"].getStr())


            let keys = node["key"].getStr().split("+")
            for x in keys:
                if(modStringToModVal.contains(x)): config.modifiers = config.modifiers or modStringToModVal[x].cint
                elif(keyToXKeys.contains(x.toLower())) : config.keycode = XKeysymToKeycode(display,keyToXKeys[x.toLower()]).cuint
                else :  config.keycode = XKeysymToKeycode(display,XStringToKeysym(x.toLower())).cuint
            if(node.contains("desc")): config.desc = node["desc"].getStr()
            result[1] = config


proc addInput*(a: KeyConfig)=
    keyConfigs.add(a)

proc doKeycodeAction*(key : cuint,mods : cint)=
    for x in keyConfigs:
        if(x.keycode == key and x.modifiers == mods):
            if(x.action != nil):
                x.action()
                return

proc addActionToConfig*(a : Action, b : proc()) = 
    if(actionToConfigs.contains(a)): actionToConfigs[a].action = b 

proc getScreenLayout*(screen : int):Layout = 
    if(screenLayout.contains(screen)): return screenLayout[screen]
    return Horizontal


proc loadConfig* (display : PDisplay)=
    screenLayout.clear()
    keyConfigs.setLen(0)
    actionToConfigs.clear()

    let file = open(configPath,fmread)
    let cfgJson = parseJson(file.readAll())
    file.close()

    for x in cfgJson["keyconfigs"]:
        let actionKeyConf = newKeyConfig(x,display)
        if(actionKeyConf[0] != NoAction):actionToConfigs.add(actionKeyConf[0],actionKeyConf[1])
        addInput(actionKeyConf[1])
    
    var index = 0
    for x in cfgJson["screenlayout"]:
        try:
            let layout = parseEnum[Layout](x.getStr())
            screenLayout.add(index,layout)
            inc(index)
        except:
            echo fmt"{x.getStr()} offers an incorrect layout, refer to docs."

    let theme = cfgJson["theme"]
    if(theme["border-size"] != nil):
        borderSize = theme["border-size"].getInt().cint


proc keyConfs* : seq[KeyConfig] = keyConfigs


proc runScript*()=
    discard execShellCmd("nim ~/goodwm/init.nims")


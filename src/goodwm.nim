import x11/[xlib, x, xutil,xatom]
import strformat
import strutils
import config
import osproc
import nre
import statusbar
import widgetEvents
import widgets/[workspacelist, launcher, timewidget, volumeslider]
import os
import times
import sugar

converter toCint(x: TKeyCode): cint = x.cint
converter int32toCint(x: int32): cint = x.cint
converter int32toCUint(x: int32): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool
proc `!`(x:bool): bool = not x

type
    Window = ref object of RootObj
        rawWindow: TWindow
        fullScreen : bool
    FloatingWindow = ref object of Window
        x, y, minw, maxw, minh, maxh: cint
    Workspace = ref object of RootObj
        windows: seq[Window]
        activeWindow: int
    Screen = ref object of RootObj
        width, height, xOffset, yOffset: cint
        drawMode: proc()
        activeWorkspace: int
        workspaces: seq[Workspace]
        barWin: TWindow
        bar: Bar
    MouseState = enum
        Nothing, Resizing, Moving

var
    display: PDisplay
    root: TWindow
    running: bool = true
    screen: cint
    screens: seq[Screen]
    selected = 0
    statusBarHeight: int32 = 30
    mouseState = Nothing


proc wincount(a: Workspace): int = a.windows.len
proc activeTWindow(a: Workspace): TWindow =
    if(a.activeWindow in 0..<a.windows.len):
        a.windows[a.activeWindow].rawWindow
    else: root


proc `[]=`(w: Workspace, index: int, win: Window) = w.windows[index] = win

proc `[]`(w: Workspace, index: int): Window = w.windows[index]

proc `[]`(s: var Screen, index: int): var Workspace = s.workspaces[index]


let eventMask = StructureNotifyMask or
                SubstructureRedirectMask or
                SubstructureNotifyMask or
                ButtonPressMask or
                PointerMotionMask or
                EnterWindowMask or
                LeaveWindowMask or
                PropertyChangeMask or
                KeyPressMask or
                KeyReleaseMask

proc selectedScreen: var Screen = screens[selected]

proc selectedWorkspace: var Workspace = selectedScreen().workspaces[
        selectedScreen().activeWorkspace]

proc activeWorkspaceIsEmpty(): bool = selectedWorkspace().wincount() == 0

proc activeTWindow: TWindow = selectedWorkspace().activeTWindow
proc activeWindow: Window = selectedWorkspace()[selectedWorkspace().activeWindow]

proc isTiled(w: Window): bool = not (w of FloatingWindow)

proc tiledWindowCount (w: Workspace): int =
    for x in w.windows:
        if(x.isTiled): inc(result)

proc getActiveWorkspace(s: var Screen): var Workspace = s[s.activeWorkspace]

proc isNotBar(w: TWindow): bool =
    for screen in screens:
        if(w == screen.barWin): return false
    return true

proc inCurrentSpace(w: TWindow): bool =
    for x in selectedWorkspace().windows:
        if(x.rawWindow == w): return true

proc getFocus(moveCursor: bool = false) =
    if(activeWorkspaceIsEmpty() or not selectedWorkspace().activeWindow in 0..<selectedWorkspace().wincount): return

    if(moveCursor):
        var winAttr = TXWindowAttributes()
        discard XGetWindowAttributes(display, activeTWindow(), winAttr.addr)
        discard XWarpPointer(display,None,activeTWindow(),0,0,0,0,winAttr.width.div(2),winAttr.height.div(2))

proc drawBar(scr: Screen) =
    let barX: cint = scr.xOffset
    let barY: cint = scr.yOffset + scr.height - statusBarHeight
    discard XMoveResizeWindow(display, scr.barWin, barX, barY, scr.width.cint, statusBarHeight)

proc drawHorizontalTiled() =
    ##Make windows horizontally tiled
    let workspace = selectedWorkspace()
    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    var
        selScreen = selectedScreen()
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = cint(selScreen.width.div(workspace.tiledWindowCount))
        height = selScreen.height - statusBarHeight

    for i in 0..<workspace.wincount:
        if(workspace.windows[i].isTiled):
            x += width
            discard XMoveResizeWindow(display, workspace.windows[i].rawWindow,
                    x, y, width, height)
    selScreen.drawBar()

proc drawVerticalTiled() =
    ##Make windows horizontally tiled
    let workspace = selectedWorkspace()
    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    var
        selScreen = selectedScreen()
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = selScreen.width
        height = cint((selScreen.height - statusBarHeight).div(
                workspace.windows.len))

    for i in 0..<workspace.wincount:
        let window = workspace[i]
        if(window.isTiled):
            if(i > 0): y += height
            discard XMoveResizeWindow(display, window.rawWindow, x + borderSize, y + borderSize, width - borderSize*2, height - borderSize*2)

    selScreen.drawBar()

proc drawAlternatingSplit(rightMain : bool = false) =
    ##Draw Main left with alternating split

    let workspace = selectedWorkspace()

    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    let selScreen = selectedScreen()
    const flag: cuint = CWX or CWY or CWWidth or CWHeight

    var winVals = TXWindowChanges()

    var
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = selScreen.width
        height = selScreen.height - statusBarHeight

    var splitVert = true
    let tiledCount = workspace.tiledWindowCount-1
    var drawnWindows = 0
    for i in 0..<workspace.wincount:
        let window = workspace[i]
        if(window.fullScreen):
            discard XMoveResizeWindow(display,window.rawWindow,selScreen.xOffset,selScreen.yOffset,selScreen.width,selScreen.height)
            return #We have a full screen application we dont need to tile shit
        if(window.isTiled):
            let hasNext = (i + 1 < workspace.wincount) and (drawnWindows < tiledCount)
            if(splitVert):
                if(drawnWindows > 0): y += height
                if(hasNext): width = width.div(2)
            else:
                if(drawnWindows > 0): x += width
                if(hasNext): height = height.div(2)
            winVals.x = x + borderSize
            winVals.y = y + borderSize

            winVals.width = width - borderSize * 2
            winVals.height = height - borderSize * 2
            #If right is main screen.Width - x - width gives right position
            if(rightMain and tiledCount > 1):
                winVals.x = (selScreen.width - winVals.x - winVals.width) + selScreen.xOffset 


            discard XConfigureWindow(display, window.rawWindow, flag, winVals.addr)

            splitVert = not splitVert
            inc(drawnWindows)
        else: discard XRaiseWindow(display,window.rawWindow)

    selScreen.drawBar()

proc drawMainSplit(rightMain : bool = false) =
    ##Draw Main left/right with opposing side vertically stacked

    let workspace = selectedWorkspace()

    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    let selScreen = selectedScreen()
    const flag: cuint = CWX or CWY or CWWidth or CWHeight

    var winVals = TXWindowChanges()

    var
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = selScreen.width
        height = selScreen.height - statusBarHeight

    let tiledCount = workspace.tiledWindowCount-1
    var secondaryHeight = height
    if(tiledCount > 0): secondaryHeight = secondaryHeight.div(tiledCount).cint
    var drawnWindows = 0
    for i in 0..<workspace.wincount:
        let window = workspace[i]
        if(window.fullScreen):
            discard XMoveResizeWindow(display,window.rawWindow,selScreen.xOffset,selScreen.yOffset,selScreen.width,selScreen.height)
            return #We have a full screen application we dont need to tile shit
        if(window.isTiled):
            #All secondary windows are at the same x but only the window after the second tiled window is offset vertically
            if(drawnWindows > 0):
                x = width
                if(drawnWindows > 1): y += secondaryHeight
                height = secondaryHeight
            elif(tiledCount > 1):
                width = width.div(2)

            winVals.x = x + borderSize
            winVals.y = y + borderSize

            winVals.width = width - borderSize * 2
            winVals.height = height - borderSize * 2
            #If right is main screen.Width - x - width gives right position, only do this if we have more than 1 window
            if(rightMain and tiledCount > 1):
                winVals.x = (selScreen.width - winVals.x - winVals.width) + selScreen.xOffset 

            discard XConfigureWindow(display, window.rawWindow, flag, winVals.addr)
            inc(drawnWindows)

        else: discard XRaiseWindow(display,window.rawWindow)

    selScreen.drawBar()

proc moveWindowsHorz(right: bool = true) =
    if(selectedWorkspace().wincount() <= 1): return
    var workspace = selectedWorkspace()
    let sourceIndex = workspace.activeWindow
    let activeWin = workspace[sourceIndex]

    let dir = if(right): 1 else: -1

    let swapIndex = (sourceIndex + dir + workspace.wincount) %%
            workspace.wincount

    workspace.activeWindow = swapIndex
    workspace[sourceIndex] = workspace.windows[swapIndex]
    workspace[swapIndex] = activeWin
    selectedScreen().drawMode()
    getFocus(true)

proc moveWindowToScreen(right: bool = true) =
    if(activeWorkspaceIsEmpty()): return

    let activeWindow = activeWindow()
    let dir = if(right): 1 else: -1
    let index = selectedWorkspace().activeWindow
    selectedWorkspace().windows.delete(index)
    selectedWorkspace().activeWindow = 0

    selectedScreen().drawMode()

    selected = (selected + dir + screens.len) %% screens.len
    selectedWorkspace().windows.add(activeWindow)
    selectedWorkspace().activeWindow = selectedWorkspace().windows.high

    selectedScreen().drawMode()
    getFocus(true)

proc assignToActive(win: TWindow) =
    ##This will search all screens and assign the window as active in the tiling logic
    for x in 0..<screens.len:
        var screen = screens[x]
        var workspace = screen.getActiveWorkspace()

        for y in 0..<workspace.wincount:
            if(workspace[y].rawWindow == win):
                workspace.activeWindow = y
                selected = x
                return


proc focusScreen(right: bool = false) =
    ##Move cursor to screen and focus first window
    let dir = if(right): 1 else: -1
    selected = (selected + dir + screens.len) %% screens.len
    discard XWarpPointer(display, None, root, 0, 0, 0, 0, selectedScreen().width.div(
            2) + selectedScreen().xOffset, selectedScreen().height.div(2) +
            selectedScreen().yOffset)

proc makeFocusedMain() =
    ##When using main child setups this moves the window to index 0, will bring to top of vertical/horizontal tiles
    if(selectedWorkspace().wincount() < 1): return
    var workspace = selectedWorkspace()
    var temp = activeWindow()
    var focused = workspace.activeWindow
    workspace.windows[focused] = workspace.windows[0]
    workspace.windows[0] = temp
    workspace.activeWindow = 0
    selectedScreen().drawMode()
    getFocus(true)

proc moveFocusHorz(right: bool = true) =
    ##Move focus horizontally in the array either left or right
    if(selectedWorkspace().wincount() == 0): return
    var index = selectedWorkspace().activeWindow
    let dir = if(right): 1 else: -1
    index = (index + dir + selectedWorkspace().wincount()) %% selectedWorkspace().wincount()
    selectedWorkspace().activeWindow = index
    getFocus(true)

proc goToWorkspace(index: int) =
    ##Go to currently selected monitors specifed workspace
    if(selectedScreen().activeWorkspace == index): return
    if(index >= 0 and index < selectedScreen().workspaces.len):
        for window in selectedWorkspace().windows:
            discard XUnmapWindow(display, window.rawWindow)

        selectedScreen().activeWorkspace = index

        for window in selectedWorkspace().windows:
            discard XMapWindow(display, window.rawWindow)

        selectedScreen().drawMode()
        getFocus(true)

proc moveWindowToWorkspace(index : int)=
    if(selectedScreen().activeWorkspace == index): return
    if(index >= 0 and index < selectedScreen().workspaces.len):
        for window in selectedWorkspace().windows:
            discard XUnmapWindow(display, window.rawWindow)

        let windowToMove = activeWindow()
        let toDelete = selectedScreen().getActiveWorkspace().windows.find(windowToMove)
        if(toDelete >= 0): selectedScreen().getActiveWorkspace().windows.delete(toDelete)
        selectedScreen().activeWorkspace = index
        selectedScreen().getActiveWorkspace().windows.add(windowToMove)


        for window in selectedWorkspace().windows:
            discard XMapWindow(display, window.rawWindow)

        selectedScreen().drawMode()
        getFocus(true)

proc closeWindow() =
    ##Makes a proper XServer message for killing windows
    if(activeWorkspaceIsEmpty()): return
    var ev = TXEvent()
    ev.xclient.theType = ClientMessage
    ev.xclient.window = activeTWindow()
    ev.xclient.message_type = XInternAtom(display, "WM_PROTOCOLS", true)
    ev.xclient.format = 32
    ev.xclient.data.l[0] = XInternAtom(display, "WM_DELETE_WINDOW", false).cint
    ev.xclient.data.l[1] = CurrentTime
    discard XSendEvent(display, activeTWindow(), false, NoEventMask, ev.addr)

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint{.cdecl.} =
    echo error.theType

proc toggleActiveFullScreen()=
    ##Toggle fullscreen on currently selected window
    if(not activeWorkspaceIsEmpty() and activeTWindow().isNotBar()):
        var win = activeWindow()
        win.fullScreen = not win.fullScreen
        if(win.fullScreen):
            discard XMoveResizeWindow(display,win.rawWindow,selectedScreen().xOffset,selectedScreen().yOffset,selectedScreen().width,selectedScreen().height)
            discard XRaiseWindow(display,win.rawWindow)
            getFocus(true)
        else:
            getFocus(true)
            selectedScreen().drawMode()

proc toggleFloatingWindow()=
    ##Toggles floating on currently selected window
    if(not activeWorkspaceIsEmpty() and activeTWindow().isNotBar()):
        let win = activeWindow()
        if(win.isTiled): selectedWorkspace()[selectedWorkspace().activeWindow] = FloatingWindow(rawWindow : win.rawWindow)
        else: selectedWorkspace()[selectedWorkspace().activeWindow] = Window(rawWindow : win.rawWindow)
        echo fmt"Window is currently tiled: {activeWindow().isTiled}"
        selectedScreen().drawMode()

    discard


proc loadScreens() =
    ##Use xrandr through shell to get active monitor information, should be using the xrandr.nim library
    let monitorReg = re"\d:.*"
    let sizeReg = re"\d*\/"
    let offsetReg = re"\+[\d]+"
    let xrandrResponse = execCmdEx("xrandr --listactivemonitors").output.findAll(monitorReg)

    for line in xrandrResponse:
        var screen = Screen()
        let size = line.findAll(sizeReg)
        let offset = line.findAll(offsetReg)
        screen.activeWorkspace = 1

        if(size.len != 2 or offset.len != 2): quit "Cant find monitors"

        #Get monitor info
        screen.width = parseInt(size[0].replace("/")).cint
        screen.height = parseInt(size[1].replace("/")).cint
        screen.xOffset = parseInt(offset[0].replace("+")).cint
        screen.yOffset = parseInt(offset[1].replace("+")).cint

        for x in 0..9: screen.workspaces.add(Workspace())

        #Make status bar
        var barPointer = spawnStatusBar(screen.width, statusBarHeight)
        if(barPointer[1] != nil):
            screen.bar = barPointer[0]
            screen.barWin = cast[TWindow](barPointer[1])
            screen.bar.addWidget(newWorkspaceList())
            screen.bar.addWidget(newLauncher())
            screen.bar.addWidget(newVolumeSlider())
            screen.bar.addWidget(newTimeWidget())
            discard XSelectInput(display, screen.barWin, PointerMotionMask or
                                                        EnterWindowMask or
                                                        LeaveWindowMask or
                                                        ButtonMotionMask)
        screens.add(screen)



proc initFromConfig() =
    ##load config and setup harcoded keybinds
    loadConfig(display)
    for key in keyConfs():
        discard XGrabKey(
                display,
                key.keycode.cint,
                key.modifiers,
                root,
                true,
                GrabModeAsync,
                GrabModeAsync)

    var screenIndex = 0

    #Intialize hardcoded workspace switching keybinds
    for i in 0..9:
            capture [i]:
                let actualNum = (i - 1 + 10) %% 10 #0-9 values on keys
                let keycode = XKeysymToKeycode(display, XStringToKeysym($actualNum))
                discard XGrabKey(
                        display,
                        keycode,
                        Mod4Mask or ShiftMask,
                        root,
                        true,
                        GrabModeAsync,
                        GrabModeAsync)
                discard XGrabKey(
                        display,
                        keycode,
                        Mod4Mask,
                        root,
                        true,
                        GrabModeAsync,
                        GrabModeAsync)
                #inside the proc the value is always the last iteration value
                var keyConf = newKeyConfig(keycode.cuint, Mod4Mask,proc() = goToWorkspace(actualNum))
                addInput(keyConf)
                keyConf = newKeyConfig(keycode.cuint, Mod4Mask or ShiftMask,proc() = moveWindowToWorkspace(actualNum))
                addInput(keyConf)

    for screen in screens:
        #Assign layout
        case(getScreenLayout(screenIndex)):
        of Horizontal:
            screen.drawMode = drawHorizontalTiled
        of LeftAlternating:
            screen.drawMode = proc() = drawAlternatingSplit(false)
        of RightAlternating:
            screen.drawMode = proc() = drawAlternatingSplit(true)
        of LeftMaster:
            screen.drawMode = proc() = drawMainSplit(false)
        of RightMaster:
            screen.drawMode = proc()= drawMainSplit(true)
        of Vertical:
            screen.drawMode = drawVerticalTiled
        else: screen.drawMode = drawHorizontalTiled
        inc(screenIndex)
        screen.drawmode()
        screen.drawBar()

    discard XGrabButton(display,1,Mod4Mask,root,true,ButtonMotionMask or 
                                                    ButtonPressMask or 
                                                    ButtonReleaseMask,
                                                    GrabModeAsync,
                                                    GrabModeAsync,
                                                    None,
                                                    None)
    discard XGrabButton(display,3,Mod4Mask,root,true,ButtonMotionMask or 
                                                    ButtonPressMask or 
                                                    ButtonReleaseMask,
                                                    GrabModeAsync,
                                                    GrabModeAsync,
                                                    None,
                                                    None)


    addActionToConfig(MoveLeft, proc() = moveWindowsHorz(false))
    addActionToConfig(MoveRight, proc() = moveWindowsHorz(true))
    addActionToConfig(FocusLeft, proc() = moveFocusHorz(false))
    addActionToConfig(FocusRight, proc() = moveFocusHorz(true))
    addActionToConfig(MakeMain, makeFocusedMain)
    addActionToConfig(MoveScreenRight, proc() = moveWindowToScreen(true))
    addActionToConfig(MoveScreenLeft, proc() = moveWindowToScreen(false))
    addActionToConfig(CloseWindow, closeWindow)
    addActionToConfig(FocusScreenRight, proc() = focusScreen(true))
    addActionToConfig(FocusScreenleft, proc() = focusScreen(false))
    addActionToConfig(ReloadConfig, widgetEvents.invokeReloadConfig)
    addActionToConfig(MakeFullScreen,toggleActiveFullScreen)
    addActionToConfig(MakeFloating,toggleFloatingWindow)


    var wa = TXSetWindowAttributes()
    wa.event_mask = eventMask

    discard XChangeWindowAttributes(display, root, CWEventMask or CWCursor, wa.addr)

proc reloadConfig() =
    ##Clears previously got keys and re-adds them
    discard XUngrabKey(display, AnyKey, AnyModifier, root)
    discard XUngrabButton(display,AnyButton,AnyModifier,root)
    initFromConfig()
    for screen in screens:
        screen.drawMode()

proc addWidgetFunctions() =
    ##Adds functions usable from outside this file
    widgetEvents.goToWorkspace = goToWorkspace
    widgetEvents.reloadConfig = reloadConfig

proc setup() =
    ##Initialize the XDisplay and set everything up
    display = XOpenDisplay(nil)
    loadScreens()
    if(display == nil): quit "Failed to open display"

    addWidgetFunctions()



    screen = DefaultScreen(display)
    root = RootWindow(display, screen)
    discard XSetErrorHandler(errorHandler)


    let supported = XInternAtom(display,"_NET_SUPPORTED",false)
    let dataType = XInternAtom(display,"ATOM",false)
    var atomsNames : array[7,TAtom]
    atomsNames[0] = (XInternAtom(display,"_NET_ACTIVE_WINDOW",false))
    atomsNames[1] = (XInternAtom(display,"_NET_WM_STATE",false))
    atomsNames[2] = (XInternAtom(display,"_NET_WM_STATE_FULLSCREEN",false))
    atomsNames[3] = (XInternAtom(display,"_NET_WM_WINDOW_TYPE",false))
    atomsNames[4] = (XInternAtom(display,"_NET_WM_STATE_MAXIMIZED_HORZ",false))
    atomsNames[5] = (XInternAtom(display,"_NET_WM_STATE_MAXIMIZED_VERT",false))
    atomsNames[6] = (XInternAtom(display,"_NET_SUPPORTING_WM_CHECK",false))


    discard XChangeProperty(display,
                            root,
                            supported,
                            dataType,
                            32,
                            PropModeReplace,
                            cast[Pcuchar](atomsNames.addr),
                            atomsNames.len.cint)
    initFromConfig()

    discard XSelectInput(display,
                    root,
                    eventMask)
    discard XSync(display, true)


proc frameWindow(w: TWindow) =
    var workspace = selectedWorkspace()
    var sizeHints = XAllocSizeHints()
    var returnMask: int
    discard XGetWMNormalHints(display, w, sizeHints, addr returnMask)
    if(sizeHints.min_width > 0 and sizeHints.min_width ==
            sizeHints.max_width and sizeHints.min_height > 0 and
            sizeHints.min_height == sizeHints.max_height):
        workspace.windows.add(FloatingWindow(rawWindow: w,
                                            minw: sizeHints.min_width,
                                            maxw: sizeHints.max_width,
                                            minh: sizeHints.min_height,
                                            maxh: sizeHints.max_height))
    else: workspace.windows.add(Window(rawWindow: w))


    discard XSelectInput(display, w,StructureNotifyMask or
                                    PropertyChangeMask or
                                    ResizeRedirectMask or
                                    EnterWindowMask or
                                    FocusChangeMask)
    discard XMapWindow(display, w)
    selectedScreen().drawMode()

proc onMapRequest(e: var TXMapRequestEvent) =
    if(not e.window.inCurrentSpace()): frameWindow(e.window)

proc onWindowDestroy(e: TXDestroyWindowEvent) =
    for screen in screens:
        for workspace in screen.workspaces:
            var toDelete = -1

            if(workspace.wincount() > 0):
                #Get window to delete
                for window in 0..<workspace.windows.len:
                    if(workspace.windows[window].rawWindow == e.window):
                        toDelete = window
                        break

                #Remove window
                if(toDelete >= 0):
                    workspace.windows.delete(toDelete)
                    toDelete = -1
    selectedWorkspace().activeWindow = 0
    if(selectedWorkspace().wincount() > 0):
        getFocus()
    selectedScreen().drawMode()

proc onKeyPress(e: TXKeyEvent) =
    var strName = XKeycodeToKeysym(display, TKeyCode(e.keycode),
            0).XKeysymToString()
    echo fmt"{e.keycode} is {strName}"
    doKeycodeAction(e.keycode.cint, e.state.cint)

proc onKeyRelease(e: TXKeyEvent) =
    case(e.keyCode):
    else: discard

proc onButtonPressed(e: TXButtonEvent) =
    if(selectedWorkspace().wincount > 0 and (e.state and Mod4Mask) == Mod4Mask and not activeWindow().isTiled):
        assignToActive(e.window)
        case e.button: 
            of 1: 
                mouseState = Moving
                var winAttr = TXWindowAttributes()
                discard XGetWindowAttributes(display,activeTWindow(),winAttr.addr)
                discard XWarpPointer(display,None,activeWindow().rawWindow,0,0,0,0,
                                    winAttr.width.div(2),
                                    winAttr.height.div(2))
            of 3 :
                mouseState = Resizing
                var winAttr = TXWindowAttributes()
                discard XGetWindowAttributes(display,activeTWindow(),winAttr.addr)
                discard XWarpPointer(display,None,activeWindow().rawWindow,0,0,0,0,
                                    winAttr.width,
                                    winAttr.height)
            else : 
                mouseState = Nothing
                discard XSetInputFocus(display,e.window,RevertToNone,CurrentTime)

proc onButtonReleased(e: TXButtonEvent) =
    mouseState = Nothing

proc onEnterEvent(e: TXCrossingEvent) =
    if(mouseState == Nothing):
        assignToActive(e.window)
        discard XSetInputFocus(display, e.window, RevertToNone, CurrentTime)

proc onMotion(e: TXMotionEvent) =
    if(selectedWorkspace().wincount > 0):
        case mouseState:
        of Moving:
            var winAttr = TXWindowAttributes()
            discard XGetWindowAttributes(display,activeTWindow(),winAttr.addr)
            discard XMoveWindow(display,activeTWindow(),e.x - winAttr.width.div(2),
                                                        e.y - winAttr.height.div(2))
        of Resizing:
            var winAttr = TXWindowAttributes()
            discard XGetWindowAttributes(display,activeTWindow(),winAttr.addr)
            discard XResizeWindow(display,activeTWindow(),e.x - winAttr.x, e.y - winattr.y)
        of Nothing:discard

proc onPropertyChanged(e : TXPropertyEvent)=
    echo XGetAtomName(display,e.atom)
    if(XGetAtomName(display,e.atom) == "_NET_WM_STATE"): discard execShellCmd("notify-send gotWmStateChange")
    if(XGetAtomName(display,e.atom) == "_NET_WM_STATE_FULLSCREEN"): discard execShellCmd("notify-send FullScreen it")
    discard

proc run() =
    ##The main loop, it's main.
    setup()
    runScript()
    var ev: TXEvent = TXEvent()
    var lastDraw = epochTime()
    var delay = 0.1
    while running:
        if(XPending(display)):
            while(XNextEvent(display,ev.addr) == 0):
                case (ev.theType):
                of DestroyNotify:
                    onWindowDestroy(ev.xdestroywindow)
                of MapRequest:
                    onMapRequest(ev.xmaprequest)
                of KeyPress:
                    onKeyPress(ev.xkey)
                of KeyRelease:
                    onKeyRelease(ev.xkey)
                of ButtonPress:
                    onButtonPressed(ev.xbutton)
                of ButtonRelease:
                    onButtonReleased(ev.xbutton)
                of EnterNotify:
                    onEnterEvent(ev.xcrossing)
                of MotionNotify:
                    onMotion(ev.xmotion)
                of PropertyNotify:
                    onPropertyChanged(ev.xproperty)
                of ClientMessage:
                    echo "Message Got" & $XGetAtomName(display, ev.xclient.message_type)
                else: discard
        if(epochTime() - lastDraw >= delay):
            barLoop()
            lastDraw = epochTime()
        sleep(1)

run()
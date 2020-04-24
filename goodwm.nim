import x11/[xlib, x, xutil]
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

converter toCint(x: TKeyCode): cint = x.cint
converter int32toCint(x: int32): cint = x.cint
converter int32toCUint(x: int32): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool


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


let eventMask = SubstructureRedirectMask or
                SubstructureNotifyMask or
                StructureNotifyMask or
                ButtonPressMask or
                ButtonReleaseMask or
                KeyPressMask or
                KeyReleaseMask or
                EnterWindowMask or
                LeaveWindowMask or
                PointerMotionMask or
                PropertyChangeMask or
                ResizeRedirectMask



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
    if(activeWorkspaceIsEmpty()): return
    if(not selectedWorkspace().activeWindow in 0..<selectedWorkspace().wincount):
        selectedWorkspace().activeWindow = 0

    if(moveCursor and activeTWindow() != root):
        var winAttr = TXWindowAttributes()
        discard XGetWindowAttributes(display, activeTWindow(), winAttr.addr)
        discard XWarpPointer(display, None, activeTWindow(), 0, 0, 0, 0,
                winAttr.width.div(2), winAttr.height.div(2))

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
            discard XMoveResizeWindow(display, window.rawWindow, x, y, width, height)

    selScreen.drawBar()

proc drawLeftAlternatingSplit() =
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
            discard XConfigureWindow(display, window.rawWindow, flag, winVals.addr)
            splitVert = not splitVert
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

        for x in 0..<workspace.wincount:
            if(workspace[x].rawWindow == win):
                workspace.activeWindow = x
                return

proc focusScreen(right: bool = false) =
    let dir = if(right): 1 else: -1
    selected = (selected + dir + screens.len) %% screens.len
    discard XWarpPointer(display, None, root, 0, 0, 0, 0, selectedScreen().width.div(
            2) + selectedScreen().xOffset, selectedScreen().height.div(2) +
            selectedScreen().yOffset)

proc makeFocusedMain() =
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
    if(selectedWorkspace().wincount() == 0): return
    var index = selectedWorkspace().activeWindow
    let dir = if(right): 1 else: -1
    index = (index + dir + selectedWorkspace().wincount()) %% selectedWorkspace().wincount()
    selectedWorkspace().activeWindow = index
    getFocus(true)

proc goToWorkspace(index: int) =
    if(selectedScreen().activeWorkspace == index): return
    if(index >= 0 and index < selectedScreen().workspaces.len):
        for window in selectedWorkspace().windows:
            discard XUnmapWindow(display, window.rawWindow)

        selectedScreen().activeWorkspace = index

        for window in selectedWorkspace().windows:
            discard XMapWindow(display, window.rawWindow)

        selectedScreen().drawMode()
        getFocus()

proc closeWindow() =
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
    if(not activeWorkspaceIsEmpty() and activeTWindow().isNotBar()):
        let win = activeWindow()
        if(win.isTiled): selectedWorkspace()[selectedWorkspace().activeWindow] = FloatingWindow(rawWindow : win.rawWindow)
        else: selectedWorkspace()[selectedWorkspace().activeWindow] = Window(rawWindow : win.rawWindow)
        echo fmt"Window is currently tiled: {activeWindow().isTiled}"
        selectedScreen().drawMode()

    discard


proc loadScreens() =
    let monitorReg = re"\d:.*"
    let sizeReg = re"\d*\/"
    let offsetReg = re"\+[\d]+"
    let xrandrResponse = execCmdEx("xrandr --listactivemonitors").output.findAll(monitorReg)

    for line in xrandrResponse:
        var screen = Screen()
        let size = line.findAll(sizeReg)
        let offset = line.findAll(offsetReg)

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
        echo fmt"Screen 0 is: {screen.width}X{screen.height}+{screen.xOffset}+{screen.yOffset}"



proc initFromConfig() =
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

    for i in 0..9:
        let actualNum = (i - 1 + 10) %% 10
        let keycode = XKeysymToKeycode(display, XStringToKeysym($actualNum))
        discard XGrabKey(
                display,
                keycode,
                Mod4Mask,
                root,
                true,
                GrabModeAsync,
                GrabModeAsync)
        let keyConf = newKeyConfig(keycode.cuint, Mod4Mask, proc() = goToWorkspace(actualNum))
        addInput(keyConf)

    for screen in screens:
        #Assign layout
        case(getScreenLayout(screenIndex)):
        of Horizontal:
            screen.drawMode = drawHorizontalTiled
        of LeftAlternating:
            screen.drawMode = drawLeftAlternatingSplit
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
    discard XUngrabKey(display, AnyKey, AnyModifier, root)
    initFromConfig()
    for screen in screens:
        screen.drawMode()

proc addWidgetFunctions() =
    widgetEvents.goToWorkspace = goToWorkspace
    widgetEvents.reloadConfig = reloadConfig

proc setup() =
    display = XOpenDisplay(nil)
    loadScreens()
    if(display == nil): quit "Failed to open display"

    addWidgetFunctions()

    screen = DefaultScreen(display)
    root = RootWindow(display, screen)
    discard XSetErrorHandler(errorHandler)

    discard XSelectInput(display,
                    root,
                    eventMask)
    discard XSync(display, false)

    initFromConfig()


proc frameWindow(w: TWindow) =
    var workspace = selectedWorkspace()
    discard XAddToSaveSet(display, w)
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
    let frame = XCreateSimpleWindow(display, root, 0, 0, sizeHints.min_width,
            sizeHints.min_width, borderSize, 0xFF00FF.culong, None)


    discard XSelectInput(display, frame, SubstructureRedirectMask or
                                        PointerMotionMask or
                                        EnterWindowMask or
                                        LeaveWindowMask or
                                        PropertyChangeMask)
    discard XReparentWindow(display, frame, w, 0, 0)
    discard XMapWindow(display, w)
    selectedScreen().drawMode()

proc onMapRequest(e: var TXMapRequestEvent) =
    for screen in screens:
        if(e.window == cast[TWindow](screen.bar)): return
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
    assignToActive(e.window)
    if(selectedWorkspace().wincount > 0 and (e.state and Mod4Mask) == Mod4Mask and not activeWindow().isTiled):
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
            else : mouseState = Nothing

    #If we dont have a current process might as well get a window
    if(mouseState == Nothing):
        discard XSetInputFocus(display, e.window, RevertToNone, CurrentTime)

proc onButtonReleased(e: TXButtonEvent) =
    mouseState = Nothing
    discard XSetInputFocus(display, e.window, RevertToNone, CurrentTime)

proc onEnterEvent(e: TXCrossingEvent) =
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
        of Nothing:
            assignToActive(e.window)
            discard XSetInputFocus(display, e.window, RevertToNone, CurrentTime)

proc run() =
    setup()
    runScript()
    var ev: TXEvent = TXEvent()
    var lastDraw = epochTime()
    var delay = 0.1
    while running:
        while(XCheckMaskEvent(display, eventMask, ev.addr)):
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
                echo ev.xproperty
            else: discard
        if(epochTime() - lastDraw >= delay):
            barLoop()
            lastDraw = epochTime()
        #idk let's see if this fixes gnome
        selectedScreen().drawMode()
        sleep(1)

run()

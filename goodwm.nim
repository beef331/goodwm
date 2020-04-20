import x11/xlib,x11/x
import strformat
import strutils
import config
import osproc
import nre
import statusbar
import widgetEvents
import widgets/workspacelist
import widgets/timewidget
import widgets/launcher
import os
import times

converter toCint(x: TKeyCode): cint = x.cint
converter int32toCint(x: int32): cint = x.cint
converter int32toCUint(x: int32): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool


type 
    Workspace = ref object of RootObj
        windows : seq[TWindow]
        activeWindow : int
    Screen = ref object of RootObj
        width,height,xOffset,yOffset : cint
        drawMode : proc()
        activeWorkspace : int
        workspaces : seq[Workspace]
        barWin : TWindow
        bar : Bar

proc mainWindow(a : Workspace):TWindow = a.windows[0]
proc wincount(a : Workspace): int = a.windows.len

var
    display:PDisplay
    root:TWindow
    running: bool = true
    screen : cint
    screens : seq[Screen]
    selected = 0
    statusBarHeight : int32 = 30

let eventMask = SubstructureRedirectMask or
                SubstructureNotifyMask or
                StructureNotifyMask or
                ButtonPressMask or
                ButtonReleaseMask or
                KeyPressMask or
                KeyReleaseMask or 
                EnterWindowMask or
                LeaveWindowMask or
                PropertyChangeMask or
                PointerMotionMask or
                EnterWindowMask or
                LeaveWindowMask

proc selectedScreen : var Screen = screens[selected]

proc selectedWorkspace : var Workspace = selectedScreen().workspaces[selectedScreen().activeWorkspace]

proc activeWorkspaceEmpty():bool= selectedWorkspace().wincount() == 0

proc activeWindow : var TWindow = selectedWorkspace().windows[selectedWorkspace().activeWindow]

proc `[]=`(w : var Workspace, index : int, win : TWindow) = w.windows[index] = win

proc `[]`(w : var Workspace, index : int) : TWindow = w.windows[index]

proc notBar(w :TWindow):bool=
    for screen in screens:
        if(w == screen.barWin): return false
    return true

proc inCurrentSpace(w : TWindow):bool = selectedWorkspace().windows.contains(w)

proc getFocus(moveCursor : bool = false)=
    if(selectedWorkspace().wincount == 0): return
    if(not selectedWorkspace().activeWindow in 0..<selectedWorkspace().wincount):
        selectedWorkspace().activeWindow = 0
    if(moveCursor and false):
        var winAttr : PXWindowAttributes
        let status = XGetWindowAttributes(display,activeWindow(),winAttr)
        if(status != 0 ): discard XWarpPointer(display,None,activeWindow(),0,0,0,0,winAttr.width.div(2),winAttr.height.div(2))
    discard XSetInputFocus(display,activeWindow(),RevertToPointerRoot,CurrentTime)

proc drawBar(scr : Screen)=
    let barX : cint = scr.xOffset
    let barY : cint = scr.yOffset + scr.height - statusBarHeight
    discard XMoveResizeWindow(display,scr.barWin,barX,barY,scr.width.cint,statusBarHeight)

proc drawHorizontalTiled()=
    ##Make windows horizontally tiled
    let workspace = selectedWorkspace()
    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    var 
        selScreen = selectedScreen()
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = cint(selScreen.width.div(workspace.windows.len))
        height = selScreen.height - statusBarHeight

    for window in workspace.windows:
        x += width
        discard XMoveResizeWindow(display,window,x,y,width,height)
    selScreen.drawBar()

proc drawVerticalTiled()=
    ##Make windows horizontally tiled
    let workspace = selectedWorkspace()
    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    var 
        selScreen = selectedScreen()
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = selScreen.width
        height = cint((selScreen.height - statusBarHeight).div(workspace.windows.len))

    for i in 0..<workspace.wincount:
        let window = workspace.windows[i]
        if(i > 0): y += height
        discard XMoveResizeWindow(display,window,x,y,width,height)
    selScreen.drawBar()

proc drawLeftAlternatingSplit()=
    ##Draw Main left with alternating split

    let workspace = selectedWorkspace()

    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    let selScreen = selectedScreen()
    const flag : cuint = CWX or CWY or CWWidth or CWHeight
    
    var winVals = TXWindowChanges()

    var 
        x = selScreen.xOffset
        y = selScreen.yOffset
        width = selScreen.width
        height = selScreen.height - statusBarHeight
    var splitVert = true
    for i in 0..<workspace.wincount:
        let window = workspace.windows[i]
        let hasNext = (i + 1 < workspace.wincount)
        if(splitVert): 
            if(i > 0): y += height
            if(hasNext): width = width.div(2)
        else: 
            if(i > 0): x += width
            if(hasNext): height = height.div(2)
        winVals.x = x
        winVals.y = y
        winVals.width = width
        winVals.height = height
        discard XConfigureWindow(display,window,flag,winVals.addr)
        splitVert = not splitVert
    selScreen.drawBar()

proc moveWindowsHorz(right : bool = true)=
    if(selectedWorkspace().wincount() <= 1): return
    var workspace = selectedWorkspace()
    let sourceIndex = workspace.activeWindow
    let activeWindow = workspace.windows[workspace.activeWindow]
    let dir = if(right): 1 else: -1
    let swapIndex = (sourceIndex + dir + workspace.wincount) %% workspace.wincount
    workspace.activeWindow = swapIndex
    workspace.windows[sourceIndex] =workspace.windows[swapIndex]
    workspace.windows[swapIndex] = activeWindow
    selectedScreen().drawMode()
    getFocus(true)

proc moveWindowToScreen(right : bool = true)=
    if(activeWorkspaceEmpty()): return

    let activeWindow = activeWindow()
    let dir = if(right): 1 else : -1
    let index = selectedWorkspace().activeWindow
    selectedWorkspace().windows.delete(index)
    selectedWorkspace().activeWindow = 0
    
    selectedScreen().drawMode()

    selected = (selected + dir + screens.len) %% screens.len
    selectedWorkspace().windows.add(activeWindow)
    selectedWorkspace().activeWindow = selectedWorkspace().windows.high
    
    selectedScreen().drawMode()
    getFocus(true)

proc focusScreen(right : bool = false)=
    let dir = if(right): 1 else : -1
    selected = (selected + dir + screens.len) %% screens.len
    discard XWarpPointer(display,None,root,0,0,0,0,selectedScreen().width.div(2) + selectedScreen().xOffset,selectedScreen().height.div(2) + selectedScreen().yOffset)

proc makeFocusedMain()=
    if(selectedWorkspace().wincount() < 1): return
    var workspace = selectedWorkspace()
    var temp = activeWindow()
    var focused = workspace.activeWindow
    workspace.windows[focused] = workspace.windows[0]
    workspace.windows[0] = temp
    workspace.activeWindow = 0
    getFocus(true)
    selectedScreen().drawMode()

proc moveFocusHorz(right : bool = true)=
    if(selectedWorkspace().wincount() == 0): return
    var index = selectedWorkspace().activeWindow
    let dir = if(right): 1 else : -1
    index = (index + dir + selectedWorkspace().wincount()) %% selectedWorkspace().wincount()
    selectedWorkspace().activeWindow = index
    getFocus(true)

proc goToWorkspace(index : int)=
    if(selectedScreen().activeWorkspace == index): return

    for window in selectedWorkspace().windows:
        discard XUnmapWindow(display,window)
    
    if(index > 0 and index < selectedScreen().workspaces.len):
        selectedScreen().activeWorkspace = index

        for window in selectedWorkspace().windows:
            discard XMapWindow(display,window)

        selectedScreen().drawMode()
        getFocus()

proc closeWindow()=
    if(activeWorkspaceEmpty()): return
    var ev = TXEvent()
    ev.xclient.theType = ClientMessage
    ev.xclient.window = activeWindow()
    ev.xclient.message_type = XInternAtom(display,"WM_PROTOCOLS",true)
    ev.xclient.format = 32
    ev.xclient.data.l[0] = XInternAtom(display,"WM_DELETE_WINDOW",false).cint
    ev.xclient.data.l[1] = CurrentTime
    discard XSendEvent(display,activeWindow(),false,NoEventMask,ev.addr)

proc errorHandler(disp: PDisplay, error: PXErrorEvent):cint{.cdecl.}=
    echo error.theType

proc loadScreens()=
    let monitorReg = re"\d:.*"
    let sizeReg = re"\d*\/"
    let offsetReg = re"\+[\d]+"
    let xrandrResponse = execCmdEx("xrandr --listactivemonitors").output.findAll(monitorReg)
    var screenIndex = 0

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
        screen.workspaces.add(Workspace())

        #Assign layout
        case(getScreenLayout(screenIndex)):
        of Horizontal:
            screen.drawMode = drawHorizontalTiled
        of LeftAlternating:
            screen.drawMode = drawLeftAlternatingSplit
        of Vertical:
            screen.drawMode = drawVerticalTiled
        else: screen.drawMode = drawHorizontalTiled

        #Make status bar
        var barPointer = spawnStatusBar(screen.width,statusBarHeight)
        if(barPointer[1] != nil):
            screen.bar = barPointer[0]
            screen.barWin = cast[TWindow](barPointer[1])
            screen.bar.addWidget(newWorkspaceList())
            screen.bar.addWidget(newTimeWidget())
            screen.bar.addWidget(newLauncher())
        inc(screenIndex)
        screens.add(screen)
        echo fmt"Screen 0 is: {screen.width}X{screen.height}+{screen.xOffset}+{screen.yOffset}"

proc addWidgetFunctions()=
    widgetEvents.goToWorkspace = goToWorkspace

proc setup()=
    display = XOpenDisplay(nil)
    loadConfig(display)
    loadScreens()
    var wa = TXSetWindowAttributes()
    let netActiveAtom = XInternAtom(display,"_NET_ACTIVE_WINDOW",false)
    if(display == nil): quit "Failed to open display"

    addWidgetFunctions()

    screen = DefaultScreen(display)
    root = RootWindow(display,screen)
    discard XSetErrorHandler(errorHandler)

    wa.event_mask = eventMask
    
    discard XChangeWindowAttributes(display,root,CWEventMask or CWCursor, wa.addr)


    discard XSelectInput(display,
                    root,
                    wa.event_mask)

    discard XSync(display,false)
    for key in keyConfs():
        discard XGrabKey(
                display,
                key.keycode.cint,
                key.modifiers,
                root,
                true,
                GrabModeAsync,
                GrabModeAsync)

    for screen in screens:
        screen.workspaces.setLen(9)
        for i in 1..9:
            screen.workspaces[i-1] = Workspace()
            let keycode = XKeysymToKeycode(display,XStringToKeysym($i))
            discard XGrabKey(
                    display,
                    keycode,
                    Mod4Mask,
                    root,
                    true,
                    GrabModeAsync,
                    GrabModeAsync)
            let keyConf = newKeyConfig(keycode.cuint,Mod4Mask,proc() = goToWorkspace(i-1))
            addInput(keyConf)
        screen.drawBar()
        discard XSelectInput(display,screen.barWin,
                                                    PointerMotionMask or 
                                                    EnterWindowMask or
                                                    LeaveWindowMask or 
                                                    Button1Mask or
                                                    Button1MotionMask or
                                                    Button2Mask or
                                                    Button2MotionMask)


    getActionConfig(MoveLeft).action = proc() = moveWindowsHorz(false)
    getActionConfig(MoveRight).action = proc() = moveWindowsHorz(true)
    getActionConfig(FocusLeft).action = proc() = moveFocusHorz(false)
    getActionConfig(FocusRight).action = proc() = moveFocusHorz(true)
    getActionConfig(MakeMain).action = makeFocusedMain
    getActionConfig(MoveScreenRight).action = proc() = moveWindowToScreen(true)
    getActionConfig(MoveScreenLeft).action = proc() = moveWindowToScreen(false)
    getActionConfig(CloseWindow).action = closeWindow
    getActionConfig(FocusScreenRight).action = proc() = focusScreen(true)
    getActionConfig(FocusScreenleft).action = proc() = focusScreen(false)

proc frameWindow(w : TWindow)=
    var workspace = selectedWorkspace()
    discard XAddToSaveSet(display,w)
    workspace.windows.add(w)
    discard XSelectInput(display,w,PointerMotionMask or EnterWindowMask or LeaveWindowMask)
    discard XReparentWindow(display,root,w,0,0)
    discard XMapWindow(display,w)
    selectedScreen().drawMode()

proc onMapRequest(e: var TXMapRequestEvent) =
    for screen in screens:
        if(e.window == cast[TWindow](screen.bar)): return
    if(not e.window.inCurrentSpace()): frameWindow(e.window)

proc onWindowDestroy(e : TXDestroyWindowEvent)=
    for screen in screens:
        for workspace in screen.workspaces:
            var toDelete = -1

            if(workspace.wincount() > 0):
                #Get window to delete
                for window in 0..<workspace.windows.len:
                    if(workspace.windows[window] == e.window):
                        toDelete = window
                        break

                #Remove window
                if(toDelete >= 0 ):
                    workspace.windows.delete(toDelete)
                    toDelete = -1
    selectedWorkspace().activeWindow = 0
    if(selectedWorkspace().wincount() > 0):
        getFocus()
    selectedScreen().drawMode()

proc onKeyPress(e : TXKeyEvent)=
    var strName = XKeycodeToKeysym(display,TKeyCode(e.keycode),0).XKeysymToString()
    echo fmt"{e.keycode} is {strName}"
    doKeycodeAction(e.keycode.cint,e.state.cint)

proc onKeyRelease(e : TXKeyEvent)=
    case(e.keyCode):
    else: discard

proc onButtonPressed(e:TXButtonEvent)=
    discard

proc onButtonReleased(e:TXButtonEvent)=
    discard

proc onEnterEvent(e : TXCrossingEvent)=
    for x in 0..<screens.len:
        let screen = screens[x]
        let workspace = screen.workspaces[screen.activeWorkspace]
        for y in 0..<workspace.wincount():
            let win = workspace.windows[y]
            if(e.window == win):
                selected = x
                screen.workspaces[screen.activeWorkspace].activeWindow = y
                getFocus()
                return

proc run()=
    setup()
    runScript()
    var ev : TXEvent = TXEvent()
    var lastDraw = epochTime()
    var delay = 0.1
    while running:
        var barDrawn = false
        while(XCheckMaskEvent(display,eventMask,ev.addr)):
            if(not barDrawn and epochTime() - lastDraw >= delay):
                barLoop()
                barDrawn = true
                lastDraw = epochTime()
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
            else: discard
        sleep(10)
run()


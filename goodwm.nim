import x11/xlib,x11/x
import strformat
import strutils
import config
import osproc
import nre

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

proc mainWindow(a : Workspace):TWindow = a.windows[0]
proc wincount(a : Workspace): int = a.windows.len

var
    display:PDisplay
    root:TWindow
    attr:TXWindowAttributes
    start:TXButtonEvent
    mask : clong
    running: bool = true
    screen : cint
    screens : seq[Screen]
    selected = 0

proc selectedScreen : var Screen = screens[selected]
proc selectedWorkspace : var Workspace = selectedScreen().workspaces[selectedScreen().activeWorkspace]
proc activeWindow : PWindow = addr selectedWorkspace().windows[selectedWorkspace().activeWindow]
proc `[]=`(w : var Workspace, index : int, win : TWindow) = w.windows[index] = win
proc inCurrentSpace(w : TWindow):bool = selectedWorkspace().windows.contains(w)

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
        height = selScreen.height - 30

    for window in workspace.windows:
        x += width
        discard XMoveResizeWindow(display,window,x,y,width,height)

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
        height = selScreen.height - 30
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


proc moveWindowsHorz(right : bool = true)=
    echo fmt"Move Window {right}"
    var temp = selectedWorkspace().windows
    var workspace = selectedWorkspace()
    let dir = if(right): -1 else: 1
    for i in 0..<temp.len:
        let index = (i + dir + temp.len) %% temp.len
        workspace.windows[i] = temp[index]
    selectedScreen().drawMode()

proc getFocus()=
    var revert : cint = RevertToNone
    discard XGetInputFocus(display, activeWindow() ,addr revert)

proc makeFocusedMain()=
    if(selectedWorkspace().wincount() < 1): return
    var workspace = selectedWorkspace()
    var temp = activeWindow()[]
    var focused = workspace.activeWindow
    workspace.windows[focused] = workspace.windows[0]
    workspace.windows[0] = temp
    workspace.activeWindow = 0
    getFocus()
    selectedScreen().drawMode()

proc moveFocusHorz(right : bool = true)=
    var index = selectedWorkspace().activeWindow
    let dir = if(right): 1 else : 1
    index = (index + dir + selectedWorkspace().wincount()) %% selectedWorkspace().wincount()
    selectedWorkspace().activeWindow = index
    getFocus()


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
        screen.width = parseInt(size[0].replace("/")).cint
        screen.height = parseInt(size[1].replace("/")).cint
        screen.xOffset = parseInt(offset[0].replace("+")).cint
        screen.yOffset = parseInt(offset[1].replace("+")).cint
        screen.workspaces.add(Workspace())
        case(getScreenLayout(screenIndex)):
        of Horizontal:
            screen.drawMode = drawHorizontalTiled
        of LeftAlternating:
            screen.drawMode = drawLeftAlternatingSplit
        else: screen.drawMode = drawHorizontalTiled
            
        screens.add(screen)
        echo fmt"Screen 0 is: {screen.width}X{screen.height}+{screen.xOffset}+{screen.yOffset}"

proc setup()=
    display = XOpenDisplay(nil)
    loadConfig(display)
    loadScreens()
    var wa = TXSetWindowAttributes()
    let netActiveAtom = XInternAtom(display,"_NET_ACTIVE_WINDOW",false)
    if(display == nil): quit "Failed to open display"

    screen = DefaultScreen(display)
    root = RootWindow(display,screen)
    discard XSetErrorHandler(errorHandler)

    wa.event_mask = SubstructureRedirectMask or
                    SubstructureNotifyMask or
                    StructureNotifyMask or
                    ButtonPressMask or
                    ButtonReleaseMask or
                    KeyPressMask or
                    KeyReleaseMask or 
                    EnterWindowMask or
                    LeaveWindowMask or
                    PropertyChangeMask or
                    PointerMotionMask
    
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

    getActionConfig(MoveLeft).action = proc() = moveWindowsHorz(false)
    getActionConfig(MoveRight).action = proc() = moveWindowsHorz(true)
    getActionConfig(FocusLeft).action = proc() = moveFocusHorz(false)
    getActionConfig(FocusRight).action = proc() = moveFocusHorz(true)
    getActionConfig(MakeMain).action = makeFocusedMain




proc frameWindow(w : TWindow)=
    var workspace = selectedWorkspace()
    discard XAddToSaveSet(display,w)
    workspace.windows.add(w)

    selectedScreen().drawMode()
    discard XMapWindow(display,w)

proc onMapRequest(e: TXMapRequestEvent) =
    if(not e.window.inCurrentSpace()): frameWindow(e.window)

proc onWindowDestroy(e : TXDestroyWindowEvent)=
    var workspace = selectedWorkspace()
    var toDelete = -1

    if(workspace.wincount >= 1):
        #Get window to delete
        for window in 0..<workspace.windows.len:
            if(workspace.windows[window] == e.window):
                toDelete = window
                break

        #Remove window
        if(toDelete >= 0 ):
            workspace.windows.delete(toDelete)

    selectedScreen().drawMode()

proc onKeyPress(e : TXKeyEvent)=
    var strName = XKeycodeToKeysym(display,TKeyCode(e.keycode),0).XKeysymToString()
    echo fmt"{e.keycode} is {strName}"
    doKeycodeAction(e.keycode.cint,e.state.cint)

proc onKeyRelease(e : TXKeyEvent)=
    case(e.keyCode):
    else: discard

proc onButtonPressed(e:TXButtonEvent)=
    echo e.button

proc onButtonReleased(e:TXButtonEvent)=
    echo e.button

proc onMouseMoved(e:TXMotionEvent)=
    var index = 0
    for screen in screens:
        if(e.x >= screen.xOffset and e.x <= (screen.xOffset + screen.width) and e.y >= screen.yOffset and e.y <= (screen.yOffset + screen.height)):
            selected = index
            index = 0
            for window in selectedWorkspace().windows:
                var winAttr = TXWindowAttributes()
                discard XGetWindowAttributes(display,window,winAttr.addr)
                if(e.x >= winAttr.x and e.x <= (winAttr.x + winAttr.width) and e.y >= winAttr.y and e.y <= (winAttr.y + winAttr.height)):
                    selectedWorkspace().activeWindow = index
                    echo "Try to focus"
                    getFocus()
                    return
                inc(index)
        inc(index)


proc run()=
    setup()
    runScript()
    while running:
        var ev : TXEvent = TXEvent() 
        discard XNextEvent(display,ev.addr)
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
        of MotionNotify:
            onMouseMoved(ev.xmotion)
        else: discard

run()


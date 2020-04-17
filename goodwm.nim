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

proc `selectedScreen`() : var Screen = screens[selected]
proc selectedWorkspace() : var Workspace = selectedScreen().workspaces[selectedScreen().activeWorkspace]

proc drawHorizontalTiled()=
    ##Make windows horizontally tiled
    let workspace = selectedWorkspace()
    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    let flag :cint = CWX or CWY or CWHeight or CWWidth

    var windowValues = TXWindowChanges()
    windowValues.x = 0
    windowValues.y = 0
    #horz is evenly scaled so we know the width
    windowValues.width = cint(selectedScreen().width.div(workspace.windows.len))
    #Add bar height later
    windowValues.height = selectedScreen().height-30
    discard XConfigureWindow(display,workspace.mainWindow,flag,addr windowValues)
    for window in workspace.windows:
        if(window == workspace.mainWindow):continue
        windowValues.x += windowValues.width
        discard XConfigureWindow(display,window,flag,addr windowValues)

proc drawLeftAlternatingSplit()=
    ##Draw Main left with alternating split
    let workspace = selectedWorkspace()

    #We dont have any windows, dont draw
    if(workspace.wincount == 0): return

    let flag :cint = CWX or CWY or CWHeight or CWWidth

    var windowValues = TXWindowChanges()
    windowValues.x = selectedScreen().xOffset
    windowValues.y = selectedScreen().yOffset
    #First window takes up a majority of space
    windowValues.width = selectedScreen().width
    #Add bar height later
    windowValues.height = selectedScreen().height-30
    var splitVert = true
    for i in 0..<workspace.wincount:
        let window = workspace.windows[i]
        let hasNext = (i < workspace.wincount - 1)
        if(splitVert): 
            if(i > 0): windowValues.y += windowValues.height
            if(hasNext): windowValues.width = windowValues.width.div(2)
        else: 
            if(i > 0): windowValues.x += windowValues.width
            if(hasNext): windowValues.height = windowValues.height.div(2)
        discard XConfigureWindow(display,window,flag,addr windowValues)
        splitVert = not splitVert


proc moveWindowsHorz(right : bool = true)=
    var temp = selectedWorkspace().windows
    var workspace = selectedWorkspace()
    let dir = if(right): -1 else: 1
    for i in 0..<temp.len:
        let index = (i + dir + temp.len) %% temp.len
        workspace.windows[i] = temp[index]
    selectedScreen().drawMode()

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
    loadScreens()
    display = XOpenDisplay(nil)

    if display == nil:
        quit "Failed to open display"
    screen = DefaultScreen(display)
    root = RootWindow(display,screen)
    
    discard XSetErrorHandler(errorHandler)
    discard XSelectInput(display,
                    root,
                    SubstructureRedirectMask or
                    SubstructureNotifyMask or
                    ButtonPressMask or
                    ButtonReleaseMask or
                    KeyPressMask or
                    KeyReleaseMask)
    discard XSync(display,false)
    discard XGrabKey(
      display,
      XKeysymToKeycode(display, XStringToKeysym("left")),
      Mod1Mask,
      root,
      false,
      KeyPressMask or KeyReleaseMask,
      GrabModeAsync)


    #add action procs
    addAction(MoveRight,proc()=moveWindowsHorz(true))
    addAction(MoveLeft,proc()=moveWindowsHorz(false))


proc onWindowCreation(e: TXCreateWindowEvent) =
    var workspace = selectedWorkspace()
    workspace.windows.add(e.window)
    discard XMapWindow(display,e.window)
    selectedScreen().drawMode()
    discard XSelectInput(display,
                e.window,
                SubstructureRedirectMask or
                SubstructureNotifyMask or
                ButtonPressMask or
                ButtonReleaseMask or
                KeyPressMask or
                KeyReleaseMask)


proc onWindowDestroy(e : TXDestroyWindowEvent)=
    var workspace = selectedWorkspace()
    var toDelete = -1

    if(workspace.wincount > 1):
        #Get window to delete
        for window in 0..<workspace.windows.len:
            if(workspace.windows[window] == e.window):
                toDelete = window
                break

        #Remove window
        if(toDelete >= 0 ):
            workspace.windows.delete(toDelete)
            workspace.windows.setLen(workspace.wincount()-1)

    selectedScreen().drawMode()

proc onKeyPress(e : TXKeyEvent)=
    var workspace = selectedWorkspace()
    var strName = XKeycodeToKeysym(display,TKeyCode(e.keycode),0).XKeysymToString()
    echo fmt"{e.keycode} is {strName}"
    doKeycodeAction(e.keycode)

proc onKeyRelease(e : TXKeyEvent)=
    case(e.keyCode):
    else: discard

proc onButtonPressed(e:TXButtonEvent)=
    echo e.button

proc onButtonReleased(e:TXButtonEvent)=
    echo e.button

proc run()=
    setup()

    while running:
        var ev : TXEvent = TXEvent() 
        discard XNextEvent(display,ev.addr)
        case (ev.theType):
        of CreateNotify:
            onWindowCreation(ev.xcreatewindow)
        of DestroyNotify:
            onWindowDestroy(ev.xdestroywindow)
        of KeyPress:
            onKeyPress(ev.xkey)
        of KeyRelease:
            onKeyRelease(ev.xkey)
        of ButtonPress:
            onButtonPressed(ev.xbutton)
        of ButtonRelease:
            onButtonReleased(ev.xbutton)
        else: discard

run()


import x11/xlib,x11/x
import strformat
import config

converter toCint(x: TKeyCode): cint = x.cint
converter int32toCint(x: int32): cint = x.cint
converter int32toCUint(x: int32): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool


type
    Workspace = ref object of RootObj
        windows : seq[TWindow]


proc mainWindow(a : Workspace):TWindow = a.windows[0]
proc wincount(a : Workspace): int = a.windows.len

var
    display:PDisplay
    root:TWindow
    attr:TXWindowAttributes
    start:TXButtonEvent
    mask : clong
    running: bool = true
    screen,screenWidth,screenHeight : cint
    workspaces = @[Workspace()]
    selected = 0

proc selectedWorkspace() : var Workspace = workspaces[selected]

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
    windowValues.width = cint(screenWidth.div(workspace.windows.len))
    #Add bar height later
    windowValues.height = screenHeight-30
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
    windowValues.x = 0
    windowValues.y = 0
    #First window takes up a majority of space
    windowValues.width = screenWidth
    #Add bar height later
    windowValues.height = screenHeight-30
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


var 
    drawMode : proc() = drawLeftAlternatingSplit

proc moveWindowsHorz(right : bool = true)=
    var temp = selectedWorkspace().windows
    var workspace = selectedWorkspace()
    let dir = if(right): -1 else: 1
    for i in 0..<temp.len:
        let index = (i + dir + temp.len) %% temp.len
        workspace.windows[i] = temp[index]
    drawMode()

proc errorHandler(disp: PDisplay, error: PXErrorEvent):cint{.cdecl.}=
    echo error.theType


proc setup()=
    display = XOpenDisplay(nil)

    if display == nil:
        quit "Failed to open display"
    screen = DefaultScreen(display)
    screenWidth = DisplayWidth(display,screen)
    screenHeight = DisplayHeight(display,screen)
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

    #add action procs
    addAction(MoveRight,proc()=moveWindowsHorz(true))
    addAction(MoveLeft,proc()=moveWindowsHorz(false))


proc onWindowCreation(e: TXCreateWindowEvent) =
    var workspace = workspaces[0]
    workspace.windows.add(e.window)
    discard XMapWindow(display,e.window)
    drawMode()
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
            if(workspace.wincount > 0):
                drawMode()
    else: 
        workspace.windows.setLen(0)
        drawMode()

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
    echo fmt"Screen is {screenWidth} X {screenHeight}"
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


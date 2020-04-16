import x11/xlib,x11/x
import strformat

converter toCint(x: TKeyCode): cint = x.cint
converter int32toCint(x: int32): cint = x.cint
converter int32toCUint(x: int32): cuint = x.cuint
converter toTBool(x: bool): TBool = x.TBool
converter toBool(x: TBool): bool = x.bool


type
    Workspace = ref object of RootObj
        main: int
        windows : seq[TWindow]


proc mainWindow(a : Workspace):TWindow = a.windows[a.main]
proc count(a : Workspace): int = a.windows.len
proc newWorkspace(): Workspace = Workspace(main : -1)

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

proc drawHorizontalTiled(wSpace:Workspace)=
    ##Make windows horizontally tiled

    #We dont have any windows, dont draw
    if(wSpace.windows.len == 0): return

    let flag :cint = CWX or CWY or CWHeight or CWWidth

    var windowValues = TXWindowChanges()
    windowValues.x = 0
    windowValues.y = 0
    #horz is evenly scaled so we know the width
    windowValues.width = cint(screenWidth.div(wSpace.windows.len))
    #Add bar height later
    windowValues.height = screenHeight-30
    discard XConfigureWindow(display,wSpace.mainWindow,flag,addr windowValues)
    for window in wSpace.windows:
        if(window == wSpace.mainWindow):continue
        windowValues.x += windowValues.width
        discard XConfigureWindow(display,window,flag,addr windowValues)

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

proc onWindowCreation(e: TXCreateWindowEvent) =
    var workspace = workspaces[0]
    if(workspace.windows.len == -1): workspace.main = 0
    workspace.windows.add(e.window)
    discard XMapWindow(display,e.window)
    drawHorizontalTiled(workspace)
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

    #Get window to delete
    for window in 0..<workspace.windows.len:
        if(workspace.windows[window] == e.window):
            toDelete = window
            break

    #Remove window
    if(toDelete >= 0):
        if(workspace.windows[toDelete] == workspace.mainWindow):
            let newIndex = (toDelete + 1 + workspace.windows.len) %% workspace.windows.len
            workspace.main = newIndex
        workspace.windows.delete(toDelete)
    drawHorizontalTiled(workspace)

proc onKeyPress(e : TXKeyEvent)=
    var workspace = selectedWorkspace()
    case(e.keyCode):
    of 113:
        if(workspace.windows.len <= 1): return
        workspace.main = (workspace.main + 1 + workspace.count).mod(workspace.count)
        drawHorizontalTiled(workspace)
    else: discard

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


import x11/[xlib, x, xutil, xatom]
import std/os
import goodwm/[desktops, inputs, types, configs]

proc onMapRequest(desktop: var Desktop, e: XMapRequestEvent) =
  var
    size = XAllocSizeHints()
    returnMask: int
  discard XGetWMNormalHints(desktop.display, e.window, size, addr returnMask)
  let isFloating = size.minWidth == size.maxWidth and size.maxHeight == size.minHeight and
      size.min_width > 0 and size.min_height > 0
  desktop.addWindow(e.window, size.x, size.y, size.minWidth, size.minHeight, isFloating)
  discard XSelectInput(desktop.display, e.window, EnterWindowMask or
                                    LeaveWindowMask)
  discard XMapWindow(desktop.display, e.window)
  #discard XSetWindowBorderWidth(desktop.display, e.window, 3)
  #discard XSetWindowBorder(desktop.display, e.window, 4)
  discard XFree(size)

proc onWindowDestroy(desktop: var Desktop, e: XDestroyWindowEvent) = desktop.del(e.window)

proc onWindowCreate(desktop: var Desktop, e: XCreateWindowEvent) = discard

proc onKeyPress(desktop: var Desktop, e: XKeyEvent) =
  desktop.onKey(initKey(e.keycode, e.state))

proc onKeyRelease(desktop: var Desktop, e: XKeyEvent) = discard

proc onButtonPressed(desktop: var Desktop, e: XButtonEvent) =
  desktop.onButton(initButton(e.button, e.state), true, e.x, e.y)

proc onButtonReleased(desktop: var Desktop, e: XButtonEvent) =
  desktop.onButton(initButton(e.button, e.state), false, 0, 0)

proc onEnter(desktop: var Desktop, e: XCrossingEvent) = desktop.mouseEnter(e.window)

proc onMotion(desktop: var Desktop, e: XMotionEvent) = desktop.mouseMotion(e.x, e.y, e.window)

proc onPropertyChanged(desktop: var Desktop, e: XPropertyEvent) = discard

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint {.cdecl.} =
  echo error.theType

proc setup(): Desktop =
  template display: PDisplay = result.display
  display = XOpenDisplay(nil)
  if display != nil:
    result.screen = DefaultScreen(display)
    result.root = RootWindow(display, result.screen)

    discard XSetErrorHandler(errorHandler)
    result.getScreens()

proc run() =
  ##The main loop, it's main.
  discard XInitThreads()
  var
    ev: XEvent = XEvent()
    desktop = setup()
    barThrd: Thread[ptr Desktop]
  if desktop.display != nil:
    desktop.reloadConfig()
    createThread(barThrd, drawBars, desktop.addr)
    while true:
      while(XNextEvent(desktop.display, ev.addr) == 0):
        case (ev.theType):
        of DestroyNotify:
          desktop.onWindowDestroy(ev.xdestroywindow)
        of CreateNotify:
          desktop.onWindowCreate(ev.xcreatewindow)
        of MapRequest:
          desktop.onMapRequest(ev.xmaprequest)
        of KeyPress:
          desktop.onKeyPress(ev.xkey)
        of KeyRelease:
          desktop.onKeyRelease(ev.xkey)
        of ButtonPress:
          desktop.onButtonPressed(ev.xbutton)
        of ButtonRelease:
          desktop.onButtonReleased(ev.xbutton)
        of EnterNotify, LeaveNotify:
          desktop.onEnter(ev.xcrossing)
        of MotionNotify:
          desktop.onMotion(ev.xmotion)
        of PropertyNotify:
          desktop.onPropertyChanged(ev.xproperty)
        of ClientMessage: discard
        else: discard
  else:
    echo "Cannot open X display"

run()

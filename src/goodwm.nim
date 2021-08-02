import x11/[xlib, x, xutil, xatom]
import std/os
import goodwm/[backend, inputs]

const
  XTrue = true.XBool
  XFalse = false.XBool

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
  discard XFree(size)

proc onWindowDestroy(desktop: var Desktop, e: XDestroyWindowEvent) = desktop.del(e.window)

proc onWindowCreate(desktop: var Desktop, e: XCreateWindowEvent) = discard

proc onKeyPress(desktop: var Desktop, e: XKeyEvent) =
  desktop.onKey(initKey(e.keycode, e.state))

proc onKeyRelease(desktop: var Desktop, e: XKeyEvent) = discard

proc onButtonPressed(desktop: var Desktop, e: XButtonEvent) =
  echo e

proc onButtonReleased(desktop: var Desktop, e: XButtonEvent) =
  discard


proc onEnter(desktop: var Desktop, e: XCrossingEvent) = desktop.mouseEnter(e.window)

proc onMotion(desktop: var Desktop, e: XMotionEvent) = desktop.mouseMotion(e.x, e.y, e.window)

proc onPropertyChanged(desktop: var Desktop, e: XPropertyEvent) = discard

proc errorHandler(disp: PDisplay, error: PXErrorEvent): cint {.cdecl.} =
  echo error.theType

proc setup(): Desktop =
  template display: PDisplay = result.display
  display = XOpenDisplay(nil)
  result.screen = DefaultScreen(display)
  result.root = RootWindow(display, result.screen)

  discard XSetErrorHandler(errorHandler)

  const
    eventMask = StructureNotifyMask or
                SubstructureRedirectMask or
                SubstructureNotifyMask or
                ButtonPressMask or
                PointerMotionMask or
                EnterWindowMask or
                LeaveWindowMask or
                PropertyChangeMask or
                KeyPressMask or
                KeyReleaseMask
    mouseMask = ButtonPressMask or
                ButtonReleaseMask or
                ButtonMotionMask

  result.getScreens()

  for key in result.keys:
    discard XGrabKey(display, key.code.cint, key.modi, result.root, XFalse, GrabModeAsync, GrabModeAsync)

  for btn in result.buttons:
    discard XGrabButton(display, btn.btn.cuint, btn.modi, result.root, XFalse, mouseMask,
        GrabModeASync, GrabModeAsync, None, None)

  discard XSelectInput(display, result.root, eventMask)

  discard XSync(display, XTrue)

proc run() =
  ##The main loop, it's main.
  var
    ev: XEvent = XEvent()
    desktop = setup()
  if desktop.display != nil:
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

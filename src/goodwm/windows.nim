import types, layouts
import bumpy
import x11/xlib except Screen
import x11/x

func add*(s: var Screen, window: ManagedWindow) = s.getActiveWorkspace.windows.add window

func del*(d: var Desktop, window: Window) =
  ## Removes a XWindow from the desktop
  block removeWindow:
    for scr in d.screens.mitems:
      for ws in scr.workSpaces.mitems:
        for i in countdown(ws.windows.high, 0):
          if ws.windows[i].window == window:
            ws.windows.delete(i)
            break removeWindow
  d.layoutActive()

func addWindow*(d: var Desktop, window: Window, x, y, width, height: int, isFloating: bool) =
  for scr in d.screens.mitems:
    if scr.isActive:
      let
        x =
          if isFloating:
            scr.bounds.x + scr.bounds.w / 2 - width / 2
          else:
            x.float
        y =
          if isFloating:
            scr.bounds.y + scr.bounds.h / 2 - height / 2
          else:
            y.float
        bounds = rect(x, y, width.float, height.float)
        state =
          if isFloating:
            floating
          else:
            tiled

      scr.getActiveWorkspace.windows.add ManagedWindow(state: state, window: window,
          bounds: bounds)
      discard XMoveResizeWindow(d.display, window, cint x, cint y, cuint width, cuint height)
      d.layoutActive
      return

func unMapWindows*(d: var Desktop) =
  for x in d.getActiveWorkspace.windows:
    discard XUnmapWindow(d.display, x.window)

func unMapWindow*(d: Desktop, w: Window) =
  discard XUnmapWindow(d.display, w)

func mapWindows*(d: var Desktop) =
  for x in d.getActiveWorkspace.windows:
    discard XMapWindow(d.display, x.window)

func mouseEnter*(d: var Desktop, w: Window) =
  ## Mouse entered a new window, ensure it's not root,
  ## then make it active
  if w != d.root:
    d.mouseState = miNone
    var i = 0
    for wind in d.getActiveWorkspace.windows.mitems:
      if wind.window == w:
        d.getActiveWorkspace.active = i
        break
      inc i

  discard XSetInputFocus(d.display, w, RevertToParent, CurrentTime)

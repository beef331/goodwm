import x11/[x, xinerama]
import x11/xlib except Screen
import std/[tables, osproc, decls]
import bumpy, vmath, statusbar
import layouts, types, windows

export windows

iterator keys*(d: Desktop): Key =
  for x in d.shortcuts.keys:
    yield x

iterator buttons*(d: Desktop): Button =
  for x in d.mouseEvent.keys:
    yield x

func cleanWorkspace(d: var Desktop) =
  if d.getActiveWorkspace.windows.len == 0:
    d.getActiveScreen.workspaces.delete(d.getActiveScreen.activeWorkspace)
    var scr {.byaddr.} = d.getActiveScreen()
    scr.activeWorkspace = min(scr.workspaces.high, scr.activeWorkspace)
    d.mapWindows()

func moveCursorToActive(d: var Desktop) =
  ## Moves the cursor to the active window
  if d.hasActiveWindow:
    let
      wnd = d.getActiveWindow
      x = (wnd.bounds.w / 2).cint
      y = (wnd.bounds.h / 2).cint

    discard XWarpPointer(d.display, None, wnd.window, 0, 0, 0, 0, x, y)

func moveUp*(d: var Desktop) =
  ## Moves active window up the stack of tiled windows
  if d.hasActiveWindow:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in countdown(workspace.active - 1, 0):
        if workspace.windows[j].state != floating:
          swap(workspace.windows[workspace.active], workspace.windows[j])
          workspace.active = j
          d.layoutActive
          d.moveCursorToActive
          break

func moveDown*(d: var Desktop) =
  ## Moves active window down the stack of tiled windows
  if d.hasActiveWindow:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in workspace.active + 1 ..< workSpace.windows.len:
        if workspace.windows[j].state != floating:
          swap(workspace.windows[workspace.active], workspace.windows[j])
          workspace.active = j
          d.layoutActive
          d.moveCursorToActive
          break

func focusUp*(d: var Desktop) =
  ## Focuses the window above the active one in the active screens stack
  if d.hasActiveWindow:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in countdown(workspace.active - 1, 0):
        if workspace.windows[j].state != floating:
          workspace.active = j
          d.moveCursorToActive
          break

func focusDown*(d: var Desktop) =
  ## Focuses the window below the active one in the active screens stack
  if d.hasActiveWindow:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in workspace.active + 1 ..< workSpace.windows.len:
        if workspace.windows[j].state != floating:
          workspace.active = j
          d.moveCursorToActive
          break

func toggleFloating*(d: var Desktop) =
  if d.hasActiveWindow:
    var wind {.byaddr.} = d.getActiveWindow
    if wind.state != fullScreen:
      case wind.state
      of tiled:
        wind.state = floating
        discard XRaiseWindow(d.display, wind.window)
      of floating:
        wind.state = tiled
        discard XLowerWindow(d.display, wind.window)
      else: discard
      d.layoutActive

func toggleFullscreen*(d: var Desktop) =
  if d.hasActiveWindow:
    var wind {.byaddr.} = d.getActiveWindow
    if wind.state != fullScreen:
      wind.lastState = wind.state
      wind.lastBounds = wind.bounds
      let scr = d.getActiveScreen()
      wind.bounds = scr.bounds
      discard XRaiseWindow(d.display, wind.window)
      discard XMoveResizeWindow(d.display, wind.window, cint scr.bounds.x, cint scr.bounds.y,
          cuint scr.bounds.w, cuint scr.bounds.h)
    else:
      wind.state = wind.lastState
      wind.bounds = wind.lastBounds
      discard XLowerWindow(d.display, wind.window)
      discard XMoveResizeWindow(d.display, wind.window, cint wind.bounds.x, cint wind.bounds.y,
          cuint wind.bounds.w, cuint wind.bounds.h)

func moveFloating(d: var Desktop, pos: Ivec2) =
  if d.hasActiveWindow and d.getActiveWindow.state == floating:
    let
      windowBounds = d.getActiveWindow.bounds
      x = (pos.x - d.mouseXOffset).cint
      y = (pos.y - d.mouseYOffset).cint
      w = windowBounds.w.cuint
      h = windowBounds.h.cuint
    d.getActiveWindow.bounds = rect(x.float, y.float, w.float, h.float)
    discard XMoveResizeWindow(d.display, d.getActiveWindow.window, x, y, w, h)

func scaleFloating(d: var Desktop, pos: Ivec2) =
  if d.hasActiveWindow and d.getActiveWindow.state == floating:
    let
      windowBounds = d.getActiveWindow.bounds
      w = abs(pos.x - windowBounds.x.int).cuint
      h = abs(pos.y - windowBounds.y.int).cuint
      x = windowBounds.x.cint
      y = windowBounds.y.cint
    d.getActiveWindow.bounds = rect(x.float, y.float, w.float, h.float)
    discard XMoveResizeWindow(d.display, d.getActiveWindow.window, x, y, w, h)

proc moveToNextWorkspace*(d: var Desktop) =
  d.getActiveWorkspace.active = -1
  var scr {.byaddr.} = d.getActiveScreen
  d.unmapWindows()
  let emptyWs = scr.getActiveWorkspace.windows.len == 0
  if emptyWs and scr.activeWorkspace != scr.workspaces.high:
    d.cleanWorkspace()
  elif not emptyWs:
    if scr.activeWorkspace == scr.workspaces.high:
      scr.workspaces.add Workspace(active: 0)

    inc scr.activeWorkspace

  d.layoutActive()
  d.mapWindows()

proc moveToLastWorkspace*(d: var Desktop) =
  d.getActiveWorkspace.active = -1
  var scr {.byaddr.} = d.getActiveScreen
  d.unmapWindows()
  let emptyWs = scr.getActiveWorkspace.windows.len == 0
  if emptyWs and scr.activeWorkspace != 0:
    d.cleanWorkspace()
  elif not emptyWs:
    if scr.activeWorkspace == 0:
      scr.workspaces.insert(Workspace(active: 0), scr.activeWorkspace)
    else:
      dec scr.activeWorkspace

  d.layoutActive()
  d.mapWindows()

proc carouselScreen*(d: var Desktop, id: int, dir = 1) =
  if id in 0..<d.screens.len:
    var scr {.byaddr.} = d.screens[id]
    let nextIndex = (scr.activeWorkspace + dir + scr.workspaces.len) mod scr.workspaces.len
    if scr.workspaces[nextIndex].windows.len > 0:
      d.unmapWindows()
      if scr.getActiveWorkspace.windows.len == 0:
        d.cleanWorkspace()
      scr.activeWorkspace = nextIndex
      d.layoutActive()
      d.mapWindows()

proc growWorkspace*(d: var Desktop) =
  d.getActiveScreen().workspaces.setLen(d.getActiveScreen().workspaces.len + 1)

proc moveWindowToNextWorkspace*(d: var Desktop) =
  if d.hasActiveWindow:
    let wind = d.getActiveWindow
    var scr {.byaddr.} = d.getActiveScreen()
    d.getActiveWorkspace.windows.delete(d.getActiveWorkspace.active)
    let newSpace = scr.activeWorkSpace + 1
    if newSpace >= scr.workspaces.len:
      scr.workspaces.add Workspace(active: 0, windows: @[wind])
    else:
      d.getActiveScreen.workspaces[newSpace].windows.add wind
    d.unmapWindow(wind.window)
    d.layoutActive()

proc moveWindowToPrevWorkspace*(d: var Desktop) =
  if d.hasActiveWindow:
    let wind = d.getActiveWindow
    var scr {.byaddr.} = d.getActiveScreen()
    d.getActiveWorkspace.windows.delete(d.getActiveWorkspace.active)
    let newSpace = scr.activeWorkSpace - 1
    if newSpace < 0:
      scr.workspaces.insert Workspace(active: 0, windows: @[wind]), 0
      scr.activeWorkspace = 1
    else:
      scr.workspaces[newSpace].windows.add wind
    d.unmapWindow(wind.window)
    d.layoutActive()

proc getScreens*(d: var Desktop) =
  let dis = d.display
  var
    count: cint
    displays = cast[ptr UncheckedArray[XineramaScreenInfo]](XineramaQueryScreens(dis, count.addr))
  d.screens.setLen(count)
  for x in 0..<count:
    let screen = displays[x]
    d.screens[x].bounds = rect(screen.xorg.float, screen.yorg.float, screen.width.float,
        screen.height.float)
    d.screens[x].workSpaces.setLen(max(1, d.screens[x].workSpaces.len))
  d.screens[0].isActive = true

func mouseMotion*(d: var Desktop, x, y: int32, w: Window) =
  ## On mouse motion assign the active window and change active screen
  case d.mouseState:
  of miNone:
    d.mouseEnter(w)
    let pos = vec2(x.float32, y.float32)
    for scr in d.screens.mitems:
      scr.isActive = scr.bounds.overlaps pos
  of miResizing:
    d.scaleFloating(ivec2(x, y))
  of miMoving:
    d.moveFloating(ivec2(x, y))

proc moveActiveWindowToScreen(d: var Desktop, i: int) =
  if d.hasActiveWindow:
    let wind = d.getActiveWindow()
    d.del(wind.window)
    d.screens[i].getActiveWorkspace.windows.add wind
    d.layoutActive

proc onKey*(d: var Desktop, key: Key) =
  if key in d.shortcuts:
    let key = d.shortcuts[key]
    case key.kind
    of command:
      try:
        discard startProcess(key.cmd, args = key.args, options = {poUsePath})
      except: discard
    of function:
      if key.event != nil:
        key.event(d)
    of moveWindowToScreen:
      d.moveActiveWindowToScreen(key.targetScreen)
    of forwardCarouselScreen:
      d.carouselScreen(key.targetScreen)
    of backCarouselScreen:
      d.carouselScreen(key.targetScreen, -1)
    of forwardCarouselActive:
      for i, x in d.screens:
        if x.isActive:
          d.carouselScreen(i)
          break
    of backCarouselActive:
      for i, x in d.screens:
        if x.isActive:
          d.carouselScreen(i, -1)
          break


proc onButton*(d: var Desktop, btn: Button, pressed: bool, x, y: int) =
  if btn in d.mouseEvent:
    let shortcut = d.mouseEvent[btn]
    if pressed:
      d.mouseState = shortcut
      if d.hasActiveWindow:
        d.mouseXOffset = x - d.getActiveWindow.bounds.x.int
        d.mouseYOffset = y - d.getActiveWindow.bounds.y.int
    elif d.mouseState == shortcut:
      d.mouseState = miNone

proc drawBars*(d: var Desktop) =
  for scr in d.screens:
    let sbW = getXWindow(scr.statusbar)
    if scr.isFullScreened:
      echo "Here"
      discard XLowerWindow(d.display, sbw)
      let active = d.getActiveWindow()
      discard XRaiseWindow(d.display, active.window)
    else:
      discard XMapWindow(d.display, sbW)
      discard XRaiseWindow(d.display, sbw)

      case scr.barPos:
      of sbpTop:
        discard XMoveResizeWindow(d.display, sbW, scr.bounds.x.cint, scr.bounds.y.cint,
            scr.bounds.w.cuint, scr.barSize.cuint)
      of sbpBot:
        let yPos = scr.bounds.y + scr.bounds.h - scr.barSize.float
        discard XMoveResizeWindow(d.display, sbW, scr.bounds.x.cint, yPos.cint, scr.bounds.w.cuint,
            scr.barSize.cuint)
      else: discard
      scr.statusBar.drawBar(StatusBarData(openWorkSpaces: scr.workSpaces.len,
            activeWorkspace: scr.activeWorkspace))

proc grabInputs*(d: var Desktop) =
  discard XUngrabKey(d.display, AnyKey, AnyModifier, d.root)
  discard XUngrabButton(d.display, AnyButton, AnyModifier, d.root)

  const mouseMask = ButtonMotionMask or ButtonPressMask or ButtonReleaseMask


  for key in d.keys:
    discard XGrabKey(d.display, key.code.cint, key.modi, d.root, false.XBool, GrabModeAsync, GrabModeAsync)

  for btn in d.buttons:
    discard XGrabButton(d.display, btn.btn.cuint, btn.modi, d.root, false.XBool, mouseMask,
        GrabModeASync, GrabModeAsync, None, None)

  const eventMask = StructureNotifyMask or
                    SubstructureRedirectMask or
                    SubstructureNotifyMask or
                    ButtonPressMask or
                    PointerMotionMask or
                    EnterWindowMask or
                    LeaveWindowMask or
                    PropertyChangeMask or
                    KeyPressMask or
                    KeyReleaseMask
  discard XSelectInput(d.display, d.root, eventMask)

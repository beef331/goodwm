import x11/[x, xinerama]
import x11/xlib except Screen
import std/[tables, osproc, options, strutils, decls, os, monotimes, times]
import bumpy, vmath, statusbar
import inputs, layouts, types, windows, notifications

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

func hasActiveWindow(d: var Desktop): bool = d.getActiveWorkspace.active in
    0..<d.getActiveWorkspace.windows.len

func killActiveWindow*(d: var Desktop) =
  ## Closes the active window
  if d.hasActiveWindow:
    discard XDestroyWindow(d.display, d.getActiveWindow.window)

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
        if not workspace.windows[j].isFloating:
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
        if not workspace.windows[j].isFloating:
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
        if not workspace.windows[j].isFloating:
          workspace.active = j
          d.moveCursorToActive
          break

func focusDown*(d: var Desktop) =
  ## Focuses the window below the active one in the active screens stack
  if d.hasActiveWindow:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in workspace.active + 1 ..< workSpace.windows.len:
        if not workspace.windows[j].isFloating:
          workspace.active = j
          d.moveCursorToActive
          break

func toggleFloating*(d: var Desktop) =
  if d.hasActiveWindow:
    d.getActiveWindow.isFloating = not d.getActiveWindow.isFloating
    let w = d.getActiveWindow.window
    if d.getActiveWindow.isFloating:
      discard XRaiseWindow(d.display, w)
    else:
      discard XLowerWindow(d.display, w)
    d.layoutActive

func moveFloating(d: var Desktop, pos: Ivec2) =
  if d.hasActiveWindow and d.getActiveWindow.isFloating:
    let
      windowBounds = d.getActiveWindow.bounds
      x = (pos.x - windowBounds.w.int div 2).cint
      y = (pos.y - windowBounds.h.int div 2).cint
      w = windowBounds.w.cuint
      h = windowBounds.h.cuint
    d.getActiveWindow.bounds = rect(x.float, y.float, w.float, h.float)
    discard XMoveResizeWindow(d.display, d.getActiveWindow.window, x, y, w, h)

func scaleFloating(d: var Desktop, pos: Ivec2) =
  if d.hasActiveWindow and d.getActiveWindow.isFloating:
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
  d.screens.setLen(0)
  let dis = d.display
  var
    count: cint
    displays = cast[ptr UncheckedArray[XineramaScreenInfo]](XineramaQueryScreens(dis, count.addr))
  for x in 0..<count:
    let
      screen = displays[x]
      bounds = rect(screen.xorg.float, screen.yorg.float, screen.width.float, screen.height.float)
    d.screens.add Screen(bounds: bounds, workSpaces: newSeq[Workspace](1), barSize: 30,
        layout: horizontalRight)
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

proc onButton*(d: var Desktop, btn: Button, pressed: bool) =
  if btn in d.mouseEvent:
    let btn = d.mouseEvent[btn]
    btn(d, pressed)

proc drawBars*(d: ptr Desktop) {.thread.} =
  while true:
    for scr in d[].screens:
      let sbW = getXWindow(scr.statusbar)
      discard XMapWindow(d.display, sbW)
      discard XRaiseWindow(d.display, sbw)
      discard XMoveResizeWindow(d.display, sbW, 0, 0, scr.bounds.w.cuint, scr.barSize.cuint)
      {.cast(gcSafe).}: # Some lies and deceit never hurt anyone I think
        scr.statusBar.drawBar(StatusBarData(openWorkSpaces: scr.workSpaces.len,
            activeWorkspace: scr.activeWorkspace))
    sleep(100)

proc grabInputs*(d: var Desktop) =
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
    mouseMask = ButtonMotionMask or ButtonPressMask or ButtonReleaseMask
  for key in d.keys:
    discard XGrabKey(d.display, key.code.cint, key.modi, d.root, false.XBool, GrabModeAsync, GrabModeAsync)

  for btn in d.buttons:
    discard XGrabButton(d.display, btn.btn.cuint, btn.modi, d.root, false.XBool, mouseMask,
        GrabModeASync, GrabModeAsync, None, None)

  discard XSelectInput(d.display, d.root, eventMask)
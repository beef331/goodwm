import x11/[x, xinerama, xlib]
import std/[tables, osproc, options, strutils, decls]
import bumpy, vmath
import inputs


type
  KeyEvent* = proc(d: var Desktop){.nimcall.}
  MouseEvent* = proc(d: var Desktop, pos: IVec2)

  ScreenLayout = enum
    verticalDown, verticalUp, horizontalRight, horizontalLeft
  ManagedWindow = object
    isFloating: bool
    bounds: Rect
    window: Window
  Workspace = object
    active: int
    windows: seq[ManagedWindow]

  Screen* = object
    isActive: bool
    bounds: Rect
    padding: int
    activeWorkspace: int
    layout: ScreenLayout
    workSpaces: seq[Workspace]

  ShortcutKind = enum
    command, function

  Shortcut = object
    case kind: ShortcutKind
    of command:
      cmd: string
      args: seq[string]
    of function:
      event: KeyEvent

  Desktop* = object
    display*: PDisplay
    root*: Window
    screen*: cint
    screens: seq[Screen]
    activeWindow: Option[Window]
    shortcuts: Table[Key, Shortcut]
    mouseShortcuts: Table[Button, MouseEvent]


func initShortcut(evt: KeyEvent): Shortcut = Shortcut(kind: function, event: evt)
func initShortcut(cmd: string): Shortcut =
  var args = cmd.split(" ")
  let cmd = args[0]
  args = args[1..^1]
  Shortcut(kind: command, cmd: cmd, args: args)

{.push inline.}
func getActiveScreen*(d: var Desktop): var Screen =
  for x in d.screens.mitems:
    if x.isActive:
      return x
  result = d.screens[0]

func getActiveWorkspace(s: var Screen): var Workspace = s.workSpaces[s.activeWorkspace]
func getActiveWorkspace(d: var Desktop): var Workspace = d.getActiveScreen.getActiveWorkSpace


func getActiveWindow*(w: var Workspace): var ManagedWindow = w.windows[w.active]
func getActiveWindow*(s: var Screen): var ManagedWindow = s.getActiveWorkspace.getActiveWindow
func getActiveWindow*(d: var Desktop): var ManagedWindow = d.getActiveScreen.getActiveWindow

func hasActiveWindow(d: var Desktop): bool =
  let activeWs = d.getActiveWorkspace
  activeWs.active in 0..<activeWs.windows.len

{.pop.}

func tiledWindows(s: Workspace): int =
  ## Counts the tiled windows
  for w in s.windows:
    if not w.isFloating:
      inc result

func layoutActive(d: var Desktop) =
  ## Calls the coresponding layout logic required
  for scr in d.screens.mitems:
    let tiledWindowCount = scr.getActiveWorkspace.tiledWindows()
    if tiledWindowCount > 0:
      let
        windowWidth = (scr.bounds.w.int div tiledWindowCount)
        windowHeight = scr.bounds.h.cuint
      for i, w in scr.getActiveWorkspace.windows:
        if not w.isFloating:
          scr.getActiveWorkspace.windows[i].bounds = rect((windowWidth * i).float + scr.bounds.x,
              scr.bounds.y, windowWidth.float, windowHeight.float)
          discard XMoveResizeWindow(d.display, w.window, (windowWidth * i).cint,
              scr.bounds.y.cint, windowWidth.cuint, windowHeight)

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
      let bounds = rect(x.float, y.float, width.float, height.float)
      scr.getActiveWorkspace.windows.add ManagedWindow(isFloating: isFloating, window: window,
          bounds: bounds)
      d.layoutActive
      return

func mouseEnter*(d: var Desktop, w: Window) =
  ## Mouse entered a new window, ensure it's not root,
  ## then make it active
  if w != d.root:
    d.activeWindow = some(w)
    var i = 0
    for wind in d.getActiveWorkspace.windows.mitems:
      if wind.window == w:
        d.getActiveWorkspace.active = i
        break
      inc i

  discard XSetInputFocus(d.display, w, RevertToParent, CurrentTime)

func mouseMotion*(d: var Desktop, x, y: int, w: Window) =
  ## On mouse motion assign the active window and change active screen
  d.mouseEnter(w)
  let pos = vec2(x.float32, y.float32)
  for scr in d.screens.mitems:
    scr.isActive = scr.bounds.overlaps pos

proc onKey*(d: var Desktop, key: Key) =
  if key in d.shortcuts:
    let key = d.shortcuts[key]
    case key.kind
    of command:
      discard startProcess(key.cmd, args = key.args, options = {poUsePath})
    of function:
      if key.event != nil:
        key.event(d)

proc onButton*(d: var Desktop, evt: XButtonEvent) =
  discard

iterator keys*(d: Desktop): Key =
  for x in d.shortcuts.keys:
    yield x

iterator buttons*(d: Desktop): Button =
  for x in d.mouseShortcuts.keys:
    yield x

func killActiveWindow(d: var Desktop) =
  ## Closes the active window
  if d.activeWindow.isSome:
    discard XDestroyWindow(d.display, d.activeWindow.get)
    d.activeWindow = none(Window)

func moveCursorToActive(d: var Desktop) =
  ## Moves the cursor to the active window
  if d.hasActiveWindow:
    let
      wnd = d.getActiveWindow
      x = (wnd.bounds.w / 2).cint
      y = (wnd.bounds.h / 2).cint

    discard XWarpPointer(d.display, None, wnd.window, 0, 0, 0, 0, x, y)

func moveUp(d: var Desktop) =
  ## Moves active window up the stack of tiled windows
  if d.activeWindow.isSome:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in countdown(workspace.active - 1, 0):
        if not workspace.windows[j].isFloating:
          swap(workspace.windows[workspace.active], workspace.windows[j])
          workspace.active = j
          d.layoutActive
          d.activeWindow = some(workspace.windows[j].window)
          d.moveCursorToActive
          break

func moveDown(d: var Desktop) =
  ## Moves active window down the stack of tiled windows
  if d.activeWindow.isSome:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in workspace.active + 1 ..< workSpace.windows.len:
        if not workspace.windows[j].isFloating:
          swap(workspace.windows[workspace.active], workspace.windows[j])
          workspace.active = j
          d.layoutActive
          d.activeWindow = some(workspace.windows[j].window)
          d.moveCursorToActive
          break


func focusUp(d: var Desktop) =
  ## Focuses the window above the active one in the active screens stack
  if d.activeWindow.isSome:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in countdown(workspace.active - 1, 0):
        if not workspace.windows[j].isFloating:
          workspace.active = j
          d.activeWindow = some(workspace.windows[j].window)
          d.moveCursorToActive
          break

func focusDown(d: var Desktop) =
  ## Focuses the window below the active one in the active screens stack
  if d.activeWindow.isSome:
    var workspace {.byaddr.} = d.getActiveWorkspace
    block moveWindow:
      for j in workspace.active + 1 ..< workSpace.windows.len:
        if not workspace.windows[j].isFloating:
          workspace.active = j
          d.activeWindow = some(workspace.windows[j].window)
          d.moveCursorToActive
          break

func toggleFloating(d: var Desktop) =
  d.getActiveWindow.isFloating = not d.getActiveWindow.isFloating
  d.layoutActive

func moveFloating(d: var Desktop, pos: Ivec2) =
  discard


func getScreens*(d: var Desktop) =
  d.screens = @[]
  let dis = d.display
  var
    count: cint
    displays = cast[ptr UncheckedArray[XineramaScreenInfo]](XineramaQueryScreens(dis, count.addr))
  for x in 0..<count:
    let
      screen = displays[x]
      bounds = rect(screen.xorg.float, screen.yorg.float, screen.width.float, screen.height.float)
    d.screens.add Screen(bounds: bounds, workSpaces: newSeq[Workspace](1))
  d.screens[0].isActive = true

  #Temporary injection site
  d.shortcuts[initKey(dis, "p", Alt)] = initShortcut("rofi -show drun")
  d.shortcuts[initKey(dis, "q", Alt)] = initShortcut(killActiveWindow)
  d.shortcuts[initKey(dis, "f", Alt)] = initShortcut(toggleFloating)
  d.shortcuts[initKey(dis, "Up", Alt)] = initShortcut(focusUp)
  d.shortcuts[initKey(dis, "Down", Alt)] = initShortcut(focusDown)
  d.shortcuts[initKey(dis, "Up", Alt or Shift)] = initShortcut(moveUp)
  d.shortcuts[initKey(dis, "Down", Alt or Shift)] = initShortcut(moveDown)

  d.mouseShortcuts[initButton(1, Alt)] = moveFloating

import x11/[x, xinerama, xlib]
import std/[tables, osproc]
import bumpy, vmath
import inputs


type
  KeyEvent* = proc(d: var Desktop){.nimcall.}

  ScreenLayout = enum
    verticalDown, verticalUp, horizontalRight, horizontalLeft
  ManagedWindow = object
    isFloating: bool
    bounds: Rect
    window: Window
  Workspace = seq[ManagedWindow]

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
    of function:
      event: KeyEvent

  Desktop* = object
    display*: PDisplay
    root*: Window
    screen*: cint
    screens: seq[Screen]
    shortcuts: Table[Key, Shortcut]

proc getActiveWorkspace(s: var Screen): var Workspace = s.workSpaces[s.activeWorkspace]

proc tiledWindows(s: Workspace): int =
  for w in s:
    if not w.isFloating:
      inc result

proc layoutActive(desktop: var Desktop) =
  for scr in desktop.screens.mitems:
    let tiledWindowCount = scr.getActiveWorkspace.tiledWindows()
    if tiledWindowCount > 0:
      let
        windowWidth = (scr.bounds.w.int div tiledWindowCount)
        windowHeight = scr.bounds.h.cuint

      for i, w in scr.getActiveWorkspace:
        if not w.isFloating:
          discard XMoveResizeWindow(desktop.display, w.window, (windowWidth * i).cint, scr.bounds.y.cint, windowWidth.cuint, windowHeight)

func add*(s: var Screen, window: ManagedWindow) = s.getActiveWorkspace.add window

func del*(d: var Desktop, window: Window) =
  block removeWindow:
    for scr in d.screens.mitems:
      for ws in scr.workSpaces.mitems:
        for i in countdown(ws.high, 0):
          if ws[i].window == window:
            ws.delete(i)
            break removeWindow
  debugecho d.screens[0].getActiveWorkspace
  d.layoutActive()

func addWindow*(d: var Desktop, window: Window, x, y, width, height: int, isFloating: bool) =
  for scr in d.screens.mitems:
    if scr.isActive:
      let bounds = rect(x.float, y.float, width.float, height.float)
      scr.getActiveWorkspace.add ManagedWindow(isFloating: isFloating, window: window, bounds: bounds)
      d.layoutActive
      return

proc getScreens*(desktop: var Desktop) =
  desktop.screens = @[]
  var
    count: cint
    displays = cast[ptr UncheckedArray[XineramaScreenInfo]](XineramaQueryScreens(desktop.display, count.addr))
  for x in 0..<count:
    let
      screen = displays[x]
      bounds = rect(screen.xorg.float, screen.yorg.float, screen.width.float, screen.width.float)
    desktop.screens.add Screen(bounds: bounds, workSpaces: newSeq[Workspace](1))
  desktop.screens[0].isActive = true

  #Temporary injection site
  desktop.shortcuts[Key(code: 33, modi: Mod4Mask)] = Shortcut(kind: command, cmd: "rofi -show drun")

func mouseMotion*(d: var Desktop, x, y: int) =
  for scr in d.screens.mitems:
    scr.isActive = scr.bounds.overlaps vec2(x.float32, y.float32)

func activeScreen*(d: var Desktop): var Screen =
  for x in d.screens.mitems:
    if x.isActive:
      return x
  result = d.screens[0]

proc onKey*(d: var Desktop, key: Key) =
  if key in d.shortcuts:
    let key = d.shortcuts[key]
    case key.kind
    of command:
      discard execCmd(key.cmd)
    of function:
      if key.event != nil:
        key.event(d)

iterator keys*(d: Desktop): Key =
  for x in d.shortcuts.keys:
    yield x
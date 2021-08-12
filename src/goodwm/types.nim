import std/tables
import x11/[x, xlib]
import sdl2/sdl, pixie
type
  ScreenLayout* = enum
    verticalDown
    verticalUp
    horizontalRight
    horizontalLeft
    alternateLeft
    alternateRight

  StatusBarPos* = enum
    sbpTop = "top"
    sbpBot = "bottom"
    sbpLeft = "left"
    sbpRight = "right"

  WindowState* = enum
    tiled, floating, fullScreen

  ManagedWindow* = object
    state*, lastState*: WindowState
    bounds*, lastBounds*: pixie.Rect
    window*: x.Window

  Workspace* = object
    active*: int
    windows*: seq[ManagedWindow]

  StatusBarDirection* = enum
    sbdLeft, sbdRight, sbdDown, sbdUp

  StatusBar* = object
    width*, height*: int
    img*: Image
    renderer*: Renderer
    window*: sdl.Window
    widgets*: Widgets
    dir*: StatusBarDirection

  Screen* = object
    isActive*: bool
    bounds*: pixie.Rect
    activeWorkspace*: int
    statusBar*: StatusBar
    barPos*: StatusBarPos
    barSize*: int
    margin*: int
    padding*: int
    layout*: ScreenLayout
    workSpaces*: seq[Workspace]

  WidgetKind* = enum
    wkWorkspace, wkTime, wkCommand

  Widget* = object
    size*: int
    margin*: int
    case kind*: WidgetKind
    of wkCommand:
      cmd*: string
    else: discard

  Widgets* = seq[Widget]

  ShortcutKind* = enum
    command
    function
    moveWindowToScreen
    forwardCarouselScreen
    backCarouselScreen
    forwardCarouselActive
    backCarouselActive

  TargettedShortcuts* = moveWindowToScreen .. backCarouselActive

  KeyEvent* = proc(d: var Desktop){.nimcall.}

  Shortcut* = object
    case kind*: ShortcutKind
    of command:
      cmd*: string
      args*: seq[string]
    of function:
      event*: KeyEvent
    of TargettedShortcuts.low .. TargettedShortcuts.high:
      targetScreen*: int

  MouseInput* = enum
    miNone = "none"
    miResizing = "resize"
    miMoving = "move"

  Desktop* = object
    display*: PDisplay
    root*: x.Window
    screen*: cint
    mouseXOffset*, mouseYOffset*: int
    screens*: seq[Screen]
    shortcuts*: Table[Key, Shortcut]
    mouseState*: MouseInput
    mouseEvent*: Table[Button, MouseInput]

  Key* = object
    code*: cuint
    modi*: cuint

  Button* = object
    btn*: range[1..5]
    modi*: cuint

  StatusBarData* = object
    openWorkspaces*: int
    activeWorkspace*: int

{.push inline.}
func getActiveScreen*(d: var Desktop): var Screen =
  for x in d.screens.mitems:
    if x.isActive:
      return x
  result = d.screens[0]

func getActiveScreen*(d: Desktop): Screen =
  for x in d.screens:
    if x.isActive:
      return x
  result = d.screens[0]


func getActiveWorkspace*(s: var Screen): var Workspace = s.workSpaces[s.activeWorkspace]
func getActiveWorkspace*(d: var Desktop): var Workspace = d.getActiveScreen.getActiveWorkSpace
func getActiveWorkspace*(s: Screen): Workspace = s.workSpaces[s.activeWorkspace]
func getActiveWorkspace*(d: Desktop): Workspace = d.getActiveScreen.getActiveWorkSpace

func hasActiveWindow*(w: Workspace): bool = w.active in 0..<w.windows.len
func hasActiveWindow*(s: Screen): bool = s.getActiveWorkspace.hasActiveWindow
func hasActiveWindow*(d: Desktop): bool = d.getActiveScreen.hasActiveWindow


func getActiveWindow*(w: Workspace): ManagedWindow =
  assert w.hasActiveWindow
  result = w.windows[w.active]
  for x in w.windows:
    if x.state == fullScreen:
      return x

func getActiveWindow*(s: Screen): ManagedWindow =
  assert s.hasActiveWindow
  s.getActiveWorkspace.getActiveWindow

func getActiveWindow*(d: Desktop): ManagedWindow =
  assert d.hasActiveWindow
  d.getActiveScreen.getActiveWindow


func getActiveWindow*(w: var Workspace): var ManagedWindow =
  assert w.hasActiveWindow
  result = w.windows[w.active]
  for x in w.windows.mitems:
    if x.state == fullScreen:
      return x

func getActiveWindow*(s: var Screen): var ManagedWindow =
  assert s.hasActiveWindow
  s.getActiveWorkspace.getActiveWindow

func getActiveWindow*(d: var Desktop): var ManagedWindow =
  assert d.hasActiveWindow
  d.getActiveScreen.getActiveWindow

func isFullScreened*(d: Desktop or Screen): bool = result = d.hasActiveWindow() and
    d.getActiveWindow().state == fullScreen

{.pop.}

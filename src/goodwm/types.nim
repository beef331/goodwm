import std/[tables, options]
import x11/[x, xlib]
import sdl2/sdl, pixie
type
  ScreenLayout* = enum
    verticalDown
    verticalUp
    horizontalRight
    horizontalLeft
    #alternatingRight, alternatingLeft

  StatusBarPos* = enum
    sbpTop = "top"
    sbpBot = "bottom"
    sbpLeft = "left"
    sbpRight = "right"

  KeyEvent* = proc(d: var Desktop){.nimcall.}
  ButtonEvent* = proc(d: var Desktop, isReleased: bool)

  ManagedWindow* = object
    isFloating*: bool
    bounds*: pixie.Rect
    window*: x.Window

  Workspace* = object
    active*: int
    windows*: seq[ManagedWindow]

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

  ShortcutKind* = enum
    command, function

  Shortcut* = object
    case kind*: ShortcutKind
    of command:
      cmd*: string
      args*: seq[string]
    of function:
      event*: KeyEvent

  MouseInput* = enum
    miNone = "none"
    miResizing = "resize"
    miMoving = "move"

  Desktop* = object
    display*: PDisplay
    root*: x.Window
    screen*: cint
    screens*: seq[Screen]
    activeWindow*: Option[x.Window]
    shortcuts*: Table[Key, Shortcut]
    mouseState*: MouseInput
    mouseEvent*: Table[Button, ButtonEvent]

  Key* = object
    code*: cuint
    modi*: cuint

  Button* = object
    btn*: range[1..5]
    modi*: cuint

  StatusBarDirection* = enum
    sbdLeft, sbdRight, sbdDown, sbdUp

  StatusBar* = object
    width*, height*: int
    img*: Image
    renderer*: Renderer
    window*: sdl.Window
    widgets*: Widgets
    dir*: StatusBarDirection

  WidgetKind* = enum
    wkWorkspace, wkTime, wkCommand

  Widget* = object
    size*: int
    margin*: int
    case kind*: WidgetKind
    of wkCommand:
      cmd*: string
    else: discard

  StatusBarData* = object
    openWorkspaces*: int
    activeWorkspace*: int

  KeyEvents* = enum
    keFocusUp = "focusup"
    keFocusDown = "focusdown"
    keMoveUp = "moveup"
    keMoveDown = "movedown"
    keClose = "close"
    keNextWorkspace = "nextworkspace"
    keLastWorkspace = "lastWorkspace"
    keWindowToNextWorkspace = "windowToNextWorkspace"
    keWindowToPrevWorkspace = "windowToPrevWorkspace"


  KeyConfig* = object
    cmd*, inputs*: string

  ButtonConfig* = object
    btn*, event*: string

  Widgets* = seq[Widget]

  Config* = object
    screenLayouts*: seq[string]
    screenStatusBarPos*: seq[string]
    padding*, margin*, barSize*: int
    backgroundColor*: string
    foregroundColor*: string
    accentColor*: string
    borderColor*: string
    fontColor*: string
    startupCommands*: seq[string]
    keyShortcuts*: seq[KeyConfig]
    mouseShortcuts*: seq[ButtonConfig]




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


func getActiveWindow*(w: var Workspace): var ManagedWindow = w.windows[w.active]
func getActiveWindow*(s: var Screen): var ManagedWindow = s.getActiveWorkspace.getActiveWindow
func getActiveWindow*(d: var Desktop): var ManagedWindow = d.getActiveScreen.getActiveWindow

func hasActiveWindow*(d: var Desktop): bool =
  let activeWs = d.getActiveWorkspace
  activeWs.active in 0..<activeWs.windows.len

{.pop.}

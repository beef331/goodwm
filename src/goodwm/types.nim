import std/[tables, options]
import x11/[x, xlib]
import sdl2/sdl, pixie
type
  ScreenLayout* = enum
    verticalDown, verticalUp, horizontalRight, horizontalLeft, #alternatingRight, alternatingLeft

  StatusBarPos* = enum
    sbpTop, sbpBot, sbpLeft, sbpRight

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
    padding*: int
    activeWorkspace*: int
    layout*: ScreenLayout
    barSize*: int
    barPos*: StatusBarPos
    statusbar*: StatusBar
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
    miNone, miResizing, miMoving

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

  Widgets* = seq[Widget]


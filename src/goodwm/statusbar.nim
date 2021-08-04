import pixie
import x11/x
import std/[times, osproc]
import sdl2/[sdl, sdl_syswm]

type
  StatusBarDirection* = enum
    sbdLeft, sbdRight, sbdDown, sbdUp

  StatusBar* = object
    width, height: int
    img: Image
    renderer: Renderer
    window: sdl.Window
    widgets: Widgets

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

const
  rmask = uint32 0x000000ff
  gmask = uint32 0x0000ff00
  bmask = uint32 0x00ff0000
  amask = uint32 0xff000000
var font = readFont("/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf")
let
  bg = parseHex("1f2430")
  fg = parseHex("cbccc6").rgba
font.paint.color = fg
font.size = 15

proc display(sb: StatusBar) =
  # update texture with new pixels from surface

  var dataPtr = sb.img.data[0].unsafeaddr
  let
    mainSurface = createRGBSurfaceFrom(dataPtr, cint sb.width, cint sb.height, cint 32, cint 4 *
      sb.width, rmask, gmask, bmask, amask)
    mainTexture = sb.renderer.createTextureFromSurface(mainSurface)
  discard sb.renderer.renderClear
  discard sb.renderer.renderCopy(mainTexture, nil, nil)
  sb.renderer.renderPresent
  destroyTexture(mainTexture)
  freeSurface(mainSurface)

proc getXWindow*(sb: StatusBar): x.Window =
  var wmInfo: SysWMinfo
  version(wmInfo.version)
  if getWindowWMInfo(sb.window, wmInfo.addr):
    result = wmInfo.info.x11.window
  else:
    debugecho "Cannot get info"

proc initStatusBar*(width, height: int, dir = sbdRight): StatusBar =
  discard init(InitVideo)
  result.window = createWindow("Goodwm Status Bar", 0, 0, cint width, cint height, WindowShown)
  result.renderer = createRenderer(result.window, -1, 0)
  result.img = newImage(width, height)
  result.width = width
  result.height = height
  result.img.fill(rgb(255, 255, 255))
  result.widgets.add Widget(kind: wkWorkspace, size: 100, margin: 5)
  result.widgets.add Widget(kind: wkTime)

proc drawWorkspaces(bar: StatusBar, active, count: int, wid: Widget, pos: var Vec2) =
  let ctx = newContext(bar.img)
  for i in 0..<count:
    if i == active:
      ctx.fillStyle = parseHex("ffcc66").rgba
    else:
      ctx.fillStyle = parseHex("707a8c").rgba
    let radius = bar.height / 2
    ctx.fillCircle(pos + vec2(radius, radius), radius)
    pos.x += radius * 2 + wid.margin.float


proc drawTime(bar: StatusBar, format: string, pos: var Vec2) =
  let
    timeString = format(now(), format)
    yOffset = font.size / 2

  bar.img.fillText(font, timeString, pos + vec2(0, yOffset.float))

proc drawCommand(bar: StatusBar, command: string, pos: var Vec2) =
  let msg = execProcess(command)
  bar.img.fillText(font, msg, pos)

proc drawBar*(bar: StatusBar, data: StatusBarData) =
  var pos = vec2(0, 0)
  bar.img.fill(bg)
  for i, widg in bar.widgets:
    case widg.kind
    of wkWorkspace:
      bar.drawWorkspaces(data.activeWorkspace, data.openWorkspaces, widg, pos)
    of wkTime:
      bar.drawTime("HH:mm:ss dd/MM/yy ddd", pos)
    of wkCommand:
      drawCommand(bar, widg.cmd, pos)

  bar.display

import pixie
import x11/x
import std/[times, osproc, options]
import sdl2/[sdl, sdl_syswm]
import types

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
  result.dir = dir
  result.img.fill(rgb(255, 255, 255))
  result.widgets.add Widget(kind: wkWorkspace, size: 150, margin: 5)
  result.widgets.add Widget(kind: wkTime)

proc calcMaxOffset(bar: StatusBar, wid: Widget, pos: Vec2): Option[Vec2] =
  if wid.size > 0:
    case bar.dir
    of sbdRight:
      result = some(pos + vec2(wid.size.float, 0))
    of sbdLeft:
      result = some(pos - vec2(wid.size.float, 0))
    of sbdDown:
      result = some(pos + vec2(0, wid.size.float))
    of sbdUp:
      result = some(pos - vec2(0, wid.size.float))


proc drawWorkspaces(bar: StatusBar, active, count: int, wid: Widget, pos: var Vec2) =
  let
    ctx = newContext(bar.img)
    maxSize = calcMaxOffset(bar, wid, pos)
  for i in 0..<count:
    if i == active:
      ctx.fillStyle = parseHex("ffcc66").rgba
    else:
      ctx.fillStyle = parseHex("707a8c").rgba
    let radius = bar.height / 2
    case bar.dir
    of sbdLeft, sbdUp:
      ctx.fillCircle(pos - vec2(radius, radius), radius)
    of sbdRight, sbdDown:
      ctx.fillCircle(pos + vec2(radius, radius), radius)

    case bar.dir:
    of sbdRight:
      pos.x += radius * 2 + wid.margin.float
    of sbdLeft:
      pos.x -= radius * 2 + wid.margin.float
    of sbdDown:
      pos.y += radius * 2 + wid.margin.float
    of sbdUp:
      pos.y -= radius * 2 + wid.margin.float

  if maxSize.isSome:
    pos = maxSize.get

proc drawTime(bar: StatusBar, format: string, pos: var Vec2) =
  let
    timeString = format(now(), format)
    yOffset = bar.height / 2
  bar.img.fillText(font, timeString, pos + vec2(0, yOffset.float), vAlign = vaMiddle)
  pos.x += font.computeBounds(timeString).x

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

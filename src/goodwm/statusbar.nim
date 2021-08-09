import pixie, x11/x
import std/[times, osproc, options, htmlparser, xmltree, strtabs, tables, strformat, parseutils, strutils]
import sdl2nim/[sdl, sdl_syswm]
import types

type XmlString = object
  msg: string
  color: ColorRGBA
  fontDesc: string

const
  rmask = uint32 0x000000ff
  gmask = uint32 0x0000ff00
  bmask = uint32 0x00ff0000
  amask = uint32 0xff000000
var loadedFonts: Table[string, fonts.Font]

let
  bg = parseHex("1f2430")
  fg = parseHex("cbccc6").rgba


proc getFont(name: string): fonts.Font =
  var name = name
  name.removeSuffix({'0'..'9'})
  if not loadedFonts.hasKey(name):
    let fonts = execProcess(fmt"fc-list", args = [name], options = {poUsePath})
    var path = ""
    discard fonts.parseUntil(path, ':')

    loadedFonts[name] = readFont(path)

  loadedFonts[name]

iterator getXmlStrings(s: XmlNode): XmlString =
  case s.kind
  of xnText:
    var str = XmlString()
    str.color = fg
    str.msg = s.innerText
    yield str
  else:
    for x in s:
      if x.kind != xnText:
        var str = XmlString()
        if x.attrs != nil:
          if x.attrs.hasKey "foreground":
            str.color = parseHex(x.attrs["foreground"][1..^1]).rgba
          if x.attrs.hasKey "font_desc":
            str.fontDesc = x.attrs["font_desc"]
        str.msg = x.innerText
        yield str
      else:
        var str = XmlString()
        str.color = fg
        str.msg = x.innerText
        yield str


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

proc updateStatusBar*(result: var StatusBar, width, height: int, dir = sbdRight) =
  if result.window.isNil:
    result.window = createWindow("Goodwm Status Bar", 0, 0, cint width, cint height, 0)
    result.renderer = createRenderer(result.window, 0, 0)
  result.img = newImage(width, height)
  result.width = width
  result.height = height
  result.dir = dir
  result.img.fill(rgb(255, 255, 255))
  result.widgets = @[Widget(kind: wkWorkspace, margin: 5), Widget(kind: wkTime), Widget(
      kind: wkCommand, cmd: "rofication-status")]

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

proc drawText(bar: StatusBar, msg: string, pos: var Vec2) =
  let yOffset = bar.height / 2
  try:
    let parsed = msg.parseHtml
    for colTxt in parsed.getXmlStrings:
      var font = getFont(colTxt.fontDesc)
      font.paint = colTxt.color
      font.size = bar.height / 2
      bar.img.fillText(font, colTxt.msg, pos + vec2(0, yOffset.float), vAlign = vaMiddle)
      pos.x += font.computeBounds(colTxt.msg).x
  except: discard


proc drawTime(bar: StatusBar, format: string, pos: var Vec2) =
  let timeString = format(now(), format)
  bar.drawText(timeString, pos)

proc drawCommand(bar: StatusBar, command: string, pos: var Vec2) =
  let msg = execProcess(command)
  bar.drawText(msg, pos)

proc drawBar*(bar: StatusBar, data: StatusBarData) =
  if bar.img != nil:
    var pos = vec2(0, 0)
    bar.img.fill(bg)
    for i, widg in bar.widgets:
      case widg.kind
      of wkWorkspace:
        bar.drawWorkspaces(data.activeWorkspace, data.openWorkspaces, widg, pos)
      of wkTime:
        bar.drawTime("HH:mm:ss dd/MM/yy ddd ", pos)
      of wkCommand:
        drawCommand(bar, widg.cmd, pos)

    bar.display



when isMainModule:
  echo getFont("JetBrains Mono Medium")

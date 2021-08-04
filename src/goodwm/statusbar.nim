import pixie
import x11/x
import std/times
import sdl2/[sdl, sdl_syswm]

type
  StatusBarDirection* = enum
    sbdLeft, sbdRight, sbdDown, sbdUp
  StatusBar* = object
    width, height: int
    img: Image
    renderer: Renderer
    window: sdl.Window

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
  sb.img.fill(bg)
  let timeString = format(now(), "HH:mm:ss dd/MM/yy ddd")
  sb.img.fillText(font, timeString, vec2(0, 0))
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

proc drawBar*(bar: StatusBar) =
  bar.display

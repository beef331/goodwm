import bumpy, cps
import std/[options, math]
import x11/xlib
import types

type
  LayoutIter* = ref object of Continuation
    rect: Option[Rect]


func calcFreeSpace*(rect: Rect, barPos: StatusBarPos, barSize, margin: int): Rect =
  result = rect
  case barPos:
  of sbpTop:
    result.y += barSize.float
    result.h -= barSize.float
  of sbpBot:
    result.h -= barSize.float
  of sbpLeft:
    result.x += barSize.float
    result.w -= barSize.float
  of sbpRight:
    result.w -= barSize.float

  result.x += margin.float
  result.y += margin.float
  result.w -= margin.float * 2
  result.h -= margin.float * 2


proc getBounds*(c: LayoutIter): Rect =
  block:
    var c: Continuation = c
    while c.running and (LayoutIter c).rect.isNone:
      c = c.fn(c)
  if not c.dismissed:
    if c.rect.isSome:
      result = c.rect.get
      c.rect = none(Rect)

proc jield(c: LayoutIter, rect: Rect): LayoutIter {.cpsMagic.} =
  c.rect = some(rect)
  return c

proc layoutVerticalUp(freeSpace: Rect, count, padding: int) {.cps: LayoutIter.} =
  if count == 0:
    jield freeSpace
  else:
    let
      width = freeSpace.w
      height = freeSpace.h / count.float - padding.float * count.float
    var
      y = freeSpace.y + freeSpace.h
      i = 0
    while i < count:
      jield rect(freeSpace.x, y, width, height)
      y -= height + padding.float
      inc i

proc layoutVerticalDown(freeSpace: Rect, count, padding: int) {.cps: LayoutIter.} =
  if count == 0:
    jield freeSpace
  else:
    let
      width = freeSpace.w
      height = freeSpace.h / count.float
    var
      y = freeSpace.y
      i = 0
    while i < count:
      jield rect(freeSpace.x, y, width, height)
      y += height
      inc i

proc layoutHorizontalRight(freeSpace: Rect, count, padding: int) {.cps: LayoutIter.} =
  if count == 1:
    jield freeSpace
  else:
    let
      width =
        if padding > 0:
          (freeSpace.w - (count.float - 1) * padding.float) / count.float
        else:
          (freeSpace.w.int div count).float
      height = freeSpace.h
    var
      x = freeSpace.x
      i = 0
    while i < count:
      jield rect(x, freeSpace.y, width, height)
      x += width
      if padding > 0:
        x += padding.float
      inc i

proc layoutHorizontalLeft(freeSpace: Rect, count, padding: int) {.cps: LayoutIter.} =
  if count == 1:
    jield freeSpace
  else:
    let
      width = freeSpace.w / count.float
      height = freeSpace.h
    var
      x = freeSpace.x + freeSpace.w
      i = 0
    while i < count:
      jield rect(x, freeSpace.y, width, height)
      x -= width
      inc i

proc layourAlterLeft(freeSpace: Rect, count, padding: int) {.cps: LayoutIter.} =
  if count == 1:
    jield freeSpace
  else:
    var
      rect = freeSpace
      i = 0
    while i < count:
      if i + 1 < count:
        if i mod 2 == 0:
          rect.w /= 2
          rect.w -= padding.float / 2
        else:
          rect.h /= 2
          rect.h -= padding.float / 2
      jield rect

      if i + 1 < count:
        if i mod 2 == 0:
          rect.x += rect.w + padding.float
        else:
          rect.y += rect.h + padding.float

      inc i


proc layourAlterRight(freeSpace: Rect, count, padding: int) {.cps: LayoutIter.} =
  if count == 1:
    jield freeSpace
  else:
    var
      rect = freeSpace
      i = 0
    while i < count:
      if i + 1 < count:
        if i mod 2 == 0:
          rect.w /= 2
          rect.w -= padding / 2
        else:
          rect.h /= 2
          rect.h -= padding / 2
      var properRect = rect
      properRect.x = freeSpace.w - rect.x - rect.w + freespace.x * 2
      {.warning: "Need to fix this weird offset on vertical splits".}
      jield properRect

      if i + 1 < count:
        if i mod 2 == 0:
          rect.x += rect.w + padding.float
        else:
          rect.y += rect.h + padding.float

      inc i

#
proc getLayout*(freeSpace: Rect, count, padding: int, layout: ScreenLayout): LayoutIter =
  result =
    case layout:
    of horizontalLeft:
      whelp layoutHorizontalLeft(freeSpace, count, padding)
    of horizontalRight:
      whelp layoutHorizontalRight(freeSpace, count, padding)
    of verticalDown:
      whelp layoutVerticalDown(freeSpace, count, padding)
    of verticalUp:
      whelp layoutVerticalUp(freeSpace, count, padding)
    of alternateLeft:
      whelp layourAlterLeft(freeSpace, count, padding)
    of alternateRight:
      whelp layourAlterRight(freeSpace, count, padding)



func tiledWindows*(s: Workspace): int =
  ## Counts the tiled windows
  for w in s.windows:
    if not w.isFloating:
      inc result

func layoutActive*(d: var Desktop) =
  ## Calls the coresponding layout logic required
  for scr in d.screens.mitems:
    let tiledWindowCount = scr.getActiveWorkspace.tiledWindows()
    if tiledWindowCount > 0:
      {.noSideEffect.}: # I'm a liar and a scoundrel
        let
          freeSpace = calcFreeSpace(scr.bounds, scr.barPos, scr.barSize, scr.margin)
          layout = getLayout(freeSpace, tiledWindowCount, scr.padding, scr.layout)
        for i, w in scr.getActiveWorkspace.windows:
          if not w.isFloating:
            let bounds = layout.getBounds()
            scr.getActiveWorkspace.windows[i].bounds = bounds
            discard XMoveResizeWindow(d.display, w.window, bounds.x.cint, bounds.y.cint,
                bounds.w.cuint, bounds.h.cuint)

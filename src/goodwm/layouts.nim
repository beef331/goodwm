import bumpy
import std/[options, math]
import x11/xlib
import types
import slicerator

type
  LayoutIter* = iterator(): Rect

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


iterator layoutVerticalUp(freeSpace: Rect, count, padding: int): Rect =
  if count == 0:
    yield freeSpace
  else:
    let
      width = freeSpace.w
      height = freeSpace.h / count.float - padding.float * count.float
    var
      y = freeSpace.y + freeSpace.h
      i = 0
    while i < count:
      yield rect(freeSpace.x, y, width, height)
      y -= height + padding.float
      inc i

iterator layoutVerticalDown(freeSpace: Rect, count, padding: int): Rect =
  if count == 0:
    yield freeSpace
  else:
    let
      width = freeSpace.w
      height =
        if padding > 0:
          (freeSpace.h - (count.float - 1) * padding.float) / count.float
        else:
          (freeSpace.h.int div count).float
    var
      y = freeSpace.y
      i = 0
    while i < count:
      yield rect(freeSpace.x, y, width, height)
      y += height
      if padding > 0:
        y += padding.float
      inc i

iterator layoutHorizontalRight(freeSpace: Rect, count, padding: int): Rect =
  if count == 1:
    yield freeSpace
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
      yield rect(x, freeSpace.y, width, height)
      x += width
      if padding > 0:
        x += padding.float
      inc i

iterator layoutHorizontalLeft(freeSpace: Rect, count, padding: int): Rect =
  if count == 1:
    yield freeSpace
  else:
    let
      width =
        if padding > 0:
          (freeSpace.w - (count.float - 1) * padding.float) / count.float
        else:
          (freeSpace.w.int div count).float
      height = freeSpace.h
    var
      x = freeSpace.w - width + freeSpace.x
      i = 0
    while i < count:
      yield rect(x, freeSpace.y, width, height)
      x -= width
      if padding > 0:
        x -= padding.float
      inc i

iterator layoutAlterLeft(freeSpace: Rect, count, padding: int): Rect =
  if count == 1:
    yield freeSpace
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
      yield rect

      if i + 1 < count:
        if i mod 2 == 0:
          rect.x += rect.w + padding.float
        else:
          rect.y += rect.h + padding.float

      inc i


iterator layoutAlterRight(freeSpace: Rect, count, padding: int): Rect =
  if count == 1:
    yield freeSpace
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
      yield properRect

      if i + 1 < count:
        if i mod 2 == 0:
          rect.x += rect.w + padding.float
        else:
          rect.y += rect.h + padding.float

      inc i

proc getLayout*(freeSpace: Rect, count, padding: int, layout: ScreenLayout): LayoutIter =
  case layout:
  of horizontalLeft:
    asClosure layoutHorizontalLeft(freeSpace, count, padding)
  of horizontalRight:
    asClosure layoutHorizontalRight(freeSpace, count, padding)
  of verticalDown:
    asClosure layoutVerticalDown(freeSpace, count, padding)
  of verticalUp:
    asClosure layoutVerticalUp(freeSpace, count, padding)
  of alternateLeft:
    asClosure layoutAlterLeft(freeSpace, count, padding)
  of alternateRight:
    asClosure layoutAlterRight(freeSpace, count, padding)

func tiledWindows*(s: Workspace): int =
  ## Counts the tiled windows
  for w in s.windows:
    if w.state == tiled:
      inc result

func layoutActive*(d: var Desktop) =
  ## Calls the coresponding layout logic required
  for scr in d.screens.mitems:
    if scr.isFullScreened:
      let win = scr.getActiveWindow()
      discard XRaiseWindow(d.display, win.window)
    else:
      let tiledWindowCount = scr.getActiveWorkspace.tiledWindows()
      if tiledWindowCount > 0:
        {.noSideEffect.}: # I'm a liar and a scoundrel
          let
            freeSpace = calcFreeSpace(scr.bounds, scr.barPos, scr.barSize, scr.margin)
            layout = getLayout(freeSpace, tiledWindowCount, scr.padding, scr.layout)
          for i, w in scr.getActiveWorkspace.windows:
            case w.state
            of tiled:
              let bounds = layout()
              scr.getActiveWorkspace.windows[i].bounds = bounds
              discard XMoveResizeWindow(d.display, w.window, bounds.x.cint, bounds.y.cint,
                  bounds.w.cuint, bounds.h.cuint)
            else:
              discard XRaiseWindow(d.display, w.window)

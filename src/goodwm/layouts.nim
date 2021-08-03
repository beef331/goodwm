import bumpy, cps
import std/options

type
  ScreenLayout* = enum
    verticalDown, verticalUp, horizontalRight, horizontalLeft, #alternatingRight, alternatingLeft

  StatusBarPos* = enum
    sbpTop, sbpBot, sbpLeft, sbpRight

  LayoutIter* = ref object of Continuation
    rect: Option[Rect]


func calcFreeSpace*(rect: Rect, barPos: StatusBarPos, size: int): Rect =
  result = rect
  case barPos:
  of sbpTop:
    result.y += size.float
  of sbpBot:
    result.h -= size.float
  of sbpLeft:
    result.x += size.float
  of sbpRight:
    result.w -= size.float


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

proc layoutVerticalUp(freeSpace: Rect, count: int) {.cps: LayoutIter.} =
  if count == 0:
    jield freeSpace
  else:
    let
      width = freeSpace.w
      height = freeSpace.h / count.float
    var
      y = freeSpace.y + freeSpace.h
      i = 0
    while i < count:
      jield rect(freeSpace.x, y, width, height)
      y -= height
      inc i

proc layoutVerticalDown(freeSpace: Rect, count: int) {.cps: LayoutIter.} =
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

proc layoutHorizontalRight(freeSpace: Rect, count: int) {.cps: LayoutIter.} =
  if count == 1:
    jield freeSpace
  else:
    let
      width = freeSpace.w / count.float
      height = freeSpace.h
    var
      x = freeSpace.x
      i = 0
    while i < count:
      jield rect(x, freeSpace.y, width, height)
      x += width
      inc i

proc layoutHorizontalLeft(freeSpace: Rect, count: int) {.cps: LayoutIter.} =
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

proc getLayout*(freeSpace: Rect, count: int, layout: ScreenLayout): LayoutIter =
  result =
    case layout:
    of horizontalLeft:
      whelp layoutHorizontalLeft(freeSpace, count)
    of horizontalRight:
      whelp layoutHorizontalRight(freeSpace, count)
    of verticalDown:
      whelp layoutVerticalDown(freeSpace, count)
    of verticalUp:
      whelp layoutVerticalUp(freeSpace, count)

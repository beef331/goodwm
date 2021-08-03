import bumpy

type
  ScreenLayout* = enum
    verticalDown, verticalUp, horizontalRight, horizontalLeft, #alternatingRight, alternatingLeft

proc layoutVerticalUp(freeSpace: Rect, count: int): iterator(): Rect =
  result = iterator(): Rect =
    if count == 0:
      yield freeSpace
    else:
      let
        width = freeSpace.w
        height = freeSpace.h / count.float
      var y = freeSpace.y + freeSpace.h
      for _ in 0..<count:
        yield rect(freeSpace.x, y, width, height)
        y -= height

proc layoutVerticalDown(freeSpace: Rect, count: int): iterator(): Rect =
  result = iterator(): Rect =
    if count == 0:
      yield freeSpace
    else:
      let
        width = freeSpace.w
        height = freeSpace.h / count.float
      var y = freeSpace.y
      for _ in 0..<count:
        yield rect(freeSpace.x, y, width, height)
        y += height

proc layoutHorizontalRight(freeSpace: Rect, count: int): iterator(): Rect =
  result = iterator(): Rect =
    if count == 1:
      yield freeSpace
    else:
      let
        width = freeSpace.w / count.float
        height = freeSpace.h
      var x = freeSpace.x
      for _ in 0..<count:
        yield rect(x, freeSpace.y, width, height)
        x += width

proc layoutHorizontalLeft(freeSpace: Rect, count: int): iterator(): Rect =
  result = iterator(): Rect =
    if count == 1:
      yield freeSpace
    else:
      let
        width = freeSpace.w / count.float
        height = freeSpace.h
      var x = freeSpace.x + freeSpace.w
      for _ in 0..<count:
        yield rect(x, freeSpace.y, width, height)
        x -= width

proc getLayout*(freeSpace: Rect, count: int, layout: ScreenLayout): iterator(): Rect =
  result =
    case layout:
    of horizontalLeft:
      layoutHorizontalLeft(freeSpace, count)
    of horizontalRight:
      layoutHorizontalRight(freeSpace, count)
    of verticalDown:
      layoutVerticalDown(freeSpace, count)
    of verticalUp:
      layoutVerticalUp(freeSpace, count)

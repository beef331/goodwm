import pixie, glfw, opengl

type
  StatusBarDirection* = enum
    sbdLeft, sbdRight, sbdDown, sbdUp
  StatusBar* = object
    width, height: int
    img: Image
    ctx: Context
    window: Window

proc display(statusBar: StatusBar) = 
  # update texture with new pixels from surface
  var dataPtr = statusBar.img.data[0].unsafeaddr
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, GLsizei statusBar.width, GLsizei statusBar.height, GL_RGBA,
      GL_UNSIGNED_BYTE, dataPtr)

  # draw a quad over the whole screen
  glClear(GL_COLOR_BUFFER_BIT)
  glBegin(GL_QUADS)
  glTexCoord2d(0.0, 0.0); glVertex2d(-1.0, +1.0)
  glTexCoord2d(1.0, 0.0); glVertex2d(+1.0, +1.0)
  glTexCoord2d(1.0, 1.0); glVertex2d(+1.0, -1.0)
  glTexCoord2d(0.0, 1.0); glVertex2d(-1.0, -1.0)
  glEnd()

  swapBuffers(statusBar.window)

proc initStatusBar*(width, height: int, dir = sbdRight): StatusBar =
  glfw.initialize()
  result.window = createWindow(width.cint, height.cint, "Goodwm Status Bar", nil, nil)
  makeContextCurrent(result.window)
  loadExtensions()

proc drawBar*(bar: StatusBar) =
  bar.display
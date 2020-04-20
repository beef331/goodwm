import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nimgl/[opengl, glfw]
import nimgl/imgui
import nimgl/glfw/native
import x11/xlib,x11/x
import times
import widget

type
    Bar* = ref object of Rootobj
        window : GLFWWindow
        width : float32
        height : float32
        widgets : seq[Widget]

proc newCol(x,y,z:float): ImVec4 = ImVec4(x:x,y:y,z:z,w:1)


proc addWidget*(bar : var Bar,widget:Widget)= bar.widgets.add(widget)


var 
    bars : seq[Bar] 
    fontsize : float32 = 24
    taskSpacing : float32 = 5

const windowFlags =  ImGuiWindowFlags(
                                    ImGuiWindowFlags.NoDecoration.int or
                                    ImGuiWindowFlags.AlwaysAutoResize.int or
                                    ImGuiWindowFlags.NoMove.int)

let themed = false



proc barLoop*()=
    glfwPollEvents()
    for bar in bars:
        bar.window.makeContextCurrent()

        discard setMouseButtonCallback(bar.window,nil)
        discard setKeyCallback(bar.window,nil)
        discard setCharCallback(bar.window,nil)
        discard setScrollCallback(bar.window,nil)

        assert glInit()
        var context = igCreateContext()
        assert igGlfwInitForOpenGL(bar.window, true)
        if(not themed):
            var style = igGetStyle()
            style.windowPadding = ImVec2(x:0f,y:0f)
            style.windowRounding = 0f


        glClearColor(1,1,1,0)
        glClear(GL_COLOR_BUFFER_BIT)
        igOpenGL3NewFrame()
        igGlfwNewFrame()
        igNewFrame()
        igSetNextWindowSize(ImVec2(x:bar.width,y:bar.height),ImGuiCond.Always)
        igSetNextWindowPos(ImVec2(x:0,y:0),ImGuiCond.Always)
        igBegin("Goodwm Status Bar",flags = windowFlags)

        for x in bar.widgets:
            x.draw(fontsize,bar.width,bar.height)

        igEnd()
        igRender()
        igOpenGL3RenderDrawData(igGetDrawData())
        bar.window.swapbuffers()
        igOpenGL3Shutdown()
        igGlfwShutdown()



proc spawnStatusBar*(width,height:int32) : (Bar,pointer)=
    ##Bar in A pointer in B
    let w : GLFWWindow = glfwCreateWindow(width, height, "Goodwm status bar")
    if(w == nil): return (nil,nil)

    var bar = Bar(window:w,
                width : float32(width),
                height : float32(height))
    result = (bar,getX11Window(w))
    bars.add(bar)


proc init() =
    assert glfwInit()

    glfwWindowHint(GLFWContextVersionMajor, 3)
    glfwWindowHint(GLFWContextVersionMinor, 3)
    glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
    glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFWResizable, GLFW_FALSE)


init()


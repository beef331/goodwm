import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nimgl/[opengl, glfw]
import nimgl/imgui
import nimgl/glfw/native
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

const windowFlags =  ImGuiWindowFlags(
                                    ImGuiWindowFlags.NoDecoration.int or
                                    ImGuiWindowFlags.AlwaysAutoResize.int or
                                    ImGuiWindowFlags.NoMove.int)


proc barLoop*()=
    glfwPollEvents()
    for bar in bars:
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

        glClearColor(1,1,1,1)
        glClear(GL_COLOR_BUFFER_BIT)

        igOpenGL3RenderDrawData(igGetDrawData())
        bar.window.swapbuffers()



proc spawnStatusBar*(width,height:int32) : (Bar,pointer)=
    ##Bar in A pointer in B

    var window : GLFWWindow

    if(bars.len == 0):
        window = glfwCreateWindow(width, height, "Goodwm status bar")
        if(window == nil): return (nil,nil)
        
        window.makeContextCurrent()
        assert igOpenGL3Init()
        assert glInit()

        var style = igGetStyle()
        style.windowPadding = ImVec2(x:0f,y:0f)
        style.windowRounding = 0

        assert igGlfwInitForOpenGL(window, true)

    else:
        window  = glfwCreateWindow(width, height, "Goodwm status bar",share = bars[0].window)

    var bar = Bar(window:window,
                width : float32(width),
                height : float32(height))

    result = (bar,getX11Window(window))
    bars.add(bar)
    


proc init() =
    assert glfwInit()

    glfwWindowHint(GLFWContextVersionMajor, 3)
    glfwWindowHint(GLFWContextVersionMinor, 3)
    glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
    glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFWResizable, GLFW_FALSE)
    igCreateContext()

init()


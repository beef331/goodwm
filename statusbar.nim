import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nimgl/[opengl, glfw]
import nimgl/imgui
import nimgl/glfw/native
import x11/xlib,x11/x
import times

type
    Bar* = ref object of Rootobj
        window : GLFWWindow
        width : float32
        height : float32
        workspaceSym : seq[string]
        activeWorkspace : int

proc newCol(x,y,z:float): ImVec4 = ImVec4(x:x,y:y,z:z,w:1)

var 
    bars : seq[Bar] 
    activeWorkspaceCol = newCol(0,0.3,0.9)
    inactiveWorkspaceCol = newCol(0,0.3,0.5)
    fontsize : float32 = 24
    taskSpacing : float32 = 5

const windowFlags =  ImGuiWindowFlags(
                                    ImGuiWindowFlags.NoDecoration.int or
                                    ImGuiWindowFlags.AlwaysAutoResize.int or
                                    ImGuiWindowFlags.NoMove.int)

let themed = false

proc barLoop*()=
    for bar in bars:
        bar.window.makeContextCurrent()
        assert glInit()
        let context = igCreateContext()
        assert igGlfwInitForOpenGL(bar.window, true)
        if(not themed):
            var style = igGetStyle()
            style.windowRounding = 0f  


        glClearColor(1,1,1,0)
        glClear(GL_COLOR_BUFFER_BIT)
        igOpenGL3NewFrame()
        igGlfwNewFrame()
        igNewFrame()
        igSetNextWindowSize(ImVec2(x:bar.width,y:bar.height),ImGuiCond.Always)
        igSetNextWindowPos(ImVec2(x:0,y:0),ImGuiCond.Always)
        igBegin("Goodwm Status Bar",flags = windowFlags)
        for x in 0..<bar.workspaceSym.len:
            igSetCursorPosY(0)
            if(igButton(bar.workspaceSym[x],ImVec2(x:fontsize,y:bar.height))):
                echo bar.workspaceSym[x]
            igSameLine(0,taskSpacing - fontsize)

            #[
            if(x == bar.activeWorkspace):
                igTextColored(activeWorkspaceCol,bar.workspaceSym[x])
            else: igTextColored(inactiveWorkspaceCol,bar.workspaceSym[x])
            igSameLine(0,taskSpacing)
            ]#


        igEnd()
        igRender()
        igOpenGL3RenderDrawData(igGetDrawData())
        bar.window.swapbuffers()



proc spawnStatusBar*(width,height:int32, workspaceSym : seq[string]) : pointer=
    let w : GLFWWindow = glfwCreateWindow(width, height, "Goodwm status bar")
    if(w == nil): return nil
    var bar = Bar(window:w,
                width:float32(width),
                height:float32(height),
                workspaceSym:workspaceSym)
    result = getX11Window(w)
    bars.add(bar)


proc init() =
    assert glfwInit()

    glfwWindowHint(GLFWContextVersionMajor, 3)
    glfwWindowHint(GLFWContextVersionMinor, 3)
    glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE) # Used for Mac
    glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
    glfwWindowHint(GLFWResizable, GLFW_FALSE)

    



init()


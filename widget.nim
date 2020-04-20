type
    Widget* = ref object of Rootobj
        draw* : proc(fontSize,bwidth,bheight:float32)
package platform_wasm

import gl "vendor:wasm/WebGL"
import dm "../dmcore"

import "core:fmt"

ScreenSpaceRectShaderSource := #load("ScreenSpaceRect.glsl", string)
SpriteShaderSource := #load("Sprite.glsl", string)
SDFFontSource := #load("SDFFont.glsl", string)

Shader_webgl :: struct {
    using base: dm.Shader,

    shaderID: gl.Program
}


Texture_wgl :: struct {
    using info: dm.TextureInfo,

    texId: gl.Texture,
}

BatchRenderData_wgl :: struct {
    buffer: gl.Buffer,
    vao: gl.VertexArrayObject,

    // perBatchUBO: gl.Buffer,
}

////
shaders: dm.ResourcePool(Shader_webgl, dm.ShaderHandle)
textures: dm.ResourcePool(Texture_wgl, dm.TexHandle)
batches: dm.ResourcePool(BatchRenderData_wgl, dm.BatchHandle)
////

PerFrameDataBindingPoint :: 0
perFrameDataBuffer: gl.Buffer

PerFrameData :: struct {
    MVP: dm.mat4
}

////

InitRenderContext :: proc(ctx: ^dm.RenderContext) {
    assert(ctx != nil)

    dm.InitResourcePool(&textures, 16)
    dm.InitResourcePool(&shaders, 16)
    dm.InitResourcePool(&batches, 16)

    ctx.CreateTexture = CreateTexture
    ctx.DrawBatch = DrawBatch
    ctx.CreateRectBatch = CreateRectBatch
    ctx.GetTextureInfo  = GetTextureInfo

    ctx.defaultShaders[.ScreenSpaceRect] = CompileShaderSource(ctx, ScreenSpaceRectShaderSource)
    ctx.defaultShaders[.Sprite] = CompileShaderSource(ctx, SpriteShaderSource)
    ctx.defaultShaders[.SDFFont] = CompileShaderSource(ctx, SDFFontSource)

    perFrameDataBuffer = gl.CreateBuffer()
    gl.BindBuffer(gl.UNIFORM_BUFFER, perFrameDataBuffer)
    gl.BufferData(gl.UNIFORM_BUFFER, size_of(PerFrameData), nil, gl.DYNAMIC_DRAW)
    gl.BindBufferRange(gl.UNIFORM_BUFFER, PerFrameDataBindingPoint, 
                       perFrameDataBuffer, 0, size_of(PerFrameData))
    gl.BindBuffer(gl.UNIFORM_BUFFER, 0)

    //////


    texData := []u8{255, 255, 255, 255}
    ctx.whiteTexture = CreateTexture(texData, 1, 1, 4, ctx)

    CreateRectBatch(ctx, &ctx.defaultBatch, 2048)
    CreatePrimitiveBatch(ctx, 1024)

    ctx.frameSize = {800, 600}

    /////

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

}

GetTextureInfo :: proc(handle: dm.TexHandle) -> (dm.TextureInfo, bool) {
    info := dm.GetElement(textures, handle)
    if info == nil {
        return {}, false
    }
    else {
        return info^, true
    }
}

CreateTexture :: proc(rawData: []u8, width, height, channels: i32, renderCtx: ^dm.RenderContext) -> dm.TexHandle {
    handle := dm.CreateHandle(textures)
    texture := dm.GetElement(textures, handle)

    texture.width = width
    texture.height = height
    texture.handle = handle

    texture.texId = gl.CreateTexture()
    gl.BindTexture(gl.TEXTURE_2D, texture.texId)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.NEAREST))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.NEAREST))

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, len(rawData), raw_data(rawData))

    gl.BindTexture(gl.TEXTURE_2D, 0)

    return dm.TexHandle(handle)
}

//////

CreateRectBatch :: proc(renderCtx: ^dm.RenderContext, batch: ^dm.RectBatch, count: int) {
    handle := dm.CreateHandle(batches)

    assert(handle.index != 0)

    renderData := dm.GetElement(batches, handle)

    // renderData.perBatchUBO = gl.CreateBuffer()
    // gl.BindBuffer(gl.UNIFORM_BUFFER, renderData.perBatchUBO)
    // gl.BufferData(gl.UNIFORM_BUFFER, size_of(BatchConstants), nil, gl.DYNAMIC_DRAW)

    // gl.BindBufferRange(gl.UNIFORM_BUFFER, 0, renderData.perBatchUBO, 0, size_of(BatchConstants))

    // gl.BindBuffer(gl.UNIFORM_BUFFER, 0)

    renderData.vao = gl.CreateVertexArray()
    gl.BindVertexArray(renderData.vao)

    renderData.buffer = gl.CreateBuffer()
    gl.BindBuffer(gl.ARRAY_BUFFER, renderData.buffer)
    gl.BufferData(gl.ARRAY_BUFFER, count * size_of(dm.RectBatchEntry),
                  nil, gl.DYNAMIC_DRAW)

    // layout (location = 0) in vec2 aPos;
    // layout (location = 1) in vec2 aSize;
    // layout (location = 2) in vec2 aTexPos;
    // layout (location = 3) in vec2 aTexSize;
    // layout (location = 4) in vec4 aColor;

    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, position))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, size))
    gl.VertexAttribPointer(2, 2, gl.UNSIGNED_INT,   false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, texPos))
    gl.VertexAttribPointer(3, 2, gl.UNSIGNED_INT,   false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, texSize))
    gl.VertexAttribPointer(4, 4, gl.FLOAT, false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, color))

    // @TODO: split input layour between SSRect and SpriteRect
    gl.VertexAttribPointer(5, 1, gl.FLOAT, false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, rotation))
    gl.VertexAttribPointer(6, 2, gl.FLOAT, false, size_of(dm.RectBatchEntry), offset_of(dm.RectBatchEntry, pivot))


    gl.VertexAttribDivisor(0, 1)
    gl.VertexAttribDivisor(1, 1)
    gl.VertexAttribDivisor(2, 1)
    gl.VertexAttribDivisor(3, 1) 
    gl.VertexAttribDivisor(4, 1)
    gl.VertexAttribDivisor(5, 1)
    gl.VertexAttribDivisor(6, 1)

    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.EnableVertexAttribArray(3)
    gl.EnableVertexAttribArray(4)
    gl.EnableVertexAttribArray(5)
    gl.EnableVertexAttribArray(6)

    gl.BindVertexArray(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    batch.buffer = make([]dm.RectBatchEntry, count)
    batch.maxCount = count
    batch.renderData = handle
}

DrawBatch :: proc(ctx: ^dm.RenderContext, batch: ^dm.RectBatch) {
    if(batch.count == 0) {
        return
    }

    assert(dm.IsHandleValid(batches, batch.renderData))
    renderData := dm.GetElement(batches, batch.renderData)


    tex := dm.GetElement(textures, batch.texture)
    gl.BindTexture(gl.TEXTURE_2D, tex.texId)

    shader := dm.GetElement(shaders, batch.shader)
    gl.UseProgram(shader.shaderID)

    blockIdx := gl.GetUniformBlockIndex(shader.shaderID, "PerFrameData")
    if blockIdx != -1 {
        gl.UniformBlockBinding(shader.shaderID, blockIdx, PerFrameDataBindingPoint)
    }
    // gl.UniformMatrix4fv(gl.GetUniformLocation(shader.shaderID, "MVP"), MVP)
    
    oneOverAtlasSize := dm.v2{1 / f32(tex.width), 1 / f32(tex.height)}
    // @TODO: get frame size from context
    screenSize := dm.v2{ 2. / 800., -2./600.}

    gl.Uniform2fv(gl.GetUniformLocation(shader.shaderID, "OneOverAtlasSize"), oneOverAtlasSize)
    gl.Uniform2fv(gl.GetUniformLocation(shader.shaderID, "ScreenSize"), screenSize)

    gl.BindVertexArray(renderData.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, renderData.buffer)


    gl.BufferSubData(gl.ARRAY_BUFFER, 0, batch.count * size_of(dm.RectBatchEntry), raw_data(batch.buffer))

    // fmt.println(mem.slice_data_cast([]u32, batch.buffer[0:1]))

    gl.DrawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, batch.count)

    gl.BindVertexArray(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)
    gl.UseProgram(0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)

    batch.count = 0
}


CompileShaderSource :: proc(renderCtx: ^dm.RenderContext, source: string) -> dm.ShaderHandle {
    @static header := "#version 300 es\n"

    vertShader := gl.CreateShader(gl.VERTEX_SHADER)
    defer gl.DeleteShader(vertShader)

    gl.ShaderSource(vertShader, {header, "#define VERTEX \n", source})
    gl.CompileShader(vertShader)

    buf: [1024]byte

    // @TODO: better errors
    if gl.GetShaderiv(vertShader, gl.COMPILE_STATUS) == 0 {
        error := gl.GetShaderInfoLog(vertShader, buf[:])
        fmt.eprintf(error)
        panic("failed compiling vert shader")
    }

    fragShader := gl.CreateShader(gl.FRAGMENT_SHADER)
    defer gl.DeleteShader(fragShader)

    gl.ShaderSource(fragShader, {header, "#define FRAGMENT \n", source})
    gl.CompileShader(fragShader)


    if gl.GetShaderiv(fragShader, gl.COMPILE_STATUS) == 0 {
        error := gl.GetShaderInfoLog(fragShader, buf[:])
        fmt.eprintf(error)
        panic("failed compiling frag shader")
    }

    shaderProg := gl.CreateProgram()
    gl.AttachShader(shaderProg, vertShader)
    gl.AttachShader(shaderProg, fragShader)
    gl.LinkProgram(shaderProg)

    if gl.GetProgramParameter(shaderProg, gl.LINK_STATUS) == 0 {
        panic("failed linking shader")
    }

    handle := cast(dm.ShaderHandle) dm.CreateHandle(shaders)
    shader := dm.GetElement(shaders, auto_cast handle)

    shader.shaderID = shaderProg

    return handle
}

////////
MVP: dm.mat4

FlushCommands :: proc(using ctx: ^dm.RenderContext) {
    frameData: PerFrameData

    //@TODO: set proper viewport
    gl.Viewport(0, 0, 800, 600)

    for c in &commandBuffer.commands {
        switch cmd in &c {
        case dm.ClearColorCommand:
            c := cmd.clearColor
            gl.ClearColor(c.r, c.g, c.b, c.a)
            gl.Clear(gl.COLOR_BUFFER_BIT)

        case dm.CameraCommand:
            view := dm.GetViewMatrix(cmd.camera)
            proj := dm.GetProjectionMatrixNTO(cmd.camera)

            frameData.MVP = proj * view
            MVP = proj * view

            gl.BindBuffer(gl.UNIFORM_BUFFER, perFrameDataBuffer)
            gl.BufferSubData(gl.UNIFORM_BUFFER, 0, size_of(PerFrameData), &frameData)
            gl.BindBuffer(gl.UNIFORM_BUFFER, 0)

        case dm.DrawRectCommand:
            if ctx.defaultBatch.shader.gen != 0 && 
               ctx.defaultBatch.shader != cmd.shader {
                DrawBatch(ctx, &ctx.defaultBatch)
            }

            if ctx.defaultBatch.texture.gen != 0 && 
               ctx.defaultBatch.texture != cmd.texture {
                DrawBatch(ctx, &ctx.defaultBatch)
            }

            ctx.defaultBatch.shader = cmd.shader
            ctx.defaultBatch.texture = cmd.texture

            entry := dm.RectBatchEntry {
                position = cmd.position,
                size = cmd.size,
                rotation = cmd.rotation,

                texPos  = {cmd.source.x, cmd.source.y},
                texSize = {cmd.source.width, cmd.source.height},
                pivot = cmd.pivot,
                color = cmd.tint,
            }

            dm.AddBatchEntry(ctx, &ctx.defaultBatch, entry)
        }
    }

    DrawBatch(ctx, &ctx.defaultBatch)

    clear(&commandBuffer.commands)
}

CreatePrimitiveBatch :: proc(ctx: ^dm.RenderContext, maxCount: int) {
    ctx.debugBatch.buffer = make([]dm.PrimitiveVertex, maxCount)

    // TODO: finish
}

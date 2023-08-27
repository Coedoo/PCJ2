package dmcore

import math "core:math/linalg/glsl"

import coreMath "core:math"

import sdl "vendor:sdl2"

import "core:fmt"

import "core:os"

import "core:mem"

// import imgLoader "core:image"
import "core:image/png"

TexHandle :: distinct Handle
ShaderHandle :: distinct Handle
BatchHandle :: distinct Handle

ToVec2 :: proc(v: math.ivec2) -> math.vec2 {
    return {
        f32(v.x),
        f32(v.y),
    }
}

Toivec2 :: proc(v: math.vec2) -> math.ivec2 {
    return {
        i32(v.x),
        i32(v.y),
    }
}

/////////////////////////////////////
//// Render Context
////////////////////////////////////

RenderContext :: struct {
    whiteTexture: TexHandle,

    frameSize: iv2,

    defaultBatch: RectBatch,
    debugBatch:   PrimitiveBatch,

    commandBuffer: CommandBuffer,

    defaultShaders: [DefaultShaderType]ShaderHandle,

    CreateTexture: proc(rawData: []u8, width, height, channels: i32, renderCtx: ^RenderContext, filter: TextureFilter) -> TexHandle,
    GetTextureInfo: proc(handle: TexHandle) -> (TextureInfo, bool),

    CreateRectBatch: proc(renderCtx: ^RenderContext, bathc: ^RectBatch, count: int),
    DrawBatch: proc(ctx: ^RenderContext, batch: ^RectBatch),
}

/////////////////////////////////////
/// Shaders
/////////////////////////////////////

DefaultShaderType :: enum {
    Sprite,
    ScreenSpaceRect,
    SDFFont,
}

Shader :: struct {
    handle: ShaderHandle,
}


/////////////////////////////////////
// Textures
/////////////////////////////////////


TextureInfo :: struct {
    handle: TexHandle,
    width: i32,
    height: i32,
}

TextureFilter :: enum {
    Point,
    Bilinear,
    Mip,
}

// DestroyTexHandle :: proc(handle: TexHandle) {
//     //@TODO: renderer destroy
//     textures[handle.index].handle.index = 0
// }

GetTextureSize :: proc(renderCtx: ^RenderContext, handle: TexHandle) -> iv2 {
    info, _ := renderCtx.GetTextureInfo(handle)
    return {info.width, info.height}
}

LoadTextureFromFile :: proc(filePath: string, renderCtx: ^RenderContext, filter := TextureFilter.Point) -> TexHandle {
    data, ok := os.read_entire_file(filePath, context.temp_allocator)

    if ok == false {
        // @TODO: error texture
        fmt.eprintf("Failed to open file: %v\n", filePath)
        return {}
    }

    return LoadTextureFromMemory(data, renderCtx)
}

LoadTextureFromMemory :: proc(data: []u8, renderCtx: ^RenderContext, filter := TextureFilter.Point) -> TexHandle {
    // @TODO: change CreateTexture so it uses std image.Image instead of passing
    // params directly
    image, ok := png.load_from_bytes(data, allocator = context.temp_allocator)

    return renderCtx.CreateTexture(image.pixels.buf[:], cast(i32) image.width, cast(i32) image.height, cast(i32) image.channels, renderCtx, filter)
}


////////////////////////////////////
/// Sprites
///////////////////////////////////
Axis :: enum {
    Horizontal,
    Vertical,
}

Sprite :: struct {
    texture: TexHandle,

    origin: v2,

    //@TODO: change to source rectangle
    atlasPos: iv2,
    pixelSize: iv2,

    tint: color,

    flipX, flipY: bool,

    scale: f32,

    frames: i32,
    currentFrame: i32,
    animDirection: Axis,
}

CreateSprite :: proc {
    CreateSpriteFromTextureRect,
    CreateSpriteFromTexturePosSize,
}

CreateSpriteFromTextureRect :: proc(texture: TexHandle, rect: RectInt) -> Sprite {
    return {
        texture = texture,

        atlasPos = {rect.x, rect.y},
        pixelSize = {rect.width, rect.height},

        origin = {0.5, 0.5},

        tint = {1, 1, 1, 1},

        scale = 1,
    }
}

CreateSpriteFromTexturePosSize :: proc(texture: TexHandle, atlasPos: iv2, atlasSize: iv2) -> Sprite {
    return {
        texture = texture,

        atlasPos = atlasPos,
        pixelSize = atlasSize,

        origin = {0.5, 0.5},

        tint = {1, 1, 1, 1},

        scale = 1,
    }
}

AnimateSprite :: proc(sprite: ^Sprite, time: f32, frameTime: f32) {
    t := cast(i32) (time / frameTime)
    t = t%sprite.frames

    sprite.currentFrame = t
}

GetSpriteSize :: proc(sprite: Sprite) -> v2 {
    sizeX := sprite.scale
    sizeY := f32(sprite.pixelSize.y) / f32(sprite.pixelSize.x) * sizeX

    return {sizeX, sizeY}
}

///////////////////////////////
/// Rect rendering
//////////////////////////////

RectBatchEntry :: struct {
    position: v2,
    size:     v2,
    rotation: f32,

    texPos:   iv2,
    texSize:  iv2,

    pivot: v2,

    color: color,
}

RectBatch :: struct {
    count: int,
    maxCount: int,
    buffer: []RectBatchEntry,

    texture: TexHandle,
    shader:  ShaderHandle,

    renderData: BatchHandle,
}

AddBatchEntry :: proc(ctx: ^RenderContext, batch: ^RectBatch, entry: RectBatchEntry) {
    assert(batch.buffer != nil)
    assert(batch.count < len(batch.buffer))

    batch.buffer[batch.count] = entry
    batch.count += 1
}

//////////////
// Debug drawing
/////////////

PrimitiveVertex :: struct {
    pos: v3,
    color: color,
}

PrimitiveBatch :: struct {
    buffer: []PrimitiveVertex,
    index: int,
}

DrawLine :: proc{
    DrawLine3D,
    DrawLine2D,
}

DrawLine2D :: proc(ctx: ^RenderContext, a, b: v2, color: color = RED) {
    using ctx.debugBatch

    buffer[index + 0] = {v3Conv(a), color}
    buffer[index + 1] = {v3Conv(b), color}

    index += 2
}

DrawLine3D :: proc(ctx: ^RenderContext, a, b: v3, color: color = RED) {
    using ctx.debugBatch

    buffer[index + 0] = {a, color}
    buffer[index + 1] = {b, color}

    index += 2
}

DrawBox2D :: proc(ctx: ^RenderContext, pos, size: v2, color: color = GREEN) {
    using ctx.debugBatch

    left  := pos.x - size.x / 2
    right := pos.x + size.x / 2
    top   := pos.y + size.y / 2
    bot   := pos.y - size.y / 2

    a := v3{left, bot, 0}
    b := v3{right, bot, 0}
    c := v3{right, top, 0}
    d := v3{left, top, 0}


    buffer[index + 0] = {a, color}
    buffer[index + 1] = {b, color}
    buffer[index + 2] = {b, color}
    buffer[index + 3] = {c, color}
    buffer[index + 4] = {c, color}
    buffer[index + 5] = {d, color}
    buffer[index + 6] = {d, color}
    buffer[index + 7] = {a, color}

    index += 8
}

DrawBounds2D :: proc(ctx: ^RenderContext, bounds: Bounds2D, color := GREEN) {
    pos := v2{
        bounds.left + (bounds.right - bounds.left) / 2,
        bounds.bot  + (bounds.top - bounds.bot) / 2,
    }

    size := v2{
        (bounds.right - bounds.left),
        (bounds.top - bounds.bot),
    }

    DrawBox2D(ctx, pos, size, color)
}


DrawCircle :: proc(ctx: ^RenderContext, pos: v2, radius: f32, color: color = GREEN) {
    using ctx.debugBatch

    resolution :: 32

    GetPosition :: proc(i: int, pos: v2, radius: f32) -> v3 {
        angle := f32(i) / f32(resolution) * coreMath.PI * 2
        pos := v3{
            coreMath.cos(angle),
            coreMath.sin(angle),
            0
        } * radius + {pos.x, pos.y, 0}

        return pos
    }

    for i in 0..<resolution {
        posA := GetPosition(i, pos, radius)
        posB := GetPosition(i + 1, pos, radius)

        buffer[index]     = {posA, color}
        buffer[index + 1] = {posB, color}
        index += 2
    }
}

DrawRay :: proc{
    DrawRay2D,
    // DrawRay3D
}

DrawRay2D :: proc(ctx: ^RenderContext, ray: Ray2D, distance: f32 = 1., color := GREEN) {
    dir := math.normalize(ray.direction) * distance
    DrawLine(ctx, ray.origin, ray.origin + dir, color)
}
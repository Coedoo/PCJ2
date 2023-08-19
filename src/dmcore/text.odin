package dmcore

import "core:mem"
import "core:os"
import "core:fmt"

import "core:encoding/base64"

import math "core:math/linalg/glsl"
import coreMath "core:math"

GLYPH_RANGE_LOW :: 32
GLYPH_RANGE_HIGH :: 383
GLYPH_COUNT :: GLYPH_RANGE_HIGH - GLYPH_RANGE_LOW

GlyphData :: struct {
    codepoint: rune,

    pixelWidth: int,
    pixelHeight: int,

    atlasPos:  v2,
    atlasSize: v2,

    offset: v2,

    advanceX: int,
}

FontType :: enum {
    Bitmap,
    SDF,
}

Font :: struct {
    size: int,
    type: FontType,

    atlas: TexHandle,
    glyphData: [GLYPH_COUNT]GlyphData,
}


GetCodepointIndex :: proc(codepoint: rune) -> int {
    if codepoint > GLYPH_RANGE_HIGH {
        return -1;
    }

    return int(codepoint) - GLYPH_RANGE_LOW
}

DrawTextCentered :: proc(ctx: ^RenderContext, str: string, font: Font, position: iv2, fontSize: int = 0) {
    size := MeasureText(str, font, fontSize)
    pos := position - size / 2

    DrawText(ctx, str, font, pos, fontSize)
}

DrawText :: proc(ctx: ^RenderContext, str: string, font: Font, position: iv2, fontSize: int = 0) {
    // @TODO: I can cache atlas size
    atlasSize := GetTextureSize(ctx, font.atlas)

    fontSize := fontSize
    if fontSize == 0 do fontSize = font.size

    scale := f32(fontSize) / f32(font.size)

    posX := 0
    posY := fontSize

    fontAtlasSize := v2 {
        cast(f32) atlasSize.x,
        cast(f32) atlasSize.y,
    }

    shader := ctx.defaultShaders[.SDFFont] if font.type == .SDF else ctx.defaultShaders[.ScreenSpaceRect]

    for c, i in str {
        if c == '\n' {
            posY += fontSize
            posX = 0

            continue
        }

        index := GetCodepointIndex(c)
        assert(index != -1)

        glyphData := font.glyphData[index]

        pos  := v2{f32(posX), f32(posY) + glyphData.offset.y * scale} + v2Conv(position)
        size := v2{f32(glyphData.pixelWidth), f32(glyphData.pixelHeight)}
        dest := Rect{pos.x, pos.y, size.x * scale, size.y * scale}

        texPos  := Toivec2(glyphData.atlasPos  * fontAtlasSize)
        texSize := Toivec2(glyphData.atlasSize * fontAtlasSize)
        src := RectInt{texPos.x, texPos.y, texSize.x, texSize.y}

        DrawRect(ctx, font.atlas, src, dest, shader)

        advance := glyphData.pixelWidth if glyphData.pixelWidth != 0 else glyphData.advanceX
        posX += int(f32(advance) * scale)
    }
}


LoadDefaultFont :: proc(renderCtx: ^RenderContext) -> Font {
    // @NOTE: I'm not sure that's strong enough check
    if font.atlas.index == 0 {
        atlasData := base64.decode(ATLAS, allocator = context.temp_allocator)
        font.atlas = renderCtx.CreateTexture(atlasData, ATLAS_SIZE, ATLAS_SIZE, 4, renderCtx)
    }

    return font
}

MeasureText :: proc(str: string, font: Font, fontSize: int = 0) -> iv2 {
    fontSize := fontSize
    if fontSize == 0 do fontSize = font.size

    scale := f32(fontSize) / f32(font.size)

    posX := 0
    lines := 1

    width := 0

    for c, i in str {
        if c == '\n' {
            width = max(width, posX)

            posX = 0
            lines += 1

            continue
        }

        index := GetCodepointIndex(c)
        assert(index != -1)

        glyphData := font.glyphData[index]

        advance := glyphData.pixelWidth if glyphData.pixelWidth != 0 else glyphData.advanceX
        posX += int(f32(advance) * scale)
    }

    width = max(width, posX)
    return {i32(width), i32(lines * fontSize)}
}

package font_converter

import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:encoding/base64"
import "core:mem"
import "core:path/slashpath"

import dm "../../src/dmcore"

DEFAULT_SIZE :: 8

main :: proc() {

    args: map[string]string

    path := os.args[1]

    for i := 2; i < len(os.args); i += 1 {
        arg := os.args[i]

        splited := strings.split(arg, ":", context.temp_allocator)

        if len(splited) == 0 {
            continue
        }
        else if len(splited) == 1 {
            args[splited[0]] = ""
        }
        else if(len(splited) == 2) {
            args[splited[0]] = splited[1]
        }
        else {
            fmt.eprintf("Incorrect argument format: `{}`\n", arg)
        }
    }

    size := DEFAULT_SIZE
    if "size" in args {
        s, ok := strconv.parse_int(args["size"])

        if ok {
            size = s
        }
        else {
            fmt.eprintf("Can't parse size argument: `{}`. Using default size.\n", args["size"])
        }
    }

    font: dm.Font
    bitmap, bitmapSize := dm.InitFontSDF(&font, path, size)

    // fmt.eprintln(os.args)

    sb: strings.Builder
    strings.builder_init(&sb, context.temp_allocator)

    fmt.sbprint(&sb, "package dmcore\n\n")

    fmt.sbprintf(&sb, "// Font name: {}\n", slashpath.name(path))
    fmt.sbprintf(&sb, "// Generated with DanMofu/font_converter\n\n")


    fmt.sbprint(&sb,  "font := Font {\n")
    fmt.sbprintf(&sb, "\tsize = {},\n",  font.size)
    fmt.sbprintf(&sb, "\ttype = .{},\n", font.type)
    fmt.sbprint(&sb,  "\tglyphData = {\n")
    for g in font.glyphData {
        fmt.sbprint(&sb, "\t{\n")
        fmt.sbprintf(&sb, "\t\tcodepoint=rune({}), // {}\n",  int(g.codepoint), g.codepoint)
        fmt.sbprintf(&sb, "\t\tpixelWidth={},\n", g.pixelWidth)
        fmt.sbprintf(&sb, "\t\tpixelHeight={},\n", g.pixelHeight)
        fmt.sbprintf(&sb, "\t\tatlasPos={{%v, %v}},\n", g.atlasPos.x, g.atlasPos.y)
        fmt.sbprintf(&sb, "\t\tatlasSize={{%v, %v}},\n", g.atlasSize.x, g.atlasSize.y)
        fmt.sbprintf(&sb, "\t\toffset={{%v, %v}},\n", g.offset.x, g.offset.y)
        fmt.sbprintf(&sb, "\t\tadvanceX={},\n", g.advanceX)
        fmt.sbprint(&sb, "\t},\n")
    }
    fmt.sbprint(&sb,  "\t}\n")
    fmt.sbprint(&sb,  "}")
    
    fmt.sbprintf(&sb, "\n")
    fmt.sbprintf(&sb, "ATLAS_SIZE :: {}\n", bitmapSize)
    fmt.sbprintf(&sb, "ATLAS :: `{}`\n", base64.encode(mem.slice_to_bytes(bitmap)))


    fmt.println(strings.to_string(sb))
}
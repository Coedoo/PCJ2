package metadata

import "core:fmt"
import "core:reflect"

// Experiments with reflections and RTTI to maybe being able 
// to detect and convert Game State structs signatures

reflection :: proc() {
    Foo :: struct {
        x: int    `tag1`,
        y: string `tag:"2"`,
        z: bool, // no tag
    }

    foo := Foo {
        x = 123,
        y = "Kappa",
        z = true,
    }

    id := typeid_of(Foo)
    fields := reflect.struct_fields_zipped(id)

    for f in fields {
        ptr := uintptr(&foo) + f.offset

        value := any{
            data = rawptr(ptr),
            id = f.type.id
        }

        fmt.println(f.name, ": ", value, sep = "")
    }

    for f in fields {
        if val, ok := reflect.struct_tag_lookup(f.tag, "tag"); ok {
            fmt.printf("tag: %s -> %s\n", f.name, val)
        }
    }
}


main :: proc() {
    reflection()
}
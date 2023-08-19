package platform_wasm

import "core:mem"
import "core:runtime"

wasmContext: runtime.Context

// @TODO make it configurable
tempBackingBuffer: [4 * mem.Megabyte]byte
tempArena: mem.Arena


mainBackingBuffer: [128 * mem.Megabyte]byte
mainArena: mem.Arena

InitContext :: proc () {
    // wasmContext = context

    mem.arena_init(&tempArena, tempBackingBuffer[:])
    wasmContext.temp_allocator = mem.arena_allocator(&tempArena)

    mem.arena_init(&mainArena, mainBackingBuffer[:])
    wasmContext.allocator = mem.arena_allocator(&mainArena)

    wasmContext.logger = context.logger
}

@(export, link_name = "get_ctx_ptr")
GetContextPtr :: proc "contextless" () -> (^runtime.Context) {
    return &wasmContext
}
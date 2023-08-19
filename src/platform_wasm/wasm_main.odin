package platform_wasm

import "core:runtime"
import "core:fmt"

import "core:mem"

import dm "../dmcore"
import "../dmcore/globals"
import gl "vendor:wasm/WebGL"

import "vendor:wasm/js"

import gameCode "../game"

import coreTime "core:time"


platform: dm.Platform

main :: proc() {
    InitContext()

    context = wasmContext

    gl.SetCurrentContextById("game_viewport")

    InitInput()

    //////////////

    platform.renderCtx = new(dm.RenderContext)
    InitRenderContext(platform.renderCtx)
    platform.mui = dm.muiInit(platform.renderCtx)

    platform.audio = InitAudio()

    ////////////

    globals.UpdateStatePointer(&platform)
    gameCode.GameLoad(&platform)

    platform.time.ticksStart = cast(u32) coreTime.now()._nsec
    fmt.println(platform.time.ticksStart)
}

@(export, link_name="step")
step :: proc "contextless" (delta: f32, ctx: ^runtime.Context) {
    context = wasmContext
    free_all(context.temp_allocator)

    ////////

    using platform

    ///////
    time.lastTicks = time.ticks
    // TODO: that feels wrong, is this proper use 
    // of that function?
    time.ticks = (cast(u32) coreTime.now()._nsec) - time.ticksStart
    // fmt.println(time.ticks)

    deltaTicks := time.ticks - time.lastTicks

    if pauseGame == false || moveOneFrame {
        time.gameTicks += deltaTicks
        time.frame += 1
    }

    time.deltaTime = f32(deltaTicks) / 1000

    time.time = f64(time.ticks) / 1000
    time.gameTime = f64(time.gameTicks) / 1000

    for key, state in input.curr {
        input.prev[key] = state
    }

    for mouseBtn, i in input.mouseCurr {
        input.mousePrev[i] = input.mouseCurr[i]
    }

    input.runesCount = 0
    input.scrollX = 0;
    input.scroll = 0;

    for i in 0..<eventBufferOffset {
        e := &eventsBuffer[i]
        // fmt.println(e)
        #partial switch e.kind {
            case .Mouse_Down:
                idx := clamp(int(e.mouse.button), 0, len(JsToDMMouseButton))
                btn := JsToDMMouseButton[idx]

                platform.input.mouseCurr[btn] = .Down

            case .Mouse_Up:
                idx := clamp(int(e.mouse.button), 0, len(JsToDMMouseButton))
                btn := JsToDMMouseButton[idx]

                platform.input.mouseCurr[btn] = .Up

            case .Mouse_Move: 
                platform.input.mousePos.x = i32(e.mouse.client.x)
                platform.input.mousePos.y = i32(e.mouse.client.y)

                platform.input.mouseDelta.x = i32(e.mouse.movement.x)
                platform.input.mouseDelta.y = i32(e.mouse.movement.y)

            case .Key_Up:
                key := JsKeyToKey[e.key.code]
                input.curr[key] = .Up

            case .Key_Down:
                key := JsKeyToKey[e.key.code]
                input.curr[key] = .Down
        }
    }
    eventBufferOffset = 0

    /////////

    moveOneFrame = false


    dm.muiProcessInput(mui, &input)
    dm.muiBegin(mui)

    when ODIN_DEBUG {
        if dm.GetKeyState(&input, .U) == .JustPressed {
            debugState = !debugState
            pauseGame = debugState

            if debugState {
                dm.muiShowWindow(mui, "Debug")
            }
        }

        if debugState && dm.muiBeginWindow(mui, "Debug", {0, 0, 100, 240}, nil) {
            dm.muiLabel(mui, "Time:", time.time)
            dm.muiLabel(mui, "GameTime:", time.gameTime)

            dm.muiLabel(mui, "Frame:", time.frame)

            if dm.muiButton(mui, "Play" if pauseGame else "Pause") {
                pauseGame = !pauseGame
            }

            if dm.muiButton(mui, ">") {
                moveOneFrame = true
            }

            dm.muiEndWindow(mui)
        }
    }


    if pauseGame == false || moveOneFrame {
        gameCode.GameUpdate(gameState)
    }

    when ODIN_DEBUG {
        gameCode.GameUpdateDebug(gameState, debugState)
    }

    gameCode.GameRender(gameState)

    FlushCommands(renderCtx)
    // DrawPrimitiveBatch(cast(^renderer.RenderContext_d3d) renderCtx)
    renderCtx.debugBatch.index = 0

    dm.muiEnd(mui)
    dm.muiRender(mui, renderCtx)
}
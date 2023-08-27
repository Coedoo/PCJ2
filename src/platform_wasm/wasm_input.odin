package platform_wasm

// @TODO:
// Fix problems with mouse delta
import "vendor:wasm/js"
import dm "../dmcore"

import "core:fmt"

JsToDMMouseButton := []dm.MouseButton {
    .Left,
    .Middle,
    .Right,
}


eventBufferOffset: int
eventsBuffer: [64]js.Event

JsKeyToKey: map[string]dm.Key

InitInput :: proc() {
    JsKeyToKey =  {
        "Enter"       = .Return,
        "NumpadEnter" = .Return,
        "Escape"      = .Esc,
        "Backspace"   = .Backspace,
        "Space"       = .Space,

        "ControlLeft"  = .LCtrl,
        "ControlRight" = .RCtrl,
        "ShiftLeft"    = .LShift,
        "ShiftRight"   = .RShift,
        "AltLeft"      = .LAlt,
        "AltRight"     = .RAlt,

        "ArrowLeft"  = .Left,
        "ArrowUp"    = .Up,
        "ArrowRight" = .Right,
        "ArrowDown"  = .Down,

        "Digit0" = .Num0,
        "Digit1" = .Num1,
        "Digit2" = .Num2,
        "Digit3" = .Num3,
        "Digit4" = .Num4,
        "Digit5" = .Num5,
        "Digit6" = .Num6,
        "Digit7" = .Num7,
        "Digit8" = .Num8,
        "Digit9" = .Num9,

        "F1" = .F1,
        "F2" = .F2,
        "F3" = .F3,
        "F4" = .F4,
        "F5" = .F5,
        "F6" = .F6,
        "F7" = .F7,
        "F8" = .F8,
        "F9" = .F9,
        "F10" = .F10,
        "F11" = .F11,
        "F12" = .F12,

        "KeyA" = .A,
        "KeyB" = .B,
        "KeyC" = .C,
        "KeyD" = .D,
        "KeyE" = .E,
        "KeyF" = .F,
        "KeyG" = .G,
        "KeyH" = .H,
        "KeyI" = .I,
        "KeyJ" = .J,
        "KeyK" = .K,
        "KeyL" = .L,
        "KeyM" = .M,
        "KeyN" = .N,
        "KeyO" = .O,
        "KeyP" = .P,
        "KeyQ" = .Q,
        "KeyR" = .R,
        "KeyS" = .S,
        "KeyT" = .T,
        "KeyU" = .U,
        "KeyV" = .V,
        "KeyW" = .W,
        "KeyX" = .X,
        "KeyY" = .Y,
        "KeyZ" = .Z,

        "Numpad0" = .Num0,
        "Numpad1" = .Num1,
        "Numpad2" = .Num2,
        "Numpad3" = .Num3,
        "Numpad4" = .Num4,
        "Numpad5" = .Num5,
        "Numpad6" = .Num6,
        "Numpad7" = .Num7,
        "Numpad8" = .Num8,
        "Numpad9" = .Num9,
    }

    js.add_window_event_listener(.Mouse_Down, nil, StoreEvent)
    js.add_window_event_listener(.Mouse_Up, nil,   StoreEvent)
    js.add_window_event_listener(.Mouse_Move, nil, StoreEvent)

    js.add_window_event_listener(.Key_Down, nil, StoreEvent)
    js.add_window_event_listener(.Key_Up, nil, StoreEvent)
}


StoreEvent :: proc(e: js.Event) {
    if eventBufferOffset < len(eventsBuffer) {
        eventsBuffer[eventBufferOffset] = e
        eventBufferOffset += 1
    }
}

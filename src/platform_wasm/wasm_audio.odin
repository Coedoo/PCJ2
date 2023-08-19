package platform_wasm

import dm "../dmcore"
import "core:fmt"

foreign import audio "audio"

foreign audio {
    // Init :: proc "contextless" () ---
    Load :: proc "c" (file: rawptr, fileSize: int) ---
    Play :: proc "contextless" () ---
}

InitAudio :: proc() -> dm.Audio {
    audio: dm.Audio
    audio.PlayMusic = PlayMusic
    audio.PlaySound = PlaySound

    audio.LoadAudio = LoadAudio
    audio.PlayAudio = PlayAudio

    return audio
}

PlayMusic :: proc(path: string, loop: bool = true) {
}

PlaySound :: proc(path: string) {
}

LoadAudio :: proc(data: []u8) {
    // fmt.println("Odin", cast(uintptr) raw_data(data), len(data))
    Load(raw_data(data), len(data))
}

PlayAudio :: proc() {
    Play()
}
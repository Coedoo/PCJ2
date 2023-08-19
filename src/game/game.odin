package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"

import "core:math/linalg/glsl"


GameState :: struct {
    entities: dm.ResourcePool(Entity, EntityHandle),

    playerHandle: EntityHandle,

}

gameState: ^GameState

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)
    dm.InitResourcePool(&gameState.entities, 1024)

}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
}



@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    using globals

    dm.ClearColor(renderCtx, {0.8, 0.8, 0.8, 1})
}
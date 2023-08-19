package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"

import "core:math/linalg/glsl"

v2  :: dm.v2
iv2 :: dm.iv2

GameState :: struct {
    entities: dm.ResourcePool(Entity, EntityHandle),

    playerHandle: EntityHandle,

    camera: dm.Camera,
}

gameState: ^GameState


testSize :: v2{2, 1}
testPos :: v2{0, 0}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)
    dm.InitResourcePool(&gameState.entities, 1024)

    gameState.camera = dm.CreateCamera(5, 800./600., 0.01, 100)
    gameState.camera.position.z = 1


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

    gameState := cast(^GameState) state

    dm.ClearColor(renderCtx, {0.8, 0.8, 0.8, 1})
    dm.SetCamera(renderCtx, gameState.camera)

    dm.DrawRectNoTexture(renderCtx, testPos, testSize, {0.1, 0.3, 1, 1})

    world := dm.v2Conv(dm.ScreenToWorldSpace(gameState.camera, input.mousePos, {800, 600}))
    pos := v2{-1, 3}
    ray := dm.Ray2DFromTwoPoints(pos, world)

    maxDist := math.distance(pos, world)

    aabb := dm.CreateBounds(testPos, testSize)
    hit, dist := dm.RayCastAABB2D(ray, aabb, maxDist)
    dist = hit ? dist : maxDist

    dm.DrawRay(renderCtx, ray, dist, color =  hit ? dm.RED : dm. GREEN)


    if dm.muiBeginWindow(mui, "T", {0, 0, 100, 120}, nil) {
        defer dm.muiEndWindow(mui)

        dm.muiLabel(mui, world)
        dm.muiLabel(mui, hit)
        dm.muiLabel(mui, dist)
    }
}
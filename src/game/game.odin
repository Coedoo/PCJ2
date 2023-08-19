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

pixelmaFile := #load("../../assets/pixelma.png")

GameState :: struct {
    entities: dm.ResourcePool(Entity, EntityHandle),

    playerHandle: EntityHandle,

    camera: dm.Camera,

    pixelmaTex: dm.TexHandle,
}

gameState: ^GameState


testSize :: v2{2, 1}
testPos :: v2{0, 0}

Raycast :: proc(ray: dm.Ray2D, maxDist: f32) -> (bool, f32) {
    for e in gameState.entities.elements {
        if .Wall in e.flags {
            bounds := dm.CreateBounds(e.position, e.collisionSize)
            hit, dist := dm.RaycastAABB2D(ray, bounds, maxDist)

            if hit {
                return hit, dist
            }
        }
    }

    return false, 0
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AlocateGameData(platform, GameState)
    dm.InitResourcePool(&gameState.entities, 1024)

    gameState.pixelmaTex = dm.LoadTextureFromMemory(pixelmaFile, globals.renderCtx)
    
    /////
    gameState.camera = dm.CreateCamera(7, 800./600., 0.01, 100)

    CreateWall({0, -3}, {5, 1})
    CreateWall({0, -5}, {20, 1})
    CreateWall({-3, 1}, {1, 4})
    CreateWall({3, 1}, {1, 4})

    gameState.playerHandle = CreatePlayerEntity()

}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    using globals

    for &e in gameState.entities.elements {
        if e.controler != .None {
            ControlEntity(&e)
        }
    }

    player := dm.GetElement(gameState.entities, gameState.playerHandle)
    // Control Camera

    if player != nil {
        camPos := cast(v2) gameState.camera.position.xy
        using focusBox := dm.CreateBounds(camPos, cameraFocusBoxSize)

        boxWidth  := right - left
        boxHeight := top - bot

        dm.DrawBounds2D(renderCtx, focusBox, dm.RED)


        if player.position.x > right {
            camPos.x = player.position.x - boxWidth / 2 
        }
        else if player.position.x < left {
            camPos.x = player.position.x + boxWidth / 2 
        }

        if player.position.y > top {
            camPos.y = player.position.y - boxHeight / 2 
        }
        else if player.position.y < bot {
            camPos.y = player.position.y + boxHeight / 2 
        }

        gameState.camera.position.xy = cast([2]f32) camPos
    }

    if dm.muiBeginWindow(mui, "T", {0, 0, 100, 120}, nil) {
        defer dm.muiEndWindow(mui)
            
        if player != nil {
            dm.muiLabel(mui, player.velocity)
        }
    }
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


    for e in gameState.entities.elements {
        if .RenderTexture in e.flags {
            // @TEMP
            dm.DrawRectNoTexture(renderCtx, e.position, e.size, e.tint)
        }

        if .RenderSprite in e.flags {
            dm.DrawSprite(renderCtx, e.sprite, e.position, 0, e.tint)
        }
    }
}
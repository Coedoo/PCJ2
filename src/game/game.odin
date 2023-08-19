package game

import "core:fmt"
import rand "core:math/rand"
import math "core:math/linalg/glsl"

import dm "../dmcore"

import "core:mem"

import globals "../dmcore/globals"

import "core:math/linalg/glsl"

import "../ldtk"

v2  :: dm.v2
iv2 :: dm.iv2

pixelmaFile := #load("../../assets/pixelma.png")

levelFile := #load("../../assets/level.json", []byte)

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

    // CreateWall({0, -3}, {5, 1})
    // CreateWall({0, -5}, {20, 1})
    // CreateWall({-3, 1}, {1, 4})
    // CreateWall({3, 1}, {1, 4})

    gameState.playerHandle = CreatePlayerEntity()
    player := dm.GetElement(gameState.entities, gameState.playerHandle)

    player.position = {3, 10}

    if project, ok := ldtk.load_from_memory(levelFile, context.temp_allocator).?; ok {
        for level in project.levels {
            for layer in level.layer_instances {
                switch layer.type {
                case .IntGrid:
                    yOffset := layer.c_height * layer.grid_size
                    for tile in layer.auto_layer_tiles {
                        posX := f32(tile.px.x) / f32(layer.grid_size)
                        posY := f32(-tile.px.y + yOffset) / f32(layer.grid_size)

                        CreateWall({posX, posY}, {1, 1}, {})
                    }

                case .Entities:
                case .Tiles:
                case .AutoLayer:
                }
            }
        }
    }

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


}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr, debug: bool) {
    using globals

    gameState.camera.orthoSize -= f32(globals.input.scroll)

    if dm.GetMouseButton(globals.input, .Right) == .Down {
        gameState.camera.position.xy -= cast([2]f32) dm.v2Conv(globals.input.mouseDelta) * 0.1
    }

    player := dm.GetElement(gameState.entities, gameState.playerHandle)

    if dm.muiBeginWindow(mui, "T", {0, 0, 100, 120}, nil) {
    defer dm.muiEndWindow(mui)
        
        if player != nil {
            dm.muiLabel(mui, player.velocity)
        }

        for &e in gameState.entities.elements {
            if .Wall in e.flags {
                dm.muiLabel(mui, e.position)
            }
        }
    }

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
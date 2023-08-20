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
atlasFile := #load("../../assets/atlas.png")

levelFile := #load("../../assets/level.json", []byte)

GameState :: struct {
    entities: dm.ResourcePool(Entity, EntityHandle),

    playerHandle: EntityHandle,
    camera: dm.Camera,

    pixelmaTex: dm.TexHandle,
    atlasTex: dm.TexHandle,

    activeLayer: LevelLayer,


    lastCheckpointPosition: v2,
    lastCheckpointHandle: EntityHandle,

    playerState: PlayerState,
}

gameState: ^GameState

Raycast :: proc(ray: dm.Ray2D, maxDist: f32, layer: LevelLayer) -> (bool, f32) {
    for e in gameState.entities.elements {
        if .Wall in e.flags && e.levelLayer == .Base || e.levelLayer == layer {
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
    gameState.atlasTex = dm.LoadTextureFromMemory(atlasFile, globals.renderCtx)
    
    gameState.activeLayer = .L1

    /////
    gameState.camera = dm.CreateCamera(7, 800./600., 0.01, 100)

    // player.position = {3, 10}

    if project, ok := ldtk.load_from_memory(levelFile, context.temp_allocator).?; ok {
        for level in project.levels {
            for layer in level.layer_instances {
                yOffset := layer.c_height * layer.grid_size

                if layer.type == .Tiles || layer.type == .IntGrid {
                    tiles := layer.type == .Tiles ? layer.grid_tiles : layer.auto_layer_tiles
                    
                    for tile in tiles {
                        posX := f32(tile.px.x) / f32(layer.grid_size)
                        posY := f32(-tile.px.y + yOffset) / f32(layer.grid_size)

                        CreateWall(
                            {posX, posY}, 
                            dm.CreateSprite(gameState.atlasTex, {i32(tile.src.x), i32(tile.src.y), 16, 16}),
                            layer.identifier
                        )
                    }
                }

                if layer.type == .Entities {
                    for entity in layer.entity_instances {
                        // fmt.println(entity)

                        if entity.identifier == "Player" {
                            gameState.playerHandle = CreatePlayerEntity()
                            player := dm.GetElement(gameState.entities, gameState.playerHandle)
                            player.position = v2{f32(entity.grid.x), f32(-entity.grid.y + layer.grid_size)}

                            gameState.lastCheckpointPosition = player.position
                        }
                        else {
                            e, handle := CreateEntity()

                            e.position = v2{f32(entity.grid.x), f32(-entity.grid.y + layer.grid_size)}
                            tileRect, ok := entity.tile.?
                            if ok {
                                e.sprite = dm.CreateSprite(gameState.atlasTex, 
                                    {i32(tileRect.x), i32(tileRect.y), i32(tileRect.w), i32(tileRect.h)})                            
                            }

                            for tag in entity.tags {
                                switch tag {
                                case "RenderSprite": e.flags += { .RenderSprite }
                                case "Trigger":      e.flags += { .Trigger }

                                case "Checkpoint": e.triggerType = .Checkpoint
                                case "Damageable": e.triggerType = .Damageable
                                }
                            }

                            e.collisionSize = {1, 1}

                            // fmt.println(entity)
                        }
                    }
                }
            }
        }
    }
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    using globals

    // Global input
    if dm.GetKeyState(input, .Up) == .JustPressed {
        gameState.activeLayer = .L1 if gameState.activeLayer == .L2 else .L2
    }


    player := dm.GetElement(gameState.entities, gameState.playerHandle)

    // player collisions
    if player != nil {
        for &e in gameState.entities.elements {
            if dm.IsHandleValid(gameState.entities, e.handle) == false {
                continue
            }

            if .Trigger in e.flags {
                aBounds := dm.CreateBounds(e.position, e.collisionSize, e.pivot)
                bBounds := dm.CreateBounds(player.position, player.collisionSize, player.pivot)

                if dm.CheckCollisionBounds(aBounds, bBounds) {
                    switch e.triggerType {
                    case .None:
                    case .Checkpoint: {
                        gameState.lastCheckpointPosition = e.position
                        gameState.lastCheckpointHandle = e.handle
                    }
                    case .Damageable: {
                        player.position = gameState.lastCheckpointPosition
                    }
                    }
                }
            }
        }
    }

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, e.handle) == false {
            continue
        }

        if e.controler != .None {
            ControlEntity(&e)
        }
    }

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

    // Debug Window
    if dm.muiBeginWindow(mui, "T", {0, 0, 100, 120}, nil) {
        defer dm.muiEndWindow(mui)
        
        dm.muiLabel(mui, "MovState:", gameState.playerState.movementState)
    }

    for &e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, e.handle) == false {
            continue
        }

        dm.DrawBox2D(renderCtx, e.position, {0.1, 0.1}, dm.BLACK)

        if .Trigger in e.flags {
            dm.DrawBox2D(renderCtx, e.position, e.collisionSize, dm.RED)
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
        if dm.IsHandleValid(gameState.entities, e.handle) == false {
            continue
        }

        if .RenderSprite in e.flags
        {
            tint := e.tint
            if e.levelLayer != gameState.activeLayer && e.levelLayer != .Base {
                tint = dm.RED
            }

            dm.DrawSprite(renderCtx, e.sprite, e.position, 0, tint)
        }
    }
}
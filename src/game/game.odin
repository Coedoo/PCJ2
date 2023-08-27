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

// pixelmaFile := #load("../../assets/pixelma.png")
characterAnimFile := #load("../../assets/player_anim.png")
atlasFile := #load("../../assets/tiles.png")

levelFile := #load("../../assets/level2.json", []byte)

AbilityMessages: [PlayerAbility]string = {
    .WorldSwitch = "You Found: Potion!\n\nIt allows you to switch colored world tiles\n\nPress ARROW UP to activate",
    .DoubleJump = "You Found: Gear!\n\nIt allows you to double jump!",
    .WallClimb = "You Found: Lemon!\n\nYou can now climb walls for some reason...",
    .Dash = "AAAAAAAA",
} 

GameState :: struct {
    entities: dm.ResourcePool(Entity, EntityHandle),

    playerHandle: EntityHandle,
    camera: dm.Camera,

    font: dm.Font,

    characterTex: dm.TexHandle,
    atlasTex: dm.TexHandle,

    activeLayer: LevelLayer,


    lastCheckpointPosition: v2,
    lastCheckpointHandle: EntityHandle,

    playerState: PlayerState,

    showMessage: bool,
    message: string,

    showPopup: bool,
    popup: string,
    popupTimer: f32,

    doFade: bool,
    fadeAmount: f32,

    deathSeq: bool,
    deathSeqTimer: f32,

    winCondition: bool,

    winSeq: bool,
    winSeqTimer: f32,

    beersFound: int,
    allBeersCount: int,
}

gameState: ^GameState

///////////////

DeathSequence :: proc() {
    assert(gameState.deathSeq)

    gameState.doFade = true

    if gameState.deathSeqTimer < deathSeqFadeTime {
        gameState.deathSeqTimer += f32(globals.time.deltaTime)

        gameState.fadeAmount = gameState.deathSeqTimer / deathSeqFadeTime
    }
    else if gameState.deathSeqTimer < 2 * deathSeqFadeTime {
        gameState.deathSeqTimer += f32(globals.time.deltaTime)

        player := dm.GetElement(gameState.entities, gameState.playerHandle)
        player.position = gameState.lastCheckpointPosition

        gameState.fadeAmount = 1 - (gameState.deathSeqTimer - deathSeqFadeTime) / deathSeqFadeTime
    }
    else {
        gameState.doFade = false
        gameState.deathSeq = false
        gameState.deathSeqTimer = 0

        player := dm.GetElement(gameState.entities, gameState.playerHandle)
        player.velocity = 0
    }
}

WinSequence :: proc() {
    assert(gameState.winSeq)

    gameState.doFade = true

    if gameState.winSeqTimer < winSeqFadeTime {
        gameState.winSeqTimer += globals.time.deltaTime

        gameState.fadeAmount = gameState.winSeqTimer / winSeqFadeTime
    }
    else {
        message := `You have finally found 
your six-pack!

It also gives you ability to dash. 
Press SHIFT to do it.

Using DASH you can find 
all hidden beer bottles.

Press spacebar to continue

`
        winSize := globals.renderCtx.frameSize
        gameState.fadeAmount = 1
        dm.DrawTextCentered(globals.renderCtx, message, gameState.font, winSize / 2, 25)
        
        if dm.GetKeyState(globals.input, .Space) == .JustPressed {
            gameState.winSeq = false
            gameState.doFade = false
        }
    }
}

Raycast :: proc(ray: dm.Ray2D, maxDist: f32, layer: LevelLayer) -> (bool, f32) {
    camPos := gameState.camera.position
    camHeight := gameState.camera.orthoSize
    camWidth  := gameState.camera.aspect * camHeight
    cameraBounds := dm.Bounds2D{
        camPos.x - camWidth, camPos.x + camWidth,
        camPos.y - camHeight, camPos.y + camHeight,
    }

    for e in gameState.entities.elements {
        // bounds := dm.CreateBounds(e.position, e.size)
        // if dm.CheckCollisionBounds(cameraBounds, bounds) == false {
        //     continue
        // }

        if .Wall in e.flags && (e.levelLayer == .Base || e.levelLayer == layer) {
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
    dm.InitResourcePool(&gameState.entities, 2048 * 2)

    // fmt.println(len(levelFile))

    gameState.characterTex = dm.LoadTextureFromMemory(characterAnimFile, globals.renderCtx, .Bilinear)
    gameState.atlasTex = dm.LoadTextureFromMemory(atlasFile, globals.renderCtx, .Bilinear)
    
    gameState.activeLayer = .L1

    gameState.playerState.idleAnim = dm.CreateSprite(gameState.characterTex, {0, 4 * 64, 64, 64})
    gameState.playerState.idleAnim.frames = 4
    gameState.playerState.idleAnim.origin = {0.5, 1}
    gameState.playerState.idleAnim.animDirection = dm.Axis.Horizontal

    gameState.playerState.runAnim = dm.CreateSprite(gameState.characterTex, {0, 0, 64, 64})
    gameState.playerState.runAnim.frames = 8
    gameState.playerState.runAnim.origin = {0.5, 1}
    gameState.playerState.runAnim.animDirection = dm.Axis.Horizontal

    gameState.playerState.jumpAnim = dm.CreateSprite(gameState.characterTex, {0, 3 * 64, 64, 64})
    gameState.playerState.jumpAnim.frames = 3
    gameState.playerState.jumpAnim.origin = {0.5, 1}
    gameState.playerState.jumpAnim.animDirection = dm.Axis.Horizontal

    gameState.playerState.dashAnim = dm.CreateSprite(gameState.characterTex, {0, 2 * 64, 64, 64})
    gameState.playerState.dashAnim.frames = 3
    gameState.playerState.dashAnim.origin = {0.5, 1}
    gameState.playerState.dashAnim.animDirection = dm.Axis.Horizontal

    gameState.playerState.idleAnim.scale = 2
    gameState.playerState.dashAnim.scale = 2
    gameState.playerState.jumpAnim.scale = 2
    gameState.playerState.runAnim.scale = 2

    /////
    gameState.camera = dm.CreateCamera(7, 800./600., 0.01, 100)
    gameState.camera.position.z = 1
 
    gameState.font = dm.LoadDefaultFont(platform.renderCtx)

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
                            dm.CreateSprite(gameState.atlasTex, {i32(tile.src.x), i32(tile.src.y), 32, 32}),
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
                            player.position = v2{f32(entity.grid.x), f32(-entity.grid.y + layer.c_height)}

                            gameState.camera.position.xy = {player.position.x, player.position.y}

                            gameState.lastCheckpointPosition = player.position
                        }
                        else {
                            e, handle := CreateEntity()
                            e.collisionSize = {0.98, 0.98}

                            e.position = v2{f32(entity.grid.x), f32(-entity.grid.y + layer.c_height)}
                            tileRect, ok := entity.tile.?
                            if ok {
                                e.sprite = dm.CreateSprite(gameState.atlasTex, 
                                    {i32(tileRect.x), i32(tileRect.y), i32(tileRect.w), i32(tileRect.h)})
                            }

                            // fmt.println(layer.grid_size, entity.grid.y, e.position)

                            for tag in entity.tags {
                                switch tag {
                                // case "RenderSprite": e.flags += { .RenderSprite }
                                case "Trigger":      e.flags += { .Trigger }

                                case "Checkpoint": e.triggerType = .Checkpoint
                                case "Damageable": e.triggerType = .Damageable
                                case "Win":        e.triggerType = .GameWin
                                case "Beer":       e.triggerType = .Beer; gameState.allBeersCount += 1
                                case "Ability": {
                                    e.triggerType = .Ability

                                    if len(entity.field_instances) > 0 {
                                        field := entity.field_instances[0]
                                        if field.identifier == "AbilityType" {
                                            if v, ok := field.value.(string); ok {
                                                switch v {
                                                case "DoubleJump":  e.pickupAbility = .DoubleJump
                                                case "WallClimb":   e.pickupAbility = .WallClimb
                                                case "WorldSwitch": e.pickupAbility = .WorldSwitch
                                                case "Dash":        e.pickupAbility = .Dash
                                                }
                                            }
                                        }
                                    }
                                }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    when ODIN_DEBUG {
        // gameState.playerState.abilities = {.DoubleJump, .Dash, .WorldSwitch, .WallClimb}
        // gameState.playerState.abilities = {.WorldSwitch, .WallClimb }
    }

    ShowMessage(`"It's just Wednesday, 
but there is no more beers in the Basement"
Tenma Thought and venture into the Phase World
in search of the golden liquid.


Press spacebar to continue`)
}

ShowMessage :: proc(message: string) {
    gameState.message = message
    gameState.showMessage = true
}

ShowPopup :: proc(message: string) {
    gameState.popup = message
    gameState.showPopup = true
    gameState.popupTimer = popupTime
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    using globals

    if gameState.showMessage {
        if dm.GetKeyState(input, .Space) == .JustPressed {
            gameState.showMessage = false
        }

        if gameState.showMessage {
            return
        }
    }

    player := dm.GetElement(gameState.entities, gameState.playerHandle)

    // player collisions
    if player != nil {
        for &e in gameState.entities.elements {
            if dm.IsHandleValid(gameState.entities, e.handle) == false {
                continue
            }
            
            if .Lifetime in e.flags {
                e.lifetimeLeft -= time.deltaTime
                if e.lifetimeLeft < 0 {
                    DestroyEntity(e.handle)
                }
            }

            if .Trigger in e.flags {
                aBounds := dm.CreateBounds(e.position, e.collisionSize, e.pivot)
                bBounds := dm.CreateBounds(player.position, player.collisionSize, player.pivot)

                if dm.CheckCollisionBounds(aBounds, bBounds) {
                    switch e.triggerType {
                    case .None:
                    case .Checkpoint:
                        if gameState.lastCheckpointHandle != e.handle {
                            gameState.lastCheckpointPosition = e.position
                            gameState.lastCheckpointHandle = e.handle

                            ShowPopup("Checkpoint  Reached!")
                        }

                    case .Damageable:
                        gameState.deathSeq = true

                    case .Ability: 
                        if e.pickupAbility not_in gameState.playerState.abilities {
                            gameState.playerState.abilities += { e.pickupAbility }
                            ShowMessage(AbilityMessages[e.pickupAbility])

                            DestroyEntity(e.handle)
                        }

                    case .Beer: 
                        gameState.beersFound += 1
                        DestroyEntity(e.handle)

                        if gameState.beersFound == gameState.allBeersCount {
                            ShowPopup("All beers found!")
                        }
                        else {
                            @static buf: [64]u8
                            ShowPopup(fmt.bprint(buf[:], "Beer found! ", gameState.beersFound, "/", gameState.allBeersCount))
                        }

                    case .GameWin:
                        if gameState.winCondition == false {
                            gameState.winSeq = true
                            gameState.winCondition = true

                            gameState.playerState.abilities += { .Dash }
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

        // dm.DrawBounds2D(renderCtx, focusBox, dm.RED)

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
    if dm.muiBeginWindow(mui, "T", {0, 0, 150, 300}, nil) {
        defer dm.muiEndWindow(mui)
        
        dm.muiLabel(mui, "MovState:", gameState.playerState.movementState)
        dm.muiLabel(mui, "Jumps:", gameState.playerState.jumpsLeftCount)
        dm.muiLabel(mui, "Vel:", player.velocity)
        dm.muiLabel(mui, "Pos:", player.position)
        dm.muiLabel(mui, "Cling:", gameState.playerState.wallClingTimer)

        // fmt.println(player.position)

        dm.muiLabel(mui, "collLeft:", gameState.playerState.collRight)
        dm.muiLabel(mui, "FacingDir:", player.facingDir)

        // dm.muiToggle(mui, "doubleJump",  &gameState.playerState.doubleJump)
        // dm.muiToggle(mui, "wallClimb",   &gameState.playerState.wallClimb)
        // dm.muiToggle(mui, "worldSwitch", &gameState.playerState.worldSwitch)
        // dm.muiToggle(mui, "canDash",     &gameState.playerState.canDash)

        for ability in PlayerAbility {
            have := ability in gameState.playerState.abilities
            if dm.muiToggle(mui, fmt.tprint(ability), &have) {
                if have {
                    gameState.playerState.abilities += {ability}
                }
                else {
                    gameState.playerState.abilities -= {ability}
                }
            }
        }
    }
}


@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    using globals

    gameState := cast(^GameState) state

    dm.ClearColor(renderCtx, {0.5, 0.5, 0.7, 1})
    dm.SetCamera(renderCtx, gameState.camera)

    camPos := gameState.camera.position
    camHeight := gameState.camera.orthoSize
    camWidth  := gameState.camera.aspect * camHeight
    cameraBounds := dm.Bounds2D{
        camPos.x - camWidth, camPos.x + camWidth,
        camPos.y - camHeight, camPos.y + camHeight,
    }


    for e in gameState.entities.elements {
        if dm.IsHandleValid(gameState.entities, e.handle) == false {
            continue
        }

        bounds := dm.CreateBounds(e.position, e.size)
        if dm.CheckCollisionBounds(cameraBounds, bounds) == false {
            continue
        }

        tint := e.tint
        if e.levelLayer != gameState.activeLayer && e.levelLayer != .Base {
            tint.a = 0.5
        }

        if e.triggerType == .Checkpoint && gameState.lastCheckpointHandle != e.handle {
            tint.a = 0.5
        }

        dm.DrawSprite(renderCtx, e.sprite, e.position, 0, tint)

        when ODIN_DEBUG {
            // dm.DrawBox2D(renderCtx, e.position, {0.1, 0.1}, dm.BLACK)

            if .Trigger in e.flags {
                dm.DrawBox2D(renderCtx, e.position, e.collisionSize, dm.RED)
            }
        }
    }

    if gameState.showMessage {
        fontSize :: 18

        windowSize := globals.renderCtx.frameSize
        textSize := dm.v2Conv(dm.MeasureText(gameState.message, gameState.font, fontSize))

        dm.DrawRectSize(renderCtx, renderCtx.whiteTexture, dm.v2Conv(windowSize / 2), textSize + {50, 50}, color = {0, 0, 0, .86})
        dm.DrawTextCentered(renderCtx, gameState.message, gameState.font, windowSize / 2, fontSize)
    }

    if gameState.showPopup {
        fontSize :: 12

        windowSize := globals.renderCtx.frameSize
        textSize := dm.v2Conv(dm.MeasureText(gameState.popup, gameState.font, fontSize))

        pos := iv2{windowSize.x / 2, windowSize.y - 70}

        dm.DrawRectSize(renderCtx, 
            renderCtx.whiteTexture, 
            dm.v2Conv(pos),
            textSize + {10, 10}, color = {0, 0, 0, .86})
        
        dm.DrawTextCentered(renderCtx, gameState.popup, gameState.font, pos, fontSize)

        gameState.popupTimer -= time.deltaTime
        if gameState.popupTimer < 0 {
            gameState.showPopup = false
        }
    }


    if gameState.doFade {
        c := dm.BLACK
        c.a = gameState.fadeAmount

        dm.DrawRectSize(renderCtx, renderCtx.whiteTexture, dm.v2Conv(renderCtx.frameSize / 2), dm.v2Conv(renderCtx.frameSize), color = c)
    }

    // @HACK: it feels wrong to put it here, but it works I guess...
    if gameState.deathSeq {
        DeathSequence()
    }

    if gameState.winSeq {
        WinSequence()
    }

    dm.DrawText(renderCtx, fmt.tprint(1 / time.deltaTime), gameState.font, {0, 0})

}
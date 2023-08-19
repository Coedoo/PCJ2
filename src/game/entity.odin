package game

import dm "../dmcore"
import "../dmcore/globals"
import "core:fmt"

import "core:math/ease"

import "core:math/linalg/glsl"

EntityHandle :: distinct dm.Handle

EntityFlag :: enum {
    Wall,
    RenderSprite,
    RenderTexture,
}

ControlerType :: enum {
    None,
    Player,
}


Entity :: struct {
    flags: bit_set[EntityFlag],
    controler: ControlerType,

    position: v2,
    size: v2,

    sprite: dm.Sprite,
    tint: dm.color,

    facingDir: f32,

    // physics
    collisionSize: v2,
    velocity: v2,

    wallClingTimer: f32,

    collTop:   bool,
    collBot:   bool,
    collLeft:  bool,
    collRight: bool,
}


CreateEntityHandle :: proc() -> EntityHandle {
    return cast(EntityHandle) dm.CreateHandle(gameState.entities)
}

CreateEntity :: proc() -> (^Entity, EntityHandle) {
    handle := CreateEntityHandle()
    assert(handle.index != 0)

    entity := dm.GetElement(gameState.entities, handle)
    entity.tint = dm.WHITE

    return entity, handle
}

DestroyEntity :: proc(handle: EntityHandle) {
    dm.FreeSlot(gameState.entities, auto_cast handle)
}


////////////

ControlEntity :: proc(entity: ^Entity) {
    switch entity.controler {
        case .Player: ControlPlayer(entity)
        case .None: // ignore
    }
}

HandleEntityDeath :: proc(entity: ^Entity) {
    switch entity.controler {
        case .Player: HandlePlayerDeath(entity)
        case .None: // ignore
    }   
}

////////////

CreateWall :: proc(pos, size: v2) {
    wall, handle := CreateEntity()

    wall.position      = pos
    wall.size          = size
    wall.collisionSize = size

    wall.flags = { .Wall, .RenderTexture }

    wall.sprite = dm.CreateSprite(globals.renderCtx.whiteTexture, {0, 0, 1, 1})
    wall.tint = {0.6, 0.6, 0.6, 1}
}

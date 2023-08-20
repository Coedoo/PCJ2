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
    Trigger,
}

ControlerType :: enum {
    None,
    Player,
}

TriggerType :: enum {
    None,
    Checkpoint,
    Damageable,
}

LevelLayer :: enum {
    Base,
    L1,
    L2,
}

Entity :: struct {
    flags: bit_set[EntityFlag],
    controler: ControlerType,

    levelLayer: LevelLayer,

    position: v2,
    size: v2,

    sprite: dm.Sprite,
    tint: dm.color,

    facingDir: f32,

    triggerType: TriggerType,

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

CreateWall :: proc(pos: v2, sprite: dm.Sprite, layer: string) {
    wall, handle := CreateEntity()

    wall.position      = pos
    wall.collisionSize = {1, 1}

    wall.flags = { .Wall, .RenderSprite }

    wall.sprite = sprite
    wall.tint = {0.4, 0.2, 0.7, 1}

    switch layer {
        case "L1": wall.levelLayer = .L1
        case "L2": wall.levelLayer = .L2
    }
}

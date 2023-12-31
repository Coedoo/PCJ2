package game

import dm "../dmcore"
import "../dmcore/globals"
import "core:fmt"

import "core:math/ease"

import "core:math/linalg/glsl"

EntityHandle :: distinct dm.Handle

EntityFlag :: enum {
    Wall,
    Trigger,
    Lifetime,
}

ControlerType :: enum {
    None,
    Player,
}

TriggerType :: enum {
    None,
    Checkpoint,
    Damageable,
    Ability,
    GameWin,
    Beer,
}

LevelLayer :: enum {
    Base,
    L1,
    L2,
}

Entity :: struct {
    handle: EntityHandle,
    flags: bit_set[EntityFlag],
    controler: ControlerType,

    levelLayer: LevelLayer,

    position: v2,
    size: v2,
    pivot: v2,

    sprite: dm.Sprite,
    tint: dm.color,

    facingDir: f32,

    triggerType: TriggerType,
    pickupAbility: PlayerAbility,

    // physics
    collisionSize: v2,
    velocity: v2,

    lifetimeLeft: f32,
}


CreateEntityHandle :: proc() -> EntityHandle {
    return cast(EntityHandle) dm.CreateHandle(gameState.entities)
}

CreateEntity :: proc() -> (^Entity, EntityHandle) {
    handle := CreateEntityHandle()
    assert(handle.index != 0)

    entity := dm.GetElement(gameState.entities, handle)
    entity.handle = handle
    entity.tint = dm.WHITE
    entity.pivot = {0.5, 0.5}

    return entity, handle
}

DestroyEntity :: proc(handle: EntityHandle) {
    dm.FreeSlot(gameState.entities, handle)
}


////////////

ControlEntity :: proc(entity: ^Entity) {
    switch entity.controler {
        case .Player: ControlPlayer(entity, &gameState.playerState)
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
    wall.collisionSize = {1.01, 1.01}
    wall.size = {1, 1}

    wall.flags = { .Wall }

    wall.sprite = sprite
    wall.tint = {0.4, 0.2, 0.7, 1}

    switch layer {
        case "L1": wall.levelLayer = .L1
        case "L2": wall.levelLayer = .L2
    }
}

package game

import dm "../dmcore"
import "../dmcore/globals"
import "core:fmt"

import "core:math/ease"

import "core:math/linalg/glsl"

EntityHandle :: distinct dm.Handle

EntityFlag :: enum {
}

ControlerType :: enum {
    None,
    Player,
}


Entity :: struct {
    flags: bit_set[EntityFlag],
    controler: ControlerType,
}


CreateEntityHandle :: proc() -> EntityHandle {
    return cast(EntityHandle) dm.CreateHandle(gameState.entities)
}

CreateEntity :: proc() -> ^Entity {
    handle := CreateEntityHandle()
    assert(handle.index != 0)

    entity := dm.GetElement(gameState.entities, handle)


    return entity
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

CreatePlayerEntity :: proc() -> ^Entity {
    player := CreateEntity()


    return player
}

ControlPlayer :: proc(player: ^Entity) {
}

HandlePlayerDeath :: proc(player: ^Entity) {
    
}
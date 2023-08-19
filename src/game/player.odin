package game

import dm "../dmcore"
import "../dmcore/globals"

import "core:math"

import "core:fmt"

CreatePlayerEntity :: proc() -> EntityHandle {
    player, handle := CreateEntity()

    player.flags = { .RenderTexture }

    player.tint = dm.BLUE
    player.controler = .Player

    player.size = {1, 1}
    player.collisionSize = {1, 1}

    return handle
}

ControlPlayer :: proc(player: ^Entity) {
    using player

    gravity   := -(2 * jumpHeight) / (jumpTime * jumpTime);
    jumpSpeed := -gravity * jumpTime;

    /// Input
    input := dm.GetAxisInt(globals.input, .Left, .Right)
    doJump := dm.GetKeyState(globals.input, .Space) == .JustPressed

    velocity.x = f32(input) * playerSpeed
    velocity.y += gravity * globals.time.deltaTime

    wallSlide := (collLeft || collRight) && collBot == false
    if wallSlide {
        velocity.y = -min(-velocity.y, wallSlideSpeed)
    }

    // @TODO: velocity smoothing
    if doJump {
        if wallSlide {
            wallDir := collLeft ? -1 : 1

            velocity.y = wallClimbSpeed.y
            velocity.x *= f32(wallDir)
        }
        else if collBot {
            velocity.y = jumpSpeed
        }
    }

    collTop   = false
    collBot   = false
    collRight = false
    collLeft  = false

    /// Collisions
    move := velocity * globals.time.deltaTime

    bounds := dm.CreateBounds(position, collisionSize)

    /// Vertical Collisions
    dir := math.sign(velocity.y)

    rayOrigin: v2
    rayOrigin.x = bounds.left
    rayOrigin.y = dir == 1 ? bounds.top - skinWidth : bounds.bot + skinWidth  

    ray := dm.CreateRay2D(rayOrigin, {0, dir})

    step := (bounds.right - bounds.left - skinWidth) / (raysPerCharacter - 1)
    rayLength := abs(velocity.y) * globals.time.deltaTime + skinWidth

    for i in 0..<raysPerCharacter {
        hit, dist := Raycast(ray, rayLength)

        dm.DrawRay(globals.renderCtx, ray, rayLength * 10, hit ? dm.RED : dm.GREEN)

        if hit {
            rayLength = dist
            move.y = (dist - skinWidth) * dir

            if dir == 1  do collTop = true
            if dir == -1 do collBot = true
        }

        ray.origin.x += step
    }

    /// Horizontal Collisions
    dir = math.sign(velocity.x)

    rayOrigin.x = dir == 1 ? bounds.right : bounds.left
    rayOrigin.y = bounds.bot

    ray = dm.CreateRay2D(rayOrigin, {dir, 0})

    step = (bounds.top - bounds.bot - skinWidth) / (raysPerCharacter - 1)
    rayLength = abs(velocity.x) * globals.time.deltaTime + skinWidth

    for i in 0..<raysPerCharacter {
        hit, dist := Raycast(ray, rayLength)

        dm.DrawRay(globals.renderCtx, ray, rayLength * 10, hit ? dm.RED : dm.GREEN)

        if hit {
            rayLength = dist
            move.x = (dist - skinWidth) * dir

            if dir == 1  do collRight = true
            if dir == -1 do collLeft  = true
        }

        ray.origin.y += step
    }


    /////

    position += move

    if collTop || collBot {
        velocity.y = 0
    }

}

HandlePlayerDeath :: proc(player: ^Entity) {
}
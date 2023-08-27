package game

import dm "../dmcore"
import "../dmcore/globals"

import "core:math"
import "core:math/linalg/glsl"

import "core:fmt"

PlayerMovementState :: enum {
    Idle,
    Run,
    Jump,
    WallSlide,
    Dash,
}

PlayerAbility :: enum {
    DoubleJump,
    WallClimb,
    WorldSwitch,
    Dash,
}

PlayerState :: struct {
    wallClingTimer: f32,

    collTop:   bool,
    collBot:   bool,
    collLeft:  bool,
    collRight: bool,

    movementState: PlayerMovementState,

    jumpsLeftCount: int,

    dashing: bool,
    dashPoint: v2,

    idleAnim: dm.Sprite,
    runAnim: dm.Sprite,
    jumpAnim: dm.Sprite,
    dashAnim: dm.Sprite,

    abilities: bit_set[PlayerAbility]
}

CreatePlayerEntity :: proc() -> EntityHandle {
    player, handle := CreateEntity()

    player.controler = .Player

    player.size = {1, 2}
    player.collisionSize = {1, 2}

    player.facingDir = 1

    // player.sprite = dm.CreateSprite(gameState.pixelmaTex, {0, 0, 32, 64})
    // player.sprite.origin = {0.5, 1}

    player.pivot = {0.5, 0}

    return handle
}

ControlPlayer :: proc(player: ^Entity, playerState: ^PlayerState) {
    using player
    using playerState

    if gameState.deathSeq || gameState.winSeq {
        return
    }

    gravity   := -(2 * jumpHeight) / (jumpTime * jumpTime);
    jumpSpeed := -gravity * jumpTime;

    // World Switch
    if .WorldSwitch in abilities && dm.GetKeyState(globals.input, .Up) == .JustPressed {
        gameState.activeLayer = .L1 if gameState.activeLayer == .L2 else .L2
    }

    /// Input
    input := dm.GetAxisInt(globals.input, .Left, .Right)
    doJump := dm.GetKeyState(globals.input, .Space) == .JustPressed
    // fmt.println(input)

    if .Dash in abilities && dm.GetKeyState(globals.input, .LShift) == .JustPressed {
        dashing = true
        dashPoint = position + {facingDir * dashDistance, 0}
        velocity = 0
    }

    targetVelX := dashing ? \
                facingDir * dashSpeed : \
                f32(input) * playerSpeed 

    velocity.x = math.lerp(velocity.x, targetVelX, 20 * globals.time.deltaTime)

    wallSlide := false

    if dashing == false {
        // velocity.x = targetVelX
        velocity.y += gravity * globals.time.deltaTime

        wallSlide = (collLeft || collRight) && collBot == false && .WallClimb in abilities
        if wallSlide {
            velocity.y = -min(-velocity.y, wallSlideSpeed)

            if wallClingTimer > 0 {
                velocity.x = 0

                if input != i32(facingDir) && input != 0 {
                    wallClingTimer -= globals.time.deltaTime
                }
                else {
                    wallClingTimer = wallClingTime
                }
            }
            else {
                    wallClingTimer = wallClingTime
            }
        }

        if doJump {
            if wallSlide {
                wallDir := collLeft ? -1 : 1

                velocity.y = wallClimbSpeed.y
                velocity.x = -f32(wallDir) * 20

                // jumpsLeftCount -= 1
            }
            else if collBot || jumpsLeftCount > 0 {
                velocity.y = jumpSpeed

                // 
                if collBot == false {
                    jumpsLeftCount -= 1
                }
            }
        }

        if velocity.x != 0 {
            facingDir = math.sign(velocity.x)
        }
    }

    collTop   = false
    collBot   = false
    collRight = false
    collLeft  = false

    /// Collisions
    move := velocity * globals.time.deltaTime

    bounds := dm.CreateBounds(position, collisionSize, pivot)

    /// Vertical Collisions
    dir := math.sign(velocity.y)

    rayOrigin: v2
    rayOrigin.x = bounds.left
    rayOrigin.y = dir == 1 ? bounds.top - skinWidth : bounds.bot + skinWidth  

    ray := dm.CreateRay2D(rayOrigin, {0, dir})

    step := (bounds.right - bounds.left - skinWidth) / (raysPerCharacter - 1)
    rayLength := abs(velocity.y) * globals.time.deltaTime + skinWidth

    collisionSize = {1, 2} if dashing == false else {1, 1}

    for i in 0..<raysPerCharacter {
        hit, dist := Raycast(ray, rayLength, gameState.activeLayer)

        when ODIN_DEBUG {
            dm.DrawRay(globals.renderCtx, ray, rayLength * 10, hit ? dm.RED : dm.GREEN)
        }

        if hit {
            rayLength = dist
            move.y = (dist - skinWidth) * dir

            if dir == 1  do collTop = true
            if dir == -1 do collBot = true
        }

        ray.origin.x += step
    }

    /// Horizontal Collisions
    dir = facingDir

    rayOrigin.x = dir == 1 ? bounds.right : bounds.left
    rayOrigin.y = bounds.bot

    ray = dm.CreateRay2D(rayOrigin, {dir, 0})

    step = (bounds.top - bounds.bot - skinWidth) / (raysPerCharacter - 1)
    rayLength = abs(velocity.x) * globals.time.deltaTime + skinWidth

    if rayLength < skinWidth {
        rayLength = skinWidth * 2
    }

    for i in 0..<raysPerCharacter {
        hit, dist := Raycast(ray, rayLength, gameState.activeLayer)

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


    if dashing {
        if facingDir == 1 {
            if position.x >= dashPoint.x {
                dashing = false
                position = dashPoint
            }
        }
        else {
            if position.x <= dashPoint.x {
                dashing = false
                position = dashPoint
            }
        }
    }

    if collLeft || collRight {
        dashing = false
    }


    if collTop || collBot {
        velocity.y = 0
    }

    prevState := movementState

    if wallSlide {
        movementState = .WallSlide
    }
    else if dashing {
        movementState = .Dash
        player.sprite = dashAnim
        dm.AnimateSprite(&sprite, cast(f32) globals.time.time, 0.1)
    }
    else if collBot == false {
        movementState = .Jump

        if prevState != .Jump {
            jumpsLeftCount -= 1
        }

        player.sprite = jumpAnim

        if velocity.y < -8 {
            player.sprite.currentFrame = 2
        }
        else if velocity.y < 8 {
            player.sprite.currentFrame = 1
        }
        else {
            player.sprite.currentFrame = 0
        }

    }
    else if velocity.x * velocity.x + velocity.y * velocity.y > math.F32_EPSILON {
        movementState = .Run
        player.sprite = runAnim
        dm.AnimateSprite(&sprite, cast(f32) globals.time.time, 0.15)
    }
    else {
        movementState = .Idle
        player.sprite = idleAnim
        dm.AnimateSprite(&sprite, cast(f32) globals.time.time, 0.2)
    }

    sprite.flipX = facingDir != 1

    if movementState != .Jump {
        jumpsLeftCount = .DoubleJump in abilities ? 2 : 1
    }

}

HandlePlayerDeath :: proc(player: ^Entity) {
}
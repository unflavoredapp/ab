import Foundation
import CoreGraphics

/// World scale and the whole movement model: momentum on the ground and in the air, jump, wall-run,
/// wall-climb, wall-jump, dashes, sword jump and landing on props.
///
/// Scale: the engine works in "world units". Eye height is 54, a standing body is ~60, walls are 80
/// (Town buildings 260), which puts 1 metre at about 33 units (eye 1.64 m, run 170 u/s = 5.2 m/s).
/// No Metal, no UIKit: this file also compiles on its own so Tests/main.swift can run the real code.
enum TMove {
    // MARK: scale
    static let unitsPerMeter: CGFloat = 33
    static let bodyH: CGFloat = 60
    static let runSpeed: CGFloat = 170

    // MARK: horizontal momentum
    static let groundAccel: CGFloat = 14       // 1/s  how fast you reach your input speed on the ground (~0.15 s)
    static let groundSlide: CGFloat = 5        // 1/s  how fast extra speed (a dash, a landing) bleeds off on the ground
    static let airSteer: CGFloat = 3           // 1/s  steering toward your input while airborne (momentum is kept)
    static let airDrag: CGFloat = 0.25         // 1/s  with no input in the air you keep almost all your speed

    // MARK: jump
    static let gravity: CGFloat = 720          // u/s^2   (21.8 m/s^2: snappy, game gravity)
    static let jumpV: CGFloat = 250            // u/s     apex 43 u = 1.3 m, air time 0.69 s
    static let wallJumpV: CGFloat = 290        // u/s     apex 58 u = 1.8 m above the kick point

    // MARK: wall contact (GunZ style: run along walls, run up them, kick off them)
    static let wallProbe: CGFloat = 30         // ray length used to look for a wall
    static let wallTouch: CGFloat = 25         // closer than this counts as contact (body radius is 14)
    static let wallMinOver: CGFloat = 30       // the wall top must stay this far above the feet (half a body)
    static let wallRunMinTop: CGFloat = 70     // lower solids (crates, tables, cars, beds) cannot be wall-run
    static let wallRunMax: CGFloat = 1.4       // s       longest run along one wall
    static let wallRunLift: CGFloat = 110      // u/s     at most this much upward speed while running along a wall
    static let wallRunPeak: CGFloat = 34       // u       a wall run you start low peaks about this high (1 m)
    static let wallRunGrav: CGFloat = 0.3      // gravity while running along a wall: a shallow arc that follows the wall
    static let wallRise: CGFloat = 25          // u/s     (kept for older tools)
    static let wallRunBoost: CGFloat = 0.45    // speed along the wall is at least run * (1 + boost)
    static let climbV: CGFloat = 240           // u/s     running straight up a wall in front of you
    static let climbMax: CGFloat = 0.5         // s
    static let wallGrace: CGFloat = 0.3        // s       wall-jump window after the last contact
    static let wallLockT: CGFloat = 0.3        // s       no re-attach right after a wall-jump
    static let wallKickSpeed: CGFloat = 400    // u/s     horizontal speed of a wall-jump
    static let wallKickT: CGFloat = 0.25       // s       (tests / older code: how long a kick displacement lasts)
    static let maxWallJumps = 3                // chained kicks before you have to land

    // MARK: dash
    static let dashSpeed: CGFloat = 640        // u/s
    static let dashT: CGFloat = 0.18           // s
    static let wallDashSpeed: CGFloat = 620    // u/s     dash along the wall you are running on
    static let wallDashT: CGFloat = 0.24       // s       no gravity during a wall dash
    static let airDashT: CGFloat = 0.16        // s       one air dash per jump, hangs in the air

    // MARK: sword
    static let swordLiftV: CGFloat = 270       // u/s     upward launch from a slash in the air
    static let swordLiftWallV: CGFloat = 330   // u/s     next to a wall: a bigger lift and the wall run restarts
    static let airSlashHang: CGFloat = 60      // u/s     every air slash stops your fall a little (aerial combos)

    static let minAirZ: CGFloat = 4
    static let stepUp: CGFloat = 8             // you walk onto anything this much above your feet

    struct State {
        var z: CGFloat = 0
        var vz: CGFloat = 0
        var wallRunT: CGFloat = 0
        var wallLock: CGFloat = 0
        var wallGrace: CGFloat = 0
        var wallN = CGVector.zero
        /// along-the-wall direction of the current / last wall run (unit, follows your input)
        var wallT = CGVector.zero
        /// top of the wall you are on (the run never lifts your feet above top - wallMinOver)
        var wallTop: CGFloat = 0
        var climbT: CGFloat = 0
        var wallJumps = 0
        var onWall = false
        var climbing = false
        /// hang time from a dash: no gravity while > 0
        var hoverT: CGFloat = 0
        var airDashUsed = false
        /// sword jumps used since you last touched the ground or kicked off a wall
        var swordLifts = 0
        /// height of whatever you are standing on (0 = the street, or the top of a crate / car)
        var ground: CGFloat = 0
        var grounded: Bool { z <= ground + 0.5 && vz <= 0 }
    }

    struct Result {
        /// extra horizontal velocity to apply this frame (units/s) — used by simple callers (tests)
        var pushV = CGVector.zero
        /// set on the frame a wall-jump fires: unit direction of the kick
        var kick: CGVector? = nil
        var onWall = false
        var climbing = false
        var landed = false
        /// downward speed at the moment of landing (u/s)
        var impact: CGFloat = 0
    }

    enum DashKind { case ground, wall, air }

    // MARK: horizontal

    /// Momentum: on the ground you snap to your input quickly and extra speed slides off; in the air you
    /// keep your speed and only steer. On a wall you run along it at least `run * (1 + boost)`, keeping
    /// any extra speed you brought in (a dash into a wall-run keeps going). Climbing stops you against it.
    static func horizontal(_ v: inout CGVector, _ s: State, wish: CGVector, speed: CGFloat, dt: CGFloat) {
        let target = CGVector(dx: wish.dx * speed, dy: wish.dy * speed)
        let wl = hypot(wish.dx, wish.dy)
        if s.climbing {
            v = CGVector(dx: -s.wallN.dx * 20, dy: -s.wallN.dy * 20)
            return
        }
        if s.onWall {
            let along = max(abs(v.dx * s.wallT.dx + v.dy * s.wallT.dy), speed * (1 + wallRunBoost))
            v = CGVector(dx: s.wallT.dx * along - s.wallN.dx * 12, dy: s.wallT.dy * along - s.wallN.dy * 12)
            return
        }
        if s.grounded {
            let cur = hypot(v.dx, v.dy)
            let rate = cur > speed + 1 ? groundSlide : groundAccel
            let k = 1 - CGFloat(exp(Double(-rate * dt)))
            v.dx += (target.dx - v.dx) * k
            v.dy += (target.dy - v.dy) * k
        } else if wl > 0.1 {
            // steer toward the input without bleeding the speed you already have in that direction
            let cur = hypot(v.dx, v.dy)
            let k = 1 - CGFloat(exp(Double(-airSteer * dt)))
            var nx = v.dx + (target.dx - v.dx) * k
            var ny = v.dy + (target.dy - v.dy) * k
            let nl = hypot(nx, ny)
            let keep = max(speed, cur)
            if nl > keep && nl > 0 { nx *= keep / nl; ny *= keep / nl }
            if nl < cur * 0.99 && nl > 0 && cur > speed { let f = cur * 0.99 / nl; nx *= f; ny *= f }
            v = CGVector(dx: nx, dy: ny)
        } else {
            let k = CGFloat(exp(Double(-airDrag * dt)))
            v.dx *= k; v.dy *= k
        }
    }

    /// Remove the part of the velocity that pushes into a wall the collision just corrected (`fix` is the
    /// displacement the collision applied). Keeps sliding along walls smooth and kills wall-sticking.
    static func clipToCollision(_ v: inout CGVector, fix: CGVector) {
        let l = hypot(fix.dx, fix.dy)
        guard l > 0.001 else { return }
        let n = CGVector(dx: fix.dx / l, dy: fix.dy / l)
        let into = v.dx * n.dx + v.dy * n.dy
        if into < 0 { v.dx -= n.dx * into; v.dy -= n.dy * into }
    }

    // MARK: dash / sword

    /// Decide what a dash does from the current state: along the wall while on (or just off) a wall,
    /// a hanging air dash once per jump, or a normal ground dash. Returns direction, speed, time.
    static func dash(_ s: inout State, move: CGVector, aim: CGFloat) -> (dir: CGVector, speed: CGFloat, time: CGFloat, kind: DashKind)? {
        let ml = hypot(move.dx, move.dy)
        let f = ml > 0.2 ? CGVector(dx: move.dx / ml, dy: move.dy / ml) : CGVector(dx: cos(aim), dy: sin(aim))
        if s.z > s.ground + minAirZ && (s.onWall || s.wallGrace > 0) && hypot(s.wallN.dx, s.wallN.dy) > 0.5 {
            var t = CGVector(dx: -s.wallN.dy, dy: s.wallN.dx)
            if t.dx * f.dx + t.dy * f.dy < 0 { t = CGVector(dx: -t.dx, dy: -t.dy) }
            s.hoverT = wallDashT
            s.vz = max(s.vz, 40)
            s.wallRunT = max(0, s.wallRunT - 0.4)   // a wall dash buys a little more run
            return (t, wallDashSpeed, wallDashT, .wall)
        }
        if s.z > s.ground + minAirZ {
            guard !s.airDashUsed else { return nil }
            s.airDashUsed = true
            s.hoverT = airDashT
            s.vz = max(s.vz, 0)
            return (f, dashSpeed, airDashT, .air)
        }
        return (f, dashSpeed, dashT, .ground)
    }

    /// A slash in the air: the first one (two next to a wall) launches you upward (GunZ sword jump);
    /// later ones just stop your fall for a moment so you can keep cutting. Returns true on a launch.
    static func swordLift(_ s: inout State) -> Bool {
        guard s.z > s.ground + minAirZ else { return false }
        let nearWall = s.onWall || s.wallGrace > 0
        guard s.swordLifts < (nearWall ? 2 : 1) else {
            s.vz = max(s.vz, airSlashHang)
            return false
        }
        s.swordLifts += 1
        s.vz = max(s.vz, nearWall ? swordLiftWallV : swordLiftV)
        s.hoverT = 0
        if nearWall {
            s.wallRunT = 0
            s.climbT = 0
            s.wallGrace = wallGrace
        }
        return true
    }

    // MARK: vertical step

    /// One vertical step. `probe(angle)` returns the distance to the nearest solid along that angle and the
    /// height of that solid's top. `ground` is the height you would stand on here. Frame-rate independent.
    static func step(_ s: inout State, dt: CGFloat, jump: Bool, move: CGVector, aim: CGFloat, baseSpeed: CGFloat,
                     ground: CGFloat = 0,
                     probe: (CGFloat) -> (dist: CGFloat, top: CGFloat)) -> Result {
        var r = Result()
        s.wallLock = max(0, s.wallLock - dt)
        s.wallGrace = max(0, s.wallGrace - dt)
        s.hoverT = max(0, s.hoverT - dt)
        // walking off a crate: the ground drops away and you fall; stepping onto one: you are lifted
        if s.z < ground && s.z >= ground - stepUp { s.z = ground }
        s.ground = ground
        let ml = hypot(move.dx, move.dy)
        if jump {
            if s.z <= ground + 1 {
                s.vz = jumpV
                s.wallRunT = 0
                s.climbT = 0
            } else if s.wallGrace > 0 && s.wallLock <= 0 && s.wallJumps < maxWallJumps {
                // kick off the wall: away from it, carrying on the way you were going
                s.vz = wallJumpV
                s.wallRunT = 0
                s.climbT = 0
                s.wallLock = wallLockT
                s.wallGrace = 0
                s.wallJumps += 1
                s.hoverT = 0
                s.airDashUsed = false
                s.swordLifts = 0
                let fx = ml > 0.2 ? move.dx / ml : cos(aim)
                let fy = ml > 0.2 ? move.dy / ml : sin(aim)
                let into = fx * s.wallN.dx + fy * s.wallN.dy        // < 0 when pushing into the wall
                let kx = s.wallN.dx * 0.9 + fx * (into < 0 ? 0.15 : 0.6)
                let ky = s.wallN.dy * 0.9 + fy * (into < 0 ? 0.15 : 0.6)
                let kl = max(0.01, hypot(kx, ky))
                r.kick = CGVector(dx: kx / kl, dy: ky / kl)
            }
        }
        // wall contact: sides first (wall run), then straight ahead (climb)
        var onWall = false, climbing = false
        if s.z > ground + minAirZ && ml > 0.3 && s.wallLock <= 0 {
            let base = atan2(move.dy, move.dx)
            for off in [CGFloat.pi / 2, -CGFloat.pi / 2, CGFloat.pi / 3, -CGFloat.pi / 3, 0] as [CGFloat] {
                let a = base + off
                let h = probe(a)
                guard h.dist < wallTouch && h.top >= wallRunMinTop && h.top - s.z > wallMinOver else { continue }
                if off == 0 {
                    guard s.climbT < climbMax else { continue }
                    climbing = true
                } else {
                    guard s.wallRunT < wallRunMax else { continue }
                }
                onWall = true
                s.wallTop = h.top
                s.wallN = CGVector(dx: -cos(a), dy: -sin(a))
                break
            }
        }
        let z0 = s.z
        if onWall {
            s.wallGrace = wallGrace
            if climbing {
                s.climbT += dt
                s.vz += (climbV - s.vz) * CGFloat(1 - exp(Double(-10 * dt)))
                // never climb past the top margin either
                let room = s.wallTop - wallMinOver - s.z
                if room <= 0 { s.vz = min(s.vz, 0) }
                s.z += s.vz * dt
                r.climbing = true
            } else {
                s.wallRunT += dt
                // follow the wall: a shallow arc. The feet never rise above top - margin, and on the frame you
                // hit the wall the rise is capped so the run peaks about `wallRunPeak` above the ground
                // (the same height at any frame rate). Sword jumps on the wall can still take you higher.
                let g = gravity * wallRunGrav
                var cap = (2 * g * max(0, s.wallTop - wallMinOver - s.z)).squareRoot()
                if !s.onWall { cap = min(cap, wallRunLift, (2 * g * max(0, ground + wallRunPeak - s.z)).squareRoot()) }
                if s.vz > cap { s.vz = cap }
                s.z += s.vz * dt - 0.5 * g * dt * dt
                s.vz -= g * dt
                var t = CGVector(dx: -s.wallN.dy, dy: s.wallN.dx)
                if t.dx * move.dx + t.dy * move.dy < 0 { t = CGVector(dx: -t.dx, dy: -t.dy) }
                s.wallT = t
                r.pushV = CGVector(dx: t.dx * baseSpeed * wallRunBoost, dy: t.dy * baseSpeed * wallRunBoost)
            }
            r.onWall = true
        } else if s.hoverT > 0 {
            s.vz = max(0, s.vz)
            s.z += s.vz * dt
            s.vz *= CGFloat(exp(Double(-12 * dt)))
        } else {
            // exact ballistic step: apex and air time do not change with the frame rate
            s.z += s.vz * dt - 0.5 * gravity * dt * dt
            s.vz -= gravity * dt
        }
        s.onWall = onWall
        s.climbing = climbing
        if s.z <= ground {
            if z0 > ground + 0.5 { r.landed = true; r.impact = max(0, -s.vz) }
            s.z = ground
            s.vz = 0
            s.wallRunT = 0
            s.climbT = 0
            s.wallJumps = 0
            s.airDashUsed = false
            s.hoverT = 0
            s.swordLifts = 0
            s.onWall = false
            s.climbing = false
        }
        return r
    }
}

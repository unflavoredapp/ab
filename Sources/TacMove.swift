import Foundation
import CoreGraphics

/// World scale and vertical movement (jump, wall-run, wall-jump, landing).
///
/// Scale: the engine works in "world units". Eye height is 54, a standing body is ~60, walls are 80 and
/// a floor is 82 apart, which puts 1 metre at about 33 units (eye 1.64 m, wall 2.4 m, run 170 u/s = 5.2 m/s).
/// No Metal, no UIKit: this file also compiles on its own so Tests/movetest.swift can run the real code.
enum TMove {
    // MARK: scale
    static let unitsPerMeter: CGFloat = 33
    static let bodyH: CGFloat = 60
    static let runSpeed: CGFloat = 170

    // MARK: jump
    static let gravity: CGFloat = 720          // u/s^2   (21.8 m/s^2: snappy, game gravity)
    static let jumpV: CGFloat = 250            // u/s     apex 43 u = 1.3 m, air time 0.69 s
    static let wallJumpV: CGFloat = 290        // u/s     apex 58 u = 1.8 m

    // MARK: wall contact (GunZ style: run along walls, run up them, kick off them)
    static let wallProbe: CGFloat = 30         // ray length used to look for a wall
    static let wallTouch: CGFloat = 28         // closer than this counts as contact (body radius is 14)
    static let wallMinOver: CGFloat = 30       // the wall top must be this far above the feet (half a body)
    static let wallRunMinTop: CGFloat = 70     // lower solids (crates, tables, cars, beds) cannot be wall-run
    static let wallRunMax: CGFloat = 1.4       // s       longest run along one wall
    static let wallRunLift: CGFloat = 170      // u/s     upward speed when you hit the wall running
    static let wallRunGrav: CGFloat = 0.3      // gravity while running along a wall (arc, not a fall)
    static let wallRise: CGFloat = 25          // u/s     (kept for tests: slow drift used by the climb end)
    static let wallRunBoost: CGFloat = 0.45    // extra speed along the wall, fraction of base speed
    static let climbV: CGFloat = 240           // u/s     running straight up a wall in front of you
    static let climbMax: CGFloat = 0.5         // s
    static let wallGrace: CGFloat = 0.3        // s       wall-jump window after the last contact
    static let wallLockT: CGFloat = 0.3        // s       no re-attach right after a wall-jump
    static let wallKickSpeed: CGFloat = 400    // u/s     push away from the wall
    static let wallKickT: CGFloat = 0.25       // s
    static let maxWallJumps = 3                // chained kicks before you have to land

    // MARK: dash
    static let dashSpeed: CGFloat = 640        // u/s
    static let dashT: CGFloat = 0.18           // s       115 u = 3.5 m
    static let wallDashSpeed: CGFloat = 620    // u/s     dash along the wall you are running on
    static let wallDashT: CGFloat = 0.24       // s
    static let airDashT: CGFloat = 0.16        // s       one air dash per jump, hangs in the air

    static let minAirZ: CGFloat = 4

    struct State {
        var z: CGFloat = 0
        var vz: CGFloat = 0
        var wallRunT: CGFloat = 0
        var wallLock: CGFloat = 0
        var wallGrace: CGFloat = 0
        var wallN = CGVector.zero
        /// along-the-wall direction of the current / last wall run (unit, follows your input)
        var wallT = CGVector.zero
        var climbT: CGFloat = 0
        var wallJumps = 0
        var onWall = false
        /// hang time from a dash: no gravity while > 0
        var hoverT: CGFloat = 0
        var airDashUsed = false
        /// sword jumps used since you last touched the ground or kicked off a wall
        var swordLifts = 0
    }

    struct Result {
        /// extra horizontal velocity to apply this frame (units/s)
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

    static let swordLiftV: CGFloat = 270       // u/s     upward launch from a slash in the air
    static let swordLiftWallV: CGFloat = 330   // u/s     next to a wall: a bigger lift and the wall run restarts

    /// A slash in the air launches you upward (GunZ sword jump). Once per airtime, twice next to a wall.
    static func swordLift(_ s: inout State) -> Bool {
        guard s.z > minAirZ else { return false }
        let nearWall = s.onWall || s.wallGrace > 0
        guard s.swordLifts < (nearWall ? 2 : 1) else { return false }
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

    /// Decide what a dash does from the current state: along the wall while on (or just off) a wall,
    /// a hanging air dash once per jump, or a normal ground dash. Returns direction, speed, time.
    static func dash(_ s: inout State, move: CGVector, aim: CGFloat) -> (dir: CGVector, speed: CGFloat, time: CGFloat, kind: DashKind)? {
        let ml = hypot(move.dx, move.dy)
        let f = ml > 0.2 ? CGVector(dx: move.dx / ml, dy: move.dy / ml) : CGVector(dx: cos(aim), dy: sin(aim))
        if s.z > minAirZ && (s.onWall || s.wallGrace > 0) && hypot(s.wallN.dx, s.wallN.dy) > 0.5 {
            // tangent of the wall, pointing the way you are pushing
            var t = CGVector(dx: -s.wallN.dy, dy: s.wallN.dx)
            if t.dx * f.dx + t.dy * f.dy < 0 { t = CGVector(dx: -t.dx, dy: -t.dy) }
            s.hoverT = wallDashT
            s.vz = max(s.vz, 40)
            s.wallRunT = max(0, s.wallRunT - 0.4)   // a wall dash buys a little more run
            return (t, wallDashSpeed, wallDashT, .wall)
        }
        if s.z > minAirZ {
            guard !s.airDashUsed else { return nil }
            s.airDashUsed = true
            s.hoverT = airDashT
            s.vz = max(s.vz, 0)
            return (f, dashSpeed, airDashT, .air)
        }
        return (f, dashSpeed, dashT, .ground)
    }

    /// One vertical step. `probe(angle)` returns the distance to the nearest solid along that angle
    /// and the height of that solid's top. Everything is frame-rate independent.
    static func step(_ s: inout State, dt: CGFloat, jump: Bool, move: CGVector, aim: CGFloat, baseSpeed: CGFloat,
                     probe: (CGFloat) -> (dist: CGFloat, top: CGFloat)) -> Result {
        var r = Result()
        s.wallLock = max(0, s.wallLock - dt)
        s.wallGrace = max(0, s.wallGrace - dt)
        s.hoverT = max(0, s.hoverT - dt)
        let ml = hypot(move.dx, move.dy)
        if jump {
            if s.z <= 1 {
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
        if s.z > minAirZ && ml > 0.3 && s.wallLock <= 0 {
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
                s.wallN = CGVector(dx: -cos(a), dy: -sin(a))
                break
            }
        }
        let z0 = s.z
        if onWall {
            if !s.onWall && !climbing { s.vz = max(s.vz, wallRunLift) }   // hitting the wall lifts you into the run
            s.wallGrace = wallGrace
            if climbing {
                s.climbT += dt
                s.vz += (climbV - s.vz) * CGFloat(1 - exp(Double(-10 * dt)))
                s.z += s.vz * dt
                r.climbing = true
            } else {
                s.wallRunT += dt
                // gentle arc along the wall
                s.z += s.vz * dt - 0.5 * gravity * wallRunGrav * dt * dt
                s.vz -= gravity * wallRunGrav * dt
                // run along the wall, a bit faster than on the ground
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
        if s.z <= 0 {
            if z0 > 0 { r.landed = true; r.impact = max(0, -s.vz) }
            s.z = 0
            s.vz = 0
            s.wallRunT = 0
            s.climbT = 0
            s.wallJumps = 0
            s.airDashUsed = false
            s.hoverT = 0
            s.swordLifts = 0
        }
        return r
    }
}

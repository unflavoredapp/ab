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

    // MARK: wall contact
    static let wallProbe: CGFloat = 26         // ray length used to look for a wall
    static let wallTouch: CGFloat = 25         // closer than this counts as contact (body radius is 14)
    static let wallMinOver: CGFloat = 30       // the wall top must be this far above the feet (half a body)
    static let wallRunMinTop: CGFloat = 70     // lower solids (crates, tables, cars, beds) cannot be wall-run
    static let wallRunMax: CGFloat = 1.1       // s
    static let wallRise: CGFloat = 25          // u/s     slow drift up while attached
    static let wallRunBoost: CGFloat = 0.35    // extra speed along the wall, fraction of base speed
    static let wallGrace: CGFloat = 0.25       // s       wall-jump window after the last contact
    static let wallLockT: CGFloat = 0.35       // s       no re-attach after a wall-jump
    static let wallKickSpeed: CGFloat = 380    // u/s     push away from the wall
    static let wallKickT: CGFloat = 0.25       // s

    // MARK: dash
    static let dashSpeed: CGFloat = 640        // u/s
    static let dashT: CGFloat = 0.18           // s       115 u = 3.5 m

    static let minAirZ: CGFloat = 4

    struct State {
        var z: CGFloat = 0
        var vz: CGFloat = 0
        var wallRunT: CGFloat = 0
        var wallLock: CGFloat = 0
        var wallGrace: CGFloat = 0
        var wallN = CGVector.zero
    }

    struct Result {
        /// extra horizontal velocity to apply this frame (units/s)
        var pushV = CGVector.zero
        /// set on the frame a wall-jump fires: unit direction of the kick
        var kick: CGVector? = nil
        var onWall = false
        var landed = false
        /// downward speed at the moment of landing (u/s)
        var impact: CGFloat = 0
    }

    /// One vertical step. `probe(angle)` returns the distance to the nearest solid along that angle
    /// and the height of that solid's top. Everything is frame-rate independent.
    static func step(_ s: inout State, dt: CGFloat, jump: Bool, move: CGVector, aim: CGFloat, baseSpeed: CGFloat,
                     probe: (CGFloat) -> (dist: CGFloat, top: CGFloat)) -> Result {
        var r = Result()
        s.wallLock = max(0, s.wallLock - dt)
        s.wallGrace = max(0, s.wallGrace - dt)
        let ml = hypot(move.dx, move.dy)
        if jump {
            if s.z <= 1 {
                s.vz = jumpV
                s.wallRunT = 0
            } else if s.wallGrace > 0 && s.wallLock <= 0 {
                s.vz = wallJumpV
                s.wallRunT = 0
                s.wallLock = wallLockT
                s.wallGrace = 0
                let fx = ml > 0.2 ? move.dx / ml : cos(aim)
                let fy = ml > 0.2 ? move.dy / ml : sin(aim)
                let kx = s.wallN.dx * 0.8 + fx * 0.6
                let ky = s.wallN.dy * 0.8 + fy * 0.6
                let kl = max(0.01, hypot(kx, ky))
                r.kick = CGVector(dx: kx / kl, dy: ky / kl)
            }
        }
        var onWall = false
        if s.z > minAirZ && ml > 0.3 && s.wallLock <= 0 && s.wallRunT < wallRunMax {
            let base = atan2(move.dy, move.dx)
            for off in [CGFloat.pi / 2, -CGFloat.pi / 2, 0] as [CGFloat] {
                let a = base + off
                let h = probe(a)
                if h.dist < wallTouch && h.top >= wallRunMinTop && h.top - s.z > wallMinOver {
                    onWall = true
                    s.wallN = CGVector(dx: -cos(a), dy: -sin(a))
                    break
                }
            }
        }
        let z0 = s.z
        if onWall {
            s.wallRunT += dt
            s.wallGrace = wallGrace
            s.vz += (wallRise - s.vz) * CGFloat(1 - exp(Double(-8 * dt)))
            s.z += s.vz * dt
            r.pushV = CGVector(dx: move.dx / ml * baseSpeed * wallRunBoost, dy: move.dy / ml * baseSpeed * wallRunBoost)
            r.onWall = true
        } else {
            // exact ballistic step: apex and air time do not change with the frame rate
            s.z += s.vz * dt - 0.5 * gravity * dt * dt
            s.vz -= gravity * dt
        }
        if s.z <= 0 {
            if z0 > 0 { r.landed = true; r.impact = max(0, -s.vz) }
            s.z = 0
            s.vz = 0
            s.wallRunT = 0
        }
        return r
    }
}

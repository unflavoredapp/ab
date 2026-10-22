// Movement test: compiles Sources/TacMove.swift on its own and runs jump, wall-run, wall-jump and landing
// at several frame rates. Run:  swiftc Sources/TacMove.swift Tests/main.swift -o movetest && ./movetest
import Foundation
import CoreGraphics

struct Trace {
    var maxZ: CGFloat = 0
    var air: CGFloat = 0
    var wallT: CGFloat = 0
    var landX: CGFloat = 0
    var impact: CGFloat = 0
    var landings = 0
    var kickAt: CGFloat = -1
}

/// Player runs along +x (or toward +y), wall is a plane at y = wallY (solid for y >= wallY), radius 14.
func sim(dt: CGFloat, move: CGVector, start: CGPoint, wallY: CGFloat?, top: CGFloat,
         wallJumpAt: CGFloat? = nil, maxT: CGFloat = 3) -> Trace {
    var s = TMove.State()
    var pos = start
    var tr = Trace()
    var t: CGFloat = 0
    var dashT: CGFloat = 0
    var dashV = CGVector.zero
    var wjDone = false
    var firstJump = true
    var endAt: CGFloat = maxT
    let speed = TMove.runSpeed
    while t < endAt {
        var jump = false
        if firstJump { jump = true; firstJump = false }
        if let w = wallJumpAt, t >= w, !wjDone, s.wallGrace > 0 { jump = true; wjDone = true }
        pos.x += move.dx * speed * dt
        pos.y += move.dy * speed * dt
        if dashT > 0 {
            dashT -= dt
            pos.x += dashV.dx * TMove.wallKickSpeed * dt
            pos.y += dashV.dy * TMove.wallKickSpeed * dt
        }
        let p = pos
        let r = TMove.step(&s, dt: dt, jump: jump, move: move, aim: 0, baseSpeed: speed) { a in
            guard let wy = wallY else { return (TMove.wallProbe, 0) }
            let sn = sin(a)
            if sn > 1e-9 {
                let h = (wy - p.y) / sn
                if h >= 0 && h <= TMove.wallProbe { return (h, top) }
            }
            return (TMove.wallProbe, 0)
        }
        pos.x += r.pushV.dx * dt
        pos.y += r.pushV.dy * dt
        if let k = r.kick { dashV = k; dashT = TMove.wallKickT; tr.kickAt = t }
        if let wy = wallY { pos.y = min(pos.y, wy - 14) }
        if s.z > 0 { tr.air += dt }
        if r.onWall { tr.wallT += dt }
        tr.maxZ = max(tr.maxZ, s.z)
        if r.landed {
            tr.landings += 1
            if tr.landings == 1 { tr.landX = pos.x; tr.impact = r.impact; endAt = min(maxT, t + dt * 2) }
        }
        t += dt
    }
    return tr
}

var failures = 0
func check(_ ok: Bool, _ msg: String) {
    print(ok ? "  PASS  " : "  FAIL  ", msg)
    if !ok { failures += 1 }
}
func f(_ v: CGFloat, _ d: Int = 2) -> String { String(format: "%.\(d)f", Double(v)) }

let dts: [CGFloat] = [1.0 / 120, 1.0 / 60, 1.0 / 30, 1.0 / 20]
let upm = TMove.unitsPerMeter
print("scale: \(f(upm, 0)) units per metre, run \(f(TMove.runSpeed, 0)) u/s = \(f(TMove.runSpeed / upm, 1)) m/s")

print("\n1. standing jump")
var apexes: [CGFloat] = []
for dt in dts {
    let r = sim(dt: dt, move: .zero, start: .zero, wallY: nil, top: 0, maxT: 1.5)
    apexes.append(r.maxZ)
    print("  dt \(f(dt * 1000, 1)) ms: apex \(f(r.maxZ, 1)) u (\(f(r.maxZ / upm)) m), air \(f(r.air, 3)) s, impact \(f(r.impact, 0)) u/s")
    check(r.maxZ > 38 && r.maxZ < 50, "apex in 38...50 u")
    check(r.air > 0.6 && r.air < 0.75, "air time 0.6...0.75 s")
    check(r.landings == 1, "lands exactly once")
    check(abs(r.impact - (2 * TMove.gravity * r.maxZ).squareRoot()) < 0.15 * r.impact, "impact speed matches fall height")
}
check((apexes.max() ?? 0) - (apexes.min() ?? 0) < 1.5, "apex does not depend on frame rate")

print("\n2. running jump on open ground")
for dt in dts {
    let r = sim(dt: dt, move: CGVector(dx: 1, dy: 0), start: .zero, wallY: nil, top: 0, maxT: 1.5)
    print("  dt \(f(dt * 1000, 1)) ms: lands \(f(r.landX, 0)) u = \(f(r.landX / upm, 1)) m")
    check(r.landX > 105 && r.landX < 130, "jump distance 105...130 u")
}

print("\n3. wall-run along a wall (gap 18 u)")
var wallTs: [CGFloat] = [], wallZs: [CGFloat] = []
for dt in dts {
    let r = sim(dt: dt, move: CGVector(dx: 1, dy: 0), start: CGPoint(x: 0, y: 82), wallY: 100, top: 80)
    wallTs.append(r.wallT); wallZs.append(r.maxZ)
    print("  top 80, dt \(f(dt * 1000, 1)) ms: on wall \(f(r.wallT)) s, peak z \(f(r.maxZ, 1)) u")
    check(r.wallT > 0.8 && r.wallT <= TMove.wallRunMax + 0.05, "wall-run lasts 0.8...\(f(TMove.wallRunMax)) s")
    check(r.maxZ <= 80 - TMove.wallMinOver + 8, "feet stay below top - margin")
}
check((wallTs.max() ?? 0) - (wallTs.min() ?? 0) < 0.12, "wall-run time does not depend on frame rate")
check((wallZs.max() ?? 0) - (wallZs.min() ?? 0) < 4, "wall-run height does not depend on frame rate")

print("\n4. contact rules")
for top: CGFloat in [22, 38, 44] {
    let r = sim(dt: 1.0 / 60, move: CGVector(dx: 1, dy: 0), start: CGPoint(x: 0, y: 82), wallY: 100, top: top)
    check(r.wallT == 0, "no wall-run on a solid \(f(top, 0)) u tall")
}
let far = sim(dt: 1.0 / 60, move: CGVector(dx: 1, dy: 0), start: CGPoint(x: 0, y: 74), wallY: 100, top: 80)
check(far.wallT == 0, "no contact at 26 u from the wall")
let near = sim(dt: 1.0 / 60, move: CGVector(dx: 1, dy: 0), start: CGPoint(x: 0, y: 76), wallY: 100, top: 80)
check(near.wallT > 0, "contact at 24 u from the wall")
check(TMove.wallRunBoost <= 0.5, "wall-run speed boost at most 1.5x run")

print("\n5. wall-jump (wall top 260, jump 0.45 s into the run)")
for dt in dts {
    let r = sim(dt: dt, move: CGVector(dx: 1, dy: 0), start: CGPoint(x: 0, y: 82), wallY: 100, top: 260, wallJumpAt: 0.45)
    print("  dt \(f(dt * 1000, 1)) ms: kick at \(f(r.kickAt, 2)) s, peak z \(f(r.maxZ, 1)) u (\(f(r.maxZ / upm)) m), air \(f(r.air, 2)) s, impact \(f(r.impact, 0)) u/s")
    check(r.kickAt >= 0, "wall-jump fires")
    check(r.maxZ > 80 && r.maxZ < 125, "wall-jump peak 80...125 u")
    check(r.landings >= 1, "lands afterwards")
}

print("\n6. momentum (ground acceleration, air momentum, dash chains)")
do {
    let d: CGFloat = 1.0 / 60
    var v = CGVector.zero
    var st = TMove.State()
    for _ in 0..<15 { TMove.horizontal(&v, st, wish: CGVector(dx: 1, dy: 0), speed: 170, dt: d) }
    print("  run speed after 0.25 s: \(f(v.dx, 0)) u/s")
    check(v.dx > 160, "reaches run speed within 0.25 s")
    v = CGVector(dx: 640, dy: 0)
    for _ in 0..<60 { TMove.horizontal(&v, st, wish: CGVector(dx: 1, dy: 0), speed: 170, dt: d) }
    check(abs(v.dx - 170) < 10, "a ground dash slides back to run speed within 1 s")
    st.z = 40; st.vz = 10
    v = CGVector(dx: 640, dy: 0)
    for _ in 0..<30 { TMove.horizontal(&v, st, wish: .zero, speed: 170, dt: d) }
    print("  air dash speed after 0.5 s with no input: \(f(v.dx, 0)) u/s")
    check(v.dx > 540, "momentum is kept in the air")
    v = CGVector(dx: 640, dy: 0)
    for _ in 0..<30 { TMove.horizontal(&v, st, wish: CGVector(dx: 0, dy: 1), speed: 170, dt: d) }
    check(v.dy > 60 && hypot(v.dx, v.dy) > 400, "air steering turns you without killing your speed")
    st.onWall = true; st.wallT = CGVector(dx: 1, dy: 0); st.wallN = CGVector(dx: 0, dy: -1)
    v = CGVector(dx: 500, dy: 0)
    TMove.horizontal(&v, st, wish: CGVector(dx: 1, dy: 0), speed: 170, dt: d)
    check(v.dx >= 499, "a dash into a wall run keeps its speed")
    v = CGVector(dx: 100, dy: 0)
    TMove.horizontal(&v, st, wish: CGVector(dx: 1, dy: 0), speed: 170, dt: d)
    check(v.dx >= 170 * (1 + TMove.wallRunBoost) - 1, "wall run is faster than running")
    var c = CGVector(dx: 0, dy: 200)
    TMove.clipToCollision(&c, fix: CGVector(dx: 0, dy: -3))
    check(abs(c.dy) < 0.001, "velocity into a wall is removed after a collision")
}

print("\n7. standing on props")
do {
    var s7 = TMove.State()
    var landedOn: CGFloat = -1
    for i in 0..<120 {
        let g: CGFloat = (s7.z >= 38 || s7.ground == 38) ? 38 : 0
        let r = TMove.step(&s7, dt: 1.0 / 60, jump: i == 0, move: .zero, aim: 0, baseSpeed: 170, ground: g) { _ in (TMove.wallProbe, 0) }
        if r.landed { landedOn = s7.z; break }
    }
    check(landedOn == 38, "jump onto a 38 u crate and land on its top")
    _ = TMove.step(&s7, dt: 1.0 / 60, jump: false, move: .zero, aim: 0, baseSpeed: 170, ground: 0) { _ in (TMove.wallProbe, 0) }
    check(s7.z < 38 && s7.z > 30, "walking off the crate you fall")
    var s8 = TMove.State()
    s8.z = 40; s8.vz = -50
    let lifted = TMove.swordLift(&s8)
    check(lifted && s8.vz >= TMove.swordLiftV, "a slash in the air launches you (sword jump)")
    let again = TMove.swordLift(&s8)
    check(!again && s8.vz >= TMove.airSlashHang, "later air slashes only hang, no second launch")
}

print(failures == 0 ? "\nALL MOVEMENT CHECKS PASSED" : "\n\(failures) MOVEMENT CHECKS FAILED")
exit(failures == 0 ? 0 : 1)

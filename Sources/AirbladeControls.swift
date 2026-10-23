import SwiftUI

// MARK: - Saved control layouts

/// One on-screen control: anchored to a screen corner / edge (ax, ay in 0...1), offset in points, and a size scale.
struct ABCtl: Codable, Equatable {
    var ax: CGFloat
    var ay: CGFloat
    var dx: CGFloat
    var dy: CGFloat
    var scale: CGFloat = 1

    func point(_ W: CGFloat, _ H: CGFloat) -> CGPoint { CGPoint(x: ax * W + dx, y: ay * H + dy) }
}

struct ABLayout: Codable, Equatable {
    var name: String
    var ctl: [String: ABCtl]
    var opacity: Double = 1
    var lookSens: Double = 1
    var aimSens: Double = 1

    static let ids = ["dash", "jump", "crouch", "weapon"]

    static func standard(_ name: String) -> ABLayout {
        ABLayout(name: name, ctl: [
            "crouch": ABCtl(ax: 1, ay: 1, dx: -40, dy: -104),
            "jump": ABCtl(ax: 1, ay: 1, dx: -40, dy: -46),
            "dash": ABCtl(ax: 1, ay: 1, dx: -100, dy: -46),
            "weapon": ABCtl(ax: 0.5, ay: 1, dx: 0, dy: -30)
        ])
    }

    func c(_ id: String) -> ABCtl { ctl[id] ?? ABLayout.standard("").ctl[id]! }
}

/// Three layout slots in UserDefaults; `current` is what the match reads.
enum ABControls {
    private static let key = "ab.controls.v1"
    private static let activeKey = "ab.controls.active"

    static var slots: [ABLayout] = load()
    static var active: Int = UserDefaults.standard.integer(forKey: activeKey)
    static var current: ABLayout { slots[max(0, min(slots.count - 1, active))] }

    private static func load() -> [ABLayout] {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode([ABLayout].self, from: d), s.count == 3 { return s }
        return [ABLayout.standard("Layout 1"), ABLayout.standard("Layout 2"), ABLayout.standard("Layout 3")]
    }

    static func save(_ s: [ABLayout], active a: Int) {
        slots = s
        active = a
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
        UserDefaults.standard.set(a, forKey: activeKey)
    }

    /// multiplier on look speed (aiming = scoped or ADS)
    static func lookMul(aiming: Bool) -> CGFloat { CGFloat(aiming ? current.aimSens : current.lookSens) }
}

// MARK: - Movement state for the HUD

extension TacticalEngine {
    var abAir: Bool { pz > ms.ground + TMove.minAirZ }
    var abNearWall: Bool { ms.onWall || ms.wallGrace > 0 }
    /// a jump press right now would kick off a wall
    var abCanWallJump: Bool { abAir && ms.wallGrace > 0 && ms.wallLock <= 0 && ms.wallJumps < TMove.maxWallJumps }
    var abWallJumpsLeft: Int { max(0, TMove.maxWallJumps - ms.wallJumps) }
    /// a dash press right now would do something (ground dash, wall dash or the one air dash)
    var abDashUsable: Bool { !abAir || abNearWall || !ms.airDashUsed }
    /// 0...1 cooldown progress (1 = ready)
    var abDashFill: CGFloat { dashCd <= 0 ? 1 : max(0, 1 - dashCd / max(0.01, dashCdMax)) }
    /// a slash right now would launch you (GunZ sword jump)
    var abSwordLiftReady: Bool { abAir && ms.swordLifts < (abNearWall ? 2 : 1) }
    /// wall run time left on the current wall, 0 when not running
    var abWallRunLeft: CGFloat { ms.onWall ? max(0, 1 - ms.wallRunT / TMove.wallRunMax) : 0 }
}

// MARK: - In-match controls

let abOrange = Color(red: 1, green: 0.55, blue: 0.16)
let abCyan = Color(red: 0.35, green: 0.85, blue: 0.85)

/// round control face shared by the match and the editor
struct ABRoundButton: View {
    let icon: String
    let d: CGFloat
    var on = false
    var dim = false
    var tint: Color = abOrange

    var body: some View {
        SF(icon, "circle.fill").font(.system(size: d * 0.42, weight: .semibold))
            .foregroundColor(on ? .black : .white.opacity(dim ? 0.35 : 0.95))
            .frame(width: d, height: d)
            .background(Circle().fill(on ? tint.opacity(0.85) : Color.black.opacity(0.18)))
            .overlay(Circle().stroke(on ? Color.white.opacity(0.8) : Color.white.opacity(0.28), lineWidth: 1))
    }
}

/// Dash / jump / crouch and the weapon box, positioned from the saved layout, with movement indicators:
/// dash cooldown ring and ready flash, wall-jump cue with kicks left, wall-run ring, sword-jump chip.
struct AirbladeTouchControls: View {
    let e: TacticalEngine
    let W: CGFloat
    let H: CGFloat

    var body: some View {
        TimelineView(.animation) { tl in
            layer(t: tl.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: W, height: H)
    }

    private func layer(t: Double) -> some View {
        let L = ABControls.current
        let pulse = 0.5 + 0.5 * sin(t * 9)
        return ZStack {
            // crouch
            let cc = L.c("crouch")
            Button { e.toggleCover() } label: { ABRoundButton(icon: "figure.stand", d: 46 * cc.scale, on: e.me.crouch) }
                .buttonStyle(TuiPress()).position(cc.point(W, H))

            // jump: turns into a wall-jump button (orange, pulsing, kicks left) while you can kick off a wall
            let jc = L.c("jump")
            let jd = 46 * jc.scale
            let wj = e.abCanWallJump
            Button { e.wantJump = true } label: {
                ZStack {
                    ABRoundButton(icon: wj ? "arrow.up.right" : "arrow.up", d: jd, on: wj, dim: e.abAir && !wj)
                    if wj {
                        Circle().stroke(abOrange.opacity(0.4 + 0.6 * pulse), lineWidth: 2).frame(width: jd + 8, height: jd + 8)
                        HStack(spacing: 3) {
                            ForEach(0..<TMove.maxWallJumps, id: \.self) { i in
                                Circle().fill(i < e.abWallJumpsLeft ? abOrange : Color.white.opacity(0.25)).frame(width: 4, height: 4)
                            }
                        }
                        .offset(y: jd / 2 + 8)
                    }
                }
            }
            .buttonStyle(TuiPress()).position(jc.point(W, H))

            // wall-run meter: a cyan ring around the jump button that drains while you run on a wall
            if e.abWallRunLeft > 0 {
                Circle().trim(from: 0, to: e.abWallRunLeft)
                    .stroke(abCyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: jd + 16, height: jd + 16)
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
                    .position(jc.point(W, H))
                    .allowsHitTesting(false)
            }

            // dash: cooldown ring fills back in, flashes when ready, greys out when the air dash is spent
            let dc = L.c("dash")
            let dd = 46 * dc.scale
            let ready = e.dashCd <= 0 && e.abDashUsable
            Button { e.wantDash = true } label: {
                ZStack {
                    ABRoundButton(icon: "bolt.fill", d: dd, on: ready, dim: !e.abDashUsable)
                    if e.dashCd > 0 {
                        Circle().trim(from: 0, to: e.abDashFill)
                            .stroke(abCyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: dd + 6, height: dd + 6)
                    }
                    if e.dashReadyT > 0 {
                        Circle().stroke(Color.white.opacity(Double(e.dashReadyT / 0.35)), lineWidth: 3)
                            .frame(width: dd + 6 + (0.35 - e.dashReadyT) * 40, height: dd + 6 + (0.35 - e.dashReadyT) * 40)
                    }
                }
            }
            .buttonStyle(TuiPress()).position(dc.point(W, H))

            // sword jump available: small chip above the dash button while airborne
            if e.abSwordLiftReady && e.me.knife {
                HStack(spacing: 4) {
                    BladeGlyph().fill(abOrange).frame(width: 22, height: 8)
                    Text("SWORD JUMP").font(.jk(8, .heavy)).tracking(1).foregroundColor(.white)
                }
                .padding(.horizontal, 6).frame(height: 15)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .overlay(Capsule().stroke(abOrange.opacity(0.4 + 0.6 * pulse), lineWidth: 1))
                .fixedSize()
                .position(x: dc.point(W, H).x - dd / 2 - 52, y: dc.point(W, H).y)
                .allowsHitTesting(false)
            }

            let wc = L.c("weapon")
            if e.gameMode != 10 { AirbladeWeaponBox(e: e).scaleEffect(wc.scale).position(wc.point(W, H)) }
        }
        .opacity(e.gameMode == 10 && e.roam.driving >= 0 ? 0 : L.opacity)
        .allowsHitTesting(!(e.gameMode == 10 && e.roam.driving >= 0))
    }
}

// MARK: - Layout editor

/// Drag controls where you want them, pick one to resize, set opacity and look speed, and keep three layouts.
struct ControlsEditorView: View {
    let close: () -> Void

    @State private var slots = ABControls.slots
    @State private var active = ABControls.active
    @State private var sel: String? = "jump"
    @State private var dragStart: ABCtl? = nil

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.9)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.22)

    private var L: ABLayout { slots[active] }

    private func set(_ f: (inout ABLayout) -> Void) {
        var s = slots
        f(&s[active])
        slots = s
    }

    private func face(_ id: String, _ c: ABCtl) -> some View {
        Group {
            switch id {
            case "weapon":
                VStack(alignment: .leading, spacing: 2) {
                    Text("∞").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    BladeGlyph().fill(Color.white.opacity(0.85)).frame(width: 56, height: 18)
                }
                .frame(width: 150, height: 48)
                .background(Color.black.opacity(0.35))
                .overlay(alignment: .bottom) { Rectangle().fill(Color(red: 0.3, green: 0.85, blue: 0.95)).frame(height: 1.5) }
                .scaleEffect(c.scale)
            case "dash": ABRoundButton(icon: "bolt.fill", d: 46 * c.scale, on: true, tint: Color(red: 0.93, green: 0.5, blue: 0.1))
            case "crouch": ABRoundButton(icon: "figure.stand", d: 46 * c.scale)
            default: ABRoundButton(icon: "arrow.up", d: 46 * c.scale)
            }
        }
    }

    private func slider(_ title: String, _ v: Double, _ r: ClosedRange<Double>, fmt: String, show: Double = 1, _ set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.jk(10, .heavy)).tracking(1).foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(String(format: fmt, v * show)).font(.jk(10, .heavy)).foregroundColor(orange).monospacedDigit()
            }
            Slider(value: Binding(get: { v }, set: set), in: r).tint(orange)
        }
    }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            ZStack {
                // stand-in for the match view
                LinearGradient(colors: [Color(red: 0.12, green: 0.13, blue: 0.16), Color(red: 0.05, green: 0.06, blue: 0.08)], startPoint: .top, endPoint: .bottom)
                Path { p in
                    var x: CGFloat = 0
                    while x < W { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: H)); x += 40 }
                    var y: CGFloat = 0
                    while y < H { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: W, y: y)); y += 40 }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 1).frame(width: 110, height: 110).position(x: 340, y: H - 90)
                Text("MOVE").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.3)).position(x: 340, y: H - 90)

                ForEach(ABLayout.ids, id: \.self) { id in
                    let c = L.c(id)
                    face(id, c)
                        .opacity(L.opacity)
                        .overlay {
                            if sel == id {
                                RoundedRectangle(cornerRadius: id == "weapon" ? 3 : 40)
                                    .stroke(orange, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                    .padding(-6)
                            }
                        }
                        .position(c.point(W, H))
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if dragStart == nil { dragStart = c; sel = id }
                                guard let s0 = dragStart else { return }
                                set { l in
                                    var n = s0
                                    let p = CGPoint(x: s0.point(W, H).x + v.translation.width, y: s0.point(W, H).y + v.translation.height)
                                    let cx = min(W - 24, max(24, p.x)), cy = min(H - 20, max(70, p.y))
                                    n.dx = cx - n.ax * W
                                    n.dy = cy - n.ay * H
                                    l.ctl[id] = n
                                }
                            }
                            .onEnded { _ in dragStart = nil })
                }

                // settings panel (top-left; the controls live along the bottom)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CONTROLS").font(.jk(15, .heavy)).tracking(2).foregroundColor(.white)
                        Spacer()
                    }
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Button { active = i; sel = "jump" } label: {
                                Text(slots[i].name).font(.jk(10, .heavy)).foregroundColor(active == i ? .black : .white.opacity(0.75))
                                    .frame(maxWidth: .infinity).frame(height: 24)
                                    .background(RoundedRectangle(cornerRadius: 2).fill(active == i ? orange : Color.white.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                    if let id = sel {
                        slider("SIZE · \(id.uppercased())", Double(L.c(id).scale), 0.7...1.6, fmt: "%.2fx") { v in
                            set { l in var c = l.c(id); c.scale = CGFloat(v); l.ctl[id] = c }
                        }
                    }
                    slider("OPACITY", L.opacity, 0.3...1, fmt: "%.0f%%", show: 100) { v in set { $0.opacity = v } }
                    slider("LOOK SPEED", L.lookSens, 0.4...2.5, fmt: "%.2fx") { v in set { $0.lookSens = v } }
                    slider("AIM / SCOPE SPEED", L.aimSens, 0.4...2.5, fmt: "%.2fx") { v in set { $0.aimSens = v } }
                    HStack(spacing: 6) {
                        Button {
                            let n = L.name
                            set { $0 = ABLayout.standard(n) }
                        } label: {
                            Text("RESET").font(.jk(11, .heavy)).foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity).frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(edge, lineWidth: 1))
                        }.buttonStyle(.plain)
                        Button {
                            ABControls.save(slots, active: active)
                            close()
                        } label: {
                            Text("SAVE & USE").font(.jk(11, .heavy)).foregroundColor(.black)
                                .frame(maxWidth: .infinity).frame(height: 30)
                                .background(RoundedRectangle(cornerRadius: 3).fill(orange))
                        }.buttonStyle(.plain)
                    }
                    Button(action: close) {
                        Text("Cancel").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.5)).frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                }
                .padding(12)
                .frame(width: 250)
                .background(RoundedRectangle(cornerRadius: 4).fill(glass))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(edge, lineWidth: 1))
                .position(x: 18 + 125, y: H * 0.42)

                Text("Drag a control to move it · tap it to resize").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.5))
                    .position(x: W * 0.62, y: 22)
            }
            .frame(width: W, height: H)
        }
        .ignoresSafeArea()
    }
}

import SwiftUI

// MARK: - 3D weapon viewer

/// One weapon on a turntable: the AIRBLADE sword (Resources/airblade_sword.glb) or a gun (gun_<id>.glb via TwGunLib),
/// centred and scaled to fit, rotated by the player's drag, zoomed by pinch, with a short intro spin.
struct WeaponModelView: UIViewRepresentable {
    let id: String
    let orbit: ABOrbit

    final class Coord {
        var pivot = MXNode()
        var cam = MXNode()
    }

    func makeCoordinator() -> Coord { Coord() }

    private static func model(_ id: String) -> MXNode? {
        if id == "blade" {
            guard let u = Bundle.main.url(forResource: "airblade_sword", withExtension: "glb") else { return nil }
            return MXGLTF.load(u)
        }
        return TwGunLib.worldGun(id)
    }

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc

        let cam = MXNode()
        cam.camera = MXCamera()
        cam.camera?.fieldOfView = 30
        cam.camera?.zNear = 0.05
        cam.camera?.zFar = 30
        cam.position = MXVector3(0, 0.15, 3.2)
        sc.rootNode.addChildNode(cam)
        v.pointOfView = cam
        cam.look(at: MXVector3(0, 0, 0))

        let lights: [(MXLightType, CGFloat, MXVector3)] = [(.ambient, 650, MXVector3(0, 0, 0)), (.directional, 1000, MXVector3(-0.6, 0.6, 0)), (.directional, 450, MXVector3(-0.2, -2.4, 0))]
        for (type, inten, ang) in lights {
            let n = MXNode()
            n.light = MXLight()
            n.light?.type = type
            n.light?.intensity = inten
            n.eulerAngles = ang
            sc.rootNode.addChildNode(n)
        }

        let co = context.coordinator
        co.cam = cam
        let pivot = MXNode()
        sc.rootNode.addChildNode(pivot)
        co.pivot = pivot
        if let m = Self.model(id) {
            // lay it along x (a sword model stands along y), then centre and fit it to ~2 units long
            let inner = MXNode()
            inner.addChildNode(m)
            let b0 = inner.boundingBox
            if b0.max.y - b0.min.y > b0.max.x - b0.min.x { inner.eulerAngles = MXVector3(0, 0, -Float.pi / 2) }
            let outer = MXNode()
            outer.addChildNode(inner)
            let bb = outer.boundingBox            // includes inner's turn (boundingBox skips only the node's own transform)
            let len = max(0.001, max(bb.max.x - bb.min.x, max(bb.max.y - bb.min.y, bb.max.z - bb.min.z)))
            let s = 2.0 / len
            let fit = MXNode()
            fit.addChildNode(outer)
            fit.scale = MXVector3(s, s, s)
            fit.position = MXVector3(-(bb.min.x + bb.max.x) / 2 * s, -(bb.min.y + bb.max.y) / 2 * s, -(bb.min.z + bb.max.z) / 2 * s)
            pivot.addChildNode(fit)
        }
        let o = orbit
        v.preRender = { [weak co] t in
            guard let co = co else { return }
            if o.spin > 0.001 {
                let step = max(0.01, o.spin * 0.06)
                o.spin = max(0, o.spin - step)
                o.yaw += step
            } else if !o.touched {
                o.yaw += 0.004
            }
            let bob = 0.03 * sin(Float(t) * 1.2)
            co.pivot.eulerAngles = MXVector3(o.pitch, o.yaw, 0)
            co.pivot.position = MXVector3(0, bob, 0)
            let z = max(0, min(1, (o.zoom - 1) / 1.4))
            co.cam.position = MXVector3(0, 0.15 - 0.1 * z, 3.2 - 1.7 * z)
            co.cam.look(at: MXVector3(0, 0, 0))
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {}
}

/// Drag to turn, pinch to zoom, double-tap to reset — attached over a 3D view.
struct OrbitGestures: ViewModifier {
    let orbit: ABOrbit
    var pitchToo = false
    @State private var startYaw: Float? = nil
    @State private var startPitch: Float = 0
    @State private var startZoom: Float? = nil

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { v in
                    if startYaw == nil { startYaw = orbit.yaw; startPitch = orbit.pitch; orbit.spin = 0 }
                    orbit.touched = true
                    orbit.yaw = (startYaw ?? 0) + Float(v.translation.width) * 0.012
                    if pitchToo { orbit.pitch = max(-0.9, min(0.9, startPitch + Float(v.translation.height) * 0.008)) }
                }
                .onEnded { _ in startYaw = nil; orbit.touched = false })
            .simultaneousGesture(MagnificationGesture()
                .onChanged { m in
                    if startZoom == nil { startZoom = orbit.zoom }
                    orbit.zoom = max(1, min(2.4, (startZoom ?? 1) * Float(m)))
                }
                .onEnded { _ in startZoom = nil })
            .onTapGesture(count: 2) { orbit.zoom = 1; orbit.pitch = 0; orbit.yaw = 0 }
    }
}

// MARK: - Inspection screen

/// Tap the hero in the hideout: turn and zoom the 3D model, see rank, title and career numbers, and inspect
/// each equipped weapon on its own turntable.
struct HeroInspectView: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var orbit = ABOrbit()
    @State private var weapon: String? = nil
    @State private var weaponOrbit = ABOrbit()

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let blue = Color(red: 0.25, green: 0.65, blue: 1)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.84)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)

    private var W: CGFloat { size.width }
    private var H: CGFloat { size.height }
    private var u: CGFloat { min(W / 1024, H / 470) }

    /// player title from lifetime sword kills
    static let titles: [(Int, String)] = [(0, "Recruit"), (10, "Blade Initiate"), (50, "Edge Walker"), (150, "Wall Dancer"), (400, "Storm Blade"), (1000, "Airblade")]
    static func title(_ swordKills: Int) -> String { titles.last(where: { swordKills >= $0.0 })?.1 ?? "Recruit" }

    var body: some View {
        let rec = ABRecords.load()
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.4).ignoresSafeArea()
            RadialGradient(colors: [orange.opacity(0.18), .clear], center: UnitPoint(x: 0.5, y: 0.6), startRadius: 10, endRadius: 330 * u)
                .ignoresSafeArea()
            Ellipse().fill(RadialGradient(colors: [Color.black.opacity(0.65), .clear], center: .center, startRadius: 2, endRadius: W * 0.1))
                .frame(width: W * 0.2, height: H * 0.06).position(x: W * 0.5, y: H * 0.93)

            if HeroModelView.available {
                HeroModelView(orbit: orbit)
                    .frame(width: W * 0.42, height: H * 0.9)
                    .modifier(OrbitGestures(orbit: orbit))
                    .position(x: W * 0.5, y: H * 0.53)
            } else {
                Image("HeroFront").resizable().scaledToFit().frame(height: H * 0.85).position(x: W * 0.5, y: H * 0.53)
            }

            VStack(spacing: 0) {
                LobbyTopBar(t: t, u: u, selected: 0, act: act)
                HStack(spacing: 8 * u) {
                    Button { act(.nav(0)) } label: {
                        HStack(spacing: 4 * u) {
                            Image(systemName: "chevron.left").font(.system(size: 10 * u, weight: .bold))
                            Text("HIDEOUT").font(.jk(10 * u, .heavy)).tracking(1 * u)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }.buttonStyle(.plain)
                    Text("/").foregroundColor(.white.opacity(0.25)).font(.jk(10 * u, .heavy))
                    Text("CHARACTER").font(.jk(11 * u, .heavy)).tracking(2 * u).foregroundColor(orange)
                    Spacer()
                }
                .padding(.leading, 27 * u).frame(height: 30 * u)
                Spacer()
            }

            profile(rec).padding(.leading, 27 * u).padding(.top, 80 * u)

            equipped(rec)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 22 * u).padding(.top, 80 * u)

            Text("Drag to rotate  ·  pinch to zoom  ·  double-tap to reset").font(.jk(9.5 * u, .semibold)).foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 10 * u)
                .allowsHitTesting(false)

            if let w = weapon { weaponPanel(w, rec).transition(.opacity) }
        }
        .frame(width: W, height: H)
    }

    // MARK: profile card

    private func profile(_ rec: ABRecords) -> some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let games = t.wins + t.losses
        let kd = Double(t.kills) / Double(max(1, rec.deaths))
        return VStack(alignment: .leading, spacing: 8 * u) {
            HStack(spacing: 10 * u) {
                BladeEmblem().frame(width: 26 * u, height: 30 * u).padding(5 * u)
                    .background(RoundedRectangle(cornerRadius: 4 * u).fill(Color(red: 0.22, green: 0.04, blue: 0.06)))
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text(TacProfile.name.uppercased()).font(.jk(15 * u, .heavy)).italic().foregroundColor(.white).lineLimit(1)
                    Text(Self.title(rec.swordKills).uppercased()).font(.jk(8.5 * u, .heavy)).tracking(1.5 * u).foregroundColor(.black)
                        .padding(.horizontal, 6 * u).frame(height: 14 * u).background(orange)
                }
            }
            HStack(spacing: 8 * u) {
                TacInsignia(idx: ri, size: 26 * u).frame(width: 30 * u, height: 30 * u)
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text(TacRank.ranks[ri].name.uppercased()).font(.jk(11 * u, .heavy)).foregroundColor(.white)
                    Text("Lv. \(HBLevel.level(xp))  ·  \(Int(HBLevel.progress(xp) * 100))% to next").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.55))
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(blue).frame(width: 196 * u * CGFloat(HBLevel.progress(xp)))
            }
            .frame(width: 196 * u, height: 3.5 * u)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 5 * u), GridItem(.flexible(), spacing: 5 * u)], spacing: 5 * u) {
                stat("MATCHES", "\(games)")
                stat("WIN RATE", games == 0 ? "—" : "\(Int(Double(t.wins) / Double(games) * 100))%")
                stat("K / D", rec.deaths == 0 && t.kills == 0 ? "—" : String(format: "%.2f", kd))
                stat("SWORD KILLS", "\(rec.swordKills)")
                stat("BEST COMBO", "x\(rec.bestCombo)")
                stat("BEST STREAK", "\(rec.bestStreak)")
            }
        }
        .padding(10 * u)
        .frame(width: 220 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1 * u) {
            Text(k).font(.jk(7.5 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.5))
            Text(v).font(.jk(15 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7 * u).frame(height: 36 * u)
        .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
    }

    // MARK: equipped weapons

    private func gearCard(_ slot: String, _ id: String, _ rec: ABRecords) -> some View {
        let lvl = mastery(id, rec).level
        return Button {
            weaponOrbit = ABOrbit()
            weaponOrbit.spin = Float.pi * 2
            withAnimation(.easeOut(duration: 0.2)) { weapon = id }
        } label: {
            HStack(spacing: 8 * u) {
                art(id, 16 * u).frame(width: 60 * u)
                VStack(alignment: .leading, spacing: 1 * u) {
                    Text(slot).font(.jk(8 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.45))
                    Text(name(id)).font(.jk(12 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text("Mastery \(lvl)").font(.jk(8 * u, .semibold)).foregroundColor(orange)
                }
                Spacer(minLength: 0)
                HStack(spacing: 3 * u) {
                    Image(systemName: "rotate.3d").font(.system(size: 10 * u, weight: .bold))
                    Text("INSPECT").font(.jk(8.5 * u, .heavy))
                }
                .foregroundColor(orange)
            }
            .padding(.horizontal, 9 * u).frame(height: 50 * u)
            .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(edge, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func equipped(_ rec: ABRecords) -> some View {
        VStack(alignment: .leading, spacing: 6 * u) {
            Text("EQUIPPED").font(.jk(10 * u, .heavy)).tracking(2 * u).foregroundColor(.white.opacity(0.8))
            gearCard("MELEE", "blade", rec)
            gearCard("PRIMARY", nav.tacGun, rec)
            gearCard("SIDEARM", TacticalEngine.secondary, rec)
            Button { act(.screen(15)) } label: {
                HStack(spacing: 6 * u) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 10 * u, weight: .bold))
                    Text("CHANGE LOADOUT").font(.jk(11 * u, .heavy)).tracking(1 * u)
                }
                .foregroundColor(orange).frame(maxWidth: .infinity).frame(height: 30 * u)
                .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(orange, lineWidth: 1.2))
            }.buttonStyle(.plain)
        }
        .padding(10 * u)
        .frame(width: 250 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    // MARK: weapon turntable

    private func name(_ id: String) -> String { id == "blade" ? "AIRBLADE" : TWeapons.w(id).name }

    @ViewBuilder private func art(_ id: String, _ h: CGFloat) -> some View {
        if id == "blade" {
            BladeGlyph().fill(Color.white).frame(width: h * 3, height: h)
        } else {
            Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                .foregroundColor(.white.opacity(0.92)).frame(height: h)
        }
    }

    private static let bladeSteps = [0, 10, 50, 150, 400, 1000]

    /// mastery level, kills and progress to the next level (sword: sword kills; guns: TacMeta mastery, 10 xp a kill)
    private func mastery(_ id: String, _ rec: ABRecords) -> (level: Int, kills: Int, next: Int?) {
        if id == "blade" {
            let k = rec.swordKills
            let l = Self.bladeSteps.lastIndex(where: { k >= $0 }) ?? 0
            return (l, k, l + 1 < Self.bladeSteps.count ? Self.bladeSteps[l + 1] : nil)
        }
        let x = TacMeta.xp(id)
        let l = TacMeta.level(id)
        return (l, x / 10, l + 1 < TacMeta.thresholds.count ? TacMeta.thresholds[l + 1] / 10 : nil)
    }

    private func bar(_ k: String, _ v: String, _ f: Double) -> some View {
        VStack(alignment: .leading, spacing: 2 * u) {
            HStack {
                Text(k).font(.jk(9 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(v).font(.jk(10 * u, .heavy)).foregroundColor(.white).monospacedDigit()
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(orange).frame(width: 200 * u * CGFloat(max(0.03, min(1, f))))
            }
            .frame(width: 200 * u, height: 3.5 * u)
        }
    }

    private func weaponPanel(_ id: String, _ rec: ABRecords) -> some View {
        let blade = id == "blade"
        let w = TWeapons.w(blade ? "pistol" : id)
        let m = mastery(id, rec)
        return ZStack {
            Color.black.opacity(0.72).ignoresSafeArea().onTapGesture { withAnimation(.easeOut(duration: 0.2)) { weapon = nil } }
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RadialGradient(colors: [orange.opacity(0.22), .clear], center: .center, startRadius: 4, endRadius: 260 * u)
                    WeaponModelView(id: id, orbit: weaponOrbit)
                        .modifier(OrbitGestures(orbit: weaponOrbit, pitchToo: true))
                    VStack(alignment: .leading, spacing: 2 * u) {
                        Text(name(id)).font(.jk(22 * u, .heavy)).italic().foregroundColor(.white)
                        Text(blade ? "Sword" : (["rifle": "Rifle", "smg": "SMG", "pistol": "Pistol", "sniper": "Sniper", "shotgun": "Shotgun"][w.cls] ?? w.cls))
                            .font(.jk(10 * u, .semibold)).foregroundColor(.white.opacity(0.55))
                    }
                    .padding(14 * u).allowsHitTesting(false)
                    Text("Drag to turn  ·  pinch to zoom").font(.jk(9 * u, .semibold)).foregroundColor(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 10 * u)
                        .allowsHitTesting(false)
                }
                .frame(width: 520 * u, height: 330 * u)
                VStack(alignment: .leading, spacing: 9 * u) {
                    Text("STATS").font(.jk(10 * u, .heavy)).tracking(2 * u).foregroundColor(orange)
                    if blade {
                        bar("DAMAGE", "\(Int(ABRules.slashDmg))", Double(ABRules.slashDmg) / 60)
                        bar("BACKSTAB", "\(Int(ABRules.backstabDmg))", Double(ABRules.backstabDmg) / 100)
                        bar("SWING SPEED", "380 ms", 0.75)
                        bar("REACH", "Close", 0.35)
                    } else {
                        let dmg = Double(ABRules.bulletDmg(w.dmg, cls: w.cls)) * Double(w.pellets)
                        bar("DAMAGE", "\(Int(dmg))", dmg / 60)
                        bar("FIRE RATE", "\(Int(60 / max(0.01, Double(w.interval)))) rpm", (60 / max(0.01, Double(w.interval))) / 900)
                        bar("ACCURACY", "\(Int((1 - Double(w.spread) / 0.1) * 100))", 1 - Double(w.spread) / 0.1)
                        bar("RANGE", "\(Int(w.range))", Double(w.range) / 2200)
                        bar("HANDLING", String(format: "%.1fs reload", Double(w.reload)), 1 - Double(w.reload) / 3.2)
                        bar("MAGAZINE", "\(w.mag)", Double(w.mag) / 50)
                    }
                    Rectangle().fill(edge).frame(height: 1)
                    Text("MASTERY").font(.jk(10 * u, .heavy)).tracking(2 * u).foregroundColor(orange)
                    HStack(alignment: .firstTextBaseline, spacing: 6 * u) {
                        Text("Lv \(m.level)").font(.jk(20 * u, .heavy)).foregroundColor(.white)
                        Text("\(m.kills) kills").font(.jk(10 * u, .semibold)).foregroundColor(.white.opacity(0.6))
                    }
                    if let n = m.next {
                        bar("NEXT LEVEL", "\(m.kills) / \(n)", Double(m.kills) / Double(max(1, n)))
                    } else {
                        Text("Maxed").font(.jk(10 * u, .heavy)).foregroundColor(orange)
                    }
                    Spacer(minLength: 0)
                    Button { withAnimation(.easeOut(duration: 0.2)) { weapon = nil } } label: {
                        Text("CLOSE").font(.jk(12 * u, .heavy)).tracking(1.5 * u).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 32 * u)
                            .background(ChamferShape(cut: 8 * u).fill(Color(red: 0.06, green: 0.08, blue: 0.13)))
                            .overlay(ChamferShape(cut: 8 * u).stroke(orange, lineWidth: 1.2))
                    }.buttonStyle(.plain)
                }
                .padding(14 * u)
                .frame(width: 250 * u, height: 330 * u)
                .background(Color.black.opacity(0.25))
            }
            .background(RoundedRectangle(cornerRadius: 5 * u).fill(glass))
            .overlay(RoundedRectangle(cornerRadius: 5 * u).stroke(edge, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 5 * u))
        }
    }
}

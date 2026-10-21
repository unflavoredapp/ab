import SwiftUI

/// Bodycam conversion switches and shared overlay pieces.
enum TBody {
    static let on = true
    /// everything hurts more: two to three hits to go down, same for the bots
    static let dmgMul: CGFloat = 2.3
    static let hipSpread: CGFloat = 1.5
    static let fov: CGFloat = 76
    /// AIRBLADE: third-person chase camera instead of the first-person bodycam view
    static let tps = true
    static let tpsDist: CGFloat = 78
    static let tpsFov: CGFloat = 66
    static let serial = "MS-CAM 4471-0092"

    static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    static func mmss(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    static func clock(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%02d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60)
    }
}

/// animated film grain, drawn at ~12 fps so it costs next to nothing
struct BodycamGrain: View {
    var strength: Double = 0.07

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.08)) { tl in
            Canvas { ctx, sz in
                var s = UInt64(tl.date.timeIntervalSinceReferenceDate * 1000) & 0xFFFF
                func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) & 0xFFFF) / 65535 }
                let n = Int(sz.width * sz.height / 420)
                for _ in 0..<n {
                    let x = rnd() * sz.width, y = rnd() * sz.height
                    let l = rnd()
                    ctx.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color((l > 0.5 ? Color.white : Color.black).opacity(strength * Double(0.4 + rnd()))))
                }
                var y: CGFloat = 0
                while y < sz.height { ctx.fill(Path(CGRect(x: 0, y: y, width: sz.width, height: 1)), with: .color(Color.black.opacity(0.05))); y += 3 }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// REC dot, date stamp, camera serial and battery, bodycam style
struct BodycamStamp: View {
    var elapsed: Double? = nil
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let blink = Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Circle().fill(Color(red: 0.95, green: 0.12, blue: 0.1)).frame(width: compact ? 7 : 9, height: compact ? 7 : 9).opacity(blink ? 1 : 0.15)
                    Text("REC").font(.system(size: compact ? 10 : 12, weight: .heavy, design: .monospaced)).foregroundColor(.white)
                    if let e = elapsed {
                        Text(TBody.clock(e)).font(.system(size: compact ? 10 : 12, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.9))
                    }
                }
                Text(TBody.stamp(tl.date)).font(.system(size: compact ? 8 : 10, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.85))
                if !compact {
                    Text(TBody.serial).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.55))
                }
            }
            .shadow(color: .black.opacity(0.8), radius: 2)
        }
        .allowsHitTesting(false)
    }
}

/// full-screen bodycam wash for the menus: grain, scanlines, corner stamp, vignette
struct BodycamMenuLayer: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(colors: [.clear, Color.black.opacity(0.5)], center: .center, startRadius: 180, endRadius: 620).ignoresSafeArea().allowsHitTesting(false)
            BodycamGrain(strength: 0.05)
        }
        .allowsHitTesting(false)
    }
}

/// in-match readout: stamp top-left under the settings button, tiny vitals and ammo, nothing else
struct BodycamHud: View {
    let e: TacticalEngine

    private let blue = Color(red: 0.12, green: 0.72, blue: 0.96)
    private let panel = Color.black.opacity(0.48)

    var body: some View {
        let me = e.me
        let hp = Int(max(0, me.hp)), ar = Int(max(0, me.armor))
        return ZStack(alignment: .topLeading) {
            // AIRBLADE's match HUD: compact, translucent and landscape-first.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("AIRBLADE").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.4)
                        .foregroundColor(.white.opacity(0.95))
                    Rectangle().fill(blue).frame(width: 2, height: 13)
                    Text(me.handle.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.82)).lineLimit(1)
                }
                HStack(spacing: 5) {
                    Text("HP").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundColor(.white.opacity(0.75)).frame(width: 20, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.14))
                            Rectangle().fill(hp < 35 ? Color.red : Color(red: 0.82, green: 0.86, blue: 0.9)).frame(width: g.size.width * CGFloat(hp) / 100)
                        }
                    }.frame(width: 158, height: 7)
                    Text("\(hp)").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundColor(.white).frame(width: 27, alignment: .trailing)
                }
                HStack(spacing: 5) {
                    Text("AR").font(.system(size: 9, weight: .heavy, design: .monospaced)).foregroundColor(.white.opacity(0.75)).frame(width: 20, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.14))
                            Rectangle().fill(blue).frame(width: g.size.width * CGFloat(ar) / 100)
                        }
                    }.frame(width: 158, height: 7)
                    Text("\(ar)").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundColor(.white).frame(width: 27, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(panel, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .leading) { Rectangle().fill(blue).frame(width: 2) }
            .padding(.leading, 14).padding(.top, 10)

            // Recent eliminations, aligned to the upper-right like the GunZ match HUD.
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(Array(e.feed.suffix(4).reversed().enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 5) {
                        Text(item.k.isEmpty ? item.text : item.k)
                            .foregroundColor(item.kTeam == me.team ? blue : .white)
                            .lineLimit(1)
                        Image(systemName: item.gun == "knife" ? "bolt.fill" : (item.head ? "scope" : "arrow.right"))
                            .foregroundColor(item.head ? Color(red: 1, green: 0.72, blue: 0.24) : .white.opacity(0.7))
                        Text(item.v.isEmpty ? "ELIMINATED" : item.v)
                            .foregroundColor(item.v == me.name || item.v == me.handle ? Color(red: 1, green: 0.42, blue: 0.36) : .white.opacity(0.86))
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(alignment: .trailing) { Rectangle().fill(item.kTeam == me.team ? blue : Color.white.opacity(0.3)).frame(width: 2) }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 14).padding(.trailing, 14)
            .animation(.easeOut(duration: 0.18), value: e.feed.count)
            .allowsHitTesting(false)

            if TBody.tps && me.alive {
                Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5).frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.7), radius: 1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Translucent AIRBLADE scoreboard opened from the top-center match strip.
struct AirbladeScoreboard: View {
    let e: TacticalEngine
    let close: () -> Void

    private let blue = Color(red: 0.12, green: 0.72, blue: 0.96)

    var body: some View {
        let players = e.players.sorted {
            if $0.kills != $1.kills { return $0.kills > $1.kills }
            if $0.alive != $1.alive { return $0.alive }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AIRBLADE").font(.system(size: 10, weight: .black, design: .rounded)).tracking(2).foregroundColor(blue)
                        Text("MATCH SCOREBOARD").font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TBody.mmss(Double(max(0, e.timer)))).font(.system(size: 19, weight: .heavy, design: .monospaced)).foregroundColor(.white).monospacedDigit()
                        Text("\(e.players.filter { $0.alive }.count) ALIVE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.55))
                    }
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .black)).foregroundColor(.white)
                            .frame(width: 28, height: 28).background(Color.white.opacity(0.12), in: Circle())
                    }.buttonStyle(.plain).padding(.leading, 8)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.white.opacity(0.045))

                HStack(spacing: 8) {
                    Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                    Text("TEAM").frame(width: 52, alignment: .center)
                    Text("KILLS").frame(width: 48, alignment: .trailing)
                    Text("STATUS").frame(width: 62, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .black, design: .monospaced)).tracking(0.8).foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 16).padding(.vertical, 8)

                ForEach(Array(players.enumerated()), id: \.element.id) { index, p in
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", index + 1)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.35)).frame(width: 22, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.handle.isEmpty ? p.name : p.handle).font(.system(size: 12, weight: p.isPlayer ? .black : .semibold)).foregroundColor(p.id == e.me.id ? blue : .white).lineLimit(1)
                            if p.id == e.me.id { Text("YOU").font(.system(size: 8, weight: .black)).tracking(1).foregroundColor(blue) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(p.team == e.me.team ? "ALLY" : "FOE").font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(p.team == e.me.team ? blue : Color(red: 1, green: 0.48, blue: 0.35)).frame(width: 52)
                        Text("\(p.kills)").font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundColor(.white).frame(width: 48, alignment: .trailing)
                        Text(p.alive ? "ACTIVE" : "DOWN").font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(p.alive ? Color(red: 0.35, green: 0.9, blue: 0.66) : .white.opacity(0.4)).frame(width: 62, alignment: .trailing)
                    }
                    .padding(.horizontal, 16).frame(height: 38)
                    .background(p.id == e.me.id ? blue.opacity(0.13) : (index.isMultiple(of: 2) ? Color.white.opacity(0.035) : Color.clear))
                    .overlay(alignment: .leading) { if p.id == e.me.id { Rectangle().fill(blue).frame(width: 2) } }
                }
                HStack {
                    Text("AIRBLADE  /  LIVE MATCH").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1).foregroundColor(.white.opacity(0.38))
                    Spacer()
                    Text("TAP OUTSIDE OR CLOSE TO RESUME").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.38))
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
            .frame(maxWidth: 540)
            .background(Color(red: 0.035, green: 0.05, blue: 0.07).opacity(0.96), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(blue.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
    }
}


/// ammo line, bottom centre; tap swaps to the other weapon
struct BodycamAmmo: View {
    let e: TacticalEngine

    var body: some View {
        let me = e.me
        let g = TGuns.get(me.gun)
        let pistol = TWeapons.isPistol(me.gun)
        return Button { e.wantSwap = true } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07))
                    Image(systemName: me.knife ? "bolt.fill" : (pistol ? "scope" : "target"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.82, blue: 1))
                }.frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text((me.knife ? "BLADE" : g.name).uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.8)
                        .foregroundColor(.white.opacity(0.82)).lineLimit(1)
                    if me.reloadT > 0 {
                        Text("RELOADING…").font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(red: 1, green: 0.7, blue: 0.2))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(me.knife ? "∞" : "\(me.mag)")
                                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                .foregroundColor(!me.knife && me.mag == 0 ? Color.red : .white)
                            if !me.knife {
                                Text(pistol ? "ROUNDS" : "/ \(me.spare * g.mag)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10, weight: .heavy)).foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .frame(minWidth: 154, alignment: .leading)
            .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .bottom) { Rectangle().fill(Color(red: 0.12, green: 0.72, blue: 0.96)).frame(height: 2).padding(.horizontal, 5) }
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// shown while down: camera feed lost, auto redeploy, tap for loadout
struct BodycamDown: View {
    let e: TacticalEngine
    let loadout: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 6) {
                Text("DOWN").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundColor(Color(red: 0.95, green: 0.2, blue: 0.15))
                if e.me.respawn > 0 && e.me.respawn < 100 {
                    Text("REDEPLOY \(Int(ceil(e.me.respawn)))").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                }
                Button(action: loadout) {
                    Text("LOADOUT").font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7).overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
        }
    }
}

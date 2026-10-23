import SwiftUI

/// Match rules and camera numbers shared by the engine and the 3D scene.
enum ABRules {
    /// no global damage boost: slashes and bullets are tuned below so a full-health, armoured fighter
    /// takes about 3-5 hits to go down
    static let dmgMul: CGFloat = 1
    /// sword slash, quick knife slash and a hit from behind
    static let slashDmg: CGFloat = 38
    static let knifeDmg: CGFloat = 30
    static let backstabDmg: CGFloat = 70
    /// bullets: rifles, SMGs and pistols hit harder than their base number, shotgun pellets less,
    /// and no single bullet does more than 60 (so even the sniper needs a few hits)
    static func bulletDmg(_ base: CGFloat, cls: String) -> CGFloat {
        let mul: CGFloat = cls == "shotgun" ? 0.6 : (cls == "sniper" ? 1 : 2)
        return min(60, base * mul)
    }
    static let hipSpread: CGFloat = 1.5
    /// third-person chase camera: distance behind the player and field of view
    static let camDist: CGFloat = 150
    static let camFov: CGFloat = 66
    /// real 3D gun models only (no pixel-art swaps) and no first-person radar
    static let realGunModels = true
    static let radarOff = true

    static func mmss(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}

/// shared colours of the match HUD
enum ABHud {
    static let blue = Color(red: 0.17, green: 0.45, blue: 0.88)
    static let allyText = Color(red: 0.45, green: 0.72, blue: 1)
    static let foeText = Color(red: 1, green: 0.38, blue: 0.34)
    static let red = Color(red: 0.78, green: 0.14, blue: 0.14)
    static let ink = Color.black.opacity(0.5)
}

/// Match HUD: level badge with HP / AP bars top-left, timer and kill count top-centre, kill feed
/// top-right. Tapping the timer opens the scoreboard.
struct AirbladeHud: View {
    let e: TacticalEngine
    let openBoard: () -> Void
    @EnvironmentObject var game: Game

    private var xp: Int { TacRank.totalXP(game.s.ex.tac ?? TacData()) }
    private var level: Int { HBLevel.level(xp) }

    private func score(_ i: Int) -> Int { e.scores.indices.contains(i) ? e.scores[i] : 0 }

    private func shadowed(_ t: Text) -> some View { t.shadow(color: .black.opacity(0.85), radius: 2, y: 1) }

    // MARK: vitals

    private func vitals(hp: Int, armor: Int) -> some View {
        let hpFrac = CGFloat(min(100, max(0, hp))) / 100
        let bw: CGFloat = 165
        return HStack(alignment: .center, spacing: 6) {
            ZStack {
                Circle().fill(Color.black.opacity(0.45))
                Circle().trim(from: 0, to: CGFloat(max(0.08, HBLevel.progress(xp))))
                    .stroke(Color(red: 0.35, green: 0.85, blue: 0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("Lv").font(.system(size: 6.5, weight: .bold)).foregroundColor(.white.opacity(0.75))
                    Text("\(level)").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                }
            }
            .frame(width: 28, height: 28)
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.35))
                    Rectangle().fill(hp < 35 ? Color(red: 1, green: 0.4, blue: 0.35) : Color.white.opacity(0.9)).frame(width: bw * hpFrac)
                }
                .frame(width: bw, height: 9)
                .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 0.5))
                .overlay(alignment: .trailing) {
                    Text("\(hp)").font(.system(size: 9, weight: .bold)).foregroundColor(.white).shadow(color: .black, radius: 1).offset(y: -9).padding(.trailing, 2)
                }
                HStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { i in
                        let seg = min(1, max(0, CGFloat(armor) / 100 * 3 - CGFloat(i)))
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.black.opacity(0.35))
                            Rectangle().fill(Color(red: 0.2, green: 0.47, blue: 0.85)).frame(width: (bw - 3) / 3 * seg)
                        }
                        .frame(width: (bw - 3) / 3, height: 7)
                    }
                }
                .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .overlay(alignment: .trailing) {
                    Text("\(armor)").font(.system(size: 8.5, weight: .bold)).foregroundColor(.white).shadow(color: .black, radius: 1).offset(y: -8).padding(.trailing, 2)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: match strip

    private func box(_ n: Int, _ fill: Color) -> some View {
        Text("\(n)").font(.system(size: 12, weight: .bold)).monospacedDigit().foregroundColor(.white)
            .frame(minWidth: 34).frame(height: 18)
            .background(fill.opacity(0.9))
    }

    private func strip(_ me: TPlayer) -> some View {
        let mode = e.gameMode
        let versus = [1, 2, 5, 8].contains(mode)
        let objective = [1, 2, 4, 5, 8].contains(mode)
        return Button(action: openBoard) {
            VStack(spacing: 2) {
                shadowed(Text(ABRules.mmss(Double(max(0, e.timer)))).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundColor(.white))
                HStack(spacing: 0) {
                    if versus { box(score(me.team), ABHud.blue) }
                    Text(objective ? "KILL \(e.killTarget)" : "KILLS").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundColor(.white.opacity(0.75))
                        .frame(minWidth: 52).frame(height: 18)
                    box(versus ? score(1 - me.team) : me.kills, versus ? ABHud.red : ABHud.blue)
                }
                .background(Color.white.opacity(0.12))
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
        }
        .buttonStyle(.plain)
    }

    // MARK: kill feed

    private func feed(_ me: TPlayer) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(Array(e.feed.suffix(4).reversed().enumerated()), id: \.offset) { _, item in
                let ally = item.kTeam == me.team
                HStack(spacing: 5) {
                    Text(item.k.isEmpty ? item.text : item.k).foregroundColor(ally ? ABHud.allyText : ABHud.foeText).lineLimit(1)
                    Image(systemName: item.head ? "scope" : "chevron.right").font(.system(size: 8, weight: .bold))
                        .foregroundColor(item.head ? Color(red: 1, green: 0.72, blue: 0.24) : .white.opacity(0.6))
                    Text(item.v.isEmpty ? "ELIMINATED" : item.v).foregroundColor(ally ? ABHud.foeText : ABHud.allyText).lineLimit(1)
                }
                .font(.jk(9, .semibold))
                .padding(.horizontal, 5).frame(height: 14)
                .background(Color.black.opacity(0.35))
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: e.feed.count)
    }

    var body: some View {
        let me = e.me
        let hp = Int(max(0, me.hp)), armor = Int(max(0, me.armor))
        return ZStack {
            vitals(hp: hp, armor: armor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 18).padding(.top, 10)
            if e.gameMode != 10 {
                strip(me)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
            }
            if e.gameMode == 10 && e.phase != 4 { RoamHUD(e: e) }
            if e.gameMode == 9 && e.phase != 4 {
                AirbladeLabHUD(e: e)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 18).padding(.top, 62)
                    .allowsHitTesting(false)
            }
            if e.gameMode != 10 {
            feed(me)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 10).padding(.trailing, 64)
                    .allowsHitTesting(false)
            }
            if me.alive {
                Circle().stroke(Color.white.opacity(0.75), lineWidth: 1).frame(width: 9, height: 9)
                    .shadow(color: .black.opacity(0.7), radius: 1.5)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Tab-style scoreboard: level, name, damage, kills and deaths for everyone in the match.
struct AirbladeScoreboard: View {
    let e: TacticalEngine
    let close: () -> Void
    @EnvironmentObject var game: Game

    private var myLevel: Int { HBLevel.level(TacRank.totalXP(game.s.ex.tac ?? TacData())) }

    private func level(_ p: TPlayer) -> Int { p.isPlayer ? 0 : max(1, min(60, p.trophies / 120)) }

    private func cell(_ s: String, _ w: CGFloat, _ align: Alignment = .trailing, _ col: Color = .white) -> some View {
        Text(s).font(.jk(12, .semibold)).foregroundColor(col).lineLimit(1).frame(width: w, alignment: align)
    }

    var body: some View {
        let me = e.me
        let players = e.players.sorted {
            if $0.kills != $1.kills { return $0.kills > $1.kills }
            if $0.deaths != $1.deaths { return $0.deaths < $1.deaths }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let mode = TWeapons.modeNames.indices.contains(e.gameMode) ? TWeapons.modeNames[e.gameMode].capitalized : "Match"
        return ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        ZStack {
                            Rectangle().fill(Color.black.opacity(0.5))
                            Image(systemName: "bolt.horizontal.fill").font(.system(size: 20, weight: .bold)).foregroundColor(.white.opacity(0.85))
                        }.frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("[\(mode)]").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.65))
                            Text(TacLobbyMaps.title(TMap.kind)).font(.jk(20, .heavy)).foregroundColor(.white)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(mode).font(.jk(15, .heavy)).foregroundColor(.white)
                        Text("Objective kills: \(e.killTarget)").font(.jk(11, .semibold)).foregroundColor(Color(red: 1, green: 0.8, blue: 0.25))
                    }
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .black)).foregroundColor(.white)
                            .frame(width: 26, height: 26).background(Color.white.opacity(0.12))
                    }.buttonStyle(.plain).padding(.leading, 10)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)

                HStack(spacing: 6) {
                    cell("Lv", 26, .leading, .white.opacity(0.55))
                    cell("Name", 140, .leading, .white.opacity(0.55))
                    Spacer(minLength: 0)
                    cell("Damage to enemy", 112, .trailing, .white.opacity(0.55))
                    cell("Kills", 44, .trailing, .white.opacity(0.55))
                    cell("Deaths", 50, .trailing, .white.opacity(0.55))
                }
                .padding(.horizontal, 14).frame(height: 24)
                .background(Color.white.opacity(0.06))

                ForEach(Array(players.enumerated()), id: \.element.id) { index, p in
                    let mine = p.id == me.id
                    let tint: Color = mine ? Color(red: 0.3, green: 0.9, blue: 1) : (p.team == me.team ? ABHud.allyText : .white)
                    HStack(spacing: 6) {
                        cell(p.isPlayer ? "\(myLevel)" : "\(level(p))", 26, .leading, tint)
                        cell(p.name, 140, .leading, tint)
                        Spacer(minLength: 0)
                        cell("\(Int(p.dmgDealt))", 112, .trailing, tint)
                        cell("\(p.kills)", 44, .trailing, tint)
                        cell("\(p.deaths)", 50, .trailing, tint)
                    }
                    .padding(.horizontal, 14).frame(height: 24)
                    .opacity(p.alive ? 1 : 0.55)
                    .background(mine ? Color.white.opacity(0.08) : (index.isMultiple(of: 2) ? Color.white.opacity(0.025) : Color.clear))
                }
                Spacer(minLength: 6)
            }
            .frame(maxWidth: 600)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color(red: 0.04, green: 0.045, blue: 0.05).opacity(0.86))
            .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }
}

/// a small sword glyph for the weapon box
struct BladeGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY - r.height * 0.18))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.06, y: r.minY + r.height * 0.1))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.2, y: r.minY + r.height * 0.18))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.06))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY - r.height * 0.42))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.34, y: r.maxY - r.height * 0.16))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY - r.height * 0.1))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.04, y: r.maxY - r.height * 0.36))
        p.closeSubpath()
        return p
    }
}

/// weapon box: ammo (or the infinity mark for the blade), weapon art and name; tap swaps weapon
struct AirbladeWeaponBox: View {
    let e: TacticalEngine

    var body: some View {
        let me = e.me
        let g = TGuns.get(me.gun)
        return Button { e.wantSwap = true } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top) {
                    if me.reloadT > 0 {
                        Text("RELOAD").font(.system(size: 10, weight: .heavy)).foregroundColor(Color(red: 1, green: 0.7, blue: 0.2))
                    } else if me.knife {
                        Text("∞").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(me.mag)").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                                .foregroundColor(me.mag == 0 ? Color(red: 1, green: 0.35, blue: 0.3) : .white)
                            Text("/ \(me.spare * g.mag)").font(.system(size: 8.5, weight: .medium)).foregroundColor(.white.opacity(0.55))
                        }
                    }
                    Spacer(minLength: 4)
                    if me.knife {
                        BladeGlyph().fill(Color.white.opacity(0.85)).frame(width: 56, height: 18)
                    } else {
                        Image(uiImage: GunSprites.icon(TWeapons.rig(me.gun))).resizable().scaledToFit().frame(width: 62, height: 20)
                    }
                }
                Spacer(minLength: 0)
                Text(me.knife ? "Airblade" : g.name).font(.jk(9.5, .semibold)).foregroundColor(.white.opacity(0.92)).lineLimit(1)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(width: 150, height: 48)
            .background(Color.black.opacity(0.45))
            .overlay(Rectangle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .overlay(alignment: .bottom) { Rectangle().fill(Color(red: 0.3, green: 0.85, blue: 0.95).opacity(0.85)).frame(height: 1.5) }
        }
        .buttonStyle(.plain)
    }
}

/// shown while down: auto redeploy
struct AirbladeDown: View {
    let e: TacticalEngine
    let loadout: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 6) {
                Text("ELIMINATED").font(.jk(24, .heavy)).foregroundColor(Color(red: 1, green: 0.3, blue: 0.26))
                if e.me.respawn > 0 && e.me.respawn < 100 {
                    Text("REDEPLOY IN \(Int(ceil(e.me.respawn)))").font(.jk(13, .semibold)).foregroundColor(.white.opacity(0.85))
                }
            }
        }
    }
}

/// Combat feedback layered over the view: hit marker, sword combo counter and the elimination callout.
/// Kept small and brief so the fight stays readable.
struct AirbladeCombatFX: View {
    let e: TacticalEngine
    let W: CGFloat
    let H: CGFloat

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)

    private var marker: some View {
        let k = e.hitKind
        let col: Color = k == 2 ? Color(red: 1, green: 0.2, blue: 0.15) : (k == 1 ? orange : .white)
        let gap: CGFloat = k == 2 ? 8 : 6, len: CGFloat = k == 2 ? 10 : 7
        let life = Double(e.hitMarkT / (k == 2 ? 0.35 : 0.22))
        return Path { p in
            for (sx, sy) in [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)] as [(CGFloat, CGFloat)] {
                p.move(to: CGPoint(x: sx * gap, y: sy * gap))
                p.addLine(to: CGPoint(x: sx * (gap + len), y: sy * (gap + len)))
            }
        }
        .offsetBy(dx: 20, dy: 20)
        .stroke(col, style: StrokeStyle(lineWidth: k == 2 ? 2.6 : 2, lineCap: .round))
        .frame(width: 40, height: 40)
        .shadow(color: .black.opacity(0.8), radius: 1.5)
        .opacity(min(1, life * 1.6))
    }

    private var combo: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("x").font(.jk(16, .heavy)).italic()
                Text("\(e.comboN)").font(.jk(34, .heavy)).italic()
            }
            .foregroundColor(.white)
            .shadow(color: orange.opacity(0.9), radius: 6)
            HStack(spacing: 5) {
                BladeGlyph().fill(orange).frame(width: 28, height: 9)
                Text("COMBO").font(.jk(10, .heavy)).tracking(2).foregroundColor(orange)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(orange).frame(width: 70 * max(0, min(1, e.comboT / 1.6)))
            }
            .frame(width: 70, height: 2.5).padding(.top, 3)
        }
        .shadow(color: .black.opacity(0.7), radius: 2)
    }

    private var calloutView: some View {
        let t = e.calloutT
        let fade = Double(min(1, t / 0.4))
        let pop: CGFloat = t > 2.05 ? 1 + (t - 2.05) * 2 : 1
        return VStack(spacing: 3) {
            HStack(spacing: 10) {
                slashes(flip: false)
                Text(e.callout).font(.jk(26, .heavy)).italic().tracking(2).foregroundColor(.white)
                    .shadow(color: orange.opacity(0.85), radius: 8)
                slashes(flip: true)
            }
            Text(e.calloutSub).font(.jk(11, .semibold)).tracking(1).foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 3)
                .background(LinearGradient(colors: [.clear, Color.black.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing))
        }
        .shadow(color: .black.opacity(0.7), radius: 2)
        .scaleEffect(pop)
        .opacity(fade)
    }

    private func slashes(flip: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Rectangle().fill(orange.opacity(flip ? 1 - Double(i) * 0.3 : 0.4 + Double(i) * 0.3))
                    .frame(width: 4, height: 18).rotationEffect(.degrees(22))
            }
        }
    }

    var body: some View {
        // own 60 fps timeline: the HUD around it refreshes at 10 fps, too slow for a 0.2 s hit marker
        TimelineView(.animation) { _ in layer }
            .frame(width: W, height: H)
            .allowsHitTesting(false)
    }

    private var layer: some View {
        ZStack {
            if e.hitMarkT > 0 { marker.position(x: W / 2, y: H / 2) }
            if e.comboN >= 2 && e.me.alive { combo.position(x: W / 2 + 130, y: H * 0.5) }
            if e.calloutT > 0 && !e.callout.isEmpty { calloutView.id(e.calloutSerial).position(x: W / 2, y: H * 0.25) }
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }
}

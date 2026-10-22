import SwiftUI

/// Match rules and camera numbers shared by the engine and the 3D scene.
enum ABRules {
    /// everything hurts more: two to three hits to go down, same for the bots
    static let dmgMul: CGFloat = 2.3
    static let hipSpread: CGFloat = 1.5
    /// third-person chase camera: distance behind the player and field of view
    static let camDist: CGFloat = 78
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
    private var level: Int { TacRank.index(xp) + 1 }

    private func score(_ i: Int) -> Int { e.scores.indices.contains(i) ? e.scores[i] : 0 }

    private func shadowed(_ t: Text) -> some View { t.shadow(color: .black.opacity(0.85), radius: 2, y: 1) }

    // MARK: vitals

    private func vitals(hp: Int, armor: Int) -> some View {
        let hpFrac = CGFloat(min(100, max(0, hp))) / 100
        return HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(Color.black.opacity(0.6))
                Circle().trim(from: 0, to: CGFloat(max(0.08, TacRank.progress(xp))))
                    .stroke(Color(red: 0.35, green: 0.85, blue: 0.75), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -1) {
                    Text("lv").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.7))
                    Text("\(level)").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                }
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(ABHud.ink)
                    Rectangle().fill(hp < 35 ? Color(red: 1, green: 0.35, blue: 0.3) : Color.white.opacity(0.92)).frame(width: 210 * hpFrac)
                }
                .frame(width: 210, height: 16)
                .overlay(alignment: .trailing) {
                    Text("\(hp)").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundColor(hp < 35 ? .white : .black).padding(.trailing, 6)
                }
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        let seg = min(1, max(0, CGFloat(armor) / 100 * 3 - CGFloat(i)))
                        ZStack(alignment: .leading) {
                            Rectangle().fill(ABHud.ink)
                            Rectangle().fill(Color(red: 0.22, green: 0.52, blue: 1)).frame(width: 68 * seg)
                        }
                        .frame(width: 68, height: 11)
                    }
                }
                .overlay(alignment: .trailing) {
                    Text("\(armor)").font(.system(size: 10, weight: .heavy, design: .monospaced)).foregroundColor(.white).shadow(color: .black, radius: 1).padding(.trailing, 6)
                }
            }
        }
    }

    // MARK: match strip

    private func box(_ n: Int, _ fill: Color) -> some View {
        Text("\(n)").font(.system(size: 15, weight: .heavy, design: .monospaced)).monospacedDigit().foregroundColor(.white)
            .frame(minWidth: 38).frame(height: 20)
            .background(fill)
    }

    private func strip(_ me: TPlayer) -> some View {
        let mode = e.gameMode
        let versus = [1, 2, 5, 8].contains(mode)
        let objective = [1, 2, 4, 5, 8].contains(mode)
        return Button(action: openBoard) {
            VStack(spacing: 3) {
                shadowed(Text(ABRules.mmss(Double(max(0, e.timer)))).font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundColor(.white))
                HStack(spacing: 0) {
                    box(objective ? score(me.team) : me.kills, ABHud.blue)
                    Text(objective ? "KILL \(e.killTarget)" : "KILLS").font(.system(size: 10, weight: .heavy)).foregroundColor(.white.opacity(0.9))
                        .frame(minWidth: 62).frame(height: 20).background(ABHud.ink)
                    if versus { box(score(1 - me.team), ABHud.red) }
                }
            }
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
                .font(.jk(12, .heavy))
                .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
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
                .padding(.leading, 14).padding(.top, 10)
            strip(me)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
            feed(me)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 62).padding(.trailing, 14)
                .allowsHitTesting(false)
            if me.alive {
                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5).frame(width: 11, height: 11)
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

    private var myLevel: Int { TacRank.index(TacRank.totalXP(game.s.ex.tac ?? TacData())) + 1 }

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
        let pistol = TWeapons.isPistol(me.gun)
        return Button { e.wantSwap = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    if me.reloadT > 0 {
                        Text("RELOAD").font(.system(size: 11, weight: .heavy, design: .monospaced)).foregroundColor(Color(red: 1, green: 0.7, blue: 0.2))
                    } else {
                        Text(me.knife ? "∞" : "\(me.mag)")
                            .font(.system(size: me.knife ? 26 : 22, weight: .heavy, design: .monospaced))
                            .foregroundColor(!me.knife && me.mag == 0 ? Color.red : .white)
                        if !me.knife {
                            Text(pistol ? "ROUNDS" : "/ \(me.spare * g.mag)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
                .frame(width: 64, alignment: .leading)
                VStack(spacing: 2) {
                    if me.knife {
                        BladeGlyph().fill(Color.white.opacity(0.9)).frame(width: 52, height: 24)
                    } else {
                        Image(uiImage: GunSprites.icon(TWeapons.rig(me.gun))).resizable().scaledToFit()
                            .frame(width: 70, height: 26)
                    }
                    Text((me.knife ? "AIRBLADE" : g.name).uppercased())
                        .font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
                }
                .frame(width: 80)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(width: 176, height: 56)
            .background(Color.black.opacity(0.6))
            .overlay(Rectangle().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// shown while down: auto redeploy, tap for loadout
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
                Button(action: loadout) {
                    Text("LOADOUT").font(.jk(13, .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 7).overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
        }
    }
}

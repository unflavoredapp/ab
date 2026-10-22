import SwiftUI

// MARK: - Match result bookkeeping

/// What one match paid out, worked out when the results screen opens.
struct ABResult {
    var xpBefore: Int
    var xpAfter: Int
    var xpBase: Int
    var xpBonus: Int
    var gems: Int
    var ratingDelta: Int
    /// stats that beat the saved personal best this match: "kills", "combo", "streak"
    var records: Set<String>

    var rankBefore: Int { TacRank.index(xpBefore) }
    var rankAfter: Int { TacRank.index(xpAfter) }
    var rankedUp: Bool { rankAfter > rankBefore }
}

/// AIRBLADE's career records, kept beside TacData (separate key so old saves stay readable).
struct ABRecords: Codable {
    var deaths = 0
    var swordKills = 0
    var airKills = 0
    var backstabs = 0
    var bestKills = 0
    var bestCombo = 0
    var bestStreak = 0
    var matches = 0
    var wins = 0
    var flawlessWins = 0        // won without dying
    var headKills = 0
    var bestMulti = 0
    var labRuns = 0
    var labBestScore = 0
    var labBestCombo = 0
    var labBestAcc = 0          // percent
    var claimed: [String] = []  // challenge ids already paid out

    init() {}

    // every field is optional on disk so records saved by earlier builds still load
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: Keys.self)
        func i(_ k: Keys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        deaths = i(.deaths); swordKills = i(.swordKills); airKills = i(.airKills); backstabs = i(.backstabs)
        bestKills = i(.bestKills); bestCombo = i(.bestCombo); bestStreak = i(.bestStreak); matches = i(.matches)
        wins = i(.wins); flawlessWins = i(.flawlessWins); headKills = i(.headKills); bestMulti = i(.bestMulti)
        labRuns = i(.labRuns); labBestScore = i(.labBestScore); labBestCombo = i(.labBestCombo); labBestAcc = i(.labBestAcc)
        claimed = (try? c.decodeIfPresent([String].self, forKey: .claimed)) ?? []
    }

    enum Keys: String, CodingKey {
        case deaths, swordKills, airKills, backstabs, bestKills, bestCombo, bestStreak, matches
        case wins, flawlessWins, headKills, bestMulti, labRuns, labBestScore, labBestCombo, labBestAcc, claimed
    }

    private static let key = "ab.records"

    static func load() -> ABRecords {
        guard let d = UserDefaults.standard.data(forKey: key), let r = try? JSONDecoder().decode(ABRecords.self, from: d) else { return ABRecords() }
        return r
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: ABRecords.key) }
    }
}

extension Game {
    /// Pays out a finished AIRBLADE match: wins / rating / gems / recent matches through tacticalFinish, then
    /// bonus XP for sword play and the personal records. Returns the before/after numbers for the results screen.
    func airbladeFinish(_ e: TacticalEngine, gems: Int) -> ABResult {
        let before = TacRank.totalXP(s.ex.tac ?? TacData())
        tacticalFinish(won: e.won, kills: e.kills, gems: gems, map: e.mapPick, mode: e.gameMode)

        let base = (40 + e.kills * 10 + (e.won ? 60 : 0)) * TacRank.mult(s.ex.tac?.prestige ?? 0)
        let bonusRaw = e.swordKills * 5 + e.backstabs * 5 + e.airKills * 5 + (e.bestCombo >= 3 ? 15 : 0) + (e.bestStreak >= 5 ? 20 : 0)
        let bonus = bonusRaw * TacRank.mult(s.ex.tac?.prestige ?? 0)
        if bonus > 0 {
            var st = s
            var d = st.ex.tac ?? TacData()
            d.xpExtra = (d.xpExtra ?? 0) + bonus
            var x = d.sx ?? TacSeasonData()
            x.xp += bonusRaw
            d.sx = x
            st.ex.tac = d
            s = st
        }
        let after = TacRank.totalXP(s.ex.tac ?? TacData())

        var rec = ABRecords.load()
        var broke = Set<String>()
        if rec.matches > 0 {
            if e.kills > rec.bestKills { broke.insert("kills") }
            if e.bestCombo > rec.bestCombo && e.bestCombo >= 2 { broke.insert("combo") }
            if e.bestStreak > rec.bestStreak && e.bestStreak >= 2 { broke.insert("streak") }
        }
        rec.matches += 1
        rec.deaths += e.me.deaths
        rec.swordKills += e.swordKills
        rec.airKills += e.airKills
        rec.backstabs += e.backstabs
        rec.headKills += e.headKills
        rec.bestMulti = max(rec.bestMulti, e.bestMulti)
        if e.won { rec.wins += 1; if e.me.deaths == 0 { rec.flawlessWins += 1 } }
        rec.bestKills = max(rec.bestKills, e.kills)
        rec.bestCombo = max(rec.bestCombo, e.bestCombo)
        rec.bestStreak = max(rec.bestStreak, e.bestStreak)
        rec.save()

        return ABResult(xpBefore: before, xpAfter: max(before, after), xpBase: base, xpBonus: bonus, gems: gems,
                        ratingDelta: e.won ? 10 : -5, records: broke)
    }
}

// MARK: - Results screen

/// Victory / defeat screen: MVP showcase, your match stats, standings, XP and rank progress, rematch.
struct AirbladeResults: View {
    let e: TacticalEngine
    let r: ABResult
    let hideout: () -> Void
    let rematch: () -> Void

    @State private var shown = false
    @State private var filled = false

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.82)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)
    private let blue = Color(red: 0.25, green: 0.65, blue: 1)
    private let red = Color(red: 0.95, green: 0.25, blue: 0.22)

    private var ranked: [TPlayer] {
        e.players.sorted {
            if $0.kills != $1.kills { return $0.kills > $1.kills }
            if $0.deaths != $1.deaths { return $0.deaths < $1.deaths }
            return $0.dmgDealt > $1.dmgDealt
        }
    }

    private func nm(_ p: TPlayer) -> String { p.isPlayer ? TacProfile.name : (p.handle.isEmpty ? p.name : p.handle) }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let u = min(W / 1024, H / 470)
            ZStack {
                backdrop
                VStack(spacing: 0) {
                    header(u).padding(.top, 14 * u)
                    HStack(alignment: .top, spacing: 14 * u) {
                        mvp(u, H).frame(width: 230 * u)
                        VStack(spacing: 10 * u) {
                            statGrid(u)
                            xpPanel(u)
                        }
                        .frame(width: 360 * u)
                        standings(u).frame(width: 290 * u)
                    }
                    .padding(.top, 10 * u)
                    Spacer(minLength: 0)
                    buttons(u).padding(.bottom, 14 * u)
                }
                .frame(width: W, height: H)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 12 * u)
            }
            .frame(width: W, height: H)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { shown = true }
            withAnimation(.easeOut(duration: 1.3).delay(0.55)) { filled = true }
        }
    }

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.8)
            RadialGradient(colors: [(e.won ? orange : red).opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 520)
            LinearGradient(colors: [.clear, Color(red: 0.02, green: 0.03, blue: 0.07).opacity(0.9)], startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    // MARK: header

    private func header(_ u: CGFloat) -> some View {
        let col = e.won ? orange : red
        let mode = TWeapons.modeNames.indices.contains(e.gameMode) ? TWeapons.modeNames[e.gameMode] : "MATCH"
        return VStack(spacing: 2 * u) {
            HStack(spacing: 14 * u) {
                slashes(u, col, flip: false)
                Text(e.won ? "VICTORY" : "DEFEAT").font(.jk(44 * u, .heavy)).italic().tracking(5 * u).foregroundColor(.white)
                    .shadow(color: col.opacity(0.9), radius: 12 * u)
                slashes(u, col, flip: true)
            }
            HStack(spacing: 10 * u) {
                Text(mode).foregroundColor(.white.opacity(0.6))
                Text("·").foregroundColor(.white.opacity(0.3))
                Text(TacLobbyMaps.title(e.gameMode == 8 ? 9 : 3)).foregroundColor(.white.opacity(0.6))
                Text("·").foregroundColor(.white.opacity(0.3))
                Text("\(e.scores[0])").foregroundColor(blue)
                Text(":").foregroundColor(.white.opacity(0.4))
                Text("\(e.rivalScore)").foregroundColor(orange)
            }
            .font(.jk(12 * u, .heavy)).tracking(1.5 * u)
        }
    }

    private func slashes(_ u: CGFloat, _ c: Color, flip: Bool) -> some View {
        HStack(spacing: 5 * u) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(c.opacity(flip ? 1 - Double(i) * 0.22 : 0.34 + Double(i) * 0.22))
                    .frame(width: 5 * u, height: 26 * u).rotationEffect(.degrees(22))
            }
        }
    }

    // MARK: MVP

    private func mvp(_ u: CGFloat, _ H: CGFloat) -> some View {
        let m = ranked.first ?? e.me
        let mine = m.id == e.me.id
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4 * u).fill(glass)
            RadialGradient(colors: [orange.opacity(0.35), .clear], center: UnitPoint(x: 0.5, y: 0.55), startRadius: 4, endRadius: 140 * u)
            Ellipse().fill(Color.black.opacity(0.5)).frame(width: 120 * u, height: 14 * u).padding(.bottom, 56 * u)
            Image("HeroFront").resizable().scaledToFit().frame(height: 236 * u).padding(.bottom, 58 * u)
            VStack(spacing: 2 * u) {
                Text(nm(m).uppercased()).font(.jk(15 * u, .heavy)).italic().foregroundColor(mine ? orange : .white).lineLimit(1)
                Text("\(m.kills) KILLS  ·  \(m.deaths) DEATHS  ·  \(Int(m.dmgDealt)) DMG").font(.jk(9 * u, .semibold)).foregroundColor(.white.opacity(0.65))
            }
            .padding(.bottom, 14 * u)
            VStack {
                HStack {
                    HStack(spacing: 5 * u) {
                        Image(systemName: "crown.fill").font(.system(size: 10 * u))
                        Text("MVP").font(.jk(12 * u, .heavy)).tracking(2 * u)
                    }
                    .foregroundColor(.black).padding(.horizontal, 10 * u).frame(height: 22 * u)
                    .background(ChamferShape(cut: 6 * u).fill(orange))
                    Spacer()
                }
                Spacer()
            }
            .padding(10 * u)
        }
        .frame(height: 320 * u)
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(mine ? orange : edge, lineWidth: mine ? 1.4 : 1))
    }

    // MARK: stats

    private func tile(_ u: CGFloat, _ icon: String, _ value: String, _ label: String, record: Bool = false) -> some View {
        VStack(spacing: 2 * u) {
            HStack(spacing: 5 * u) {
                Image(systemName: icon).font(.system(size: 10 * u, weight: .bold)).foregroundColor(orange)
                Text(label).font(.jk(9 * u, .heavy)).tracking(1.2 * u).foregroundColor(.white.opacity(0.6))
            }
            Text(value).font(.jk(24 * u, .heavy)).foregroundColor(.white).monospacedDigit()
            Text(record ? "NEW RECORD" : " ").font(.jk(7.5 * u, .heavy)).tracking(1 * u).foregroundColor(.black)
                .padding(.horizontal, 5 * u).background(record ? orange : .clear)
        }
        .frame(maxWidth: .infinity).frame(height: 70 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(record ? orange : edge, lineWidth: record ? 1.3 : 1))
    }

    private func statGrid(_ u: CGFloat) -> some View {
        VStack(spacing: 6 * u) {
            HStack(spacing: 6 * u) {
                tile(u, "scope", "\(e.kills)", "KILLS", record: r.records.contains("kills"))
                tile(u, "xmark", "\(e.me.deaths)", "DEATHS")
                tile(u, "flame.fill", "\(Int(e.me.dmgDealt))", "DAMAGE")
            }
            HStack(spacing: 6 * u) {
                tile(u, "bolt.fill", "\(e.swordKills)", "SWORD KILLS")
                tile(u, "chevron.right.2", "x\(e.bestCombo)", "BEST COMBO", record: r.records.contains("combo"))
                tile(u, "flame", "\(e.bestStreak)", "BEST STREAK", record: r.records.contains("streak"))
            }
        }
    }

    private func xpPanel(_ u: CGFloat) -> some View {
        let from = r.rankedUp ? 0 : TacRank.progress(r.xpBefore)
        let to = TacRank.progress(r.xpAfter)
        let rk = TacRank.ranks[r.rankAfter]
        return VStack(alignment: .leading, spacing: 6 * u) {
            HStack(spacing: 10 * u) {
                TacInsignia(idx: r.rankAfter, size: 34 * u).frame(width: 40 * u, height: 40 * u)
                VStack(alignment: .leading, spacing: 2 * u) {
                    HStack(spacing: 6 * u) {
                        Text(rk.name.uppercased()).font(.jk(13 * u, .heavy)).foregroundColor(.white)
                        if r.rankedUp {
                            Text("RANK UP").font(.jk(8 * u, .heavy)).tracking(1 * u).foregroundColor(.black)
                                .padding(.horizontal, 6 * u).frame(height: 14 * u).background(orange)
                                .scaleEffect(filled ? 1 : 0.4).opacity(filled ? 1 : 0)
                        }
                    }
                    Text(TacRank.toNext(r.xpAfter) > 0 ? "\(TacRank.toNext(r.xpAfter)) XP to \(TacRank.ranks[min(TacRank.ranks.count - 1, r.rankAfter + 1)].name)" : "Max rank")
                        .font(.jk(9 * u, .medium)).foregroundColor(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1 * u) {
                    Text("+\(r.xpBase + r.xpBonus) XP").font(.jk(16 * u, .heavy)).foregroundColor(orange)
                    if r.xpBonus > 0 {
                        Text("incl. +\(r.xpBonus) blade bonus").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: g.size.width * CGFloat(from))
                    Capsule().fill(LinearGradient(colors: [orange.opacity(0.7), orange], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * CGFloat(filled ? to : from))
                        .shadow(color: orange.opacity(0.7), radius: 4 * u)
                }
            }
            .frame(height: 6 * u)
            HStack(spacing: 14 * u) {
                reward(u, "C", "+\(r.gems)", Color(red: 1, green: 0.75, blue: 0.22))
                reward(u, "ZC", r.ratingDelta >= 0 ? "+\(r.ratingDelta)" : "\(r.ratingDelta)", blue)
                Spacer(minLength: 0)
            }
        }
        .padding(10 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private func reward(_ u: CGFloat, _ l: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 6 * u) {
            Text(l).font(.jk(7 * u, .heavy)).foregroundColor(.black.opacity(0.75)).frame(width: 16 * u, height: 16 * u).background(Circle().fill(c))
            Text(v).font(.jk(12 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
    }

    // MARK: standings

    private func standings(_ u: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("PLAYER").frame(maxWidth: .infinity, alignment: .leading)
                Text("K").frame(width: 28 * u, alignment: .trailing)
                Text("D").frame(width: 28 * u, alignment: .trailing)
                Text("DMG").frame(width: 44 * u, alignment: .trailing)
            }
            .font(.jk(9 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 10 * u).frame(height: 26 * u)
            .overlay(alignment: .bottom) { Rectangle().fill(orange.opacity(0.5)).frame(height: 1) }
            ForEach(Array(ranked.prefix(8).enumerated()), id: \.element.id) { i, p in
                let me = p.id == e.me.id
                HStack(spacing: 0) {
                    Text("\(i + 1)").font(.jk(9 * u, .heavy)).foregroundColor(i == 0 ? orange : .white.opacity(0.4)).frame(width: 16 * u, alignment: .leading)
                    Rectangle().fill(p.team == e.me.team ? blue : orange).frame(width: 2 * u, height: 12 * u).padding(.trailing, 6 * u)
                    Text(nm(p)).font(.jk(11 * u, me ? .heavy : .semibold)).foregroundColor(me ? orange : .white).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(p.kills)").frame(width: 28 * u, alignment: .trailing)
                    Text("\(p.deaths)").frame(width: 28 * u, alignment: .trailing).foregroundColor(.white.opacity(0.6))
                    Text("\(Int(p.dmgDealt))").frame(width: 44 * u, alignment: .trailing).foregroundColor(.white.opacity(0.6))
                }
                .font(.jk(11 * u, .semibold)).foregroundColor(.white).monospacedDigit()
                .padding(.horizontal, 10 * u).frame(height: 30 * u)
                .background(me ? orange.opacity(0.12) : (i.isMultiple(of: 2) ? Color.white.opacity(0.025) : .clear))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 320 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    // MARK: buttons

    private func buttons(_ u: CGFloat) -> some View {
        HStack(spacing: 12 * u) {
            Button(action: hideout) {
                HStack(spacing: 7 * u) {
                    Image(systemName: "house.fill").font(.system(size: 12 * u, weight: .bold))
                    Text("HIDEOUT").font(.jk(14 * u, .heavy)).tracking(1.5 * u)
                }
                .foregroundColor(.white.opacity(0.9)).frame(width: 170 * u, height: 38 * u)
                .background(ChamferShape(cut: 9 * u).fill(Color(red: 0.06, green: 0.08, blue: 0.13)))
                .overlay(ChamferShape(cut: 9 * u).stroke(edge, lineWidth: 1))
            }.buttonStyle(.plain)
            Button(action: rematch) {
                HStack(spacing: 7 * u) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12 * u, weight: .bold))
                    Text("REMATCH").font(.jk(14 * u, .heavy)).tracking(1.5 * u)
                }
                .foregroundColor(.white).frame(width: 170 * u, height: 38 * u)
                .background(ChamferShape(cut: 9 * u).fill(LinearGradient(colors: [Color(red: 0.2, green: 0.1, blue: 0.04), Color(red: 0.08, green: 0.05, blue: 0.03)], startPoint: .top, endPoint: .bottom)))
                .overlay(ChamferShape(cut: 9 * u).stroke(orange, lineWidth: 1.4))
                .shadow(color: orange.opacity(0.5), radius: 8 * u)
            }.buttonStyle(.plain)
        }
    }
}

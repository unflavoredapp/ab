import SwiftUI

// MARK: - Movement Lab bookkeeping

enum ABLab {
    /// length of one run, seconds
    static let duration: CGFloat = 90

    struct Run {
        var score: Int
        var targets: Int
        var bestCombo: Int
        var airKills: Int
        var accuracy: Int          // percent
        var newBest: Set<String>   // "score", "combo", "acc"
    }

    /// Saves a finished run to the career records and returns what it beat.
    static func record(_ e: TacticalEngine) -> Run {
        var rec = ABRecords.load()
        let score = e.labScore
        let acc = Int(e.labAccuracy * 100)
        var broke = Set<String>()
        if rec.labRuns > 0 {
            if score > rec.labBestScore { broke.insert("score") }
            if e.bestCombo > rec.labBestCombo && e.bestCombo >= 2 { broke.insert("combo") }
            if acc > rec.labBestAcc { broke.insert("acc") }
        }
        rec.labRuns += 1
        rec.labBestScore = max(rec.labBestScore, score)
        rec.labBestCombo = max(rec.labBestCombo, e.bestCombo)
        rec.labBestAcc = max(rec.labBestAcc, acc)
        // practice counts toward the same career numbers the challenges read
        rec.swordKills += e.swordKills
        rec.airKills += e.airKills
        rec.backstabs += e.backstabs
        rec.bestCombo = max(rec.bestCombo, e.bestCombo)
        rec.bestStreak = max(rec.bestStreak, e.bestStreak)
        rec.save()
        return Run(score: score, targets: e.me.kills, bestCombo: e.bestCombo, airKills: e.airKills, accuracy: acc, newBest: broke)
    }
}

// MARK: - Challenges

struct ABChallenge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let goal: Int
    let reward: Int
    let icon: String
    let value: (ABRecords) -> Int

    static let all: [ABChallenge] = [
        ABChallenge(id: "air10", title: "Sky Hunter", detail: "10 aerial eliminations", goal: 10, reward: 150, icon: "arrow.up.forward") { $0.airKills },
        ABChallenge(id: "combo5", title: "Chain Master", detail: "Land a 5-hit sword combo", goal: 5, reward: 150, icon: "bolt.horizontal.fill") { $0.bestCombo },
        ABChallenge(id: "sword25", title: "Edge Walker", detail: "25 sword eliminations", goal: 25, reward: 100, icon: "scissors") { $0.swordKills },
        ABChallenge(id: "back10", title: "Backstabber", detail: "10 backstab eliminations", goal: 10, reward: 100, icon: "figure.walk") { $0.backstabs },
        ABChallenge(id: "flaw1", title: "Untouchable", detail: "Win a match without dying", goal: 1, reward: 200, icon: "shield.fill") { $0.flawlessWins },
        ABChallenge(id: "streak7", title: "Unstoppable", detail: "A 7 kill streak", goal: 7, reward: 150, icon: "flame.fill") { $0.bestStreak },
        ABChallenge(id: "multi3", title: "Triple Threat", detail: "Triple kill in one go", goal: 3, reward: 100, icon: "3.circle.fill") { $0.bestMulti },
        ABChallenge(id: "head20", title: "Marksman", detail: "20 headshot eliminations", goal: 20, reward: 100, icon: "scope") { $0.headKills },
        ABChallenge(id: "wins10", title: "Veteran", detail: "Win 10 matches", goal: 10, reward: 250, icon: "trophy.fill") { $0.wins },
        ABChallenge(id: "lab1500", title: "Lab Rat", detail: "Score 1500 in the Movement Lab", goal: 1500, reward: 150, icon: "figure.run") { $0.labBestScore }
    ]
}

extension Game {
    /// pays out a finished challenge once
    @discardableResult
    func claimChallenge(_ c: ABChallenge) -> Bool {
        var rec = ABRecords.load()
        guard !rec.claimed.contains(c.id), c.value(rec) >= c.goal else { return false }
        rec.claimed.append(c.id)
        rec.save()
        var st = s
        st.ex.gems += c.reward
        s = st
        return true
    }
}

// MARK: - Movement Lab HUD + results

/// small readout while a Lab run is live: targets, chain, air kills, accuracy
struct AirbladeLabHUD: View {
    let e: TacticalEngine
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)

    private func cell(_ k: String, _ v: String, hot: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(v).font(.jk(14, .heavy)).foregroundColor(hot ? orange : .white).monospacedDigit()
            Text(k).font(.jk(7, .heavy)).tracking(1).foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 52)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "figure.run").font(.system(size: 9, weight: .bold)).foregroundColor(orange)
                Text("MOVEMENT LAB").font(.jk(8.5, .heavy)).tracking(1.5).foregroundColor(.white.opacity(0.85))
            }
            HStack(spacing: 0) {
                cell("TARGETS", "\(e.me.kills)")
                cell("COMBO", "x\(e.comboN)", hot: e.comboN >= 2)
                cell("BEST", "x\(e.bestCombo)")
                cell("AIR", "\(e.airKills)")
                cell("ACC", "\(Int(e.labAccuracy * 100))%")
            }
            Text("SCORE \(e.labScore)").font(.jk(9, .heavy)).tracking(1).foregroundColor(orange)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.42)))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 2)
    }
}

struct AirbladeLabResults: View {
    let e: TacticalEngine
    let hideout: () -> Void
    let retry: () -> Void

    @State private var run: ABLab.Run? = nil
    @State private var shown = false

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.86)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)

    private func tile(_ u: CGFloat, _ icon: String, _ v: String, _ k: String, best: Bool = false) -> some View {
        VStack(spacing: 2 * u) {
            HStack(spacing: 5 * u) {
                Image(systemName: icon).font(.system(size: 10 * u, weight: .bold)).foregroundColor(orange)
                Text(k).font(.jk(9 * u, .heavy)).tracking(1.2 * u).foregroundColor(.white.opacity(0.6))
            }
            Text(v).font(.jk(24 * u, .heavy)).foregroundColor(.white).monospacedDigit()
            Text(best ? "NEW BEST" : " ").font(.jk(7.5 * u, .heavy)).tracking(1 * u).foregroundColor(.black)
                .padding(.horizontal, 5 * u).background(best ? orange : .clear)
        }
        .frame(maxWidth: .infinity).frame(height: 72 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(best ? orange : edge, lineWidth: best ? 1.3 : 1))
    }

    var body: some View {
        GeometryReader { g in
            let u = min(g.size.width / 1024, g.size.height / 470)
            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()
                RadialGradient(colors: [orange.opacity(0.2), .clear], center: .top, startRadius: 10, endRadius: 520).ignoresSafeArea()
                if let r = run {
                    VStack(spacing: 12 * u) {
                        VStack(spacing: 2 * u) {
                            Text("MOVEMENT LAB").font(.jk(11 * u, .heavy)).tracking(3 * u).foregroundColor(orange)
                            Text("RUN COMPLETE").font(.jk(34 * u, .heavy)).italic().tracking(3 * u).foregroundColor(.white)
                                .shadow(color: orange.opacity(0.8), radius: 10 * u)
                        }
                        VStack(spacing: 0) {
                            Text("SCORE").font(.jk(10 * u, .heavy)).tracking(2 * u).foregroundColor(.white.opacity(0.55))
                            Text("\(r.score)").font(.jk(46 * u, .heavy)).foregroundColor(.white).monospacedDigit()
                            Text(r.newBest.contains("score") ? "NEW PERSONAL BEST" : "BEST  \(ABRecords.load().labBestScore)")
                                .font(.jk(9 * u, .heavy)).tracking(1.5 * u)
                                .foregroundColor(r.newBest.contains("score") ? .black : .white.opacity(0.55))
                                .padding(.horizontal, 8 * u).frame(height: 15 * u)
                                .background(r.newBest.contains("score") ? orange : .clear)
                        }
                        HStack(spacing: 8 * u) {
                            tile(u, "scope", "\(r.targets)", "TARGETS")
                            tile(u, "chevron.right.2", "x\(r.bestCombo)", "BEST COMBO", best: r.newBest.contains("combo"))
                            tile(u, "arrow.up.forward", "\(r.airKills)", "AIR KILLS")
                            tile(u, "target", "\(r.accuracy)%", "ACCURACY", best: r.newBest.contains("acc"))
                        }
                        .frame(width: 560 * u)
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
                            Button(action: retry) {
                                HStack(spacing: 7 * u) {
                                    Image(systemName: "arrow.clockwise").font(.system(size: 12 * u, weight: .bold))
                                    Text("RETRY").font(.jk(14 * u, .heavy)).tracking(1.5 * u)
                                }
                                .foregroundColor(.white).frame(width: 170 * u, height: 38 * u)
                                .background(ChamferShape(cut: 9 * u).fill(LinearGradient(colors: [Color(red: 0.2, green: 0.1, blue: 0.04), Color(red: 0.08, green: 0.05, blue: 0.03)], startPoint: .top, endPoint: .bottom)))
                                .overlay(ChamferShape(cut: 9 * u).stroke(orange, lineWidth: 1.4))
                                .shadow(color: orange.opacity(0.5), radius: 8 * u)
                            }.buttonStyle(.plain)
                        }
                    }
                    .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 10 * u)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            if run == nil { run = ABLab.record(e) }
            withAnimation(.easeOut(duration: 0.35)) { shown = true }
        }
    }
}

// MARK: - Challenges + mastery screen

/// Reached from the lobby's Achievements tab: challenges with progress and claimable rewards, weapon mastery for
/// the sword and every gun, and the Movement Lab records.
struct AirbladeProgressView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var tab = 0
    @State private var rec = ABRecords.load()
    @State private var flash: String? = nil

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.86)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    // MARK: pieces

    private func bar(_ f: Double, _ w: CGFloat, _ c: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule().fill(c).frame(width: w * CGFloat(max(0, min(1, f))))
        }
        .frame(width: w, height: 4 * u)
    }

    private func challengeRow(_ c: ABChallenge) -> some View {
        let v = min(c.goal, c.value(rec))
        let done = v >= c.goal
        let paid = rec.claimed.contains(c.id)
        return HStack(spacing: 10 * u) {
            Image(systemName: c.icon).font(.system(size: 14 * u, weight: .bold)).foregroundColor(paid ? .white.opacity(0.35) : orange)
                .frame(width: 34 * u, height: 34 * u)
                .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.35)))
            VStack(alignment: .leading, spacing: 2 * u) {
                Text(c.title.uppercased()).font(.jk(12 * u, .heavy)).foregroundColor(paid ? .white.opacity(0.5) : .white)
                Text(c.detail).font(.jk(9 * u, .medium)).foregroundColor(.white.opacity(0.55))
                HStack(spacing: 6 * u) {
                    bar(Double(v) / Double(c.goal), 150 * u, done ? orange : Color(red: 0.25, green: 0.65, blue: 1))
                    Text("\(v) / \(c.goal)").font(.jk(8.5 * u, .heavy)).foregroundColor(.white.opacity(0.7)).monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            if paid {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 16 * u)).foregroundColor(.white.opacity(0.35))
            } else {
                Button {
                    if game.claimChallenge(c) { rec = ABRecords.load(); flash = "+\(c.reward) coins · \(c.title)" }
                } label: {
                    VStack(spacing: 0) {
                        Text(done ? "CLAIM" : "\(c.reward)").font(.jk(11 * u, .heavy))
                        if !done { Text("COINS").font(.jk(6.5 * u, .heavy)).tracking(1 * u) }
                    }
                    .foregroundColor(done ? .black : .white.opacity(0.6)).frame(width: 62 * u, height: 32 * u)
                    .background(RoundedRectangle(cornerRadius: 3 * u).fill(done ? orange : Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain).disabled(!done)
            }
        }
        .padding(.horizontal, 10 * u).frame(height: 52 * u)
        .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(done && !paid ? orange : edge, lineWidth: done && !paid ? 1.3 : 1))
    }

    private var challenges: some View {
        let list = ABChallenge.all.sorted {
            let a = $0.value(rec) >= $0.goal && !rec.claimed.contains($0.id)
            let b = $1.value(rec) >= $1.goal && !rec.claimed.contains($1.id)
            if a != b { return a }
            return false
        }
        return ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8 * u), GridItem(.flexible(), spacing: 8 * u)], spacing: 8 * u) {
                ForEach(list) { challengeRow($0) }
            }
        }
    }

    // mastery: the sword counts sword kills; guns use the existing per-gun mastery (10 xp a kill)
    private static let bladeSteps = [0, 10, 50, 150, 400, 1000]

    private func masteryRow(_ id: String) -> some View {
        let blade = id == "blade"
        let kills: Int, level: Int, next: Int?
        if blade {
            kills = rec.swordKills
            level = Self.bladeSteps.lastIndex(where: { kills >= $0 }) ?? 0
            next = level + 1 < Self.bladeSteps.count ? Self.bladeSteps[level + 1] : nil
        } else {
            kills = TacMeta.xp(id) / 10
            level = TacMeta.level(id)
            next = level + 1 < TacMeta.thresholds.count ? TacMeta.thresholds[level + 1] / 10 : nil
        }
        let prev = blade ? Self.bladeSteps[level] : TacMeta.thresholds[level] / 10
        let f = next.map { Double(kills - prev) / Double(max(1, $0 - prev)) } ?? 1
        let on = id == "blade" || id == nav.tacGun || id == TacticalEngine.secondary
        return HStack(spacing: 8 * u) {
            Group {
                if blade { BladeGlyph().fill(Color.white).frame(width: 40 * u, height: 14 * u) }
                else {
                    Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                        .foregroundColor(.white.opacity(0.92)).frame(height: 15 * u)
                }
            }
            .frame(width: 50 * u)
            VStack(alignment: .leading, spacing: 2 * u) {
                HStack(spacing: 5 * u) {
                    Text(blade ? "AIRBLADE" : TWeapons.w(id).name).font(.jk(11 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                    if on { Text("E").font(.jk(7 * u, .heavy)).foregroundColor(.black).frame(width: 11 * u, height: 11 * u).background(orange) }
                }
                bar(f, 110 * u, orange)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text("LV \(level)").font(.jk(13 * u, .heavy)).foregroundColor(level >= 5 ? orange : .white)
                Text(next.map { "\(kills)/\($0)" } ?? "MAX").font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.55)).monospacedDigit()
            }
        }
        .padding(.horizontal, 10 * u).frame(height: 46 * u)
        .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(on ? orange.opacity(0.7) : edge, lineWidth: 1))
    }

    private var mastery: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8 * u), GridItem(.flexible(), spacing: 8 * u)], spacing: 8 * u) {
                masteryRow("blade")
                ForEach(TWeapons.all, id: \.id) { masteryRow($0.id) }
            }
        }
    }

    private func recordTile(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2 * u) {
            Text(k).font(.jk(8.5 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.55))
            Text(v).font(.jk(22 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12 * u).frame(height: 56 * u)
        .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(edge, lineWidth: 1))
    }

    private var lab: some View {
        VStack(alignment: .leading, spacing: 10 * u) {
            HStack(spacing: 8 * u) {
                Image(systemName: "figure.run").font(.system(size: 14 * u, weight: .bold)).foregroundColor(orange)
                Text("MOVEMENT LAB").font(.jk(13 * u, .heavy)).tracking(2 * u).foregroundColor(.white)
                Spacer()
            }
            Text("90 seconds in the Duel Arena. Targets stand still: wall-run, sword-jump and chain your slashes. Score = targets, best chain, air kills and accuracy. Start it from the mission board.")
                .font(.jk(10 * u, .medium)).foregroundColor(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8 * u), count: 4), spacing: 8 * u) {
                recordTile("RUNS", "\(rec.labRuns)")
                recordTile("BEST SCORE", "\(rec.labBestScore)")
                recordTile("BEST COMBO", "x\(rec.labBestCombo)")
                recordTile("BEST ACCURACY", "\(rec.labBestAcc)%")
            }
            Text("CAREER").font(.jk(10 * u, .heavy)).tracking(2 * u).foregroundColor(orange).padding(.top, 4 * u)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8 * u), count: 4), spacing: 8 * u) {
                recordTile("SWORD KILLS", "\(rec.swordKills)")
                recordTile("AIR KILLS", "\(rec.airKills)")
                recordTile("BACKSTABS", "\(rec.backstabs)")
                recordTile("HEADSHOTS", "\(rec.headKills)")
                recordTile("BEST STREAK", "\(rec.bestStreak)")
                recordTile("BEST MULTI-KILL", "\(rec.bestMulti)")
                recordTile("MATCHES", "\(rec.matches)")
                recordTile("FLAWLESS WINS", "\(rec.flawlessWins)")
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: body

    var body: some View {
        let ready = ABChallenge.all.filter { $0.value(rec) >= $0.goal && !rec.claimed.contains($0.id) }.count
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.45).ignoresSafeArea()
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
                    Text("ACHIEVEMENTS").font(.jk(11 * u, .heavy)).tracking(2 * u).foregroundColor(orange)
                    Spacer()
                    if let f = flash {
                        Text(f).font(.jk(10 * u, .heavy)).foregroundColor(.black).padding(.horizontal, 10 * u).frame(height: 20 * u).background(orange)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 27 * u).frame(height: 30 * u)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(["CHALLENGES", "WEAPON MASTERY", "LAB & RECORDS"].enumerated()), id: \.offset) { i, s in
                            Button { tab = i } label: {
                                HStack(spacing: 6 * u) {
                                    Text(s).font(.jk(11 * u, i == tab ? .heavy : .semibold)).tracking(1 * u)
                                    if i == 0 && ready > 0 {
                                        Text("\(ready)").font(.jk(8 * u, .heavy)).foregroundColor(.black).frame(width: 14 * u, height: 14 * u).background(Circle().fill(orange))
                                    }
                                }
                                .foregroundColor(i == tab ? .white : .white.opacity(0.55))
                                .padding(.horizontal, 18 * u).frame(height: 30 * u)
                                .overlay(alignment: .bottom) { Rectangle().fill(i == tab ? orange : .clear).frame(height: 2 * u).padding(.horizontal, 8 * u) }
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .overlay(alignment: .bottom) { Rectangle().fill(edge).frame(height: 1) }
                    Group {
                        switch tab {
                        case 0: challenges
                        case 1: mastery
                        default: lab
                        }
                    }
                    .padding(10 * u)
                }
                .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
                .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
                .padding(.horizontal, 22 * u).padding(.bottom, 14 * u)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear { rec = ABRecords.load() }
        .onChange(of: flash) { f in
            guard f != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { flash = nil } }
        }
    }
}

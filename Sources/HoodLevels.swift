import SwiftUI

/// Player level 1...99. XP comes from match results (the old stats formula) plus Free Roam: knockouts, contracts, districts.
enum HBLevel {
    static let maxLevel = 99
    private static let key = "ab.roam.xp"

    /// XP earned in Free Roam (added into TacRank.totalXP so every screen agrees)
    static var roamXP: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: key) }
    }

    /// total XP at which `level` begins
    static func xpFor(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        return Int(30 * pow(Double(min(level, maxLevel) - 1), 1.8))
    }

    static func level(_ xp: Int) -> Int {
        var lo = 1, hi = maxLevel
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if xp >= xpFor(mid) { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    /// 0...1 toward the next level (1 at 99)
    static func progress(_ xp: Int) -> Double {
        let l = level(xp)
        if l >= maxLevel { return 1 }
        let a = xpFor(l), b = xpFor(l + 1)
        return min(1, max(0, Double(xp - a) / Double(max(1, b - a))))
    }

    static func toNext(_ xp: Int) -> Int { level(xp) >= maxLevel ? 0 : xpFor(level(xp) + 1) - xp }

    static func add(_ n: Int) { roamXP += n }
}

/// watches the level while you play and announces level-ups
struct RoamLevelWatcher: View {
    @EnvironmentObject var game: Game
    @State private var last = -1

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let lv = HBLevel.level(TacRank.totalXP(game.s.ex.tac ?? TacData()))
            Color.clear.frame(width: 1, height: 1)
                .onAppear { if last < 0 { last = lv } }
                .onChange(of: lv) { v in
                    if last >= 0 && v > last {
                        BlokNet.shared.showCard("LEVEL UP", ["YOU ARE NOW LEVEL \(v)"], Color(red: 1, green: 0.8, blue: 0.25))
                    }
                    last = v
                }
        }
        .allowsHitTesting(false)
    }
}

import SwiftUI

// MARK: - HUD preferences

final class RoamPrefs: ObservableObject {
    static let shared = RoamPrefs()
    private let d = UserDefaults.standard

    @Published var scale: Double { didSet { d.set(scale, forKey: "ab.hud.scale") } }
    @Published var mapLeft: Bool { didSet { d.set(mapLeft, forKey: "ab.hud.mapLeft") } }
    @Published var mapSize: Int { didSet { d.set(mapSize, forKey: "ab.hud.mapSize") } }       // 0 small 1 medium 2 large
    @Published var dmgNumbers: Bool { didSet { d.set(dmgNumbers, forKey: "ab.hud.dmg") } }
    @Published var phoneFreq: Int { didSet { d.set(phoneFreq, forKey: "ab.hud.phone") } }     // 0 off 1 low 2 normal
    @Published var ticker: Bool { didSet { d.set(ticker, forKey: "ab.hud.ticker") } }

    private init() {
        let s = d.double(forKey: "ab.hud.scale")
        scale = s == 0 ? 1 : s
        mapLeft = d.bool(forKey: "ab.hud.mapLeft")
        mapSize = d.object(forKey: "ab.hud.mapSize") as? Int ?? 1
        dmgNumbers = d.object(forKey: "ab.hud.dmg") as? Bool ?? true
        phoneFreq = d.object(forKey: "ab.hud.phone") as? Int ?? 2
        ticker = d.object(forKey: "ab.hud.ticker") as? Bool ?? true
    }

    var mapDia: CGFloat { [76, 92, 112][min(2, max(0, mapSize))] }

    /// bring your crew into the city (set on the ready-up screen)
    static var crewOn: Bool { UserDefaults.standard.object(forKey: "ab.loadout.crew") as? Bool ?? true }
}

// MARK: - Crew status strip

struct RoamCrewStrip: View {
    let e: TacticalEngine
    private let blue = Color(red: 0.3, green: 0.75, blue: 1)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let crew = e.players.filter { $0.ally }
            if !crew.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(crew, id: \.id) { p in row(p) }
                }
            }
        }
    }

    private func row(_ p: TPlayer) -> some View {
        let st = e.allyStatus(p)
        let col: Color = st == "DOWN" ? Color(red: 1, green: 0.3, blue: 0.26) : (st == "FIGHTING" ? Color(red: 1, green: 0.55, blue: 0.16) : (st == "REGROUPING" ? Color(red: 1, green: 0.8, blue: 0.25) : blue))
        let hp = p.alive ? max(0, min(1, p.hp / 100)) : 0
        return Button {
            if p.alive { e.roam.waypoint = p.pos }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(col).frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(p.name.uppercased()).font(.jk(8, .heavy)).tracking(0.6).foregroundColor(.white)
                        if p.alive { Text("\(Int(tDist(p.pos, e.me.pos) / 33))m").font(.jk(7, .semibold)).foregroundColor(.white.opacity(0.6)).monospacedDigit() }
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(col).frame(width: 46 * hp)
                    }.frame(width: 46, height: 3)
                }
                Text(st).font(.jk(6.5, .heavy)).tracking(0.5).foregroundColor(col)
            }
            .padding(.horizontal, 7).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(col.opacity(0.35), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - City activity ticker (real world state only)

struct RoamTicker: View {
    let e: TacticalEngine
    @ObservedObject var net = BlokNet.shared

    private func dName(_ p: CGPoint) -> String { OWDistrict.base[OWWorld.districtAt(p)].name }

    private func items() -> [String] {
        var out: [String] = []
        // fights between crews, wherever they are
        if let f = e.players.first(where: { !$0.isPlayer && !$0.civ && !$0.ally && $0.alive && $0.targetID >= 0 && tDist($0.pos, e.me.pos) > 500 }) {
            out.append("\(dName(f.pos)) — SHOTS REPORTED")
        }
        if let b = e.players.first(where: { $0.id == e.roam.bossID && $0.alive }) {
            out.append("RAZOR SPOTTED — \(dName(b.pos))")
        }
        if let c = e.roam.cars.first(where: { $0.wrecked }) { out.append("WRECKED WHIP — \(dName(c.pos))") }
        if e.roam.job == nil, e.roam.offers.contains(where: { $0.kind == .drop }) { out.append("DEAD DROP AVAILABLE — OPEN BLOK PHONE") }
        for p in e.players where p.ally && !p.alive { out.append("\(p.name.uppercased()) IS DOWN") }
        if let a = net.alerts.first, Date().timeIntervalSince1970 - a.ts < 600 { out.append(a.text.uppercased()) }
        return out
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let list = items()
            if !list.isEmpty {
                let i = Int(tl.date.timeIntervalSinceReferenceDate / 6) % list.count
                HStack(spacing: 6) {
                    Text("LIVE").font(.jk(6.5, .heavy)).tracking(1).foregroundColor(.black)
                        .padding(.horizontal, 4).frame(height: 12).background(Capsule().fill(Color(red: 1, green: 0.55, blue: 0.16)))
                    Text(list[i]).font(.jk(8.5, .heavy)).tracking(0.8).foregroundColor(.white).lineLimit(1)
                        .id(list[i]).transition(.opacity)
                }
                .padding(.horizontal, 8).frame(height: 20)
                .background(Capsule().fill(Color.black.opacity(0.5)))
                .animation(.easeInOut(duration: 0.3), value: list[i])
            }
        }
    }
}

// MARK: - REP up toast

struct RoamRepToast: View {
    @ObservedObject var net = BlokNet.shared
    @State private var last: Double = BlokNet.shared.rep.respect
    @State private var lastTitle = BlokNet.shared.rep.title
    @State private var acc: Double = 0
    @State private var title: String? = nil
    @State private var stamp = 0

    var body: some View {
        Group {
            if acc >= 1 || title != nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 11, weight: .bold))
                    Text(title.map { "NEW TITLE · \($0)" } ?? "+ \(Int(acc)) RESPECT").font(.jk(10, .heavy)).tracking(1)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12).frame(height: 24)
                .background(Capsule().fill(Color(red: 1, green: 0.55, blue: 0.16)))
                .shadow(color: Color(red: 1, green: 0.55, blue: 0.16).opacity(0.6), radius: 6)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: acc >= 1)
        .onChange(of: net.rep.respect) { v in
            let d = v - last
            last = v
            if d > 0 { acc += d }
            if net.rep.title != lastTitle { title = net.rep.title; lastTitle = net.rep.title }
            stamp += 1
            let s = stamp
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { if s == stamp { acc = 0; title = nil } }
        }
    }
}

// MARK: - Settings panel

struct RoamHUDSettings: View {
    @ObservedObject var p = RoamPrefs.shared
    let close: () -> Void
    private let gold = Color(red: 1, green: 0.8, blue: 0.25)

    private func seg(_ title: String, _ opts: [String], _ sel: Int, _ set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title).font(.jk(9, .heavy)).tracking(0.8).foregroundColor(.white.opacity(0.8))
            Spacer()
            HStack(spacing: 3) {
                ForEach(opts.indices, id: \.self) { i in
                    Button { set(i) } label: {
                        Text(opts[i]).font(.jk(8.5, .heavy)).foregroundColor(sel == i ? .black : .white)
                            .padding(.horizontal, 9).frame(height: 22)
                            .background(RoundedRectangle(cornerRadius: 3).fill(sel == i ? gold : Color.white.opacity(0.1)))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text("HUD SETTINGS").font(.jk(13, .heavy)).tracking(2).foregroundColor(.white)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.8)).frame(width: 26, height: 22)
                }.buttonStyle(.plain)
            }
            HStack {
                Text("HUD SCALE").font(.jk(9, .heavy)).tracking(0.8).foregroundColor(.white.opacity(0.8))
                Slider(value: $p.scale, in: 0.8...1.3).tint(gold).frame(width: 150)
                Text("\(Int(p.scale * 100))%").font(.jk(9, .heavy)).foregroundColor(gold).monospacedDigit().frame(width: 34)
            }
            seg("MINIMAP SIDE", ["LEFT", "RIGHT"], p.mapLeft ? 0 : 1) { p.mapLeft = $0 == 0 }
            seg("MINIMAP SIZE", ["S", "M", "L"], p.mapSize) { p.mapSize = $0 }
            seg("DAMAGE NUMBERS", ["OFF", "ON"], p.dmgNumbers ? 1 : 0) { p.dmgNumbers = $0 == 1 }
            seg("CITY TICKER", ["OFF", "ON"], p.ticker ? 1 : 0) { p.ticker = $0 == 1 }
            seg("PHONE ALERTS", ["OFF", "LOW", "NORMAL"], p.phoneFreq) { p.phoneFreq = $0 }
            Text("Move or resize the touch buttons from the controls layout editor in Settings.")
                .font(.jk(7.5, .medium)).foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
        .padding(14).frame(width: 340)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.04, green: 0.045, blue: 0.055).opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 1, green: 0.55, blue: 0.16).opacity(0.5), lineWidth: 1))
    }
}

import SwiftUI

// MARK: - Free Roam: state, jobs, HUD and results
//
// Free Roam is the open-world mode on the Town map: no rounds, no timer. Pedestrians wander, two rival
// crews hold their corners, and you fight with your hands (jab, cross, kick finisher, air kick, rush punch).
// Jobs are picked from the phone chip and finished in the streets.

struct RoamJob: Identifiable, Equatable {
    enum Kind { case drop, turf, boss }
    let id: Int
    var kind: Kind
    var title: String
    var brief: String
    var reward: Int
    var need = 1
    var got = 0
    var stage = 0
    var pts: [CGPoint] = []
    var timeLeft: CGFloat = 0
    /// map district this job belongs to (-1 = anywhere) and whether finishing it captures the district
    var district = -1
    var capture = false
}

struct RoamState {
    var cash = 0
    var crewKOs = 0
    var civKOs = 0
    var jobsDone = 0
    var jobsFailed = 0
    var bestCombo = 0
    var step = 0
    var comboT: CGFloat = 0
    var swingT: CGFloat = 0
    var job: RoamJob? = nil
    var offers: [RoamJob] = []
    var jobsOpen = false
    var pool: [CGPoint] = []
    var homes: [CGPoint] = []
    var hideout = CGPoint.zero
    var bossID = -1
    var started: CGFloat = 0
    var startDistrict = -1
    var startPos: CGPoint? = nil
    var lastDistrict = -1
    /// weapons: 0 fists, 1 bat, 2 pistol; owned slots persist between sessions
    var weapon = 0
    var waypoint: CGPoint? = nil
    var owned: Set<Int> = [0]
    static let magSize = 12
    var ammo = 12
    var reserve = 36
    var reloadT: CGFloat = 0
    var feed: [RoamFeedItem] = []
    /// drivable cars and the index of the one you are in (-1 on foot)
    var cars: [RoamCar] = []
    var driving = -1

    static func loadOwned() -> Set<Int> {
        Set((UserDefaults.standard.array(forKey: "ab.roam.owned") as? [Int]) ?? []).union([0])
    }
    static func saveOwned(_ s: Set<Int>) { UserDefaults.standard.set(Array(s), forKey: "ab.roam.owned") }
}

final class RoamCar {
    var pos: CGPoint
    var heading: CGFloat
    var speed: CGFloat = 0
    var hp: CGFloat = 120
    var maxHP: CGFloat = 120
    var kind = 0          // 0 sedan, 1 sport, 2 truck
    var mine = false
    let home: CGPoint
    let homeHeading: CGFloat
    let color: Int
    var wreckT: CGFloat = 0
    init(pos: CGPoint, heading: CGFloat, color: Int) { self.pos = pos; self.heading = heading; self.home = pos; self.homeHeading = heading; self.color = color }
    var wrecked: Bool { wreckT > 0 }
}

struct RoamFeedItem: Identifiable {
    let id = UUID()
    var killer: String
    var victim: String
    var weapon: Int
    var life: CGFloat
    var mine: Bool
    var boss: Bool
}

enum RoamCrew {
    static let names = ["", "EAST SIDE KINGS", "VIPER ROW"]
    static let cols: [Color] = [.white, Color(red: 1, green: 0.74, blue: 0.2), Color(red: 0.4, green: 0.9, blue: 0.5)]
}

extension Game {
    /// session cash turns into coins when you leave; paid once
    func roamPayout(_ e: TacticalEngine) -> Int {
        let coins = max(0, e.roam.cash / 10 + e.roam.jobsDone * 5)
        if coins > 0 {
            var st = s
            st.ex.gems += coins
            s = st
        }
        return coins
    }
}

// MARK: - HUD

struct RoamHUD: View {
    let e: TacticalEngine
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let gold = Color(red: 1, green: 0.8, blue: 0.25)

    @EnvironmentObject var game: Game
    @State private var phoneOpen = false

    private var pills: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("$").font(.jk(9, .heavy)).foregroundColor(.black.opacity(0.75)).frame(width: 17, height: 17).background(Circle().fill(gold))
                Text("\(e.roam.cash)").font(.jk(12, .semibold)).foregroundColor(.white).monospacedDigit()
            }
            .padding(.horizontal, 9).frame(height: 24).background(Capsule().fill(Color.black.opacity(0.45))).overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            if e.roam.lastDistrict >= 0 {
                let d = OWDistrict.all[e.roam.lastDistrict]
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(d.color)
                    Text(d.name).font(.jk(9, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text("\(d.control)%").font(.jk(9, .heavy)).foregroundColor(d.color).monospacedDigit()
                }
                .padding(.horizontal, 9).frame(height: 24).background(Capsule().fill(Color.black.opacity(0.45))).overlay(Capsule().stroke(d.color.opacity(0.6), lineWidth: 1))
            }
            HStack(spacing: 6) {
                Text("K.O.").font(.jk(7, .heavy)).foregroundColor(.black.opacity(0.75)).frame(width: 17, height: 17).background(Circle().fill(Color(red: 0.4, green: 0.7, blue: 1)))
                Text("\(e.roam.crewKOs + e.roam.civKOs)").font(.jk(12, .semibold)).foregroundColor(.white).monospacedDigit()
                if e.comboN >= 2 { Text("x\(e.comboN)").font(.jk(10, .heavy)).foregroundColor(orange) }
            }
            .padding(.horizontal, 9).frame(height: 24).background(Capsule().fill(Color.black.opacity(0.45))).overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.5), radius: 2)
    }

    /// ACTIVE CONTRACT card, like the mockup
    private var contractCard: some View {
        let j = e.roam.job
        var prog = ""
        if let j = j {
            switch j.kind {
            case .turf: prog = "\(j.got)/\(j.need)"
            case .drop: prog = "\(min(j.stage, j.pts.count))/\(j.pts.count)"
            case .boss: prog = e.roamObjectiveText.hasPrefix("Find") ? "0/1" : "…"
            }
        }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill").font(.system(size: 12, weight: .bold)).foregroundColor(gold)
                Text(j == nil ? "NO ACTIVE CONTRACT" : "ACTIVE CONTRACT").font(.jk(7.5, .semibold)).tracking(0.8).foregroundColor(gold)
            }
            Text(j?.title ?? "Open your phone to take a job").font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1)
            if let j = j {
                Text(e.roamObjectiveText).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
                HStack {
                    Text(prog).font(.jk(8, .heavy)).foregroundColor(.white).monospacedDigit()
                    Spacer()
                    if j.kind == .drop { Text(ABRules.mmss(Double(j.timeLeft))).font(.jk(8, .heavy)).foregroundColor(j.timeLeft < 25 ? Color(red: 1, green: 0.3, blue: 0.26) : .white).monospacedDigit() }
                    Text("$\(j.reward)").font(.jk(8, .heavy)).foregroundColor(gold)
                }
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6).frame(width: 190, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.78)))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 2)
    }

    private func distText(_ d: CGFloat) -> String { "\(Int(d / 33)) m" }

    /// arrow + distance to the objective
    private var tracker: some View {
        Group {
            if let t = e.roamMarker {
                let dx = t.x - e.me.pos.x, dy = t.y - e.me.pos.y
                let fwd = dx * cos(e.me.aim) + dy * sin(e.me.aim)
                let rgt = dx * -sin(e.me.aim) + dy * cos(e.me.aim)
                HStack(spacing: 6) {
                    Image(systemName: "location.north.fill").font(.system(size: 13, weight: .bold)).foregroundColor(gold)
                        .rotationEffect(.radians(Double(atan2(rgt, fwd))))
                    Text(distText(hypot(dx, dy))).font(.jk(10, .heavy)).foregroundColor(.white).monospacedDigit()
                }
                .padding(.horizontal, 12).frame(height: 24)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .overlay(Capsule().stroke(gold.opacity(0.5), lineWidth: 1))
            }
        }
    }

    private var jobsButton: some View {
        Button { phoneOpen.toggle() } label: {
            Image(systemName: "iphone").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(red: 0.04, green: 0.08, blue: 0.16).opacity(0.85)))
                .overlay(Circle().stroke(Color(red: 0.3, green: 0.65, blue: 1), lineWidth: 1.8))
                .shadow(color: Color.blue.opacity(0.6), radius: 6)
        }
        .buttonStyle(.plain)
    }

    private func offerRow(_ j: RoamJob) -> some View {
        let active = e.roam.job?.id == j.id
        return HStack(spacing: 10) {
            Image(systemName: j.kind == .drop ? "shippingbox.fill" : (j.kind == .boss ? "crown.fill" : "flag.fill"))
                .font(.system(size: 16, weight: .bold)).foregroundColor(gold).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(j.title).font(.jk(12, .heavy)).foregroundColor(.white)
                Text(j.brief).font(.jk(9, .medium)).foregroundColor(.white.opacity(0.65)).lineLimit(2)
            }
            Spacer(minLength: 6)
            Text("$\(j.reward)").font(.jk(13, .heavy)).foregroundColor(gold)
            Button {
                if active { e.roamAbandon() } else { e.roamAccept(j) }
            } label: {
                Text(active ? "DROP" : "TAKE").font(.jk(10, .heavy)).tracking(1)
                    .foregroundColor(active ? .white : .black).frame(width: 54, height: 26)
                    .background(RoundedRectangle(cornerRadius: 3).fill(active ? Color.white.opacity(0.18) : gold))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(active ? 0.1 : 0.05)))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(active ? gold.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1))
    }

    private var jobsPanel: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "iphone").font(.system(size: 12, weight: .bold)).foregroundColor(gold)
                Text("STREET JOBS").font(.jk(13, .heavy)).tracking(2).foregroundColor(.white)
                Spacer()
                Button { e.roam.jobsOpen = false } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.8))
                        .frame(width: 26, height: 22)
                }.buttonStyle(.plain)
            }
            ForEach(e.roam.offers) { offerRow($0) }
        }
        .padding(12).frame(width: 380)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.55, green: 0.7, blue: 1).opacity(0.25), lineWidth: 1))
    }

    @ObservedObject private var prefs = RoamPrefs.shared
    @State private var settingsOpen = false
    @State private var mapBig = false

    private var gearButton: some View {
        Button { settingsOpen.toggle() } label: {
            Image(systemName: "slider.horizontal.3").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    var body: some View {
        let sc = CGFloat(prefs.scale)
        let left = prefs.mapLeft
        let mapPad: CGFloat = left ? 18 : 64
        let shift: CGFloat = left ? (mapBig ? 250 : 62 + prefs.mapDia - 92) : 0
        return ZStack {
            Group {
            contractCard
                .scaleEffect(sc, anchor: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 18).padding(.top, 62 + shift)
                .allowsHitTesting(false)
            pills
                .scaleEffect(sc, anchor: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                .allowsHitTesting(false)
            VStack(spacing: 5) {
                RoamCompass(e: e)
                tracker
                RoamThreat(e: e)
                RoamEventCard()
                RoamRepToast()
            }
            .scaleEffect(sc, anchor: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 36)
            .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) { jobsButton; gearButton }
                RoamCrewStrip(e: e)
            }
            .scaleEffect(sc, anchor: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 18).padding(.top, 150 + shift)
            RoamMinimap(e: e, size: prefs.mapDia, big: $mapBig)
                .scaleEffect(sc, anchor: left ? .topLeading : .topTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: left ? .topLeading : .topTrailing)
                .padding(left ? .leading : .trailing, mapPad).padding(.top, 8)
            }
            Group {
            if !mapBig {
                RoamFeedView(e: e)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 64).padding(.top, left ? 8 : 122)
                    .allowsHitTesting(false)
            }
            if e.roam.driving < 0 {
                RoamWeaponBar(e: e)
                    .scaleEffect(sc, anchor: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12)
            }
            if prefs.ticker {
                RoamTicker(e: e)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, e.roam.driving < 0 ? 50 : 12)
                    .allowsHitTesting(false)
            }
            RoamCarHUD(e: e)
                .scaleEffect(sc, anchor: .trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
            if phoneOpen {
                RoamPhone(e: e, close: { phoneOpen = false }, openJobs: { phoneOpen = false; e.roam.jobsOpen = true })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing).padding(.trailing, 20)
            }
            if e.roam.jobsOpen {
                jobsPanel.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if settingsOpen {
                RoamHUDSettings { settingsOpen = false }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            }
        }
    }
}

// MARK: - Knocked out + results

struct RoamDown: View {
    let e: TacticalEngine
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 6) {
                Text("K.O.").font(.jk(30, .heavy)).tracking(3).foregroundColor(Color(red: 1, green: 0.3, blue: 0.26))
                Text("Hospital fees took 15% of your cash").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.75))
                if e.me.respawn > 0 && e.me.respawn < 100 {
                    Text("BACK AT THE HIDEOUT IN \(Int(ceil(e.me.respawn)))").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct RoamResults: View {
    let e: TacticalEngine
    let hideout: () -> Void
    let again: () -> Void
    @EnvironmentObject var game: Game

    @State private var coins = 0
    @State private var paid = false
    @State private var shown = false

    private let gold = Color(red: 1, green: 0.8, blue: 0.25)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)

    private func tile(_ u: CGFloat, _ icon: String, _ v: String, _ k: String) -> some View {
        VStack(spacing: 3 * u) {
            HStack(spacing: 5 * u) {
                Image(systemName: icon).font(.system(size: 10 * u, weight: .bold)).foregroundColor(gold)
                Text(k).font(.jk(9 * u, .heavy)).tracking(1.2 * u).foregroundColor(.white.opacity(0.6))
            }
            Text(v).font(.jk(24 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity).frame(height: 66 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private func button(_ u: CGFloat, _ icon: String, _ title: String, primary: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 7 * u) {
                Image(systemName: icon).font(.system(size: 12 * u, weight: .bold))
                Text(title).font(.jk(14 * u, .heavy)).tracking(1.5 * u)
            }
            .foregroundColor(primary ? .white : .white.opacity(0.9)).frame(width: 180 * u, height: 38 * u)
            .background(ChamferShape(cut: 9 * u).fill(primary ? Color(red: 0.2, green: 0.14, blue: 0.04) : Color(red: 0.06, green: 0.08, blue: 0.13)))
            .overlay(ChamferShape(cut: 9 * u).stroke(primary ? gold : edge, lineWidth: primary ? 1.4 : 1))
        }.buttonStyle(.plain)
    }

    var body: some View {
        GeometryReader { g in
            let u = min(g.size.width / 1024, g.size.height / 470)
            let r = e.roam
            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()
                RadialGradient(colors: [gold.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 520).ignoresSafeArea()
                VStack(spacing: 12 * u) {
                    VStack(spacing: 2 * u) {
                        Text("FREE ROAM").font(.jk(11 * u, .heavy)).tracking(3 * u).foregroundColor(gold)
                        Text("OFF THE STREETS").font(.jk(32 * u, .heavy)).italic().tracking(3 * u).foregroundColor(.white)
                            .shadow(color: gold.opacity(0.7), radius: 10 * u)
                    }
                    VStack(spacing: 0) {
                        Text("CASH MADE").font(.jk(10 * u, .heavy)).tracking(2 * u).foregroundColor(.white.opacity(0.55))
                        Text("$\(r.cash)").font(.jk(44 * u, .heavy)).foregroundColor(.white).monospacedDigit()
                        Text("+\(coins) COINS BANKED").font(.jk(9 * u, .heavy)).tracking(1.5 * u).foregroundColor(.black)
                            .padding(.horizontal, 8 * u).frame(height: 15 * u).background(gold)
                    }
                    HStack(spacing: 8 * u) {
                        tile(u, "flag.checkered", "\(r.jobsDone)", "JOBS DONE")
                        tile(u, "person.3.fill", "\(r.crewKOs)", "CREW K.O.")
                        tile(u, "figure.walk", "\(r.civKOs)", "BYSTANDERS")
                        tile(u, "bolt.fill", "x\(r.bestCombo)", "BEST COMBO")
                    }
                    .frame(width: 580 * u)
                    HStack(spacing: 12 * u) {
                        button(u, "house.fill", "HIDEOUT", primary: false, hideout)
                        button(u, "arrow.clockwise", "BACK OUT", primary: true, again)
                    }
                }
                .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 10 * u)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            if !paid { paid = true; coins = game.roamPayout(e) }
            withAnimation(.easeOut(duration: 0.35)) { shown = true }
        }
    }
}

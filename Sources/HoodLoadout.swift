import SwiftUI

// MARK: - REP identity card

struct BlokRepCard: View {
    let u: CGFloat
    @ObservedObject var net = BlokNet.shared
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private static let steps: [Double] = [0, 15, 35, 55, 75, 90, 100]
    private static let titles = ["NOBODY", "NEW FACE", "KNOWN", "RESPECTED", "BLOK LEGEND", "OG"]

    private var progress: (next: String, frac: Double) {
        let r = net.rep.respect
        for i in 1..<Self.steps.count where r < Self.steps[i] {
            let lo = Self.steps[i - 1], hi = Self.steps[i]
            return (i < Self.titles.count ? Self.titles[i] : "MAX", (r - lo) / (hi - lo))
        }
        return ("MAX", 1)
    }

    private var badges: [(String, String)] {
        var b: [(String, String)] = []
        if net.captures > 0 { b.append(("flag.fill", "TAKER")) }
        if net.bossDowns > 0 { b.append(("crown.fill", "BOSS DOWN")) }
        if net.wrecks > 0 { b.append(("car.fill", "WRECKER")) }
        if net.rep.fear > 40 { b.append(("bolt.fill", "FEARED")) }
        if net.rep.trust > 75 { b.append(("heart.fill", "TRUSTED")) }
        return b
    }

    var body: some View {
        let name = UserDefaults.standard.string(forKey: "ab.playername") ?? "MRZEFV"
        let mine = OWDistrict.all.filter { $0.owner == .yours }.count
        let pr = progress
        return VStack(alignment: .leading, spacing: 6 * u) {
            HStack(spacing: 8 * u) {
                ZStack {
                    Circle().fill(orange.opacity(0.2))
                    Text(String(name.prefix(1))).font(.jk(18 * u, .heavy)).foregroundColor(orange)
                }
                .frame(width: 36 * u, height: 36 * u)
                .overlay(Circle().stroke(orange, lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 1 * u) {
                    Text(name.uppercased()).font(.jk(13 * u, .heavy)).tracking(1 * u).foregroundColor(.white)
                    Text(net.rep.title).font(.jk(9 * u, .heavy)).tracking(1.2 * u).foregroundColor(orange)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 2 * u) {
                HStack {
                    Text("NEXT: \(pr.next)").font(.jk(7 * u, .heavy)).tracking(0.8 * u).foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(net.rep.respect)) REP").font(.jk(7 * u, .heavy)).foregroundColor(.white).monospacedDigit()
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(orange).frame(width: 190 * u * CGFloat(max(0.03, pr.frac)))
                }.frame(height: 4 * u)
            }
            HStack(spacing: 10 * u) {
                stat("\(mine)/\(OWDistrict.all.count)", "DISTRICTS")
                stat("\(net.captures)", "TAKEN")
                stat("\(net.bossDowns)", "BOSSES")
                stat("\(Int(net.rep.loyalty))", "LOYALTY")
            }
            if !badges.isEmpty {
                HStack(spacing: 4 * u) {
                    ForEach(badges, id: \.1) { b in
                        HStack(spacing: 3 * u) {
                            Image(systemName: b.0).font(.system(size: 7 * u, weight: .bold))
                            Text(b.1).font(.jk(6.5 * u, .heavy)).tracking(0.5 * u)
                        }
                        .foregroundColor(.black).padding(.horizontal, 5 * u).frame(height: 14 * u)
                        .background(Capsule().fill(orange))
                    }
                }
            }
        }
        .padding(10 * u).frame(width: 210 * u, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5 * u).fill(Color(red: 0.05, green: 0.055, blue: 0.065).opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 5 * u).stroke(orange.opacity(0.45), lineWidth: 1))
    }

    private func stat(_ v: String, _ k: String) -> some View {
        VStack(spacing: 1 * u) {
            Text(v).font(.jk(11 * u, .heavy)).foregroundColor(.white).monospacedDigit()
            Text(k).font(.jk(5.5 * u, .heavy)).tracking(0.5 * u).foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Ready-up / loadout

struct OWLoadoutView: View {
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let wnames = ["FISTS", "BAT", "PISTOL"]
    private let wicons = ["hand.raised.fill", "figure.baseball", "scope"]

    @State private var weapon = UserDefaults.standard.integer(forKey: "ab.loadout.weapon")
    @State private var crewOn = RoamPrefs.crewOn
    @State private var district = 0
    @ObservedObject private var net = BlokNet.shared

    private var owned: Set<Int> { RoamState.loadOwned() }

    private func choose<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4 * u) {
            Text(title).font(.jk(7.5 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.55))
            HStack(spacing: 4 * u) { content() }
        }
    }

    private func chip(_ text: String, icon: String? = nil, on: Bool, locked: Bool = false, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 4 * u) {
                if let i = icon { Image(systemName: locked ? "lock.fill" : i).font(.system(size: 9 * u, weight: .bold)) }
                Text(text).font(.jk(8 * u, .heavy)).tracking(0.5 * u).lineLimit(1)
            }
            .foregroundColor(on ? .black : .white.opacity(locked ? 0.35 : 1))
            .padding(.horizontal, 8 * u).frame(height: 24 * u)
            .background(RoundedRectangle(cornerRadius: 3 * u).fill(on ? orange : Color.white.opacity(0.1)))
        }.buttonStyle(.plain).disabled(locked)
    }

    private func primary(_ title: String, _ sub: String, _ icon: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            HStack(spacing: 10 * u) {
                Image(systemName: icon).font(.system(size: 20 * u, weight: .bold)).foregroundColor(orange).frame(width: 30 * u)
                VStack(alignment: .leading, spacing: 1 * u) {
                    Text(title).font(.jk(16 * u, .heavy)).tracking(1.2 * u).foregroundColor(.white)
                    Text(sub).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.65)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12 * u, weight: .bold)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12 * u).frame(width: 300 * u, height: 54 * u)
            .background(RoundedRectangle(cornerRadius: 5 * u).fill(Color(red: 0.07, green: 0.075, blue: 0.09).opacity(0.94)))
            .overlay(RoundedRectangle(cornerRadius: 5 * u).stroke(orange.opacity(0.55), lineWidth: 1.2))
        }.buttonStyle(TuiPress())
    }

    private func save() {
        UserDefaults.standard.set(weapon, forKey: "ab.loadout.weapon")
        UserDefaults.standard.set(crewOn, forKey: "ab.loadout.crew")
    }

    private func launch(_ pending: OWWorld.Pending?) {
        save()
        OWWorld.pending = pending
        act(.launch(10))
    }

    var body: some View {
        let ds = OWDistrict.all
        let d = ds[min(district, ds.count - 1)]
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.72).ignoresSafeArea()
            Button { act(.screen(0)) } label: {
                HStack(spacing: 5 * u) {
                    Image(systemName: "chevron.left").font(.system(size: 11 * u, weight: .bold))
                    Text("BACK").font(.jk(10 * u, .heavy)).tracking(1 * u)
                }.foregroundColor(.white).padding(.horizontal, 10 * u).frame(height: 26 * u)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain).padding(.leading, 24 * u).padding(.top, 20 * u)

            VStack(alignment: .leading, spacing: 8 * u) {
                Text("READY UP").font(.jk(22 * u, .heavy)).tracking(3 * u).foregroundColor(.white)
                BlokRepCard(u: u)
                choose("LOADOUT") {
                    ForEach(0..<3, id: \.self) { w in
                        chip(wnames[w], icon: wicons[w], on: weapon == w, locked: !owned.contains(w)) { weapon = w }
                    }
                }
                choose("CREW") {
                    chip("BRING CREW", icon: "person.3.fill", on: crewOn) { crewOn = true }
                    chip("SOLO", icon: "person.fill", on: !crewOn) { crewOn = false }
                }
                choose("OUTFIT") {
                    chip("SAFEHOUSE · CHANGE LOOK", icon: "tshirt.fill", on: false) { act(.screen(15)) }
                }
            }
            .padding(.leading, 24 * u).padding(.top, 52 * u)

            VStack(alignment: .trailing, spacing: 8 * u) {
                choose("DISTRICT") {
                    Menu {
                        ForEach(ds) { x in Button("\(x.name) · \(x.control)%") { district = x.id } }
                    } label: {
                        HStack(spacing: 5 * u) {
                            Circle().fill(d.color).frame(width: 7 * u, height: 7 * u)
                            Text("\(d.name) · \(d.control)%").font(.jk(8.5 * u, .heavy)).foregroundColor(.white)
                            Image(systemName: "chevron.down").font(.system(size: 8 * u, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 9 * u).frame(height: 26 * u)
                        .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.white.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(d.color.opacity(0.7), lineWidth: 1))
                    }
                }
                primary("FREE ROAM", "Drop into the city, no strings", "map.fill") { launch(nil) }
                primary("CONTRACTS", "Dead drop in \(d.name)", "doc.text.fill") {
                    launch(OWWorld.Pending(district: d.id, capture: false, kind: .drop))
                }
                primary("TERRITORY WAR", d.owner == .yours ? "Defend \(d.name)" : "Take \(d.name)", "flag.fill") {
                    launch(OWWorld.Pending(district: d.id, capture: d.owner != .yours, kind: .turf))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 24 * u).padding(.top, 20 * u)
        }
        .frame(width: size.width, height: size.height)
        .onAppear { if !owned.contains(weapon) { weapon = 0 } }
    }
}

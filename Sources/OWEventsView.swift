import SwiftUI

// MARK: - EVENTS tab: live event, upcoming events, details and the event calendar
// Event data is sample content until a live-ops backend exists.

struct OWEventsView: View {
    @EnvironmentObject var game: Game
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var side = 0
    @State private var joined = false

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    private let sides: [(String, String, String)] = [
        ("calendar.badge.clock", "LIVE EVENTS", "Active now"), ("star.circle.fill", "SEASONAL", "Limited time"), ("trophy.fill", "TOURNAMENTS", "Competitive"),
        ("target", "CHALLENGES", "Daily & Weekly"), ("star.fill", "SPECIALS", "Exclusive rewards"),
    ]

    private var sidebar: some View {
        VStack(spacing: 2 * u) {
            ForEach(0..<sides.count, id: \.self) { i in
                Button { side = i; if i == 3 { act(.screen(18)) } } label: {
                    HStack(spacing: 9 * u) {
                        Image(systemName: sides[i].0).font(.system(size: 16 * u)).foregroundColor(.white).frame(width: 24 * u)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(sides[i].1).font(.jk(9.5 * u, .heavy)).foregroundColor(.white)
                            Text(sides[i].2).font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        if side == i { Image(systemName: "chevron.right").font(.system(size: 9 * u, weight: .bold)).foregroundColor(.white) }
                    }
                    .padding(.horizontal, 10 * u).frame(height: 40 * u)
                    .background(RoundedRectangle(cornerRadius: 3 * u).fill(side == i ? OW.cyan.opacity(0.45) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(side == i ? OW.cyan : .clear, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        .padding(4 * u).owPanel(u)
    }

    private func goal(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 6 * u) {
            Image(systemName: icon).font(.system(size: 13 * u)).foregroundColor(.white).frame(width: 26 * u, height: 26 * u)
                .background(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            VStack(alignment: .leading, spacing: 0) {
                Text(k).font(.jk(8 * u, .semibold)).foregroundColor(.white)
                Text(v).font(.jk(8 * u, .heavy)).foregroundColor(.white.opacity(0.75))
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            OWArt(w: 560 * u, h: 190 * u, anchor: UnitPoint(x: 0.6, y: 0.3), zoom: 1.5, tint: OW.red.opacity(0.18))
            LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
            AirbladeHero().frame(width: 200 * u, height: 190 * u).offset(x: 190 * u).allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 4 * u) {
                HStack(spacing: 5 * u) {
                    Text("LIVE EVENT").font(.jk(9 * u, .heavy)).foregroundColor(.white).padding(.horizontal, 7 * u).frame(height: 17 * u).background(OW.red)
                    HStack(spacing: 3 * u) { Image(systemName: "clock").font(.system(size: 8 * u)); Text("2d 14h 32m").font(.jk(8 * u, .semibold)) }
                        .foregroundColor(.white).padding(.horizontal, 6 * u).frame(height: 17 * u).background(Color.black.opacity(0.5))
                }
                Text("RIVAL CREW").font(.jk(26 * u, .heavy)).italic().foregroundColor(.white)
                Text("TAKEDOWN").font(.jk(30 * u, .heavy)).italic().foregroundColor(OW.red).offset(y: -6 * u)
                Text("Take down rival crews, hold the zones, earn exclusive rewards.").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.9)).frame(width: 230 * u, alignment: .leading)
                HStack(spacing: 8 * u) {
                    goal("person.crop.circle.badge.xmark", "Eliminate Rival Members", "0/50")
                    goal("crown.fill", "Hold Territory", "0/3")
                    goal("star.fill", "Earn Event Points", "0/10,000")
                }
                Button { joined = true; act(.launch(10)) } label: {
                    HStack(spacing: 6 * u) {
                        Text(joined ? "ENTER EVENT" : "JOIN EVENT").font(.jk(10.5 * u, .heavy))
                        Image(systemName: "chevron.right").font(.system(size: 9 * u, weight: .bold))
                    }
                    .foregroundColor(.black).padding(.horizontal, 16 * u).frame(height: 26 * u).background(RoundedRectangle(cornerRadius: 3 * u).fill(OW.cyan))
                    .shadow(color: OW.cyan.opacity(0.5), radius: 6 * u)
                }.buttonStyle(.plain)
            }
            .padding(10 * u)
            VStack(alignment: .leading, spacing: 2 * u) {
                Text("TOP CREW REWARD").font(.jk(8 * u, .heavy)).foregroundColor(.white)
                ZStack {
                    RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.5))
                    Image(systemName: "person.fill").font(.system(size: 40 * u)).foregroundColor(.white.opacity(0.4))
                }
                .frame(width: 100 * u, height: 78 * u).overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(OW.gold.opacity(0.8), lineWidth: 1))
                Text("RIVAL HUNTER OUTFIT").font(.jk(6.5 * u, .heavy)).foregroundColor(.white)
                Text("LEGENDARY").font(.jk(6.5 * u, .heavy)).foregroundColor(OW.gold)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8 * u)
        }
        .frame(maxWidth: .infinity).frame(height: 190 * u).clipShape(RoundedRectangle(cornerRadius: 4 * u))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(OW.cyan.opacity(0.5), lineWidth: 1.2))
    }

    private func upcoming(_ title: String, _ time: String, _ desc: String, _ tags: [(String, Color)], _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                OWArt(w: 130 * u, h: 62 * u, anchor: UnitPoint(x: 0.5, y: 0.4), zoom: 2.2, tint: tint)
                LinearGradient(colors: [.clear, Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                HStack(spacing: 3 * u) { Image(systemName: "clock").font(.system(size: 7 * u)); Text(time).font(.jk(7.5 * u, .semibold)) }
                    .foregroundColor(.white).padding(.horizontal, 5 * u).frame(height: 14 * u).background(Color.black.opacity(0.55)).padding(5 * u)
                Text(title).font(.jk(13 * u, .heavy)).italic().foregroundColor(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(6 * u)
            }
            .frame(height: 62 * u).clipped()
            Text(desc).font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.8)).lineLimit(2).padding(.horizontal, 6 * u).padding(.top, 4 * u)
            Spacer(minLength: 0)
            HStack(spacing: 4 * u) {
                ForEach(0..<tags.count, id: \.self) { i in
                    Text(tags[i].0).font(.jk(6 * u, .heavy)).foregroundColor(tags[i].1).padding(.horizontal, 5 * u).frame(height: 13 * u)
                        .background(Capsule().fill(tags[i].1.opacity(0.14))).overlay(Capsule().stroke(tags[i].1.opacity(0.8), lineWidth: 1))
                }
            }
            .padding(.horizontal, 6 * u).padding(.bottom, 5 * u)
        }
        .frame(height: 120 * u).owPanel(u)
        .clipShape(RoundedRectangle(cornerRadius: 4 * u))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5 * u) {
            Text("EVENT DETAILS").font(.jk(10 * u, .heavy)).foregroundColor(.white)
            HStack(spacing: 6 * u) {
                Image(systemName: "flame.fill").font(.system(size: 16 * u)).foregroundColor(OW.red)
                Text("RIVAL CREW TAKEDOWN").font(.jk(12 * u, .heavy)).italic().foregroundColor(.white)
            }
            Text("Rival crews are moving in. Work with your crew to take control of their territories, eliminate their members, and claim the rewards.")
                .font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.85))
            row("timer", "Event Duration", "2d 14h 32m")
            row("chart.bar.fill", "Your Progress", "3,240 pts")
            ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.12)); Capsule().fill(OW.cyan).frame(width: 168 * 0.32 * u) }.frame(height: 3.5 * u)
            row("crown.fill", "Rank", "#4")
            Text("REWARDS").font(.jk(9 * u, .heavy)).foregroundColor(OW.cyan).padding(.top, 2 * u)
            HStack(spacing: 4 * u) {
                ForEach(Array(["person.fill", "scope", "shield.lefthalf.filled", "banknote.fill"].enumerated()), id: \.offset) { i, s in
                    Image(systemName: s).font(.system(size: 15 * u)).foregroundColor(.white.opacity(0.85)).frame(maxWidth: .infinity).frame(height: 34 * u)
                        .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.white.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke([OW.gold, OW.purple, OW.gold, OW.edge][i], lineWidth: 1))
                }
            }
            Spacer(minLength: 0)
            OWButton(u: u, icon: nil, title: "VIEW LEADERBOARD", filled: false) { act(.ranks) }
        }
        .padding(9 * u).frame(width: 190 * u).frame(maxHeight: .infinity).owPanel(u)
    }

    private func row(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 6 * u) {
            Image(systemName: icon).font(.system(size: 10 * u)).foregroundColor(.white.opacity(0.8)).frame(width: 16 * u)
            Text(k).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(v).font(.jk(8.5 * u, .heavy)).foregroundColor(.white)
        }
    }

    private var calendar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6 * u) {
                Image(systemName: "calendar").font(.system(size: 11 * u)).foregroundColor(.white.opacity(0.8))
                Text("EVENT CALENDAR").font(.jk(8 * u, .heavy)).foregroundColor(.white.opacity(0.85))
            }
            .frame(width: 100 * u)
            ForEach(Array([("TODAY", "Rival Crew Takedown", "2d 14h", "flame.fill", OW.red), ("TOMORROW", "Race Night", "3d 14h", "flag.checkered", OW.cyan),
                           ("SAT", "Crew Wars", "5d 14h", "crown.fill", OW.purple), ("SUN", "Supply Drop", "1w 2d", "shippingbox.fill", OW.green),
                           ("MON", "King of the Streets", "1w 5d", "crown.fill", OW.gold)].enumerated()), id: \.offset) { i, e in
                VStack(alignment: .leading, spacing: 1 * u) {
                    Text(e.0).font(.jk(6.5 * u, .heavy)).foregroundColor(i == 0 ? OW.cyan : .white.opacity(0.6))
                    HStack(spacing: 5 * u) {
                        Image(systemName: e.3).font(.system(size: 12 * u)).foregroundColor(e.4)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(e.1).font(.jk(7.5 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                            Text(e.2).font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 8 * u).frame(maxWidth: .infinity, alignment: .leading).frame(height: 36 * u)
                .background(RoundedRectangle(cornerRadius: 3 * u).fill(i == 0 ? OW.cyan.opacity(0.12) : .clear))
                .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(i == 0 ? OW.cyan : .clear, lineWidth: 1))
            }
        }
        .frame(height: 42 * u).owPanel(u)
    }

    var body: some View {
        OWScreen(t: t, u: u, selected: 5, act: act) {
            VStack(spacing: 6 * u) {
                HStack(alignment: .top, spacing: 8 * u) {
                    VStack(spacing: 6 * u) { sidebar; Spacer(minLength: 0) }.frame(width: 140 * u)
                    VStack(alignment: .leading, spacing: 5 * u) {
                        hero
                        Text("UPCOMING EVENTS").font(.jk(9 * u, .heavy)).foregroundColor(.white)
                        HStack(spacing: 6 * u) {
                            upcoming("RACE NIGHT", "3d 14h", "Win races, earn cash and exclusive vehicle skins.", [("PVP", OW.red), ("RACING", OW.green)], OW.purple.opacity(0.3))
                            upcoming("CREW WARS", "5d 14h", "Compete against other crews for territory and rewards.", [("PVP", OW.red), ("TERRITORY", OW.green)], OW.purple.opacity(0.3))
                            upcoming("SUPPLY DROP", "1w 2d", "Secure supply drops around the city for rare loot.", [("PVE", OW.cyan), ("LOOT", OW.green)], OW.cyan.opacity(0.2))
                            upcoming("KING OF THE STREETS", "1w 5d", "Complete challenges and climb the leaderboard.", [("PVP", OW.red), ("LEADERBOARD", OW.gold)], OW.gold.opacity(0.3))
                        }
                        Spacer(minLength: 0)
                    }
                    details
                }
                calendar
            }
            .padding(.horizontal, 12 * u).padding(.top, 8 * u).padding(.bottom, 8 * u)
        }
        .frame(width: size.width, height: size.height)
    }
}

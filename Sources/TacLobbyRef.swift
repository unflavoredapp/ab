import SwiftUI

/// Maps the lobby offers, open-air ones first (town, warehouse yard), then the indoor ones.
enum TacLobbyMaps {
    static let ids = [3]
    static let fallback = 3

    private static let names = ["THE HOUSE", "THE WOODS", "WAREHOUSE", "TOWN", "HARBOR COMPLEX", "CUSTOM MAP", "BLOCK 9", "ANNEX", "TOWN", "DUEL ARENA"]

    static func title(_ k: Int) -> String {
        names.indices.contains(k) ? names[k] : "TOWN"
    }
}

/// HIDEOUT page: the character stands in the hideout, news and profile on the left, QUICK START at
/// the bottom left, character slots along the bottom, currency and level across the top.
/// rectangle with two cut corners (top-left and bottom-right), the shape of the lobby buttons
struct ChamferShape: Shape {
    var cut: CGFloat = 8
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + cut, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut)); p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.minY + cut)); p.closeSubpath()
        return p
    }
}

/// the hero's face cut from the character art, for slots and profile tiles
struct HeroFace: View {
    let s: CGFloat
    var body: some View {
        let fw = s * 3.4, fh = fw * 670 / 331
        Image("HeroFront").resizable().frame(width: fw, height: fh)
            .offset(x: fw * (0.5 - 154 / 331), y: fh * (0.5 - 62 / 670))
            .frame(width: s, height: s).clipped()
    }
}

/// HIDEOUT page laid out like the GunZ hideout: a thin top bar, two news cards top-left, the clan card
/// and QUICK START bottom-left, the character standing on the floor, a small slot bar under her feet.
/// Every size is in GunZ pixels (1024x576 reference) times `u`.
struct LobbyHome: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void

    @State private var showChallenges = false

    private let blue = Color(red: 0.25, green: 0.65, blue: 1.0)
    private let discord = Color(red: 0.345, green: 0.396, blue: 0.949)

    private var W: CGFloat { size.width }
    private var H: CGFloat { size.height }
    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    // MARK: top bar

    private func currency(_ letter: String, _ value: String, _ ring: Color) -> some View {
        HStack(spacing: 5 * u) {
            Text(letter).font(.jk(7 * u, .heavy)).foregroundColor(ring)
                .frame(width: 15 * u, height: 15 * u)
                .overlay(Circle().stroke(ring, lineWidth: 1.2))
            Text(value).font(.jk(10 * u, .semibold)).foregroundColor(.white.opacity(0.9)).monospacedDigit().fixedSize()
        }
    }

    private func topNav(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(13 * u, .semibold)).foregroundColor(selected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 20 * u).frame(height: 40 * u)
                .background(selected ? Color.white.opacity(0.09) : Color.clear)
        }.buttonStyle(.plain)
    }

    private func subNav(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(10.5 * u, selected ? .heavy : .semibold)).foregroundColor(selected ? .white : .white.opacity(0.42))
                .padding(.horizontal, 12 * u).frame(height: 22 * u)
        }.buttonStyle(.plain)
    }

    private func icon(_ name: String, dot: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13 * u, weight: .regular)).foregroundColor(.white.opacity(0.7))
                .frame(width: 30 * u, height: 30 * u)
                .overlay(alignment: .topTrailing) {
                    if dot { Circle().fill(Color.red).frame(width: 5 * u, height: 5 * u).offset(x: -6 * u, y: 6 * u) }
                }
        }.buttonStyle(.plain)
    }

    private var profileTile: some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return Button { act(.ranks) } label: {
            HStack(spacing: 7 * u) {
                BladeEmblem().frame(width: 22 * u, height: 25 * u).padding(3 * u)
                    .background(Color(red: 0.25, green: 0.05, blue: 0.07)).overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2 * u) {
                    HStack(spacing: 6 * u) {
                        Text("Lv. \(ri + 1)").font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.75)).fixedSize()
                        Text(TacProfile.name.uppercased()).font(.jk(9.5 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                    }
                    HStack(spacing: 4 * u) {
                        Text("EXP \(Int(TacRank.progress(xp) * 100))%").font(.jk(7.5 * u, .semibold)).foregroundColor(.white.opacity(0.6)).fixedSize()
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.15))
                            Rectangle().fill(blue).frame(width: 60 * u * CGFloat(TacRank.progress(xp)))
                        }
                        .frame(width: 60 * u, height: 3 * u)
                    }
                }
                .frame(width: 100 * u, alignment: .leading)
            }
            .padding(.horizontal, 6 * u).frame(height: 34 * u)
            .background(Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                AirbladeLogo(size: 15 * u).padding(.leading, 26 * u).padding(.trailing, 14 * u)
                topNav("HideOut", selected: true) { act(.nav(0)) }
                topNav("Play") { act(.screen(1)) }
                topNav("Shop") { act(.nav(6)) }
                topNav("Event") { act(.season(0)) }
                Spacer(minLength: 6 * u)
                HStack(spacing: 22 * u) {
                    currency("C", game.s.ex.gems.formatted(), Color(red: 1, green: 0.75, blue: 0.22))
                    currency("ZC", "\(t.rating)", Color(red: 0.4, green: 0.7, blue: 1))
                }
                .padding(.trailing, 24 * u)
                profileTile
                HStack(spacing: 2 * u) {
                    icon("person.2.fill") { act(.friends) }
                    icon("envelope.fill", dot: true) { act(.friends) }
                    icon("gearshape.fill") { act(.stats) }
                }
                .padding(.leading, 10 * u).padding(.trailing, 14 * u)
            }
            .frame(height: 40 * u)
            .background(LinearGradient(colors: [Color.black.opacity(0.62), Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
            HStack(spacing: 0) {
                subNav("Lobby", selected: true) { act(.nav(0)) }
                subNav("Record") { act(.stats) }
                subNav("Achievements") { withAnimation(.easeOut(duration: 0.15)) { showChallenges.toggle() } }
                Spacer()
            }
            .padding(.leading, 98 * u).padding(.top, 4 * u)
        }
    }

    // MARK: character

    private var hero: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color.black.opacity(0.6), .clear], center: .center, startRadius: 2, endRadius: W * 0.11))
                .frame(width: W * 0.22, height: H * 0.07)
                .position(x: W * 0.53, y: H * 0.945)
            AirbladeHero()
                .frame(width: W * 0.42, height: H * 0.95)
                .position(x: W * 0.53, y: H * 0.545)
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }

    // MARK: left column

    private func pageDots(_ on: Int, _ n: Int) -> some View {
        HStack(spacing: 4 * u) {
            ForEach(0..<n, id: \.self) { k in
                Circle().fill(Color.white.opacity(k == on ? 0.9 : 0.3)).frame(width: 4 * u, height: 4 * u)
            }
        }
    }

    private var websiteCard: some View {
        VStack(spacing: 4 * u) {
            AirbladeLogo(size: 16 * u)
            HStack(spacing: 4 * u) {
                Text("AIRBLADE Official Website").font(.jk(10 * u, .heavy)).italic().foregroundColor(.white).fixedSize()
                Image(systemName: "arrow.up.right.square").font(.system(size: 8 * u, weight: .bold)).foregroundColor(.white.opacity(0.85))
            }
            pageDots(0, 2)
        }
        .frame(width: 198 * u, height: 70 * u)
        .background(LinearGradient(colors: [Color(white: 0.33).opacity(0.75), Color(white: 0.16).opacity(0.75)], startPoint: .top, endPoint: .bottom))
        .overlay(Rectangle().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }

    private var discordCard: some View {
        Button { } label: {
            VStack(spacing: 8 * u) {
                Image(systemName: "gamecontroller.fill").font(.system(size: 22 * u, weight: .bold))
                Text("JOIN OFFICIAL DISCORD").font(.jk(15 * u, .heavy)).italic().fixedSize()
            }
            .foregroundColor(.white).frame(width: 198 * u, height: 104 * u)
            .background(discord)
        }.buttonStyle(.plain)
    }

    private var clanCard: some View {
        let ri = TacRank.index(TacRank.totalXP(t))
        return Button { act(.ranks) } label: {
            HStack(spacing: 10 * u) {
                BladeEmblem().frame(width: 36 * u, height: 40 * u)
                    .frame(width: 52 * u, height: 52 * u)
                    .background(Color(red: 0.2, green: 0.05, blue: 0.06))
                VStack(alignment: .leading, spacing: 3 * u) {
                    Text(TacProfile.name).font(.jk(10.5 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text("Rank : \(TacRank.ranks[ri].name)").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                    Text("\(t.wins)W \(t.losses)L  ·  \(t.kills) K").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                    pageDots(0, 2).padding(.top, 1 * u)
                }
                Spacer(minLength: 0)
            }
            .padding(5 * u).frame(width: 198 * u, height: 62 * u)
            .background(Color(red: 0.06, green: 0.07, blue: 0.08).opacity(0.82))
            .overlay(Rectangle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var quickStart: some View {
        Button { act(.screen(2)) } label: {
            Text("QUICK START").font(.jk(12.5 * u, .heavy)).foregroundColor(.white)
                .frame(width: 198 * u, height: 32 * u)
                .background(LinearGradient(colors: [Color(red: 0.2, green: 0.45, blue: 0.62), Color(red: 0.12, green: 0.3, blue: 0.45)], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: bottom

    private func slot(_ k: Int, selected: Bool) -> some View {
        Button { act(.avatar) } label: {
            ZStack {
                Rectangle().fill(Color.black.opacity(0.55))
                if k == 0 {
                    HeroFace(s: 26 * u)
                } else {
                    Image(systemName: "person.fill").font(.system(size: 14 * u)).foregroundColor(.white.opacity(0.35))
                }
            }
            .frame(width: 28 * u, height: 28 * u)
            .overlay(Rectangle().stroke(selected ? Color(red: 0.92, green: 0.15, blue: 0.15) : Color.white.opacity(0.28), lineWidth: selected ? 1.6 : 1))
        }.buttonStyle(TuiPress())
    }

    private var slotBar: some View {
        HStack(spacing: 10 * u) {
            slot(0, selected: true)
            slot(1, selected: false)
            slot(2, selected: false)
            Button { act(.avatar) } label: {
                Image(systemName: "plus").font(.system(size: 13 * u, weight: .light)).foregroundColor(.white.opacity(0.55))
                    .frame(width: 28 * u, height: 28 * u)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.28), lineWidth: 1))
            }.buttonStyle(TuiPress())
        }
        .position(x: W * 0.51, y: H - 34 * u)
    }

    private var cornerIcons: some View {
        HStack(spacing: 14 * u) {
            Image(systemName: "trash").font(.system(size: 12 * u))
            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 12 * u))
            Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 12 * u))
        }
        .foregroundColor(.white.opacity(0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 22 * u).padding(.bottom, 12 * u)
        .allowsHitTesting(false)
    }

    // MARK: challenges

    private func challenge(_ title: String, _ have: Int, _ need: Int, _ xp: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 2.5)
                Circle().trim(from: 0, to: CGFloat(have) / CGFloat(max(1, need)))
                    .stroke(blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.jk(11, .semibold)).foregroundColor(.white).lineLimit(1)
                Text("\(have)/\(need)").font(.jk(9, .medium)).foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Text("\(xp) XP").font(.jk(10, .heavy)).foregroundColor(blue)
        }
        .padding(.horizontal, 10).frame(height: 38)
    }

    private var challengePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DAILY CHALLENGES").font(.jk(11, .heavy)).foregroundColor(.white)
                Spacer()
                Text("RESETS 12h").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 10).frame(height: 28)
            challenge("Get 25 Kills", t.kills % 25, 25, 1000)
            challenge("Win 3 Matches", t.wins % 3, 3, 1500)
            challenge("Play 5 Matches", (t.wins + t.losses) % 5, 5, 1000)
        }
        .frame(width: 250)
        .background(Color(red: 0.04, green: 0.05, blue: 0.05).opacity(0.94))
        .overlay(Rectangle().stroke(blue.opacity(0.6), lineWidth: 1))
    }

    // MARK: body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // the hero stands in the 3D hideout behind this page (HideoutBackdrop in Lobby.swift)

            VStack(alignment: .leading, spacing: 5 * u) {
                websiteCard
                discordCard
            }
            .padding(.leading, 27 * u).padding(.top, 104 * u)

            VStack(alignment: .leading, spacing: 8 * u) {
                Spacer(minLength: 0)
                clanCard
                quickStart
            }
            .padding(.leading, 27 * u).padding(.bottom, 52 * u)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Text("Version 1.0").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 6 * u).padding(.bottom, 4 * u)
                .allowsHitTesting(false)

            slotBar
            cornerIcons
            topBar

            if showChallenges {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { showChallenges = false }
                challengePanel.frame(maxWidth: .infinity, maxHeight: .infinity).transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if ![0, 1, 5, 8].contains(nav.tacMode) { nav.tacMode = 8 }
            if !TacLobbyMaps.ids.contains(nav.tacMap) { nav.tacMap = TacLobbyMaps.fallback }
        }
    }
}

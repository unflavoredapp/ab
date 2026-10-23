import SwiftUI

/// Maps the lobby offers, open-air ones first (town, warehouse yard), then the indoor ones.
enum TacLobbyMaps {
    static let ids = [3]
    static let fallback = 3

    private static let names = ["THE HOUSE", "THE WOODS", "WAREHOUSE", "TOWN", "HARBOR COMPLEX", "CUSTOM MAP", "BLOCK 9", "ANNEX", "TOWN", "DUEL ARENA", "HOODBLOK CITY"]

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
/// HIDEOUT page, laid out like the open-world mockup: your turf and the main menu on the left, the hero in
/// the middle (drawn by the backdrop), war countdown / daily challenges / crew activity on the right,
/// four mode tiles bottom-left and PLAY NOW bottom-right.
struct LobbyHome: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void

    @State private var tile = 0          // 0 free roam, 1 contracts, 2 territory war, 3 crew ops
    @State private var party = 0         // solo / duo / squad (cosmetic until online play exists)

    private let blue = Color(red: 0.25, green: 0.65, blue: 1.0)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.78)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.22)
    private var W: CGFloat { size.width }
    private var H: CGFloat { size.height }
    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    private struct Tile { let title: String; let icon: String; let anchor: UnitPoint; let zoom: CGFloat }
    private let tiles = [
        Tile(title: "FREE ROAM", icon: "mappin.and.ellipse", anchor: UnitPoint(x: 0.3, y: 0.25), zoom: 2.4),
        Tile(title: "CONTRACTS", icon: "doc.text.fill", anchor: UnitPoint(x: 0.82, y: 0.4), zoom: 2.6),
        Tile(title: "TERRITORY WAR", icon: "crown.fill", anchor: UnitPoint(x: 0.5, y: 0.5), zoom: 2.0),
        Tile(title: "CREW OPS", icon: "person.3.fill", anchor: UnitPoint(x: 0.2, y: 0.8), zoom: 2.4),
    ]

    private func art(_ w: CGFloat, _ h: CGFloat, anchor: UnitPoint = .center, zoom: CGFloat = 1) -> some View {
        ZStack {
            if let bg = HideoutBackdrop.userBg {
                Image(uiImage: bg).resizable().scaledToFill().frame(width: w, height: h)
                    .scaleEffect(zoom, anchor: anchor).clipped()
            } else {
                LinearGradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.22), Color(red: 0.03, green: 0.04, blue: 0.08)], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: w, height: h).clipped()
    }

    // MARK: left column

    private var turf: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR TURF").font(.jk(9 * u, .semibold)).tracking(0.5 * u).foregroundColor(.white.opacity(0.75))
                .padding(.leading, 10 * u).frame(width: 210 * u, height: 17 * u, alignment: .leading).background(glass)
            ZStack(alignment: .bottomLeading) {
                art(210 * u, 80 * u, anchor: UnitPoint(x: 0.35, y: 0.2), zoom: 2.2)
                LinearGradient(colors: [.clear, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text("RIVERSIDE").font(.jk(17 * u, .heavy)).foregroundColor(.white)
                    HStack(spacing: 3 * u) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 7.5 * u)).foregroundColor(.white)
                        Text("OWNED BY: YOUR CREW").font(.jk(7.5 * u, .semibold)).foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.leading, 9 * u).padding(.bottom, 6 * u)
            }
            .frame(width: 210 * u, height: 80 * u)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4 * u))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private func menuRow(_ icon: String, _ title: String, _ sub: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            HStack(spacing: 10 * u) {
                Image(systemName: icon).font(.system(size: 17 * u, weight: .regular)).foregroundColor(.white.opacity(0.88)).frame(width: 28 * u)
                VStack(alignment: .leading, spacing: 1 * u) {
                    Text(title).font(.jk(13 * u, .heavy)).foregroundColor(.white)
                    Text(sub).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9 * u, weight: .semibold)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 10 * u).frame(width: 210 * u, height: 43 * u)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
        }.buttonStyle(TuiPress())
    }

    private var menu: some View {
        VStack(spacing: 4 * u) {
            menuRow("scope", "PLAY", "Free Roam / Missions") { act(.launch(10)) }
            menuRow("flag.2.crossed.fill", "TERRITORY WAR", "Fight for control") { act(.launch(5)) }
            menuRow("person.3.fill", "CREW", "Recruit / Manage") { act(.screen(20)) }
            menuRow("house.fill", "SAFEHOUSE", "Upgrade / Customize") { act(.screen(15)) }
        }
    }

    private func tileView(_ i: Int) -> some View {
        let on = tile == i
        let d = tiles[i]
        return Button {
            tile = i
            if i == 1 { act(.screen(16)) }
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    art(104 * u, 36 * u, anchor: d.anchor, zoom: d.zoom)
                    LinearGradient(colors: [.clear, Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
                HStack(spacing: 5 * u) {
                    Image(systemName: d.icon).font(.system(size: 9 * u, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                    Text(d.title).font(.jk(8.5 * u, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 7 * u).frame(width: 104 * u, height: 22 * u)
                .background(Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.92))
            }
            .frame(width: 104 * u, height: 58 * u)
            .clipShape(RoundedRectangle(cornerRadius: 3 * u))
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(on ? blue : edge, lineWidth: on ? 1.5 : 1))
            .shadow(color: on ? blue.opacity(0.5) : .clear, radius: 5 * u)
        }.buttonStyle(.plain)
    }

    // MARK: right column

    private func panelTitle(_ s: String) -> some View {
        Text(s).font(.jk(10 * u, .heavy)).tracking(0.3 * u).foregroundColor(.white.opacity(0.92))
    }

    /// BLOK PHONE preview: latest BLOKUP post, unread BLOKCHAT, newest BLOK WATCH alert
    private var phonePreview: some View {
        BlokPhonePreview(u: u, glass: glass, edge: edge) { act(.screen(19)) }
    }

    private var warPanel: some View {
        Button { act(.launch(5)) } label: {
            HStack(spacing: 8 * u) {
                VStack(alignment: .leading, spacing: 4 * u) {
                    panelTitle("NEXT TERRITORY WAR")
                    HStack(spacing: 4 * u) {
                        Image(systemName: "clock").font(.system(size: 8 * u)).foregroundColor(.white.opacity(0.8))
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let period: Double = 3 * 3600
                            let left = period - ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
                            let s = Int(left)
                            Text(String(format: "%02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60))
                                .font(.jk(10 * u, .semibold)).monospacedDigit().foregroundColor(.white)
                        }
                    }
                    HStack(spacing: 6 * u) {
                        Image(systemName: "crown.fill").font(.system(size: 14 * u)).foregroundColor(.white.opacity(0.85))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("RIVERSIDE VS").font(.jk(8 * u, .heavy)).foregroundColor(.white)
                            Text("KANE GANG").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                Spacer(minLength: 0)
                art(60 * u, 54 * u, anchor: UnitPoint(x: 0.5, y: 0.3), zoom: 2.4)
                    .clipShape(RoundedRectangle(cornerRadius: 2 * u))
            }
            .padding(.horizontal, 9 * u).frame(width: 190 * u, height: 72 * u)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func challengeRow(_ icon: String, _ text: String, _ have: Int, _ need: Int) -> some View {
        HStack(spacing: 8 * u) {
            Image(systemName: icon).font(.system(size: 12 * u)).foregroundColor(.white.opacity(0.8)).frame(width: 20 * u)
            Text(text).font(.jk(9 * u, .medium)).foregroundColor(.white.opacity(0.92)).lineLimit(2)
            Spacer(minLength: 2 * u)
            Text("\(have)/\(need)").font(.jk(9.5 * u, .heavy)).monospacedDigit().foregroundColor(.white)
        }
        .frame(height: 28 * u)
    }

    private var challengesPanel: some View {
        let rec = ABRecords.load()
        return Button { act(.screen(18)) } label: {
            VStack(alignment: .leading, spacing: 2 * u) {
                panelTitle("DAILY CHALLENGES")
                challengeRow("figure.boxing", "Win 2\nMatches", t.wins % 2, 2)
                challengeRow("scope", "Get 10\nHeadshots", rec.headKills % 10, 10)
                challengeRow("flag.fill", "Play 3\nMatches", (t.wins + t.losses) % 3, 3)
            }
            .padding(.horizontal, 9 * u).padding(.vertical, 7 * u).frame(width: 190 * u, height: 115 * u, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func crewRow(_ name: String, _ what: String, _ ago: String) -> some View {
        HStack(spacing: 6 * u) {
            Text(String(name.prefix(1))).font(.jk(8 * u, .heavy)).foregroundColor(.white)
                .frame(width: 18 * u, height: 18 * u).background(Circle().fill(Color.white.opacity(0.16)))
                .overlay(alignment: .bottomTrailing) { Circle().fill(Color.green).frame(width: 5 * u, height: 5 * u) }
            (Text(name).foregroundColor(blue) + Text(" \(what)").foregroundColor(.white.opacity(0.8)))
                .font(.jk(7.5 * u, .medium)).lineLimit(1)
            Spacer(minLength: 2 * u)
            Text(ago).font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.5))
        }
        .frame(height: 22 * u)
    }

    private var crewPanel: some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return Button { act(.screen(20)) } label: {
            VStack(alignment: .leading, spacing: 3 * u) {
                panelTitle("CREW ACTIVITY")
                HStack(spacing: 8 * u) {
                    BladeEmblem().frame(width: 22 * u, height: 25 * u)
                    VStack(alignment: .leading, spacing: 3 * u) {
                        Text("\(TacProfile.name.uppercased()) CREW").font(.jk(8.5 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                        HStack {
                            Text("Lv. \(ri + 1)").font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(Int(TacRank.progress(xp) * 100))%").font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.7))
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.14))
                            Capsule().fill(blue).frame(width: 118 * u * CGFloat(TacRank.progress(xp)))
                        }
                        .frame(width: 118 * u, height: 3 * u)
                    }
                }
                .padding(.vertical, 3 * u)
                Rectangle().fill(edge).frame(height: 1)
                crewRow("Jax", "joined the crew", "2h ago")
                crewRow("Nova", "is online", "3h ago")
            }
            .padding(.horizontal, 9 * u).padding(.vertical, 7 * u).frame(width: 190 * u, height: 115 * u, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var partyPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(["SOLO", "DUO", "SQUAD"].enumerated()), id: \.offset) { i, s in
                Button { party = i } label: {
                    Text(s).font(.jk(8.5 * u, .heavy)).foregroundColor(party == i ? .white : .white.opacity(0.7))
                        .frame(maxWidth: .infinity).frame(height: 20 * u)
                        .background(party == i ? Color(red: 0.4, green: 0.5, blue: 0.7).opacity(0.7) : .clear)
                }.buttonStyle(.plain)
            }
        }
        .frame(width: 204 * u).background(glass)
        .overlay(RoundedRectangle(cornerRadius: 2 * u).stroke(edge, lineWidth: 1))
    }

    private var playNow: some View {
        Button {
            switch tile {
            case 1: act(.screen(16))
            case 2: act(.launch(5))
            case 3: act(.launch(1))
            default: act(.launch(10))
            }
        } label: {
            HStack {
                Spacer()
                Text("PLAY NOW").font(.jk(18 * u, .heavy)).tracking(1 * u).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13 * u, weight: .bold)).foregroundColor(.white).padding(.trailing, 14 * u)
            }
            .frame(width: 204 * u, height: 40 * u)
            .background(RoundedRectangle(cornerRadius: 6 * u).fill(LinearGradient(colors: [Color(red: 0.08, green: 0.13, blue: 0.22), Color(red: 0.03, green: 0.06, blue: 0.12)], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 6 * u).stroke(Color(red: 0.55, green: 0.7, blue: 1).opacity(0.7), lineWidth: 1.4))
            .shadow(color: blue.opacity(0.35), radius: 8 * u)
        }.buttonStyle(TuiPress())
    }

    // MARK: body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // the hero stands in the hideout behind this page (HideoutBackdrop in Lobby.swift); tap him to inspect
            Color.clear.contentShape(Rectangle())
                .frame(width: W * 0.2, height: H * 0.62)
                .position(x: W * 0.5, y: H * 0.55)
                .onTapGesture { act(.screen(17)) }

            VStack(alignment: .leading, spacing: 6 * u) {
                turf
                menu
            }
            .padding(.leading, 27 * u).padding(.top, 52 * u)

            VStack(alignment: .trailing, spacing: 5 * u) {
                phonePreview
                warPanel
                challengesPanel
                crewPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 20 * u).padding(.top, 52 * u)

            HStack(spacing: 6 * u) { ForEach(0..<4, id: \.self) { tileView($0) } }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 27 * u).padding(.bottom, 24 * u)

            VStack(alignment: .trailing, spacing: 6 * u) {
                partyPicker
                playNow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20 * u).padding(.bottom, 20 * u)

            HStack(spacing: 4 * u) {
                Image(systemName: "globe").font(.system(size: 7 * u))
                Text("Version 1.0.0").font(.jk(7.5 * u, .medium))
            }
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 27 * u).padding(.bottom, 7 * u)
            .allowsHitTesting(false)

            LobbyTopBar(t: t, u: u, selected: 0, act: act)
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if ![0, 1, 5, 8, 9, 10].contains(nav.tacMode) { nav.tacMode = 10 }
            if !TacLobbyMaps.ids.contains(nav.tacMap) && !(nav.tacMap == 10 && nav.tacMode == 10) { nav.tacMap = TacLobbyMaps.fallback }
        }
    }
}


struct BlokPhonePreview: View {
    let u: CGFloat
    let glass: Color
    let edge: Color
    let open: () -> Void
    @ObservedObject var net = BlokNet.shared
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)

    private func row(_ icon: String, _ tag: String, _ text: String, _ badge: Int = 0) -> some View {
        HStack(spacing: 5 * u) {
            Image(systemName: icon).font(.system(size: 8 * u, weight: .bold)).foregroundColor(orange).frame(width: 11 * u)
            VStack(alignment: .leading, spacing: 0) {
                Text(tag).font(.jk(6.5 * u, .heavy)).tracking(0.8 * u).foregroundColor(.white.opacity(0.55))
                Text(text).font(.jk(7.5 * u, .semibold)).foregroundColor(.white).lineLimit(1)
            }
            Spacer(minLength: 0)
            if badge > 0 {
                Text("\(badge)").font(.jk(7 * u, .heavy)).foregroundColor(.black)
                    .frame(minWidth: 12 * u, minHeight: 12 * u).background(Circle().fill(orange))
            }
        }
    }

    var body: some View {
        let post = net.posts.first
        let unread = net.threads.reduce(0) { $0 + $1.unread }
        let msg = net.threads.first(where: { $0.unread > 0 })
        let alert = net.alerts.first
        return Button(action: open) {
            VStack(alignment: .leading, spacing: 4 * u) {
                HStack {
                    Text("BLOK PHONE").font(.jk(9 * u, .heavy)).tracking(0.6 * u).foregroundColor(.white.opacity(0.92))
                    Spacer()
                    Image(systemName: "iphone").font(.system(size: 9 * u)).foregroundColor(orange)
                }
                row("camera.fill", "BLOKUP", post.map { "@\($0.handle): \($0.text)" } ?? "No posts yet")
                row("bubble.left.fill", "BLOKCHAT", msg.map { "\($0.id): \($0.msgs.last?.text ?? "")" } ?? "No new messages", unread)
                row("eye.fill", "BLOK WATCH", alert?.text ?? "All quiet")
            }
            .padding(.horizontal, 9 * u).padding(.vertical, 6 * u).frame(width: 190 * u)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

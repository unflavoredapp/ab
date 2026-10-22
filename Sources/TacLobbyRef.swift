import SwiftUI

/// Maps the lobby offers, open-air ones first (town, warehouse yard), then the indoor ones.
enum TacLobbyMaps {
    static let ids = [3]
    static let fallback = 3

    private static let names = ["THE HOUSE", "THE WOODS", "WAREHOUSE", "TOWN", "HARBOR COMPLEX", "CUSTOM MAP", "BLOCK 9", "ANNEX"]

    static func title(_ k: Int) -> String {
        names.indices.contains(k) ? names[k] : "TOWN"
    }
}

/// HIDEOUT page: the character stands in the hideout, news and profile on the left, QUICK START at
/// the bottom left, character slots along the bottom, currency and level across the top.
struct LobbyHome: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void

    @State private var showChallenges = false

    private let blue = Color(red: 0.25, green: 0.65, blue: 1.0)
    private let modeIds = [8, 0, 1, 5]
    private let modeTitles = [8: "DUEL", 0: "TACTICAL", 1: "TDM", 5: "CONTROL"]
    private let diffNames = ["EASY", "NORMAL", "HARD"]

    private func cycle(_ ids: [Int], _ cur: Int) -> Int {
        let i = ids.firstIndex(of: cur) ?? 0
        return ids[(i + 1) % ids.count]
    }

    // MARK: top bar

    private func currency(_ letter: String, _ value: String, _ ring: Color) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.jk(13, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
            Text(letter).font(.jk(10, .heavy)).foregroundColor(.white)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(ring, lineWidth: 1.5))
        }
    }

    private func topNav(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(12, selected ? .heavy : .semibold)).foregroundColor(selected ? .white : .white.opacity(0.66))
                .padding(.horizontal, 11).frame(height: 48)
                .background(selected ? Color.white.opacity(0.07) : Color.clear)
                .overlay(alignment: .bottom) { Rectangle().fill(selected ? blue : .clear).frame(height: 2) }
        }.buttonStyle(.plain)
    }

    private func subNav(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(10, selected ? .heavy : .medium)).foregroundColor(selected ? .white : .white.opacity(0.55))
                .padding(.horizontal, 14).frame(height: 31)
                .overlay(alignment: .bottom) { Rectangle().fill(selected ? Color.blue : .clear).frame(height: 2) }
        }.buttonStyle(.plain)
    }

    private var topBar: some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return HStack(spacing: 0) {
            AirbladeLogo(size: 19).padding(.horizontal, 14)
            Rectangle().fill(Color.white.opacity(0.16)).frame(width: 1, height: 26)
            HStack(spacing: 0) {
                topNav("HideOut", selected: true) { act(.nav(0)) }
                topNav("Play") { act(.screen(1)) }
                topNav("Shop") { act(.nav(6)) }
                topNav("Event") { act(.season(0)) }
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                currency("C", game.s.ex.gems.formatted(), Color(red: 1, green: 0.75, blue: 0.22))
                currency("ZC", "\(t.rating)", Color(red: 0.25, green: 0.7, blue: 1))
                Button { act(.ranks) } label: {
                    HStack(spacing: 8) {
                        PortraitAvatar(key: TacAvatar.myKey, size: 34, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)
                            .clipShape(Rectangle()).overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TacProfile.name.uppercased()).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1)
                            HStack(spacing: 5) {
                                Text("Lv. \(ri + 1)").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7))
                                Text("EXP \(Int(TacRank.progress(xp) * 100))%").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7))
                            }
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.13))
                                Rectangle().fill(Color.blue).frame(width: 84 * CGFloat(TacRank.progress(xp)))
                            }
                            .frame(width: 84, height: 3)
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.black.opacity(0.24))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }.buttonStyle(.plain)
                Button { act(.stats) } label: { Image(systemName: "gearshape.fill").font(.system(size: 17)).foregroundColor(.white.opacity(0.8)).frame(width: 28, height: 32) }.buttonStyle(.plain)
            }.padding(.trailing, 10)
        }
        .frame(height: 48)
        .background(Color.black.opacity(0.22))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
    }

    // MARK: character

    private var hero: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color.black.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: size.width * 0.15))
                .frame(width: size.width * 0.3, height: size.height * 0.09)
                .position(x: size.width * 0.53, y: size.height * 0.9)
            AirbladeHero()
                .frame(width: size.width * 0.36, height: size.height * 0.9)
                .position(x: size.width * 0.53, y: size.height * 0.53)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: left column

    private var seasonBanner: some View {
        VStack(spacing: 4) {
            AirbladeLogo(size: 24)
            Text("SEASON 1  ·  OPEN ARENAS").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.85))
        }
        .frame(width: 206, height: 66)
        .background(Color.black.opacity(0.48))
        .overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var challengeButton: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { showChallenges.toggle() } } label: {
            VStack(spacing: 5) {
                Image(systemName: "flag.checkered").font(.system(size: 22, weight: .bold))
                Text("DAILY CHALLENGES").font(.jk(14, .heavy)).italic()
            }
            .foregroundColor(.white).frame(width: 206, height: 66)
            .background(LinearGradient(colors: [Color(red: 0.28, green: 0.34, blue: 0.95), Color(red: 0.2, green: 0.28, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }.buttonStyle(.plain)
    }

    private var profileCard: some View {
        let ri = TacRank.index(TacRank.totalXP(t))
        return Button { act(.ranks) } label: {
            HStack(spacing: 10) {
                ZStack {
                    Rectangle().fill(Color(red: 0.08, green: 0.14, blue: 0.2))
                    Image(systemName: "shield.fill").font(.system(size: 26, weight: .black)).foregroundColor(blue.opacity(0.7))
                }.frame(width: 50, height: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(TacProfile.name).font(.jk(12, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text(TacRank.ranks[ri].name).font(.jk(10, .medium)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                    Text("W \(t.wins)   L \(t.losses)   K \(t.kills)").font(.jk(10, .medium)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8).frame(width: 225, height: 66)
            .background(Color.black.opacity(0.62))
            .overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var quickStart: some View {
        Button { act(.screen(2)) } label: {
            HStack {
                Spacer()
                Text("QUICK START").font(.jk(14, .heavy))
                Spacer()
                Image(systemName: "chevron.forward.2").font(.system(size: 16, weight: .black))
            }
            .foregroundColor(.white).padding(.horizontal, 12).frame(width: 225, height: 38)
            .background(LinearGradient(colors: [Color(red: 0.1, green: 0.3, blue: 0.48), Color(red: 0.08, green: 0.18, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Rectangle().stroke(Color.blue.opacity(0.7), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: bottom

    private func slot(selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(Color.black.opacity(0.55))
                if selected {
                    PortraitAvatar(key: TacAvatar.myKey, size: 34, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy).clipShape(Rectangle())
                } else {
                    Image(systemName: "person.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.28))
                }
            }
            .frame(width: 38, height: 38)
            .overlay(Rectangle().stroke(selected ? Color(red: 0.9, green: 0.15, blue: 0.15) : Color.white.opacity(0.3), lineWidth: selected ? 2 : 1))
        }.buttonStyle(TuiPress())
    }

    private var slotBar: some View {
        HStack(spacing: 6) {
            slot(selected: true) { act(.avatar) }
            slot(selected: false) { act(.avatar) }
            slot(selected: false) { act(.avatar) }
            Button { act(.avatar) } label: {
                Text("+").font(.jk(20, .semibold)).foregroundColor(.white.opacity(0.55)).frame(width: 38, height: 38)
                    .overlay(Rectangle().stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }.buttonStyle(TuiPress())
            Button { act(.friends) } label: {
                Image(systemName: "person.2.fill").font(.system(size: 15)).foregroundColor(.white.opacity(0.8)).frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }.buttonStyle(TuiPress()).padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
    }

    private func cell(_ top: String, _ icon: String, _ value: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(top).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
                SF(icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                    .frame(width: 46, height: 30)
                    .background(Color.white.opacity(0.08))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(value).font(.jk(8, .heavy)).foregroundColor(blue).lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(TuiPress())
    }

    private var matchCells: some View {
        HStack(spacing: 8) {
            cell("MODE", "person.2.fill", modeTitles[nav.tacMode] ?? "DUEL") { nav.tacMode = cycle(modeIds, nav.tacMode) }
            cell("MAP", "map", TacLobbyMaps.title(nav.tacMap)) { nav.tacMap = cycle(TacLobbyMaps.ids, nav.tacMap) }
            cell("LEVEL", "speedometer", diffNames[max(0, min(2, diff))]) { diff = (diff + 1) % 3 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 20).padding(.bottom, 10)
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
        ZStack(alignment: .top) {
            hero

            VStack(spacing: 0) {
                topBar
                HStack(spacing: 0) {
                    subNav("Lobby", selected: true) { act(.nav(0)) }
                    subNav("Record") { act(.stats) }
                    subNav("Achievements") { withAnimation(.easeOut(duration: 0.15)) { showChallenges.toggle() } }
                    Spacer()
                }
                .padding(.leading, 28)
                .frame(height: 31)
                .background(Color.black.opacity(0.12))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                seasonBanner
                challengeButton
                Spacer(minLength: 0)
                profileCard
                quickStart
            }
            .padding(.leading, 22).padding(.top, 86).padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            slotBar
            matchCells

            if showChallenges {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { showChallenges = false }
                challengePanel.transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if ![0, 1, 5, 8].contains(nav.tacMode) { nav.tacMode = 8 }
            if !TacLobbyMaps.ids.contains(nav.tacMap) { nav.tacMap = TacLobbyMaps.fallback }
        }
    }
}

import SwiftUI

/// PLAY page, laid out like the reference lobby: operator in a detection frame in the middle,
/// loadout bottom-left, PLAY bottom-right, currency and VIP across the top, no navigation bar.
struct LobbyHome: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void

    @State private var showChallenges = false

    private let green = Color(red: 0.25, green: 0.65, blue: 1.0)
    private let ink = Color(red: 0.04, green: 0.05, blue: 0.05)
    private let modeIds = [8, 0, 1, 5]
    private let modeTitles = [8: "DUEL", 0: "TACTICAL", 1: "TDM", 5: "CONTROL"]
    private let mapIds = [7, 6, 5]
    private let mapTitles = [7: "ANNEX", 6: "BLOCK 9", 5: "CUSTOM"]
    private let diffNames = ["EASY", "NORMAL", "HARD"]
    private let barcode: [CGFloat] = [2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2]

    private var gunName: String { TWeapons.all.first(where: { $0.id == nav.tacGun })?.name ?? nav.tacGun.uppercased() }

    private func cycle(_ ids: [Int], _ cur: Int) -> Int {
        let i = ids.firstIndex(of: cur) ?? 0
        return ids[(i + 1) % ids.count]
    }

    // MARK: pieces

    private func glyph(_ name: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                SF(name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                Text(label).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.7)).lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(TuiPress())
    }

    private func cell(_ top: String, _ icon: String, _ value: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(top).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
                SF(icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                    .frame(width: 46, height: 36)
                    .background(Color.white.opacity(0.08))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(value).font(.jk(8, .heavy)).foregroundColor(green).lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(TuiPress())
    }

    private func currency(_ letter: String, _ value: String, _ ring: Color) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.jk(15, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
            Text(letter).font(.jk(10, .heavy)).foregroundColor(.white)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(ring, lineWidth: 1.5))
        }
    }

    private var topBar: some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return HStack(spacing: 0) {
            Text("AIRBLADE")
                .font(.system(size: 22, weight: .black, design: .serif).italic())
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.48, green: 0.72, blue: 1), .white], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.blue.opacity(0.45), radius: 8)
                .padding(.horizontal, 18)
            Rectangle().fill(Color.white.opacity(0.16)).frame(width: 1, height: 26)
            HStack(spacing: 0) {
                topNav("HideOut", selected: true) { act(.nav(0)) }
                topNav("Play") { act(.screen(1)) }
                topNav("Shop") { act(.nav(6)) }
                topNav("Inventory") { act(.loadout) }
                topNav("Event") { act(.season(0)) }
            }
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                currency("C", game.s.ex.gems.formatted(), Color(red: 1, green: 0.75, blue: 0.22))
                currency("ZC", "\(t.rating)", Color(red: 0.25, green: 0.7, blue: 1))
                Button { act(.ranks) } label: {
                    HStack(spacing: 8) {
                        ZStack { Rectangle().fill(Color(red: 0.35, green: 0.03, blue: 0.08)); Image(systemName: "shield.lefthalf.filled").font(.system(size: 21, weight: .black)).foregroundColor(.red) }
                            .frame(width: 34, height: 34).overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TacProfile.name.uppercased()).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1)
                            HStack(spacing: 5) {
                                Text("Lv. \(ri + 1)").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7))
                                Text("EXP \(Int(TacRank.progress(xp) * 100))%").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7))
                            }
                            GeometryReader { proxy in ZStack(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.13)); Rectangle().fill(Color.blue).frame(width: proxy.size.width * CGFloat(TacRank.progress(xp))) } }.frame(height: 3)
                        }.frame(width: 105)
                    }.padding(.horizontal, 8).padding(.vertical, 4).background(Color.black.opacity(0.24)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }.buttonStyle(.plain)
                Button { act(.stats) } label: { Image(systemName: "gearshape.fill").font(.system(size: 17)).foregroundColor(.white.opacity(0.8)).frame(width: 28, height: 32) }.buttonStyle(.plain)
            }.padding(.trailing, 14)
        }
        .frame(height: 48)
        .background(Color.black.opacity(0.22))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1) }
    }

    private func topNav(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(12, selected ? .heavy : .semibold)).foregroundColor(selected ? .white : .white.opacity(0.66))
                .padding(.horizontal, 15).frame(height: 48)
                .background(selected ? Color.white.opacity(0.07) : Color.clear)
                .overlay(alignment: .bottom) { Rectangle().fill(selected ? Color(red: 0.25, green: 0.65, blue: 1) : .clear).frame(height: 2) }
        }.buttonStyle(.plain)
    }

    private var operatorFrame: some View {
        let fw = min(size.width * 0.24, 210)
        let fh = size.height * 0.64
        return ZStack {
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: TacRank.index(TacRank.totalXP(t)), gun: nav.tacGun)
                .frame(width: size.width * 0.34, height: size.height * 0.86)
                .allowsHitTesting(false)
            Rectangle().stroke(green.opacity(0.8), lineWidth: 1).frame(width: fw, height: fh)
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("001").font(.jk(11, .semibold)).foregroundColor(green)
                    HStack(spacing: 1) {
                        ForEach(0..<barcode.count, id: \.self) { i in
                            Rectangle().fill(green.opacity(0.9)).frame(width: barcode[i], height: 9)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6).frame(width: fw, height: 20)
                .background(Color.black.opacity(0.45))
                Spacer(minLength: 0)
            }
            .frame(width: fw, height: fh + 20)
            .offset(y: -10)
            .allowsHitTesting(false)
        }
    }

    private var promo: some View {
        Button { act(.loadout) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Image(uiImage: GunSprites.icon(nav.tacGun)).resizable().scaledToFit()
                    .padding(6).frame(width: 118, height: 66)
                    .background(Color.white.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(gunName).font(.jk(11, .semibold)).foregroundColor(.white).lineLimit(1).frame(width: 118, alignment: .leading)
                Text("CHANGE").font(.jk(11, .heavy)).foregroundColor(green)
            }
        }
        .buttonStyle(TuiPress())
    }

    private var loadoutRow: some View {
        Button { act(.loadout) } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text("LOADOUT").font(.jk(15, .heavy)).foregroundColor(green)
                HStack(spacing: 6) {
                    Image(uiImage: GunSprites.icon(nav.tacGun)).resizable().scaledToFit()
                        .padding(6).frame(width: 74, height: 50)
                        .background(Color.white.opacity(0.1))
                        .overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    Color.white.opacity(0.06).frame(width: 74, height: 50)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    Text("+").font(.jk(20, .semibold)).foregroundColor(.white.opacity(0.5)).frame(width: 74, height: 50)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                }
            }
        }
        .buttonStyle(TuiPress())
    }

    private var playButton: some View {
        Button { act(.screen(2)) } label: {
            HStack(spacing: 0) {
                SF("chevron.forward.2", "chevron.right").font(.system(size: 20, weight: .bold)).foregroundColor(green)
                    .frame(width: 52, height: 50)
                    .background(green.opacity(0.35))
                Text("PLAY").font(.jk(26, .semibold)).foregroundColor(green)
                    .frame(width: 124, height: 50)
                    .background(Color.black.opacity(0.55))
            }
            .overlay(Rectangle().stroke(green.opacity(0.8), lineWidth: 1))
            .overlay(alignment: .topLeading) { Rectangle().fill(green).frame(width: 5, height: 5).offset(x: -2.5, y: -2.5) }
            .overlay(alignment: .bottomLeading) { Rectangle().fill(green).frame(width: 5, height: 5).offset(x: -2.5, y: 2.5) }
            .overlay(alignment: .bottomTrailing) { Rectangle().fill(green).frame(width: 5, height: 5).offset(x: 2.5, y: 2.5) }
        }
        .buttonStyle(TuiPress())
    }

    private func challenge(_ title: String, _ have: Int, _ need: Int, _ xp: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 2.5)
                Circle().trim(from: 0, to: CGFloat(have) / CGFloat(max(1, need)))
                    .stroke(green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.jk(11, .semibold)).foregroundColor(.white).lineLimit(1)
                Text("\(have)/\(need)").font(.jk(9, .medium)).foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Text("\(xp) XP").font(.jk(10, .heavy)).foregroundColor(green)
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
        .overlay(Rectangle().stroke(green.opacity(0.6), lineWidth: 1))
    }

    // MARK: body

    var body: some View {
        ZStack(alignment: .top) {
            operatorFrame.position(x: size.width * 0.53, y: size.height * 0.53)

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

            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    Text("AIRBLADE").font(.system(size: 25, weight: .black, design: .serif).italic()).foregroundColor(.white).shadow(color: .blue.opacity(0.4), radius: 6)
                    HStack(spacing: 5) { Text("Official Website"); Image(systemName: "arrow.up.right.square") }.font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.9)).padding(.top, 5)
                }
                .frame(width: 206, height: 78).background(Color.black.opacity(0.48)).overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                Button { act(.stats) } label: {
                    VStack(spacing: 7) { Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 24, weight: .bold)); Text("JOIN OFFICIAL DISCORD").font(.jk(14, .heavy)).italic() }
                        .foregroundColor(.white).frame(width: 206, height: 84).background(LinearGradient(colors: [Color(red: 0.28, green: 0.34, blue: 0.95), Color(red: 0.2, green: 0.28, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }.buttonStyle(.plain)
                Spacer()
                HStack(spacing: 10) {
                    ZStack { Rectangle().fill(Color(red: 0.08, green: 0.19, blue: 0.09)); Image(systemName: "shield.fill").font(.system(size: 29, weight: .black)).foregroundColor(.green.opacity(0.65)) }.frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reunion").font(.jk(12, .heavy)).foregroundColor(.white)
                        Text("Clan: OWOL").font(.jk(10, .medium)).foregroundColor(.white.opacity(0.75))
                        Text("Clan_Master").font(.jk(10, .medium)).foregroundColor(.white.opacity(0.75))
                    }
                    Spacer(minLength: 0)
                }.padding(8).frame(width: 225, height: 72).background(Color.black.opacity(0.62)).overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                Button { act(.screen(1)) } label: {
                    HStack { Spacer(); Text("QUICK START").font(.jk(14, .heavy)); Spacer(); Image(systemName: "chevron.forward.2").font(.system(size: 16, weight: .black)) }
                        .foregroundColor(.white).padding(.horizontal, 12).frame(width: 225, height: 38)
                        .background(LinearGradient(colors: [Color(red: 0.1, green: 0.3, blue: 0.48), Color(red: 0.08, green: 0.18, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Rectangle().stroke(Color.blue.opacity(0.7), lineWidth: 1))
                }.buttonStyle(.plain).padding(.top, 5)
            }
            .padding(.leading, 22).padding(.top, 86).padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                cell("MODE", "person.2.fill", modeTitles[nav.tacMode] ?? "DUEL") { nav.tacMode = cycle(modeIds, nav.tacMode) }
                cell("MAP", "map", mapTitles[nav.tacMap] ?? "ANNEX") { nav.tacMap = cycle(mapIds, nav.tacMap) }
                cell("LEVEL", "speedometer", diffNames[max(0, min(2, diff))]) { diff = (diff + 1) % 3 }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 12)

            HStack(spacing: 7) {
                glyph("person.crop.circle.fill", "CHARACTER") { act(.avatar) }
                glyph("person.2.fill", "SOCIAL") { act(.friends) }
                glyph("plus", "ADD SLOT") { act(.avatar) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20).padding(.bottom, 10)

            if showChallenges {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { showChallenges = false }
                challengePanel.transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            if ![0, 1, 5, 8].contains(nav.tacMode) { nav.tacMode = 8 }
            if ![5, 6, 7].contains(nav.tacMap) { nav.tacMap = 7 }
        }
    }

    private func subNav(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(10, selected ? .heavy : .medium)).foregroundColor(selected ? .white : .white.opacity(0.55))
                .padding(.horizontal, 14).frame(height: 31)
                .overlay(alignment: .bottom) { Rectangle().fill(selected ? Color.blue : .clear).frame(height: 2) }
        }.buttonStyle(.plain)
    }
}

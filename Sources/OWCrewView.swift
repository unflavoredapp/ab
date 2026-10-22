import SwiftUI

// MARK: - CREW tab: crew card, member table, stats, activity and the crew shortcuts bar
// Members and activity are sample data until online crews exist.

struct OWCrewView: View {
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var tab = 0
    @State private var row = 0

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    private struct Member { let name: String; let lv: Int; let role: String; let status: Int; let last: String }
    @ObservedObject private var online = OWOnline.shared
    @State private var draft = ""
    @State private var serverText = OWOnline.shared.baseURL
    private var members: [Member] { online.members.map { Member(name: $0.name, lv: $0.level, role: $0.role, status: $0.status, last: $0.last) } }

    private func roleIcon(_ r: String) -> String {
        ["Leader": "crown.fill", "Officer": "shield.lefthalf.filled", "Member": "person.2.fill", "Recruit": "plus.circle.fill"][r] ?? "person.fill"
    }

    private func statusView(_ s: Int) -> some View {
        let (c, n) = s == 0 ? (OW.green, "Online") : (s == 1 ? (OW.cyan, "In Menu") : (Color.gray, "Offline"))
        return HStack(spacing: 5 * u) {
            Circle().fill(c).frame(width: 6 * u, height: 6 * u)
            Text(n).font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: left

    private func statRow(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 7 * u) {
            Image(systemName: icon).font(.system(size: 10 * u)).foregroundColor(.white.opacity(0.8)).frame(width: 18 * u)
            Text(k).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.8))
            Spacer(minLength: 0)
            Text(v).font(.jk(9 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
        .frame(height: 19 * u)
    }

    private var crewCard: some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return VStack(alignment: .leading, spacing: 4 * u) {
            ZStack(alignment: .bottomLeading) {
                OWArt(w: 188 * u, h: 62 * u, anchor: UnitPoint(x: 0.3, y: 0.2), zoom: 2.6)
                LinearGradient(colors: [.clear, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                Image(systemName: "crown.fill").font(.system(size: 26 * u)).foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8 * u)
                HStack(spacing: 5 * u) {
                    Text("RIVERSIDE").font(.jk(16 * u, .heavy)).foregroundColor(.white)
                    Text("YOUR CREW").font(.jk(6 * u, .heavy)).foregroundColor(.white).padding(.horizontal, 4 * u).padding(.vertical, 1.5 * u)
                        .background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan))
                }
                .padding(.leading, 8 * u).padding(.bottom, 3 * u)
            }
            .frame(width: 188 * u, height: 62 * u).clipShape(RoundedRectangle(cornerRadius: 3 * u))
            Text("LOYALTY BUILDS EMPIRES").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.8))
            HStack {
                Text("LV. \(ri + 1)").font(.jk(10 * u, .heavy)).foregroundColor(.white)
                Spacer()
                Text("\(Int(TacRank.progress(xp) * 5000)) / 5,000 XP").font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.7))
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(OW.cyan).frame(width: 188 * u * CGFloat(TacRank.progress(xp)))
            }
            .frame(width: 188 * u, height: 4 * u)
            statRow("person.2.fill", "MEMBERS", "\(online.members.count) / 12")
            statRow("shield.lefthalf.filled", "TERRITORY", "Riverside District")
            statRow("building.columns.fill", "CREW BANK", "$ 248,560")
        }
        .padding(8 * u).frame(width: 204 * u).owPanel(u)
    }

    private var tags: some View {
        VStack(alignment: .leading, spacing: 4 * u) {
            Text("CREW TAGS").font(.jk(9 * u, .heavy)).foregroundColor(.white)
            HStack(spacing: 4 * u) {
                ForEach(["#Riverside", "#HardWork", "#Respect"], id: \.self) { s in
                    Text(s).font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.9)).padding(.horizontal, 6 * u).frame(height: 15 * u)
                        .background(Capsule().fill(OW.cyan.opacity(0.18)))
                }
            }
            Text("#NoSnakes").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.9)).padding(.horizontal, 6 * u).frame(height: 15 * u)
                .background(Capsule().fill(OW.cyan.opacity(0.18)))
            Text("DESCRIPTION").font(.jk(9 * u, .heavy)).foregroundColor(.white).padding(.top, 2 * u)
            Text("We move smart, stay loyal, and take what's ours. Riverside isn't just a crew, it's a family.")
                .font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.8)).lineLimit(4)
            Spacer(minLength: 0)
            Button { } label: {
                HStack(spacing: 5 * u) {
                    Image(systemName: "pencil").font(.system(size: 9 * u))
                    Text("EDIT CREW").font(.jk(8.5 * u, .heavy))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 22 * u).owPanel(u, r: 3)
            }.buttonStyle(.plain)
        }
        .padding(8 * u).frame(width: 204 * u).frame(maxHeight: .infinity).owPanel(u)
    }

    // MARK: middle

    private var banner: some View {
        ZStack {
            OWArt(w: 500 * u, h: 78 * u, anchor: UnitPoint(x: 0.5, y: 0.45), zoom: 1.6)
            LinearGradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            AirbladeHero().frame(width: 130 * u, height: 130 * u).offset(y: 12 * u).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity).frame(height: 78 * u).clipShape(RoundedRectangle(cornerRadius: 3 * u))
    }

    private var tabs: some View {
        HStack(spacing: 18 * u) {
            ForEach(Array(["MEMBERS", "REQUESTS", "CREW CHAT", "LOGS"].enumerated()), id: \.offset) { i, s in
                Button { tab = i } label: {
                    HStack(spacing: 4 * u) {
                        Text(s).font(.jk(10 * u, .heavy)).foregroundColor(tab == i ? OW.cyan : .white.opacity(0.75))
                        if i == 1 && !online.requests.isEmpty { Text("\(online.requests.count)").font(.jk(7 * u, .heavy)).foregroundColor(.white).frame(width: 12 * u, height: 12 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan)) }
                    }
                    .frame(height: 24 * u).overlay(alignment: .bottom) { Rectangle().fill(tab == i ? OW.cyan : .clear).frame(height: 2 * u) }
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10 * u)
    }

    private func memberRow(_ i: Int) -> some View {
        let m = members[i]
        let on = row == i
        return Button { row = i } label: {
            HStack(spacing: 0) {
                HStack(spacing: 7 * u) {
                    OWAvatar(name: m.name, s: 24 * u)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4 * u) {
                            Text(m.name).font(.jk(10 * u, .heavy)).foregroundColor(.white)
                            if i == 0 { Text("LEADER").font(.jk(5.5 * u, .heavy)).foregroundColor(OW.cyan) }
                        }
                        Text("Lv. \(m.lv)").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(width: 150 * u, alignment: .leading)
                HStack(spacing: 5 * u) {
                    Image(systemName: roleIcon(m.role)).font(.system(size: 9 * u)).foregroundColor(.white.opacity(0.85))
                    Text(m.role).font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 90 * u, alignment: .leading)
                statusView(m.status).frame(width: 80 * u, alignment: .leading)
                Text(m.last).font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.75)).frame(width: 70 * u, alignment: .leading)
                Spacer(minLength: 0)
                Text("···").font(.jk(11 * u, .heavy)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 8 * u).frame(height: 29 * u)
            .background(RoundedRectangle(cornerRadius: 3 * u).fill(on ? OW.cyan.opacity(0.14) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(on ? OW.cyan : .clear, lineWidth: 1.2))
        }.buttonStyle(.plain)
    }

    private var table: some View {
        VStack(spacing: 0) {
            tabs
            if tab == 0 {
                HStack(spacing: 0) {
                    Text("MEMBER").frame(width: 150 * u, alignment: .leading)
                    Text("ROLE").frame(width: 90 * u, alignment: .leading)
                    Text("STATUS").frame(width: 80 * u, alignment: .leading)
                    Text("LAST ACTIVE").frame(width: 70 * u, alignment: .leading)
                    Spacer()
                }
                .font(.jk(7 * u, .semibold)).foregroundColor(.white.opacity(0.5)).padding(.horizontal, 8 * u).frame(height: 18 * u)
                VStack(spacing: 0) { ForEach(0..<members.count, id: \.self) { memberRow($0) } }.padding(.horizontal, 2 * u)
                Spacer(minLength: 0)
            } else if tab == 1 {
                ScrollView {
                    VStack(spacing: 3 * u) {
                        if online.requests.isEmpty { Text("No pending requests.").font(.jk(10 * u, .medium)).foregroundColor(.white.opacity(0.5)).padding(.top, 30 * u) }
                        ForEach(online.requests) { r in
                            HStack(spacing: 7 * u) {
                                OWAvatar(name: r.name, s: 24 * u)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(r.name).font(.jk(10 * u, .heavy)).foregroundColor(.white)
                                    Text("Lv. \(r.level) · \(r.last)").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                Button { online.respond(r, accept: true) } label: { Text("ACCEPT").font(.jk(8 * u, .heavy)).foregroundColor(.black).padding(.horizontal, 9 * u).frame(height: 20 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan)) }.buttonStyle(.plain)
                                Button { online.respond(r, accept: false) } label: { Text("DECLINE").font(.jk(8 * u, .heavy)).foregroundColor(.white).padding(.horizontal, 9 * u).frame(height: 20 * u).owPanel(u, r: 2) }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8 * u).frame(height: 32 * u)
                        }
                    }.padding(4 * u)
                }
            } else if tab == 2 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4 * u) {
                        ForEach(online.chat.suffix(40)) { m in
                            HStack(alignment: .top, spacing: 6 * u) {
                                OWAvatar(name: m.from, s: 16 * u)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(m.from).font(.jk(7.5 * u, .heavy)).foregroundColor(m.from == online.playerName ? OW.cyan : .white)
                                    Text(m.text).font(.jk(9 * u, .medium)).foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8 * u)
                }
                HStack(spacing: 5 * u) {
                    TextField("Message your crew", text: $draft).font(.jk(9 * u, .medium)).foregroundColor(.white)
                        .padding(.horizontal, 7 * u).frame(height: 22 * u).owPanel(u, r: 2)
                        .onSubmit { online.send(draft); draft = "" }
                    Button { online.send(draft); draft = "" } label: { Image(systemName: "paperplane.fill").font(.system(size: 10 * u)).foregroundColor(.black).frame(width: 30 * u, height: 22 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan)) }.buttonStyle(.plain)
                }.padding(6 * u)
            } else {
                VStack(alignment: .leading, spacing: 5 * u) {
                    HStack(spacing: 5 * u) {
                        Circle().fill(online.connected ? OW.green : OW.gold).frame(width: 7 * u, height: 7 * u)
                        Text(online.status).font(.jk(9 * u, .heavy)).foregroundColor(.white)
                    }
                    Text("SERVER ADDRESS").font(.jk(7 * u, .semibold)).foregroundColor(.white.opacity(0.5))
                    HStack(spacing: 5 * u) {
                        TextField("http://192.168.1.20:8080", text: $serverText).font(.jk(9 * u, .medium)).foregroundColor(.white)
                            .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                            .padding(.horizontal, 7 * u).frame(height: 22 * u).owPanel(u, r: 2)
                        Button { online.baseURL = serverText; online.connect() } label: { Text("CONNECT").font(.jk(8 * u, .heavy)).foregroundColor(.black).padding(.horizontal, 10 * u).frame(height: 22 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan)) }.buttonStyle(.plain)
                    }
                    Text("Leave it empty to play offline. The reference server is in the server folder.").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.55))
                    ScrollView { VStack(alignment: .leading, spacing: 1 * u) { ForEach(Array(online.logs.enumerated()), id: \.offset) { _, l in Text(l).font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.6)) } } }
                }.padding(10 * u)
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity).owPanel(u)
    }

    // MARK: right

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CREW STATS").font(.jk(11 * u, .heavy)).foregroundColor(.white).padding(.bottom, 4 * u)
            ForEach(Array([("person.2.fill", "TOTAL MEMBERS", "8 / 12"), ("circle.fill", "ONLINE NOW", "4"), ("crown.fill", "TERRITORIES HELD", "1"),
                           ("flag.2.crossed.fill", "TOTAL WARS WON", "12"), ("star.circle.fill", "WIN RATE", "67%")].enumerated()), id: \.offset) { _, e in
                HStack(spacing: 7 * u) {
                    Image(systemName: e.0).font(.system(size: 11 * u)).foregroundColor(e.0 == "circle.fill" ? OW.green : .white.opacity(0.85)).frame(width: 18 * u)
                    Text(e.1).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.85))
                    Spacer(minLength: 0)
                    Text(e.2).font(.jk(10 * u, .heavy)).foregroundColor(.white).monospacedDigit()
                }
                .frame(height: 23 * u)
            }
        }
        .padding(8 * u).frame(width: 190 * u).owPanel(u)
    }

    private func activity(_ n: String, _ icon: String, _ s: String, _ ago: String) -> some View {
        HStack(spacing: 6 * u) {
            OWAvatar(name: n, s: 20 * u)
            VStack(alignment: .leading, spacing: 0) {
                Text(n).font(.jk(8 * u, .heavy)).foregroundColor(.white)
                Text(s).font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.65)).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(ago).font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.45))
        }
        .frame(height: 25 * u)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT ACTIVITY").font(.jk(11 * u, .heavy)).foregroundColor(.white).padding(.bottom, 3 * u)
            activity("ShadowK", "crown.fill", "captured the Riverside District", "12m ago")
            activity("RicoStacks", "doc.text.fill", "completed a contract", "27m ago")
            activity("LunaZ", "person.2.fill", "joined the crew", "1h ago")
            activity("TacoBandit", "dollarsign.circle", "donated $5,000 to the crew bank", "2h ago")
            activity("BigDre", "xmark", "left the crew", "4h ago")
        }
        .padding(8 * u).frame(width: 190 * u).owPanel(u)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(Array([("crown.fill", "CREW PERKS", 0), ("lock.shield.fill", "CREW VAULT", 0), ("doc.text.fill", "CREW CONTRACTS", 16),
                           ("flag.2.crossed.fill", "TERRITORY WAR", -1), ("cart.fill", "CREW SHOP", 21)].enumerated()), id: \.offset) { _, e in
                Button {
                    if e.2 == -1 { act(.launch(5)) } else if e.2 > 0 { act(.screen(e.2)) }
                } label: {
                    HStack(spacing: 8 * u) {
                        Image(systemName: e.0).font(.system(size: 15 * u)).foregroundColor(.white.opacity(0.9))
                        Text(e.1).font(.jk(9 * u, .heavy)).foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }
        }
        .frame(height: 38 * u).owPanel(u)
    }

    var body: some View {
        OWScreen(t: t, u: u, selected: 2, act: act) {
            VStack(spacing: 6 * u) {
                HStack(alignment: .top, spacing: 8 * u) {
                    VStack(spacing: 6 * u) { crewCard; tags }
                    VStack(spacing: 6 * u) { banner; table }.frame(maxWidth: .infinity)
                    VStack(spacing: 6 * u) {
                        statsPanel
                        recent
                        OWButton(u: u, icon: "person.2.fill", title: "MANAGE CREW", filled: false) { act(.friends) }
                    }
                }
                bottomBar
            }
            .padding(.horizontal, 12 * u).padding(.top, 8 * u).padding(.bottom, 8 * u)
        }
        .frame(width: size.width, height: size.height)
        .onAppear { online.connect() }
    }
}

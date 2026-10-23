import SwiftUI

// MARK: - BLOK PHONE apps: BLOKUP, BLOKCHAT, BLOK WATCH, REP, BLOK TRENDS, MY BLOK
// Sized for the 150 x 300 in-world phone.

struct BlokApp: View {
    let kind: String
    let e: TacticalEngine
    let back: () -> Void
    let openJobs: () -> Void

    @ObservedObject private var net = BlokNet.shared
    @ObservedObject private var online = OWOnline.shared
    @State private var open: String? = nil

    private let gold = Color(red: 1, green: 0.8, blue: 0.25)
    private let blue = Color(red: 0.4, green: 0.65, blue: 1)
    private let red = Color(red: 1, green: 0.32, blue: 0.3)
    private let green = Color(red: 0.3, green: 0.85, blue: 0.45)

    static let titles: [String: (String, String)] = [
        "blokup": ("BLOKUP", "The whole Blok talking."),
        "blokchat": ("BLOKCHAT", "Tap in with your people."),
        "watch": ("BLOK WATCH", "Know what's happening on your Blok."),
        "rep": ("REP", "Your name carries weight."),
        "trends": ("BLOK TRENDS", "What's hot. What's not. Who switched up."),
        "myblok": ("MY BLOK", "Put your name on the map."),
    ]

    private var me: String { UserDefaults.standard.string(forKey: "ab.playername") ?? "MRZEFV" }

    private func header() -> some View {
        let t = Self.titles[kind] ?? ("", "")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button { if open != nil { open = nil } else { back() } } label: { Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold)).foregroundColor(blue) }.buttonStyle(.plain)
                Text(t.0).font(.jk(11, .heavy)).tracking(0.6).foregroundColor(.white)
                Spacer()
            }
            Text(t.1).font(.jk(6.5, .medium)).foregroundColor(.white.opacity(0.5)).padding(.leading, 13)
        }
        .padding(.horizontal, 10).padding(.top, 2).padding(.bottom, 3)
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().padding(.horizontal, 7).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
    }

    private func chip(_ s: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            Text(s).font(.jk(7, .heavy)).foregroundColor(.white).lineLimit(1).padding(.horizontal, 7).frame(height: 18)
                .background(Capsule().fill(Color.white.opacity(0.14)))
        }.buttonStyle(.plain)
    }

    private func meter(_ label: String, _ v: Double, _ col: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(label).font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.85)); Spacer(); Text("\(Int(v))").font(.jk(7, .heavy)).foregroundColor(col).monospacedDigit() }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(col).frame(width: 124 * CGFloat(max(0, min(100, v))) / 100)
            }.frame(width: 124, height: 3.5)
        }
    }

    // MARK: BLOKUP

    private var blokup: some View {
        VStack(spacing: 3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(["On my block 💪", "Who want smoke?", "Tap in 🔥", "Heard y'all loud"], id: \.self) { s in chip(s) { net.publish(s) } }
                }.padding(.horizontal, 2)
            }.frame(height: 20)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(net.posts) { p in
                        card {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    OWAvatar(name: p.handle, s: 14)
                                    Text("@\(p.handle)").font(.jk(7, .heavy)).foregroundColor(p.you ? gold : blue).lineLimit(1)
                                    Spacer()
                                    Text(BlokNet.ago(p.ts)).font(.jk(6, .medium)).foregroundColor(.white.opacity(0.4))
                                }
                                Text(p.text).font(.jk(7.5, .medium)).foregroundColor(.white.opacity(0.92)).fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 8) {
                                    Button { net.like(p.id) } label: {
                                        HStack(spacing: 2) { Image(systemName: p.liked ? "heart.fill" : "heart").font(.system(size: 7)); Text("\(p.likes)").font(.jk(6.5, .heavy)) }
                                            .foregroundColor(p.liked ? red : .white.opacity(0.6))
                                    }.buttonStyle(.plain)
                                    HStack(spacing: 2) { Image(systemName: "bubble.left").font(.system(size: 7)); Text("\(p.comments.count)").font(.jk(6.5, .heavy)) }.foregroundColor(.white.opacity(0.5))
                                    Text("#\(p.tag)").font(.jk(6.5, .heavy)).foregroundColor(gold.opacity(0.8))
                                }
                                if let c = p.comments.first { Text("↳ \(c)").font(.jk(6.5, .medium)).foregroundColor(.white.opacity(0.5)) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { net.markSeen() }
    }

    // MARK: BLOKCHAT

    private func lastLine(_ t: BlokThread) -> String {
        if t.crew { return online.chat.last.map { "\($0.from): \($0.text)" } ?? "No messages yet" }
        return t.msgs.last?.text ?? ""
    }

    private var blokchat: some View {
        Group {
            if let id = open, let t = net.threads.first(where: { $0.id == id }) { thread(t) }
            else {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(net.threads) { t in
                            Button { open = t.id; net.read(t.id) } label: {
                                card {
                                    HStack(spacing: 6) {
                                        OWAvatar(name: t.id, s: 20)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(t.id).font(.jk(8, .heavy)).foregroundColor(.white)
                                            Text(lastLine(t)).font(.jk(6.5, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        if t.unread > 0 { Text("\(t.unread)").font(.jk(6.5, .heavy)).foregroundColor(.white).frame(width: 12, height: 12).background(Circle().fill(red)) }
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func thread(_ t: BlokThread) -> some View {
        let lines: [BlokMsg] = t.crew ? online.chat.suffix(30).map { BlokMsg(mine: $0.from == online.playerName, text: t.crew && $0.from != online.playerName ? "\($0.from): \($0.text)" : $0.text) } : t.msgs
        return VStack(spacing: 3) {
            Text(t.id).font(.jk(8, .heavy)).foregroundColor(gold)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, m in
                        HStack {
                            if m.mine { Spacer(minLength: 20) }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.text).font(.jk(7.5, .medium)).foregroundColor(.white)
                                if m.invite { chip("ACCEPT RUN") { openJobs() } }
                            }
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 7).fill(m.mine ? blue.opacity(0.55) : Color.white.opacity(0.12)))
                            if !m.mine { Spacer(minLength: 20) }
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(["Twin, where you at?", "On my way", "Say less", "Nah"], id: \.self) { s in
                        chip(s) { if t.crew { online.send(s) } else { net.send(s, to: t.id) } }
                    }
                }
            }.frame(height: 20)
        }
    }

    // MARK: BLOK WATCH

    private var watch: some View {
        let recent = Set(net.alerts.filter { Date().timeIntervalSince1970 - $0.ts < 900 && $0.hot }.map { $0.district })
        return ScrollView {
            VStack(spacing: 3) {
                ForEach(OWDistrict.all.prefix(6)) { d in
                    card {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(d.name).font(.jk(7.5, .heavy)).foregroundColor(.white).lineLimit(1)
                                if recent.contains(d.id) { Text("HOT").font(.jk(5.5, .heavy)).foregroundColor(.black).padding(.horizontal, 3).background(Capsule().fill(red)) }
                                Spacer()
                                Text("\(d.control)%").font(.jk(7.5, .heavy)).foregroundColor(d.color)
                            }
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.12))
                                Capsule().fill(d.color).frame(width: 124 * CGFloat(d.control) / 100)
                            }.frame(width: 124, height: 3)
                        }
                    }
                }
                Text("ALERTS").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
                ForEach(net.alerts.prefix(5)) { a in
                    card {
                        HStack(spacing: 4) {
                            Image(systemName: a.hot ? "exclamationmark.triangle.fill" : "info.circle.fill").font(.system(size: 8)).foregroundColor(a.hot ? gold : blue)
                            Text(a.text).font(.jk(7, .medium)).foregroundColor(.white.opacity(0.9))
                            Spacer(minLength: 0)
                            Text(BlokNet.ago(a.ts)).font(.jk(6, .medium)).foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                card {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 8)).foregroundColor(red)
                        Text("Rival Crew Takedown").font(.jk(7, .heavy)).foregroundColor(.white)
                        Spacer()
                        Text("\(min(OWOnline.eventGoal, max(e.roam.crewKOs, online.takedowns)))/\(OWOnline.eventGoal)").font(.jk(7, .heavy)).foregroundColor(.white).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: REP

    private func rival(_ name: String, _ v: Double) -> some View {
        card {
            HStack {
                Text(name).font(.jk(7.5, .heavy)).foregroundColor(.white)
                Spacer()
                Text(v > 40 ? "ALLIES" : (v > 5 ? "FRIENDLY" : (v > -30 ? "TENSE" : (v > -65 ? "BEEF" : "WAR")))).font(.jk(7, .heavy))
                    .foregroundColor(v > 5 ? green : (v > -30 ? gold : red))
            }
        }
    }

    private var rep: some View {
        let r = net.rep
        return ScrollView {
            VStack(spacing: 4) {
                card {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.title).font(.jk(13, .heavy)).foregroundColor(gold)
                        Text(r.line).font(.jk(7, .medium)).foregroundColor(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                card {
                    VStack(spacing: 5) {
                        meter("RESPECT", r.respect, gold)
                        meter("CREW LOYALTY", r.loyalty, blue)
                        meter("FEAR", r.fear, red)
                        meter("BLOCK TRUST", r.trust, green)
                    }
                }
                Text("RIVALRIES").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
                rival("East Side Kings", r.kings)
                rival("Viper Row", r.vipers)
            }
        }
    }

    // MARK: BLOK TRENDS

    private var trends: some View {
        let top = net.posts.max(by: { $0.likes < $1.likes })
        let gossip = net.posts.filter { ["RUMOR", "EXPOSED", "SWITCHEDUP"].contains($0.tag) }.prefix(3)
        return ScrollView {
            VStack(spacing: 3) {
                ForEach(Array(net.trending.enumerated()), id: \.offset) { i, t in
                    card {
                        HStack {
                            Text("\(i + 1)").font(.jk(8, .heavy)).foregroundColor(gold).frame(width: 10)
                            Text("#\(t.0)").font(.jk(8, .heavy)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            Text("\(t.1 * 12)").font(.jk(6.5, .medium)).foregroundColor(.white.opacity(0.5)).monospacedDigit()
                        }
                    }
                }
                if let p = top {
                    Text("MOST VIRAL").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
                    card { VStack(alignment: .leading, spacing: 1) { Text("@\(p.handle)").font(.jk(7, .heavy)).foregroundColor(blue); Text(p.text).font(.jk(7, .medium)).foregroundColor(.white.opacity(0.9)); Text("♥ \(p.likes)").font(.jk(6.5, .heavy)).foregroundColor(red) } }
                }
                if !gossip.isEmpty {
                    Text("WHO SWITCHED UP").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
                    ForEach(Array(gossip)) { p in card { Text(p.text).font(.jk(7, .medium)).foregroundColor(.white.opacity(0.85)) } }
                }
            }
        }
    }

    // MARK: MY BLOK

    private var badges: [(String, String, Bool)] {
        [("First Blood", "figure.boxing", e.roam.crewKOs + e.roam.civKOs > 0), ("Whole Blok", "crown.fill", net.captures > 0),
         ("Boss Down", "flame.fill", net.bossDowns > 0), ("Wrecked", "car.fill", net.wrecks > 0),
         ("Street Famous", "star.fill", net.rep.respect >= 50), ("Poster", "bubble.left.fill", net.yourPosts >= 3)]
    }

    private var myblok: some View {
        ScrollView {
            VStack(spacing: 4) {
                card {
                    HStack(spacing: 7) {
                        OWAvatar(name: me, s: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(me.uppercased()).font(.jk(9.5, .heavy)).foregroundColor(.white)
                            Text("RIVERSIDE CREW").font(.jk(6.5, .heavy)).foregroundColor(blue)
                            Text(net.status).font(.jk(7, .medium)).foregroundColor(gold)
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) { ForEach(["Grinding", "Laying low", "On the run", "Looking for smoke"], id: \.self) { s in chip(s) { net.setStatus(s) } } }
                }.frame(height: 20)
                card {
                    VStack(spacing: 3) {
                        stat("Cash", "$\(e.roam.cash)"); stat("K.O.s", "\(e.roam.crewKOs + e.roam.civKOs)")
                        stat("Jobs done", "\(e.roam.jobsDone)"); stat("Best combo", "x\(max(e.roam.bestCombo, e.bestCombo))"); stat("Rep", net.rep.title)
                    }
                }
                Text("ACHIEVEMENTS").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                    ForEach(badges, id: \.0) { b in
                        VStack(spacing: 2) {
                            Image(systemName: b.1).font(.system(size: 11)).foregroundColor(b.2 ? gold : .white.opacity(0.25))
                            Text(b.0).font(.jk(5.5, .heavy)).foregroundColor(b.2 ? .white : .white.opacity(0.35)).multilineTextAlignment(.center).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 34).background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(b.2 ? 0.1 : 0.04)))
                    }
                }
                let mine = net.posts.filter { $0.you }.prefix(3)
                if !mine.isEmpty {
                    Text("MY POSTS").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(mine)) { p in card { Text(p.text).font(.jk(7, .medium)).foregroundColor(.white.opacity(0.9)) } }
                }
            }
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.jk(7, .medium)).foregroundColor(.white.opacity(0.75)); Spacer(); Text(v).font(.jk(7.5, .heavy)).foregroundColor(.white).monospacedDigit() }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case "blokup": blokup
        case "blokchat": blokchat
        case "watch": watch
        case "rep": rep
        case "trends": trends
        default: myblok
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header()
            content.padding(.horizontal, 2)
            Spacer(minLength: 0)
        }
    }
}

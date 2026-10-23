import SwiftUI

// MARK: - BLOK PHONE ecosystem: one event stream that BLOKUP, BLOKCHAT, BLOK WATCH, REP, TRENDS and MY BLOK all react to
//
// The game reports what happened (`BlokNet.shared.emit(...)`). One event fans out to every app: a post on BLOKUP,
// a hashtag on TRENDS, an alert on BLOK WATCH, a DM in BLOKCHAT and a change to your REP. Ambient city drama
// (crews switching, people getting exposed, rumours) is generated on a timer so the feed is alive even when you are quiet.

enum BlokEvent {
    case captured(Int)              // district id
    case lost(Int)
    case bossDown(String)
    case crewKO(String, Int)        // victim name, tier
    case civHurt(String)
    case jobDone(String)
    case wreck
    case runOver(String)
    case youDown(String)            // who put you down
}

struct BlokPost: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var handle: String
    var text: String
    var tag: String
    var likes: Int
    var comments: [String]
    var ts: Double
    var you = false
    var liked = false
}

struct BlokMsg: Codable, Equatable { var mine: Bool; var text: String; var invite = false }

struct BlokThread: Identifiable, Codable, Equatable {
    var id: String            // handle
    var msgs: [BlokMsg]
    var unread: Int
    var crew = false          // the crew group chat is backed by the online crew chat
}

struct BlokAlert: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var text: String
    var district: Int
    var hot: Bool
    var ts: Double
}

struct BlokRep: Codable, Equatable {
    var respect: Double = 20      // what the streets think of you
    var loyalty: Double = 50      // with your own crew
    var fear: Double = 5          // how scared people are of you
    var trust: Double = 60        // civilians
    var kings: Double = 0         // East Side Kings: -100 war ... +100 allies
    var vipers: Double = -10      // Viper Row

    var title: String {
        switch respect {
        case ..<15: return "NOBODY"
        case ..<35: return "NEW FACE"
        case ..<55: return "KNOWN"
        case ..<75: return "RESPECTED"
        case ..<90: return "BLOK LEGEND"
        default: return "OG"
        }
    }
    var line: String {
        if fear > 70 && trust < 35 { return "People cross the street when they see you." }
        if trust < 25 { return "The block does not trust you." }
        if respect > 70 { return "Corners know your name." }
        if fear > 50 { return "Rivals watch their backs around you." }
        if loyalty < 30 { return "Your crew is wondering where you stand." }
        return "Still earning your name."
    }
}

final class BlokNet: ObservableObject {
    static let shared = BlokNet()

    @Published var posts: [BlokPost] = []
    @Published var threads: [BlokThread] = []
    @Published var alerts: [BlokAlert] = []
    @Published var trends: [String: Int] = [:]
    @Published var rep = BlokRep()
    @Published var status = "Grinding"
    @Published var seenPosts = 0
    @Published var captures = 0
    @Published var bossDowns = 0
    @Published var wrecks = 0
    @Published var yourPosts = 0

    private var ambientT: Double = 40
    private var lastCiv: Double = 0
    private var koCount = 0
    private let key = "ab.blok.v1"

    private struct Saved: Codable {
        var posts: [BlokPost]; var threads: [BlokThread]; var alerts: [BlokAlert]; var trends: [String: Int]; var rep: BlokRep
        var status: String; var captures: Int; var bossDowns: Int; var wrecks: Int; var yourPosts: Int
    }

    private init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            posts = s.posts; threads = s.threads; alerts = s.alerts; trends = s.trends; rep = s.rep
            status = s.status; captures = s.captures; bossDowns = s.bossDowns; wrecks = s.wrecks; yourPosts = s.yourPosts
        }
        if threads.isEmpty { seed() }
    }

    private func save() {
        let s = Saved(posts: Array(posts.prefix(40)), threads: threads, alerts: Array(alerts.prefix(12)), trends: trends, rep: rep,
                      status: status, captures: captures, bossDowns: bossDowns, wrecks: wrecks, yourPosts: yourPosts)
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }

    private func seed() {
        threads = [
            BlokThread(id: "RIVERSIDE CREW", msgs: [], unread: 0, crew: true),
            BlokThread(id: "Rico", msgs: [BlokMsg(mine: false, text: "Twin, where you at? Viper Row is on our corner again."), BlokMsg(mine: false, text: "Got a run that needs doing.", invite: true)], unread: 2),
            BlokThread(id: "Dee", msgs: [BlokMsg(mine: false, text: "Got a package that needs to move. Check Jobs.")], unread: 1),
        ]
        let now = Date().timeIntervalSince1970
        posts = [
            BlokPost(handle: "dee.onthemove", text: "Whole Blok quiet till somebody makes a move 👀", tag: "BLOK", likes: 41, comments: ["facts"], ts: now - 600),
            BlokPost(handle: "tasha.rsd", text: "Who still owes Rico? Don't make me say names.", tag: "BEEF", likes: 88, comments: ["💀", "say it"], ts: now - 1500),
        ]
        trends = ["BLOK": 12, "BEEF": 18]
        alerts = [BlokAlert(text: "Viper Row spotted near the Yard", district: 2, hot: true, ts: now - 300)]
    }

    // MARK: helpers

    static func ago(_ ts: Double) -> String {
        let s = max(0, Date().timeIntervalSince1970 - ts)
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60))m" }
        return "\(Int(s / 3600))h"
    }
    private func hot(_ v: Int) -> Int { v + Int.random(in: 0...(v / 3 + 2)) }
    private func district(_ id: Int) -> String { OWDistrict.base[min(max(id, 0), OWDistrict.base.count - 1)].name.capitalized }

    private func post(_ handle: String, _ text: String, tag: String, likes: Int, comments: [String] = []) {
        DispatchQueue.main.async {
            self.posts.insert(BlokPost(handle: handle, text: text, tag: tag, likes: self.hot(likes), comments: comments, ts: Date().timeIntervalSince1970), at: 0)
            if self.posts.count > 60 { self.posts.removeLast() }
            self.trends[tag, default: 0] += max(1, likes / 6)
            self.save()
        }
    }
    private func alert(_ text: String, _ d: Int, hot: Bool = true) {
        DispatchQueue.main.async {
            self.alerts.insert(BlokAlert(text: text, district: d, hot: hot, ts: Date().timeIntervalSince1970), at: 0)
            if self.alerts.count > 14 { self.alerts.removeLast() }
        }
    }
    private func dm(_ who: String, _ text: String, invite: Bool = false) {
        DispatchQueue.main.async {
            if let i = self.threads.firstIndex(where: { $0.id == who }) {
                self.threads[i].msgs.append(BlokMsg(mine: false, text: text, invite: invite))
                self.threads[i].unread += 1
            } else {
                self.threads.append(BlokThread(id: who, msgs: [BlokMsg(mine: false, text: text, invite: invite)], unread: 1))
            }
            self.save()
        }
    }
    private func bump(_ f: @escaping (inout BlokRep) -> Void) {
        DispatchQueue.main.async {
            f(&self.rep)
            self.rep.respect = max(0, min(100, self.rep.respect)); self.rep.loyalty = max(0, min(100, self.rep.loyalty))
            self.rep.fear = max(0, min(100, self.rep.fear)); self.rep.trust = max(0, min(100, self.rep.trust))
            self.rep.kings = max(-100, min(100, self.rep.kings)); self.rep.vipers = max(-100, min(100, self.rep.vipers))
            self.save()
        }
    }

    // MARK: one event, every app

    func emit(_ ev: BlokEvent) {
        let me = UserDefaults.standard.string(forKey: "ab.playername") ?? "MRZEFV"
        switch ev {
        case .captured(let d):
            let n = district(d)
            DispatchQueue.main.async { self.captures += 1 }
            post("riverside.rae", "\(n) just flipped. \(me) running the whole block now 💀🔥", tag: n.uppercased().replacingOccurrences(of: " ", with: ""), likes: 120, comments: ["WE UP", "Downtown next"])
            alert("\(n) captured by your crew", d)
            dm("Rico", "We got \(n), twin. Hold it down.")
            bump { $0.respect += 6; $0.loyalty += 3; $0.kings -= 2 }
        case .lost(let d):
            let n = district(d)
            post("blokwatch.daily", "\(n) fell. Somebody ain't holding their corner 😭", tag: n.uppercased().replacingOccurrences(of: " ", with: ""), likes: 90, comments: ["who let this happen"])
            alert("\(n) lost to a rival crew", d)
            dm("Rico", "They took \(n). We gotta answer that.", invite: true)
            bump { $0.loyalty -= 3; $0.respect -= 2 }
        case .bossDown(let name):
            DispatchQueue.main.async { self.bossDowns += 1 }
            post("viper.row.exposed", "\(name.uppercased()) GOT DROPPED IN THE STREET. Somebody film that?? 😭😭", tag: "\(name.uppercased())DOWN", likes: 300, comments: ["it's over for them", "who did this"])
            alert("\(name) taken down", 2)
            dm("Viper_Ghost", "You made a mistake. We know your face.")
            bump { $0.respect += 10; $0.fear += 12; $0.vipers -= 20; $0.loyalty += 4 }
        case .crewKO(let victim, let tier):
            koCount += 1
            bump { $0.respect += tier > 0 ? 1.4 : 0.5; $0.fear += 0.6; $0.vipers -= 1; $0.kings -= 0.5 }
            if koCount % 5 == 0 {
                post("tasha.rsd", "Somebody out here knocking \(victim) and them out, no warning 😭", tag: "BEEF", likes: 70, comments: ["twin??"])
            }
        case .civHurt(let name):
            bump { $0.trust -= 2; $0.fear += 0.8; $0.respect -= 0.3 }
            let t = Date().timeIntervalSince1970
            if t - lastCiv > 25 {
                lastCiv = t
                post("marcus.m", "Somebody jumped \(name) on the block for NOTHING. This ain't it.", tag: "NOTIT", likes: 60, comments: ["facts"])
            }
        case .jobDone(let title):
            post("dee.onthemove", "\(me) delivered. Clean. \(title.capitalized) done ✅", tag: "BLOK", likes: 45, comments: ["he moves different"])
            bump { $0.respect += 2; $0.loyalty += 1.5 }
        case .wreck:
            DispatchQueue.main.async { self.wrecks += 1 }
            post("whip.watch", "Somebody just wrecked a whip on the main strip 🚗💀", tag: "WRECKED", likes: 55, comments: ["insurance??"])
            bump { $0.trust -= 1 }
        case .runOver(let name):
            bump { $0.trust -= 3; $0.fear += 2 }
            post("marcus.m", "\(name) got hit by a car and the driver kept going 😡", tag: "NOTIT", likes: 80)
        case .youDown(let by):
            post("viper.row.exposed", "\(me) got caught lacking by \(by) 😭", tag: "CAUGHTLACKING", likes: 110, comments: ["L", "revenge arc?"])
            bump { $0.respect -= 2; $0.vipers += 0 }
        }
    }

    // MARK: ambient city drama

    func tick(_ dt: Double) {
        ambientT -= dt
        guard ambientT <= 0 else { return }
        ambientT = Double.random(in: 70...140)
        let hd = Int.random(in: 0..<OWDistrict.base.count)
        let n = district(hd)
        let pick = Int.random(in: 0..<6)
        switch pick {
        case 0: post("blokwatch.daily", "BREAKING: a member just switched crews in \(n). Allegiance is a suggestion now.", tag: "SWITCHEDUP", likes: 130, comments: ["not them 😭", "called it"]); bump { $0.vipers += 1 }
        case 1: post("tasha.rsd", "Y'all hear what happened at the \(n) corner? I'm not saying, I'm just saying.", tag: "RUMOR", likes: 75, comments: ["tell us"])
        case 2: post("viper.row.exposed", "EXPOSED: somebody on the East Side been talking to Viper Row 👀", tag: "EXPOSED", likes: 160, comments: ["wait what", "receipts??"]); bump { $0.kings -= 1.5 }
        case 3: alert("Crew movement spotted in \(n)", hd)
        case 4: post("dee.onthemove", "\(n) got a new spot opening. Whoever gets there first.", tag: "BLOK", likes: 50)
        default: dm(["Rico", "Dee"].randomElement()!, ["Where you at? Tap in.", "You seen what they posting?", "Need you on a run, twin."].randomElement()!)
        }
        // trends cool off
        DispatchQueue.main.async {
            for (k, v) in self.trends { self.trends[k] = max(0, v - 2); if self.trends[k] == 0 { self.trends[k] = nil } }
        }
    }

    // MARK: player actions

    func publish(_ text: String, tag: String = "MYBLOK") {
        let me = UserDefaults.standard.string(forKey: "ab.playername") ?? "MRZEFV"
        posts.insert(BlokPost(handle: me.lowercased(), text: text, tag: tag, likes: Int.random(in: 4...30), comments: [], ts: Date().timeIntervalSince1970, you: true), at: 0)
        yourPosts += 1
        trends[tag, default: 0] += 3
        rep.respect = min(100, rep.respect + 0.4)
        save()
    }

    func like(_ id: String) {
        guard let i = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[i].liked.toggle()
        posts[i].likes += posts[i].liked ? 1 : -1
        save()
    }

    func send(_ text: String, to id: String) {
        guard let i = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[i].msgs.append(BlokMsg(mine: true, text: text))
        save()
        let replies = ["on my way 🫡", "say less.", "bet. tap in when you close", "twin, you wild 😭", "I got you."]
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.2...2.8)) {
            if let j = self.threads.firstIndex(where: { $0.id == id }) {
                self.threads[j].msgs.append(BlokMsg(mine: false, text: replies.randomElement()!))
                self.save()
            }
        }
    }

    func setStatus(_ s: String) { status = s; save() }
    func read(_ id: String) { if let i = threads.firstIndex(where: { $0.id == id }), threads[i].unread > 0 { threads[i].unread = 0 } }
    func markSeen() { seenPosts = posts.count }
    var unreadChats: Int { threads.reduce(0) { $0 + $1.unread } }
    var trending: [(String, Int)] { trends.sorted { $0.value > $1.value }.prefix(6).map { ($0.key, $0.value) } }
}

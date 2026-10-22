import SwiftUI

// MARK: - Online layer for Crew, Events, Shop and the shared map
//
// One service object. With a server address set (CREW screen > LOGS tab, or UserDefaults "ab.server") every call goes to
// that server (reference implementation: server/server.js). With no address it runs fully offline on this device, so
// the screens always work. Real-money payments are NOT part of this: the shop pays with in-game coins.

struct OWMember: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var level: Int
    var role: String
    var status: Int          // 0 online, 1 in menu, 2 offline
    var last: String
}

struct OWChatMsg: Codable, Identifiable, Equatable {
    var id: String
    var from: String
    var text: String
    var ts: Double
}

struct OWCrewData: Codable {
    var members: [OWMember]
    var requests: [OWMember]
    var chat: [OWChatMsg]
}

final class OWOnline: ObservableObject {
    static let shared = OWOnline()

    @Published var members: [OWMember] = OWOnline.sampleMembers
    @Published var requests: [OWMember] = OWOnline.sampleRequests
    @Published var chat: [OWChatMsg] = []
    @Published var takedowns = 0
    @Published var claimed = false
    @Published var connected = false
    @Published var status = "OFFLINE · LOCAL"
    @Published var logs: [String] = []

    static let eventGoal = 50
    static let eventReward = 2500          // coins

    private let d = UserDefaults.standard
    let playerID: String

    var baseURL: String {
        get { d.string(forKey: "ab.server") ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "ab.server") }
    }
    var playerName: String { d.string(forKey: "ab.playername") ?? "MRZEFV" }

    private init() {
        if let id = UserDefaults.standard.string(forKey: "ab.playerid") { playerID = id }
        else { playerID = UUID().uuidString; UserDefaults.standard.set(playerID, forKey: "ab.playerid") }
        takedowns = d.integer(forKey: "ab.ev.takedowns")
        claimed = d.bool(forKey: "ab.ev.claimed")
        if let data = d.data(forKey: "ab.chat"), let c = try? JSONDecoder().decode([OWChatMsg].self, from: data) { chat = c }
        else { chat = [OWChatMsg(id: "s1", from: "RicoStacks", text: "Yard is wide open tonight", ts: Date().timeIntervalSince1970 - 900),
                       OWChatMsg(id: "s2", from: "ShadowK", text: "On my way, bring the crew", ts: Date().timeIntervalSince1970 - 600)] }
    }

    static let sampleMembers = [
        OWMember(id: "m0", name: "MRZEFV", level: 12, role: "Leader", status: 0, last: "Now"),
        OWMember(id: "m1", name: "RicoStacks", level: 11, role: "Officer", status: 0, last: "2m ago"),
        OWMember(id: "m2", name: "ShadowK", level: 10, role: "Officer", status: 0, last: "5m ago"),
        OWMember(id: "m3", name: "LunaZ", level: 9, role: "Member", status: 1, last: "12m ago"),
        OWMember(id: "m4", name: "TacoBandit", level: 8, role: "Member", status: 0, last: "16m ago"),
        OWMember(id: "m5", name: "GhostRider", level: 7, role: "Member", status: 2, last: "1h ago"),
        OWMember(id: "m6", name: "BigDre", level: 6, role: "Member", status: 2, last: "3h ago"),
        OWMember(id: "m7", name: "KillaBee", level: 5, role: "Recruit", status: 2, last: "5h ago"),
    ]
    static let sampleRequests = [
        OWMember(id: "r1", name: "NightOwl", level: 6, role: "Recruit", status: 2, last: "Request 1h ago"),
        OWMember(id: "r2", name: "Vex", level: 8, role: "Recruit", status: 2, last: "Request 3h ago"),
        OWMember(id: "r3", name: "Dozer", level: 4, role: "Recruit", status: 2, last: "Request 6h ago"),
    ]

    // MARK: plumbing

    private func log(_ s: String) {
        DispatchQueue.main.async { self.logs.insert(s, at: 0); if self.logs.count > 30 { self.logs.removeLast() } }
    }

    private func request(_ path: String, _ method: String = "GET", body: [String: Any]? = nil) async -> Data? {
        guard !baseURL.isEmpty, let url = URL(string: baseURL + path) else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 6)
        r.httpMethod = method
        if let b = body {
            r.httpBody = try? JSONSerialization.data(withJSONObject: b)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        r.setValue(playerID, forHTTPHeaderField: "X-Player")
        do {
            let (data, resp) = try await URLSession.shared.data(for: r)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { log("\(method) \(path) -> HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)"); return nil }
            return data
        } catch {
            log("\(method) \(path) failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func setStatus(_ on: Bool) {
        DispatchQueue.main.async {
            self.connected = on
            self.status = on ? "ONLINE" : (self.baseURL.isEmpty ? "OFFLINE · LOCAL" : "SERVER UNREACHABLE · LOCAL")
        }
    }

    private func saveChat() {
        if let data = try? JSONEncoder().encode(Array(chat.suffix(60))) { d.set(data, forKey: "ab.chat") }
    }

    // MARK: connect

    /// say hello, pull the crew and the world; falls back to local data when there is no server
    func connect() {
        Task {
            let me: [String: Any] = ["player": playerID, "name": playerName, "level": 12]
            if let _ = await request("/api/hello", "POST", body: me) {
                setStatus(true)
                await refreshCrew()
                await pullWorld()
                await pullEvent()
            } else {
                setStatus(false)
            }
        }
    }

    // MARK: crew

    func refreshCrew() async {
        guard let data = await request("/api/crew"), let c = try? JSONDecoder().decode(OWCrewData.self, from: data) else { return }
        await MainActor.run { members = c.members; requests = c.requests; chat = c.chat }
    }

    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let m = OWChatMsg(id: UUID().uuidString, from: playerName, text: String(t.prefix(140)), ts: Date().timeIntervalSince1970)
        chat.append(m)
        saveChat()
        Task {
            if await request("/api/crew/chat", "POST", body: ["player": playerID, "name": playerName, "text": m.text]) != nil { await refreshCrew() }
        }
    }

    func respond(_ r: OWMember, accept: Bool) {
        requests.removeAll { $0.id == r.id }
        if accept {
            var m = r; m.role = "Member"; m.last = "Just joined"
            members.append(m)
        }
        Task { _ = await request("/api/crew/request", "POST", body: ["id": r.id, "accept": accept]); await refreshCrew() }
    }

    // MARK: events

    func progress(_ delta: Int) {
        takedowns += delta
        d.set(takedowns, forKey: "ab.ev.takedowns")
        Task { _ = await request("/api/event/progress", "POST", body: ["player": playerID, "delta": delta]) }
    }

    func pullEvent() async {
        guard let data = await request("/api/event"), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        await MainActor.run {
            if let t = j["takedowns"] as? Int { takedowns = max(takedowns, t); d.set(takedowns, forKey: "ab.ev.takedowns") }
            if let c = j["claimed"] as? Bool, c { claimed = true; d.set(true, forKey: "ab.ev.claimed") }
        }
    }

    /// coins won, 0 when not finished or already paid
    func claim() async -> Int {
        guard takedowns >= Self.eventGoal, !claimed else { return 0 }
        if !baseURL.isEmpty {
            guard let data = await request("/api/event/claim", "POST", body: ["player": playerID]),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], (j["ok"] as? Bool) == true else { return 0 }
        }
        await MainActor.run { claimed = true; d.set(true, forKey: "ab.ev.claimed") }
        return Self.eventReward
    }

    // MARK: shop

    /// pay with coins; the server records the purchase. Returns false if the server refused.
    func checkout(items: [String], cost: Int) async -> Bool {
        if !baseURL.isEmpty {
            guard let data = await request("/api/shop/checkout", "POST", body: ["player": playerID, "items": items, "cost": cost]),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any], (j["ok"] as? Bool) == true else { return false }
        }
        var owned = d.stringArray(forKey: "ab.purchases") ?? []
        owned.append(contentsOf: items)
        d.set(owned, forKey: "ab.purchases")
        return true
    }

    // MARK: shared map

    func pushDelta(_ district: Int, _ delta: Int) {
        guard !baseURL.isEmpty else { return }
        Task { _ = await request("/api/world/delta", "POST", body: ["player": playerID, "district": district, "delta": delta]) }
    }

    func pullWorld() async {
        guard let data = await request("/api/world"), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else { return }
        await MainActor.run { for (k, v) in j { if let id = Int(k), (0..<OWDistrict.base.count).contains(id) { OWWorld.shared.set(id, v) } } }
    }
}

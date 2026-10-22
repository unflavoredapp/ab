import SwiftUI

// MARK: - In-world phone: an iPhone-style device with working apps (Free Roam)

struct RoamPhone: View {
    let e: TacticalEngine
    let close: () -> Void
    let openJobs: () -> Void

    @State private var app = ""            // "" is the home screen
    @State private var toast = ""

    private let gold = Color(red: 1, green: 0.8, blue: 0.25)
    private let blue = Color(red: 0.4, green: 0.65, blue: 1)
    private let W: CGFloat = 150
    private let H: CGFloat = 300

    private struct App { let id: String; let icon: String; let title: String; let tint: Color }
    private var apps: [App] {
        [App(id: "jobs", icon: "briefcase.fill", title: "Jobs", tint: gold), App(id: "map", icon: "map.fill", title: "Map", tint: blue),
         App(id: "crew", icon: "person.3.fill", title: "Crew", tint: blue), App(id: "inv", icon: "bag.fill", title: "Inventory", tint: blue),
         App(id: "shop", icon: "cart.fill", title: "Shop", tint: Color.green), App(id: "events", icon: "calendar", title: "Events", tint: Color.red),
         App(id: "msg", icon: "message.fill", title: "Messages", tint: Color.green), App(id: "set", icon: "gearshape.fill", title: "Settings", tint: .gray),
         App(id: "contacts", icon: "person.crop.circle.fill", title: "Contacts", tint: blue)]
    }

    private func say(_ s: String) {
        toast = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if toast == s { toast = "" } }
    }

    // MARK: chrome

    private var status: some View {
        HStack {
            Text("9:41").font(.jk(8, .heavy)).foregroundColor(.white)
            Spacer()
            Image(systemName: "cellularbars").font(.system(size: 7)).foregroundColor(.white)
            Image(systemName: "wifi").font(.system(size: 7)).foregroundColor(.white)
            Image(systemName: "battery.100").font(.system(size: 8)).foregroundColor(.white)
        }
        .padding(.horizontal, 14).frame(height: 18)
        .overlay(Capsule().fill(Color.black).frame(width: 44, height: 11).overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)))
    }

    private var homeBar: some View {
        Button { if app.isEmpty { close() } else { withAnimation(.easeOut(duration: 0.18)) { app = "" } } } label: {
            Capsule().fill(Color.white.opacity(0.75)).frame(width: 46, height: 3.5).frame(width: 120, height: 14)
        }.buttonStyle(.plain)
    }

    private func header(_ t: String) -> some View {
        HStack(spacing: 4) {
            Button { withAnimation(.easeOut(duration: 0.18)) { app = "" } } label: { Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold)).foregroundColor(blue) }.buttonStyle(.plain)
            Text(t).font(.jk(11, .heavy)).foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.top, 2)
    }

    // MARK: home

    private func icon(_ a: App) -> some View {
        Button {
            if a.id == "set" { e.paused = true; close() }
            else if a.id == "jobs" { openJobs() }
            else { withAnimation(.easeOut(duration: 0.18)) { app = a.id } }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: a.icon).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [a.tint.opacity(0.7), a.tint.opacity(0.3)], startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 0.7))
                    .overlay(alignment: .topTrailing) {
                        if a.id == "jobs" && e.roam.job == nil { Text("3").font(.jk(6.5, .heavy)).foregroundColor(.white).frame(width: 11, height: 11).background(Circle().fill(Color.red)).offset(x: 3, y: -3) }
                    }
                Text(a.title).font(.jk(6.5, .medium)).foregroundColor(.white.opacity(0.9))
            }
        }.buttonStyle(.plain)
    }

    private var home: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "crown.fill").font(.system(size: 10)).foregroundColor(Color(red: 1, green: 0.6, blue: 0.2))
                Text("HOOD WARS").font(.jk(10, .heavy)).italic().foregroundColor(.white.opacity(0.9))
            }
            .padding(.top, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 8) {
                ForEach(apps, id: \.id) { icon($0) }
            }
            .padding(.horizontal, 10)
            Spacer(minLength: 0)
            if !toast.isEmpty { Text(toast).font(.jk(7.5, .semibold)).foregroundColor(gold).multilineTextAlignment(.center) }
        }
    }

    // MARK: apps

    private func row(_ l: String, _ r: String, _ col: Color = .white) -> some View {
        HStack {
            Text(l).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(r).font(.jk(8, .heavy)).foregroundColor(col).monospacedDigit()
        }
        .padding(.horizontal, 8).frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
    }

    private var mapApp: some View {
        VStack(spacing: 4) {
            header("Map")
            ForEach(OWDistrict.all.prefix(6)) { d in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(d.name).font(.jk(7.5, .heavy)).foregroundColor(.white)
                        Spacer()
                        Text("\(d.control)%").font(.jk(7.5, .heavy)).foregroundColor(d.color)
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(d.color).frame(width: 116 * CGFloat(d.control) / 100)
                    }.frame(width: 116, height: 3)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
            }
            Spacer(minLength: 0)
        }
    }

    private var crewApp: some View {
        VStack(spacing: 4) {
            header("Crew")
            ForEach([("MRZEFV", "Leader", true), ("RicoStacks", "Officer", true), ("ShadowK", "Officer", true), ("LunaZ", "Member", false), ("TacoBandit", "Member", true)], id: \.0) { m in
                HStack(spacing: 6) {
                    OWAvatar(name: m.0, s: 18, online: m.2 ? Color.green : Color.gray)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(m.0).font(.jk(8, .heavy)).foregroundColor(.white)
                        Text(m.1).font(.jk(6.5, .medium)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 8).frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
            }
            Spacer(minLength: 0)
        }
    }

    private var invApp: some View {
        VStack(spacing: 4) {
            header("Inventory")
            row("Weapon", "FISTS")
            row("Health", "\(Int(e.me.hp))")
            row("Armor", "\(Int(e.me.armor))")
            row("Cash", "$\(e.roam.cash)", gold)
            row("K.O.s", "\(e.roam.crewKOs + e.roam.civKOs)")
            row("Best combo", "x\(max(e.roam.bestCombo, e.bestCombo))")
            Spacer(minLength: 0)
        }
    }

    private func buy(_ name: String, _ cost: Int, _ what: @escaping () -> Bool) -> some View {
        Button {
            if e.roam.cash < cost { say("Not enough cash") }
            else if what() { e.roam.cash -= cost; say("\(name) bought") }
        } label: {
            HStack {
                Text(name).font(.jk(8.5, .heavy)).foregroundColor(.white)
                Spacer()
                Text("$\(cost)").font(.jk(8.5, .heavy)).foregroundColor(gold)
            }
            .padding(.horizontal, 8).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.09)))
        }.buttonStyle(.plain)
    }

    private var shopApp: some View {
        VStack(spacing: 4) {
            header("Shop")
            row("Your cash", "$\(e.roam.cash)", gold)
            buy("Medkit  +50 HP", 150) {
                guard e.me.alive, e.me.hp < 100 else { say("Already healthy"); return false }
                e.me.hp = min(100, e.me.hp + 50); return true
            }
            buy("Armor vest", 300) {
                guard e.me.alive, e.me.armor < 100 else { say("Armor is full"); return false }
                e.me.armor = 100; e.me.armorKind = 1; return true
            }
            Text(toast).font(.jk(7.5, .semibold)).foregroundColor(gold)
            Spacer(minLength: 0)
        }
    }

    private var eventsApp: some View {
        let n = e.roam.crewKOs
        return VStack(spacing: 4) {
            header("Events")
            VStack(alignment: .leading, spacing: 3) {
                Text("RIVAL CREW TAKEDOWN").font(.jk(9, .heavy)).italic().foregroundColor(.white)
                Text("Knock out rival crew members.").font(.jk(7, .medium)).foregroundColor(.white.opacity(0.7))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Color.red).frame(width: 118 * CGFloat(min(50, n)) / 50)
                }.frame(width: 118, height: 3.5)
                Text("\(n) / 50").font(.jk(8, .heavy)).foregroundColor(.white)
            }
            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
            Spacer(minLength: 0)
        }
    }

    private var msgApp: some View {
        VStack(spacing: 4) {
            header("Messages")
            ForEach([("Dee", "Got a package that needs to move. Check Jobs."), ("Rico", "Viper Row is on our corner again."), ("Nova", "Razor was seen near the yard.")], id: \.0) { m in
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.0).font(.jk(8, .heavy)).foregroundColor(blue)
                    Text(m.1).font(.jk(7.5, .medium)).foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 8).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var screen: some View {
        switch app {
        case "map": mapApp
        case "crew", "contacts": crewApp
        case "inv": invApp
        case "shop": shopApp
        case "events": eventsApp
        case "msg": msgApp
        default: home
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            status.padding(.top, 8)
            screen.padding(.horizontal, 6).transition(.opacity)
            homeBar.padding(.bottom, 4)
        }
        .frame(width: W, height: H)
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.06, blue: 0.02), Color(red: 0.02, green: 0.03, blue: 0.06), Color(red: 0.02, green: 0.03, blue: 0.06)], startPoint: .topTrailing, endPoint: .bottomLeading))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(white: 0.55), lineWidth: 3))
        .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.black, lineWidth: 3).padding(-3))
        .shadow(color: Color.blue.opacity(0.35), radius: 12)
    }
}

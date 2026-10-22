import SwiftUI

/// Shared top bar for the lobby pages (logo, tabs, currencies, profile, icons). `selected`: 0 HideOut, 1 Play,
/// 2 Shop, 3 Inventory, 4 Event.
struct LobbyTopBar: View {
    @EnvironmentObject var game: Game
    let t: TacData
    let u: CGFloat
    let selected: Int
    var accent = Color(red: 0.25, green: 0.65, blue: 1.0)
    let act: (LobbyAct) -> Void

    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.78)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.22)

    private func tab(_ title: String, _ i: Int, _ action: @escaping () -> Void) -> some View {
        let on = i == selected
        return Button(action: action) {
            Text(title).font(.jk(13 * u, on ? .heavy : .semibold)).foregroundColor(on ? accent : .white.opacity(0.62))
                .padding(.horizontal, 16 * u).frame(height: 44 * u)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(on ? accent : .clear).frame(height: 2 * u).padding(.horizontal, 8 * u)
                        .shadow(color: accent.opacity(0.9), radius: 5 * u)
                }
        }.buttonStyle(.plain)
    }

    private func currency(_ letter: String, _ value: String, _ ring: Color) -> some View {
        HStack(spacing: 6 * u) {
            Text(letter).font(.jk(7 * u, .heavy)).foregroundColor(.black.opacity(0.75))
                .frame(width: 16 * u, height: 16 * u).background(Circle().fill(ring))
            Text(value).font(.jk(10.5 * u, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
        }
        .padding(.horizontal, 9 * u).frame(height: 24 * u)
        .background(Capsule().fill(glass)).overlay(Capsule().stroke(edge, lineWidth: 1))
    }

    var body: some View {
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        return HStack(spacing: 0) {
            AirbladeLogo(size: 18 * u).padding(.leading, 26 * u).padding(.trailing, 14 * u)
            tab("HideOut", 0) { act(.nav(0)) }
            tab("Play", 1) { act(.screen(1)) }
            tab("Shop", 2) { act(.nav(6)) }
            tab("Inventory", 3) { act(.screen(15)) }
            tab("Event", 4) { act(.season(0)) }
            Spacer(minLength: 6 * u)
            HStack(spacing: 10 * u) {
                currency("C", game.s.ex.gems.formatted(), Color(red: 1, green: 0.75, blue: 0.22))
                currency("ZC", "\(t.rating)", Color(red: 0.4, green: 0.7, blue: 1))
            }
            .padding(.trailing, 14 * u)
            Button { act(.ranks) } label: {
                HStack(spacing: 8 * u) {
                    BladeEmblem().frame(width: 22 * u, height: 25 * u).padding(4 * u)
                        .background(RoundedRectangle(cornerRadius: 4 * u).fill(Color(red: 0.22, green: 0.04, blue: 0.06)))
                    VStack(alignment: .leading, spacing: 3 * u) {
                        Text(TacProfile.name.uppercased()).font(.jk(10.5 * u, .heavy)).italic().foregroundColor(.white).lineLimit(1)
                        HStack(spacing: 6 * u) {
                            Text("Lv. \(ri + 1)").font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.7)).fixedSize()
                            Spacer(minLength: 0)
                            Text("EXP \(Int(TacRank.progress(xp) * 100))%").font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.7)).fixedSize()
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.14))
                            Capsule().fill(Color(red: 0.25, green: 0.65, blue: 1)).frame(width: 96 * u * CGFloat(TacRank.progress(xp)))
                        }
                        .frame(width: 96 * u, height: 3.5 * u)
                    }
                    .frame(width: 96 * u, alignment: .leading)
                }
                .padding(.horizontal, 8 * u).frame(height: 38 * u)
                .background(RoundedRectangle(cornerRadius: 6 * u).fill(glass))
                .overlay(RoundedRectangle(cornerRadius: 6 * u).stroke(edge, lineWidth: 1))
            }.buttonStyle(.plain)
            HStack(spacing: 2 * u) {
                Button { act(.friends) } label: {
                    Image(systemName: "envelope.fill").font(.system(size: 14 * u)).foregroundColor(.white.opacity(0.75)).frame(width: 30 * u, height: 30 * u)
                        .overlay(alignment: .topTrailing) { Circle().fill(Color.red).frame(width: 5 * u, height: 5 * u).offset(x: -6 * u, y: 6 * u) }
                }.buttonStyle(.plain)
                Button { act(.stats) } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 14 * u)).foregroundColor(.white.opacity(0.75)).frame(width: 30 * u, height: 30 * u)
                }.buttonStyle(.plain)
            }
            .padding(.leading, 8 * u).padding(.trailing, 14 * u)
        }
        .frame(height: 44 * u)
        .background(LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.06).opacity(0.88), Color(red: 0.02, green: 0.03, blue: 0.06).opacity(0.3)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Rectangle().fill(edge).frame(height: 1) }
    }
}

/// INVENTORY page, laid out like the mockup: equipped slots on the left, the hero in the middle (drawn by the
/// backdrop), the item browser on the right (tabs, class filters, search, list, details) and Delete / Equip.
struct InventoryView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var subTab = 0          // 0 Storage, 1 Customize
    @State private var tab = 0             // Weapons, Armor, Items, Account
    @State private var filter = "all"      // all, rifle, smg, pistol, sniper, shotgun, melee
    @State private var search = ""
    @State private var picked = "blade"
    @State private var note = ""

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.82)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)

    private var W: CGFloat { size.width }
    private var H: CGFloat { size.height }
    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    // MARK: data

    private struct Item: Identifiable { let id: String; let name: String; let cls: String }

    private var items: [Item] {
        var out = [Item(id: "blade", name: "AIRBLADE", cls: "melee")]
        out += TWeapons.all.map { Item(id: $0.id, name: $0.name, cls: $0.cls) }
        return out.filter { (filter == "all" || $0.cls == filter) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }

    private func equipped(_ id: String) -> Bool {
        id == "blade" || id == nav.tacGun || id == TacticalEngine.secondary
    }

    private func clsTitle(_ c: String) -> String {
        ["melee": "Sword", "rifle": "Rifle", "smg": "SMG", "pistol": "Pistol", "sniper": "Sniper", "shotgun": "Shotgun"][c] ?? c.capitalized
    }

    @ViewBuilder private func art(_ id: String, h: CGFloat) -> some View {
        if id == "blade" {
            BladeGlyph().fill(LinearGradient(colors: [.white, Color(white: 0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: h * 3, height: h)
        } else {
            Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit().foregroundColor(.white.opacity(0.92)).frame(height: h)
        }
    }

    // MARK: left: equipped

    private func slot(_ title: String, _ id: String?, _ icon: String, h: CGFloat, hot: Bool = false) -> some View {
        Button { if let i = id { picked = i } } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 4 * u).fill(card)
                if let i = id {
                    art(i, h: h * 0.42).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 10 * u)
                } else {
                    Image(systemName: icon).font(.system(size: h * 0.32)).foregroundColor(.white.opacity(0.25))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Text(title).font(.jk(8.5 * u, .semibold)).foregroundColor(.white.opacity(id == nil ? 0.35 : 0.9))
                    .padding(.leading, 7 * u).padding(.bottom, 5 * u)
            }
            .frame(width: 150 * u, height: h)
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(hot ? orange : edge, lineWidth: hot ? 1.5 : 1))
            .shadow(color: hot ? orange.opacity(0.45) : .clear, radius: 6 * u)
        }.buttonStyle(.plain)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 5 * u) {
            HStack(spacing: 0) {
                ForEach(Array(["scope", "shield.lefthalf.filled", "person.crop.circle"].enumerated()), id: \.offset) { i, s in
                    Image(systemName: s).font(.system(size: 13 * u)).foregroundColor(i == 0 ? .white : .white.opacity(0.45))
                        .frame(width: 50 * u, height: 26 * u)
                        .overlay(alignment: .bottom) { Rectangle().fill(i == 0 ? orange : .clear).frame(height: 2 * u).padding(.horizontal, 8 * u) }
                }
            }
            slot("AIRBLADE", "blade", "", h: 56 * u, hot: picked == "blade")
            slot(TWeapons.w(nav.tacGun).name, nav.tacGun, "", h: 46 * u, hot: picked == nav.tacGun)
            slot(TWeapons.w(TacticalEngine.secondary).name, TacticalEngine.secondary, "", h: 46 * u, hot: picked == TacticalEngine.secondary)
            slot("Grenade", nil, "circle.grid.cross.fill", h: 38 * u)
            slot("Item", nil, "cross.case.fill", h: 38 * u)
        }
    }

    private var bottomLeft: some View {
        HStack(alignment: .bottom, spacing: 6 * u) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 2 * u) {
                    Image(systemName: "circle.circle").font(.system(size: 20 * u, weight: .light)).foregroundColor(.white.opacity(0.7))
                    Text("Ring").font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.7))
                }
                .frame(width: 50 * u, height: 50 * u)
                .background(RoundedRectangle(cornerRadius: 4 * u).fill(card))
                .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
            }
            VStack(spacing: 0) {
                stat("plus", "HP", "100")
                stat("bolt.fill", "AP", "100")
                stat("lock.fill", "WT", "\(3)(20)")
            }
            .frame(width: 140 * u)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(card))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
        }
    }

    private func stat(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 6 * u) {
            Image(systemName: icon).font(.system(size: 9 * u, weight: .bold)).foregroundColor(orange).frame(width: 12 * u)
            Text(k).font(.jk(10 * u, .semibold)).foregroundColor(.white)
            Spacer(minLength: 0)
            Text(v).font(.jk(10 * u, .semibold)).foregroundColor(.white).monospacedDigit()
        }
        .padding(.horizontal, 8 * u).frame(height: 17 * u)
    }

    // MARK: right: browser

    private var panelTabs: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Weapons", "Armor", "Items", "Account"].enumerated()), id: \.offset) { i, s in
                Button { tab = i } label: {
                    Text(s).font(.jk(11 * u, i == tab ? .heavy : .semibold)).foregroundColor(i == tab ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity).frame(height: 28 * u)
                        .background(i == tab ? LinearGradient(colors: [orange.opacity(0.95), orange.opacity(0.55)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
                }.buttonStyle(.plain)
            }
        }
        .background(Color.black.opacity(0.35))
        .overlay(alignment: .bottom) { Rectangle().fill(orange.opacity(0.6)).frame(height: 1) }
    }

    private var filters: some View {
        let fs: [(String, String)] = [("all", "square.grid.2x2.fill"), ("rifle", "r"), ("smg", "s"), ("pistol", "p"), ("sniper", "x"), ("shotgun", "g"), ("melee", "m")]
        return HStack(spacing: 0) {
            ForEach(fs.indices, id: \.self) { k in
                let f = fs[k]
                Button { filter = f.0 } label: {
                    Group {
                        if f.0 == "all" {
                            Image(systemName: f.1).font(.system(size: 13 * u))
                        } else if f.0 == "melee" {
                            BladeGlyph().fill(Color.white).frame(width: 30 * u, height: 11 * u)
                        } else {
                            Image(uiImage: GunSprites.icon(TWeapons.rig(TWeapons.all.first(where: { $0.cls == f.0 })?.id ?? "rifle"))).renderingMode(.template).resizable().scaledToFit().frame(height: 11 * u)
                        }
                    }
                    .foregroundColor(.white)
                    .opacity(filter == f.0 ? 1 : 0.45)
                    .frame(maxWidth: .infinity).frame(height: 26 * u)
                    .overlay(alignment: .bottom) { Rectangle().fill(filter == f.0 ? orange : .clear).frame(height: 2 * u).padding(.horizontal, 10 * u) }
                }.buttonStyle(.plain)
            }
        }
    }

    private func listCard(_ it: Item) -> some View {
        let on = it.id == picked
        return Button { picked = it.id; note = "" } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 3 * u).fill(card)
                art(it.id, h: 18 * u).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 12 * u)
                HStack(spacing: 4 * u) {
                    Text(it.name).font(.jk(9 * u, .semibold)).foregroundColor(.white).lineLimit(1)
                    if equipped(it.id) {
                        Text("E").font(.jk(7 * u, .heavy)).foregroundColor(.black).frame(width: 11 * u, height: 11 * u).background(orange)
                    }
                }
                .padding(.leading, 7 * u).padding(.bottom, 5 * u)
            }
            .frame(height: 48 * u)
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(on ? orange : edge, lineWidth: on ? 1.5 : 1))
            .shadow(color: on ? orange.opacity(0.45) : .clear, radius: 5 * u)
        }.buttonStyle(.plain)
    }

    private func bar(_ f: CGFloat, _ c: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule().fill(c).frame(width: 90 * u * max(0, min(1, f)))
        }
        .frame(width: 90 * u, height: 3.5 * u)
    }

    private func row(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(spacing: 6 * u) {
            Image(systemName: icon).font(.system(size: 9 * u, weight: .bold)).foregroundColor(.white.opacity(0.8)).frame(width: 12 * u)
            Text(k).font(.jk(9.5 * u, .semibold)).foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 0)
            Text(v).font(.jk(9.5 * u, .semibold)).foregroundColor(.white).monospacedDigit()
        }
        .padding(.horizontal, 8 * u).frame(height: 18 * u)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }

    private var details: some View {
        let blade = picked == "blade"
        let w = TWeapons.w(blade ? "pistol" : picked)
        let name = blade ? "AIRBLADE" : w.name
        let cls = blade ? "melee" : w.cls
        let dmg = blade ? ABRules.slashDmg : ABRules.bulletDmg(w.dmg, cls: w.cls) * CGFloat(w.pellets)
        let delay = blade ? 380 : Int(w.interval * 1000)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                art(picked, h: 26 * u).frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 14 * u).padding(.trailing, 8 * u)
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text(name).font(.jk(15 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text(clsTitle(cls)).font(.jk(9 * u, .medium)).foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 8 * u).padding(.top, 6 * u)
            HStack(spacing: 6 * u) {
                Image(systemName: "gauge.with.dots.needle.33percent").font(.system(size: 9 * u)).foregroundColor(orange)
                Text("Durability").font(.jk(9 * u, .semibold)).foregroundColor(.white.opacity(0.85))
                Spacer(minLength: 0)
                Text("Permanent").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 8 * u).padding(.top, 6 * u)
            bar(1, orange).padding(.horizontal, 8 * u).padding(.top, 3 * u)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1 * u) {
                    Text("Damage").font(.jk(8.5 * u, .semibold)).foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 8 * u) {
                        Text("\(Int(dmg))").font(.jk(18 * u, .heavy)).foregroundColor(.white)
                        bar(dmg / 60, orange)
                    }
                }
                Spacer(minLength: 0)
                if !blade {
                    VStack(alignment: .trailing, spacing: 1 * u) {
                        Text("\(w.mag)/\(w.mag * 2)").font(.jk(9 * u, .semibold)).foregroundColor(.white).monospacedDigit()
                        Text("Reload \(String(format: "%.1f", Double(w.reload)))s").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 8 * u).padding(.vertical, 6 * u)
            .background(Color.white.opacity(0.03))
            row("bolt.fill", "Delay", "\(delay)")
            row("plus", "Hp", "0")
            row("shield.fill", "Ap", "0")
            VStack(alignment: .leading, spacing: 3 * u) {
                Text("Info").font(.jk(9.5 * u, .heavy)).foregroundColor(.white)
                Text(blade ? "Your sword. Slash in the air to sword-jump." : "\(clsTitle(cls)) · range \(Int(w.range))").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(2)
                Text("Additional Effect").font(.jk(9.5 * u, .heavy)).foregroundColor(.white).padding(.top, 4 * u)
                Text(blade ? "Backstab: \(Int(ABRules.backstabDmg)) damage" : "—").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.6))
            }
            .padding(8 * u)
            Spacer(minLength: 0)
        }
        .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(edge, lineWidth: 1))
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            panelTabs
            if tab == 0 {
                filters
                HStack(alignment: .top, spacing: 6 * u) {
                    VStack(spacing: 5 * u) {
                        HStack(spacing: 5 * u) {
                            Image(systemName: "magnifyingglass").font(.system(size: 9 * u)).foregroundColor(.white.opacity(0.6))
                            TextField("", text: $search, prompt: Text("Search item...").foregroundColor(.white.opacity(0.35)))
                                .font(.jk(9 * u, .medium)).foregroundColor(.white)
                                .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                        }
                        .padding(.horizontal, 7 * u).frame(height: 22 * u)
                        .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.45)))
                        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(edge, lineWidth: 1))
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 5 * u) {
                                ForEach(items) { listCard($0) }
                            }
                        }
                    }
                    .frame(width: 150 * u)
                    details
                }
                .padding(6 * u)
            } else {
                Text(["", "No armor yet", "No items yet", "Account items coming soon"][tab])
                    .font(.jk(11 * u, .semibold)).foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 370 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private var buttons: some View {
        HStack(spacing: 10 * u) {
            Button { note = picked == "blade" ? "The AIRBLADE can't be removed" : "Starter weapons can't be deleted" } label: {
                Text("Delete").font(.jk(13 * u, .heavy)).foregroundColor(.white.opacity(0.85))
                    .frame(width: 140 * u, height: 34 * u)
                    .background(ChamferShape(cut: 8 * u).fill(Color(red: 0.06, green: 0.08, blue: 0.13)))
                    .overlay(ChamferShape(cut: 8 * u).stroke(edge, lineWidth: 1))
            }.buttonStyle(.plain)
            Button {
                if picked == "blade" { note = "Always equipped" }
                else if TWeapons.cls(picked) == "pistol" { TacticalEngine.secondary = picked; note = "Equipped as sidearm" }
                else { nav.tacGun = picked; note = "Equipped as primary" }
            } label: {
                Text("Equip").font(.jk(13 * u, .heavy)).foregroundColor(.white)
                    .frame(width: 140 * u, height: 34 * u)
                    .background(ChamferShape(cut: 8 * u).fill(LinearGradient(colors: [Color(red: 0.2, green: 0.1, blue: 0.04), Color(red: 0.08, green: 0.05, blue: 0.03)], startPoint: .top, endPoint: .bottom)))
                    .overlay(ChamferShape(cut: 8 * u).stroke(orange, lineWidth: 1.4))
                    .shadow(color: orange.opacity(0.5), radius: 7 * u)
            }.buttonStyle(.plain)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                LobbyTopBar(t: t, u: u, selected: 3, accent: orange, act: act)
                HStack(spacing: 0) {
                    ForEach(Array(["Storage", "Customize"].enumerated()), id: \.offset) { i, s in
                        Button { subTab = i } label: {
                            Text(s).font(.jk(11 * u, i == subTab ? .heavy : .semibold)).foregroundColor(i == subTab ? orange : .white.opacity(0.5))
                                .padding(.horizontal, 16 * u).frame(height: 26 * u)
                                .overlay(alignment: .bottom) { Rectangle().fill(i == subTab ? orange : .clear).frame(height: 2 * u).padding(.horizontal, 8 * u) }
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.leading, 40 * u)
                Spacer()
            }

            leftColumn
                .padding(.leading, 27 * u).padding(.top, 76 * u)

            bottomLeft
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 27 * u).padding(.bottom, 12 * u)

            rightPanel
                .frame(height: H - 76 * u - 58 * u)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing, 22 * u).padding(.top, 76 * u)

            VStack(alignment: .trailing, spacing: 4 * u) {
                if !note.isEmpty {
                    Text(note).font(.jk(9 * u, .semibold)).foregroundColor(orange)
                }
                buttons
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 22 * u).padding(.bottom, 12 * u)
        }
        .frame(width: size.width, height: size.height)
    }
}

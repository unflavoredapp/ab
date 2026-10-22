import SwiftUI

// MARK: - INVENTORY tab: categories, item grid, item detail with Equip / Discard
// Weapons are the real game weapons; the rest are sample items until those systems exist.

struct OWInventoryView: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var cat = "all"
    @State private var search = ""
    @State private var sortRarity = true
    @State private var picked = "blade"
    @State private var note = ""
    @State private var bottom = 0

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    struct Item: Identifiable {
        let id: String
        let name: String
        let sub: String
        let cat: String
        let rarity: String
        var count: Int? = nil
        var icon = "shippingbox.fill"
        var desc = ""
        var weapon: TWeapons.W? = nil
    }

    private static func rarity(_ w: TWeapons.W) -> String {
        w.price >= 3000 ? "LEGENDARY" : (w.price >= 2000 ? "EPIC" : (w.price >= 1000 ? "RARE" : (w.price >= 500 ? "UNCOMMON" : "COMMON")))
    }

    private static func clsTitle(_ c: String) -> String {
        ["rifle": "Assault Rifle", "smg": "SMG", "pistol": "Pistol", "sniper": "Sniper Rifle", "shotgun": "Shotgun"][c] ?? c.capitalized
    }

    private var all: [Item] {
        var out = [Item(id: "blade", name: "AIRBLADE", sub: "Sword", cat: "weapons", rarity: "LEGENDARY", icon: "bolt.fill",
                        desc: "Your signature blade. Fast slashes, air slashes and backstabs reward good movement.")]
        out += TWeapons.all.map {
            Item(id: $0.id, name: $0.name, sub: Self.clsTitle($0.cls), cat: "weapons", rarity: Self.rarity($0),
                 desc: "A reliable \(Self.clsTitle($0.cls).lowercased()) favored by crews for its balance of power and mobility.", weapon: $0)
        }
        out += [
            Item(id: "armor4", name: "Level 4 Armor", sub: "Body Armor", cat: "armor", rarity: "EPIC", icon: "shield.lefthalf.filled", desc: "Heavy plates that soak up bullets."),
            Item(id: "helmet", name: "Tactical Helmet", sub: "Headgear", cat: "armor", rarity: "RARE", icon: "person.crop.square.fill", desc: "Protects against headshots."),
            Item(id: "pack", name: "Tactical Backpack", sub: "Gear", cat: "gear", rarity: "RARE", icon: "bag.fill", desc: "Carry more loot into the fight."),
            Item(id: "drone", name: "Recon Drone", sub: "Gear", cat: "gear", rarity: "EPIC", count: 3, icon: "airplane", desc: "Scout a block before you walk into it."),
            Item(id: "medkit", name: "Medkit", sub: "Consumable", cat: "consumables", rarity: "COMMON", count: 5, icon: "cross.case.fill", desc: "Restores health over a few seconds."),
            Item(id: "plate", name: "Armor Plate", sub: "Consumable", cat: "consumables", rarity: "RARE", count: 12, icon: "square.stack.3d.up.fill", desc: "Swap in a fresh plate mid-fight."),
            Item(id: "frag", name: "Frag Grenade", sub: "Consumable", cat: "consumables", rarity: "RARE", count: 8, icon: "circle.hexagongrid.fill", desc: "Clears a doorway."),
            Item(id: "smoke", name: "Smoke Grenade", sub: "Consumable", cat: "consumables", rarity: "UNCOMMON", count: 6, icon: "smoke.fill", desc: "Blocks sight lines for a few seconds."),
            Item(id: "cash", name: "Money Stack", sub: "Currency", cat: "materials", rarity: "COMMON", count: 4850, icon: "banknote.fill", desc: "Cash from the streets."),
            Item(id: "scrap", name: "Scrap Metal", sub: "Material", cat: "materials", rarity: "EPIC", count: 3, icon: "wrench.and.screwdriver.fill", desc: "Used for crafting and mods."),
            Item(id: "circuit", name: "Circuit Board", sub: "Material", cat: "materials", rarity: "EPIC", count: 2, icon: "cpu.fill", desc: "Used for gadgets."),
            Item(id: "blueprint", name: "Blueprint", sub: "Crafting", cat: "materials", rarity: "RARE", count: 4, icon: "doc.richtext.fill", desc: "Unlocks a crafting recipe."),
            Item(id: "keycard", name: "Safehouse Key", sub: "Key Item", cat: "key", rarity: "UNCOMMON", icon: "key.fill", desc: "Opens a crew safehouse."),
            Item(id: "hoodie", name: "Raven Hoodie", sub: "Cosmetic", cat: "cosmetics", rarity: "LEGENDARY", icon: "tshirt.fill", desc: "Limited outfit."),
        ]
        return out
    }

    private let cats: [(String, String, String)] = [
        ("all", "ALL ITEMS", "square.grid.2x2.fill"), ("weapons", "WEAPONS", "scope"), ("armor", "ARMOR", "shield.lefthalf.filled"),
        ("gear", "GEAR", "bag.fill"), ("consumables", "CONSUMABLES", "cross.case.fill"), ("materials", "MATERIALS", "cube.fill"),
        ("key", "KEY ITEMS", "key.fill"), ("cosmetics", "COSMETICS", "theatermasks.fill"),
    ]

    private func count(_ c: String) -> Int { c == "all" ? all.count : all.filter { $0.cat == c }.count }

    private var shown: [Item] {
        let order = ["LEGENDARY": 0, "EPIC": 1, "RARE": 2, "UNCOMMON": 3, "COMMON": 4]
        var l = all.filter { (cat == "all" || $0.cat == cat) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
        l.sort { sortRarity ? (order[$0.rarity] ?? 9, $0.name) < (order[$1.rarity] ?? 9, $1.name) : $0.name < $1.name }
        return l
    }

    private func equipped(_ id: String) -> Bool { id == "blade" || id == nav.tacGun || id == TacticalEngine.secondary }

    // MARK: pieces

    @ViewBuilder private func art(_ it: Item, h: CGFloat) -> some View {
        if it.id == "blade" {
            BladeGlyph().fill(LinearGradient(colors: [.white, Color(white: 0.6)], startPoint: .top, endPoint: .bottom)).frame(width: h * 3, height: h)
        } else if let w = it.weapon {
            Image(uiImage: GunSprites.icon(TWeapons.rig(w.id))).renderingMode(.template).resizable().scaledToFit().foregroundColor(.white.opacity(0.92)).frame(height: h)
        } else {
            Image(systemName: it.icon).font(.system(size: h * 0.85)).foregroundColor(.white.opacity(0.85))
        }
    }

    private func card(_ it: Item) -> some View {
        let col = OW.rarity(it.rarity)
        let on = picked == it.id
        return Button { picked = it.id; note = "" } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4 * u).fill(LinearGradient(colors: [col.opacity(0.22), Color.black.opacity(0.55)], startPoint: .bottom, endPoint: .top))
                art(it, h: 26 * u).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 20 * u)
                VStack(alignment: .leading, spacing: 0) {
                    if equipped(it.id) {
                        Text("EQUIPPED").font(.jk(5.5 * u, .heavy)).foregroundColor(.white).padding(.horizontal, 4 * u).padding(.vertical, 1.5 * u)
                            .background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan)).padding(5 * u)
                    }
                    Spacer(minLength: 0)
                    Text(it.name).font(.jk(8.5 * u, .heavy)).foregroundColor(.white).lineLimit(1).padding(.leading, 6 * u)
                    HStack {
                        Text(it.sub).font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.65))
                        Spacer()
                        if let c = it.count { Text("x\(c.formatted())").font(.jk(7 * u, .heavy)).foregroundColor(.white) }
                    }
                    .padding(.horizontal, 6 * u)
                    Text(it.rarity).font(.jk(6.5 * u, .heavy)).foregroundColor(col).padding(.horizontal, 6 * u).padding(.bottom, 4 * u)
                }
            }
            .frame(height: 84 * u)
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(on ? OW.cyan : col.opacity(0.6), lineWidth: on ? 1.8 : 1))
            .shadow(color: on ? OW.cyan.opacity(0.5) : .clear, radius: 6 * u)
        }.buttonStyle(.plain)
    }

    private var sidebar: some View {
        VStack(spacing: 2 * u) {
            ForEach(cats, id: \.0) { c in
                Button { cat = c.0 } label: {
                    HStack(spacing: 8 * u) {
                        Image(systemName: c.2).font(.system(size: 11 * u)).foregroundColor(.white.opacity(0.9)).frame(width: 18 * u)
                        Text(c.1).font(.jk(9.5 * u, .heavy)).foregroundColor(.white)
                        Spacer()
                        Text("\(count(c.0))").font(.jk(9 * u, .semibold)).foregroundColor(.white.opacity(0.8)).monospacedDigit()
                    }
                    .padding(.horizontal, 9 * u).frame(height: 28 * u)
                    .background(RoundedRectangle(cornerRadius: 3 * u).fill(cat == c.0 ? OW.cyan.opacity(0.4) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(cat == c.0 ? OW.cyan : .clear, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        .padding(4 * u).owPanel(u)
    }

    private var stash: some View {
        VStack(alignment: .leading, spacing: 4 * u) {
            ZStack {
                OWArt(w: 124 * u, h: 52 * u, anchor: UnitPoint(x: 0.3, y: 0.85), zoom: 3)
                Image(systemName: "bag.fill").font(.system(size: 26 * u)).foregroundColor(.white.opacity(0.85))
            }
            .frame(width: 124 * u, height: 52 * u).clipShape(RoundedRectangle(cornerRadius: 3 * u))
            Text("UPGRADE YOUR STASH").font(.jk(8.5 * u, .heavy)).foregroundColor(.white)
            Text("Expand your inventory space and carry more loot into the fight.").font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.7))
            Button { note = "Stash upgrades need the shop" } label: {
                HStack(spacing: 4 * u) {
                    Image(systemName: "cart.fill").font(.system(size: 8 * u))
                    Text("PURCHASE EXPANSION").font(.jk(7 * u, .heavy))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 19 * u).owPanel(u, r: 2)
            }.buttonStyle(.plain)
        }
        .padding(6 * u).frame(width: 136 * u).owPanel(u)
    }

    private var gridPanel: some View {
        VStack(spacing: 5 * u) {
            HStack(spacing: 8 * u) {
                Text("INVENTORY").font(.jk(13 * u, .heavy)).foregroundColor(.white)
                HStack(spacing: 5 * u) {
                    TextField("Search items...", text: $search).font(.jk(9 * u, .medium)).foregroundColor(.white)
                    Image(systemName: "magnifyingglass").font(.system(size: 9 * u)).foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 8 * u).frame(height: 22 * u).background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(OW.edge, lineWidth: 1))
                Button { sortRarity.toggle() } label: {
                    HStack(spacing: 4 * u) {
                        Text("Sort: \(sortRarity ? "Rarity" : "Name")").font(.jk(8.5 * u, .medium))
                        Image(systemName: "chevron.down").font(.system(size: 7 * u))
                    }
                    .foregroundColor(.white).padding(.horizontal, 8 * u).frame(height: 22 * u).owPanel(u, r: 3)
                }.buttonStyle(.plain)
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6 * u), count: 4), spacing: 6 * u) {
                    ForEach(shown) { card($0) }
                }
            }
            HStack {
                Image(systemName: "plus.circle.fill").font(.system(size: 9 * u)).foregroundColor(.white.opacity(0.7))
                Text("\(all.count) / 200").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("Total Value:").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.7))
                Image(systemName: "dollarsign.circle.fill").font(.system(size: 9 * u)).foregroundColor(OW.gold)
                Text("248,560").font(.jk(9 * u, .heavy)).foregroundColor(OW.gold)
            }
        }
        .padding(8 * u).frame(maxHeight: .infinity).owPanel(u)
    }

    private func bar(_ k: String, _ v: Int) -> some View {
        HStack(spacing: 8 * u) {
            Text(k).font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.85)).frame(width: 52 * u, alignment: .leading)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(OW.cyan).frame(width: 108 * u * CGFloat(min(100, max(0, v))) / 100)
            }
            .frame(width: 108 * u, height: 3.5 * u)
            Text("\(v)").font(.jk(8.5 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
        .frame(height: 15 * u)
    }

    private var detail: some View {
        let it = all.first { $0.id == picked } ?? all[0]
        let col = OW.rarity(it.rarity)
        return VStack(alignment: .leading, spacing: 4 * u) {
            HStack {
                Image(systemName: "crown.fill").font(.system(size: 13 * u)).foregroundColor(col)
                VStack(alignment: .leading, spacing: 0) {
                    Text(it.name).font(.jk(13 * u, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text(it.sub).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(it.rarity).font(.jk(7.5 * u, .heavy)).foregroundColor(col)
            }
            art(it, h: 34 * u).frame(maxWidth: .infinity).frame(height: 54 * u)
                .background(RoundedRectangle(cornerRadius: 3 * u).fill(LinearGradient(colors: [col.opacity(0.2), .clear], startPoint: .bottom, endPoint: .top)))
            Text(it.desc).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(3).frame(height: 30 * u, alignment: .topLeading)
            if let w = it.weapon {
                let dmg = min(100, Int(ABRules.bulletDmg(w.dmg, cls: w.cls) * CGFloat(w.pellets) * 1.6))
                let mob = ["pistol": 90, "smg": 80, "rifle": 70, "shotgun": 65, "sniper": 45][w.cls] ?? 70
                bar("Damage", dmg)
                bar("Range", Int(min(100, w.range / 22)))
                bar("Accuracy", Int(max(0, min(100, (1 - w.spread * 8) * 100))))
                bar("Fire Rate", Int(min(100, 14 / w.interval)))
                bar("Mobility", mob)
                HStack(spacing: 6 * u) {
                    Image(systemName: "bolt.horizontal.fill").font(.system(size: 9 * u)).foregroundColor(.white.opacity(0.8))
                    Text("Ammo").font(.jk(8.5 * u, .medium)).foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("\(w.mag) / \(w.mag * 4)").font(.jk(9 * u, .heavy)).foregroundColor(.white)
                }.padding(.top, 2 * u)
            } else if it.id == "blade" {
                bar("Damage", Int(ABRules.slashDmg * 2.4))
                bar("Backstab", Int(ABRules.backstabDmg))
                bar("Mobility", 100)
            }
            Spacer(minLength: 0)
            if !note.isEmpty { Text(note).font(.jk(8 * u, .semibold)).foregroundColor(OW.gold) }
            OWButton(u: u, icon: "checkmark.shield.fill", title: equipped(it.id) ? "EQUIPPED" : "EQUIP") {
                if it.id == "blade" { note = "Always equipped" }
                else if let w = it.weapon {
                    if w.cls == "pistol" { TacticalEngine.secondary = w.id; note = "Equipped as sidearm" }
                    else { nav.tacGun = w.id; note = "Equipped as primary" }
                } else { note = "Consumables are used in the field" }
            }
            OWButton(u: u, icon: "trash", title: "DISCARD", filled: false) { note = it.weapon != nil || it.id == "blade" ? "Weapons can't be discarded" : "Nothing to discard here" }
        }
        .padding(9 * u).frame(width: 200 * u).frame(maxHeight: .infinity).owPanel(u)
    }

    private var bottomBar: some View {
        HStack(spacing: 8 * u) {
            ForEach(Array([("bag.fill", "EQUIP"), ("wrench.and.screwdriver.fill", "MODS"), ("hammer.fill", "CRAFTING"), ("dollarsign.circle", "SELL")].enumerated()), id: \.offset) { i, e in
                Button { bottom = i; if i > 0 { note = "\(e.1.capitalized) opens up later" } } label: {
                    HStack(spacing: 6 * u) {
                        Image(systemName: e.0).font(.system(size: 12 * u))
                        Text(e.1).font(.jk(9.5 * u, .heavy))
                    }
                    .foregroundColor(.white).padding(.horizontal, 16 * u).frame(height: 28 * u)
                    .background(RoundedRectangle(cornerRadius: 3 * u).fill(bottom == i ? OW.cyan.opacity(0.45) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(bottom == i ? OW.cyan : .clear, lineWidth: 1))
                }.buttonStyle(.plain)
            }
            Spacer()
            HStack(spacing: 5 * u) {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 9 * u))
                Text("FILTERS").font(.jk(8.5 * u, .heavy))
            }
            .foregroundColor(.white).padding(.horizontal, 12 * u).frame(height: 24 * u).owPanel(u, r: 3)
        }
        .padding(.horizontal, 8 * u).frame(height: 36 * u).owPanel(u)
    }

    var body: some View {
        OWScreen(t: t, u: u, selected: 3, act: act) {
            VStack(spacing: 6 * u) {
                HStack(alignment: .top, spacing: 8 * u) {
                    VStack(spacing: 6 * u) { sidebar; stash }
                    gridPanel
                    detail
                }
                bottomBar
            }
            .padding(.horizontal, 12 * u).padding(.top, 8 * u).padding(.bottom, 8 * u)
        }
        .frame(width: size.width, height: size.height)
    }
}

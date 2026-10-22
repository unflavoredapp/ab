import SwiftUI

// MARK: - SHOP tab: featured pack, item shelves, cart and offers
// Prices are placeholders; checkout isn't connected to any payment or currency yet.

struct OWShopView: View {
    @EnvironmentObject var game: Game
    @ObservedObject private var online = OWOnline.shared
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var cat = 0
    @State private var cart: [Int] = [0, 1, 7]
    @State private var note = ""

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }

    struct Product { let name: String; let rarity: String; let price: Double; let icon: String; let isNew: Bool }
    private let products: [Product] = [
        Product(name: "Raven Outfit", rarity: "LEGENDARY", price: 4.99, icon: "person.fill", isNew: true),
        Product(name: "MK18 - Blackout", rarity: "EPIC", price: 2.99, icon: "scope", isNew: true),
        Product(name: "Combat Helicopter", rarity: "LEGENDARY", price: 14.99, icon: "airplane", isNew: true),
        Product(name: "Elite Supply Crate", rarity: "EPIC", price: 5.99, icon: "shippingbox.fill", isNew: true),
        Product(name: "Armor Plate Bundle (x5)", rarity: "RARE", price: 1.99, icon: "square.stack.3d.up.fill", isNew: false),
        Product(name: "Smoke Grenade (x5)", rarity: "UNCOMMON", price: 0.99, icon: "smoke.fill", isNew: false),
        Product(name: "Medkit (x3)", rarity: "COMMON", price: 0.79, icon: "cross.case.fill", isNew: false),
        Product(name: "Tactical Backpack", rarity: "RARE", price: 3.99, icon: "bag.fill", isNew: false),
        Product(name: "Money Stack", rarity: "COMMON", price: 2.49, icon: "banknote.fill", isNew: false),
        Product(name: "Scrap Bundle (x5)", rarity: "EPIC", price: 4.99, icon: "wrench.and.screwdriver.fill", isNew: false),
    ]
    private let cats: [(String, String)] = [("cart.fill", "FEATURED"), ("scope", "WEAPONS"), ("shield.lefthalf.filled", "ARMOR"), ("car.fill", "VEHICLES"),
                                            ("bag.fill", "GEAR"), ("cross.case.fill", "CONSUMABLES"), ("dollarsign.circle.fill", "CURRENCY"), ("shippingbox.fill", "BUNDLES"), ("theatermasks.fill", "COSMETICS")]

    private var total: Double { cart.reduce(0) { $0 + products[$1].price } }
    private func money(_ d: Double) -> String { "\(coins(d)) ◎" }
    /// shelf prices are in dollars on the mockup; in the game they cost coins (1 dollar = 100 coins)
    private func coins(_ d: Double) -> Int { Int((d * 100).rounded()) }

    private var sidebar: some View {
        VStack(spacing: 1 * u) {
            ForEach(0..<cats.count, id: \.self) { i in
                Button { cat = i } label: {
                    HStack(spacing: 8 * u) {
                        Image(systemName: cats[i].0).font(.system(size: 11 * u)).foregroundColor(.white).frame(width: 18 * u)
                        Text(cats[i].1).font(.jk(9 * u, .heavy)).foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 9 * u).frame(height: 25 * u)
                    .background(RoundedRectangle(cornerRadius: 3 * u).fill(cat == i ? OW.cyan.opacity(0.45) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(cat == i ? OW.cyan : .clear, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        .padding(3 * u).owPanel(u)
    }

    private var support: some View {
        VStack(spacing: 3 * u) {
            Image(systemName: "crown.fill").font(.system(size: 20 * u)).foregroundColor(.white)
            Text("SUPPORT THE CREW").font(.jk(8.5 * u, .heavy)).foregroundColor(.white)
            Text("Get exclusive items and help your crew grow.").font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button { note = "Crew bundles are coming" } label: {
                Text("VIEW CREW BUNDLES").font(.jk(7 * u, .heavy)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 19 * u).owPanel(u, r: 2, hot: OW.cyan)
            }.buttonStyle(.plain)
        }
        .padding(8 * u).frame(width: 128 * u).owPanel(u)
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            OWArt(w: 560 * u, h: 100 * u, anchor: UnitPoint(x: 0.4, y: 0.35), zoom: 1.7, tint: OW.red.opacity(0.25))
            LinearGradient(colors: [Color.black.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 1 * u) {
                Text("LIMITED TIME").font(.jk(15 * u, .heavy)).italic().foregroundColor(OW.gold)
                Text("RAVEN PACK").font(.jk(26 * u, .heavy)).italic().foregroundColor(OW.gold)
                Text("EXCLUSIVE OUTFIT + WEAPON SKIN + MORE").font(.jk(7 * u, .heavy)).foregroundColor(.white)
                HStack(spacing: 4 * u) {
                    Image(systemName: "clock").font(.system(size: 9 * u))
                    Text("2d 14h 32m").font(.jk(9 * u, .medium))
                }.foregroundColor(.white).padding(.top, 3 * u)
            }
            .padding(.leading, 28 * u).padding(.bottom, 6 * u).frame(maxHeight: .infinity, alignment: .bottom)
            Button { cart.append(0); note = "Raven Pack added" } label: {
                Text("$ 4.99").font(.jk(13 * u, .heavy)).foregroundColor(OW.gold).padding(.horizontal, 12 * u).frame(height: 24 * u)
                    .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.55)))
                    .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(OW.gold, lineWidth: 1.2))
            }
            .buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(8 * u)
        }
        .frame(maxWidth: .infinity).frame(height: 100 * u).clipShape(RoundedRectangle(cornerRadius: 4 * u))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(OW.cyan.opacity(0.6), lineWidth: 1.2))
    }

    private func featured(_ i: Int) -> some View {
        let p = products[i]
        let c = OW.rarity(p.rarity)
        return Button { cart.append(i); note = "\(p.name) added" } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: p.icon).font(.system(size: 34 * u)).foregroundColor(.white.opacity(0.85)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    if p.isNew { Text("NEW").font(.jk(6 * u, .heavy)).foregroundColor(.black).padding(.horizontal, 5 * u).padding(.vertical, 1.5 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.gold)).padding(5 * u) }
                }
                Text(p.name.uppercased()).font(.jk(8.5 * u, .heavy)).foregroundColor(.white).padding(.leading, 8 * u).lineLimit(1)
                Text(p.rarity).font(.jk(7 * u, .heavy)).foregroundColor(c).padding(.leading, 8 * u)
                Text(money(p.price)).font(.jk(10 * u, .heavy)).foregroundColor(.white).padding(.leading, 8 * u).padding(.vertical, 3 * u)
            }
            .frame(height: 98 * u)
            .background(RoundedRectangle(cornerRadius: 4 * u).fill(LinearGradient(colors: [c.opacity(0.28), Color.black.opacity(0.6)], startPoint: .bottom, endPoint: .top)))
            .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(c, lineWidth: 1.3))
        }.buttonStyle(.plain)
    }

    private func popular(_ i: Int) -> some View {
        let p = products[i]
        let c = OW.rarity(p.rarity)
        return Button { cart.append(i); note = "\(p.name) added" } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: p.icon).font(.system(size: 20 * u)).foregroundColor(.white.opacity(0.85)).frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(p.name).font(.jk(7 * u, .heavy)).foregroundColor(.white).lineLimit(1).padding(.leading, 5 * u)
                Text(p.rarity).font(.jk(6 * u, .heavy)).foregroundColor(c).padding(.leading, 5 * u)
                Text(money(p.price)).font(.jk(8.5 * u, .heavy)).foregroundColor(.white).padding(.leading, 5 * u).padding(.bottom, 3 * u)
            }
            .frame(height: 74 * u)
            .background(RoundedRectangle(cornerRadius: 3 * u).fill(LinearGradient(colors: [c.opacity(0.2), Color.black.opacity(0.55)], startPoint: .bottom, endPoint: .top)))
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(c.opacity(0.8), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var center: some View {
        VStack(alignment: .leading, spacing: 5 * u) {
            banner
            Text("FEATURED ITEMS").font(.jk(10 * u, .heavy)).foregroundColor(.white)
            HStack(spacing: 6 * u) { ForEach(0..<4, id: \.self) { featured($0) } }
            Text("POPULAR ITEMS").font(.jk(10 * u, .heavy)).foregroundColor(.white)
            HStack(spacing: 5 * u) { ForEach(4..<10, id: \.self) { popular($0) } }
            Spacer(minLength: 0)
        }
    }

    private var cartPanel: some View {
        VStack(alignment: .leading, spacing: 3 * u) {
            HStack {
                Image(systemName: "cart.fill").font(.system(size: 10 * u)).foregroundColor(OW.cyan)
                Text("YOUR CART").font(.jk(10 * u, .heavy)).foregroundColor(.white)
                Spacer()
                Text("\(cart.count) ITEMS").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.7))
            }
            ForEach(Array(cart.prefix(3).enumerated()), id: \.offset) { idx, i in
                let p = products[i]
                HStack(spacing: 6 * u) {
                    Image(systemName: p.icon).font(.system(size: 13 * u)).foregroundColor(.white.opacity(0.85)).frame(width: 26 * u, height: 26 * u)
                        .background(RoundedRectangle(cornerRadius: 2 * u).fill(Color.white.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(p.name).font(.jk(8 * u, .semibold)).foregroundColor(.white).lineLimit(1)
                        Text(p.rarity).font(.jk(6.5 * u, .heavy)).foregroundColor(OW.rarity(p.rarity))
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        Button { cart.remove(at: idx) } label: { Image(systemName: "xmark").font(.system(size: 6 * u)).foregroundColor(.white.opacity(0.5)) }.buttonStyle(.plain)
                        Text(money(p.price)).font(.jk(8.5 * u, .heavy)).foregroundColor(.white)
                    }
                }
                .frame(height: 29 * u)
            }
            Rectangle().fill(OW.edge).frame(height: 1)
            HStack {
                Text("TOTAL").font(.jk(9 * u, .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(money(total)).font(.jk(11 * u, .heavy)).foregroundColor(.white)
            }
            OWButton(u: u, icon: "cart.fill", title: "CHECKOUT") {
                guard !cart.isEmpty else { note = "Your cart is empty"; return }
                let cost = cart.reduce(0) { $0 + coins(products[$1].price) }
                guard game.s.ex.gems >= cost else { note = "Not enough coins (\(cost) needed)"; return }
                let names = cart.map { products[$0].name }
                Task {
                    if await online.checkout(items: names, cost: cost) {
                        var st = game.s; st.ex.gems -= cost; game.s = st
                        cart.removeAll(); note = "PURCHASED · -\(cost) coins"
                    } else { note = "Purchase refused by the server" }
                }
            }
        }
        .padding(8 * u).frame(width: 182 * u).owPanel(u)
    }

    private var offers: some View {
        VStack(alignment: .leading, spacing: 3 * u) {
            HStack {
                Image(systemName: "flame.fill").font(.system(size: 9 * u)).foregroundColor(OW.red)
                Text("LIMITED TIME OFFERS").font(.jk(8.5 * u, .heavy)).foregroundColor(.white)
                Spacer()
                Image(systemName: "clock").font(.system(size: 7 * u)).foregroundColor(OW.red)
                Text("2d 14h 32m").font(.jk(7 * u, .medium)).foregroundColor(OW.red)
            }
            ZStack(alignment: .topTrailing) {
                OWArt(w: 166 * u, h: 38 * u, anchor: UnitPoint(x: 0.6, y: 0.9), zoom: 2.4, tint: OW.purple.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 3 * u))
                Text("-50%").font(.jk(9 * u, .heavy)).foregroundColor(.white).padding(.horizontal, 5 * u).background(OW.red)
            }
            Text("STREET RACER PACK").font(.jk(9 * u, .heavy)).italic().foregroundColor(.white)
            HStack {
                Text("CAR SKIN + OUTFIT + CASH").font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.75))
                Spacer()
                Text("749 ◎").font(.jk(10 * u, .heavy)).foregroundColor(OW.green)
                Text("1499 ◎").font(.jk(7 * u, .medium)).strikethrough().foregroundColor(.white.opacity(0.5))
            }
            Text("DAILY DEAL").font(.jk(8.5 * u, .heavy)).foregroundColor(.white).padding(.top, 2 * u)
            HStack(spacing: 6 * u) {
                Image(systemName: "shippingbox.fill").font(.system(size: 14 * u)).foregroundColor(OW.gold).frame(width: 28 * u, height: 28 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(Color.white.opacity(0.08)))
                VStack(alignment: .leading, spacing: 0) {
                    Text("SUPPLY CRATE").font(.jk(8 * u, .heavy)).foregroundColor(.white)
                    Text("1,500").font(.jk(8.5 * u, .heavy)).foregroundColor(OW.gold)
                }
                Spacer()
                Button { if game.s.ex.gems >= 1500 { var st = game.s; st.ex.gems -= 1500; game.s = st; note = "Supply crate bought" } else { note = "Not enough coins" } } label: { Text("BUY").font(.jk(8 * u, .heavy)).foregroundColor(.black).padding(.horizontal, 10 * u).frame(height: 18 * u).background(RoundedRectangle(cornerRadius: 2 * u).fill(OW.cyan)) }.buttonStyle(.plain)
            }
        }
        .padding(8 * u).frame(width: 182 * u).owPanel(u)
    }

    private var footer: some View {
        HStack(spacing: 18 * u) {
            ForEach(Array([("lock.shield.fill", "Pay with coins"), ("bolt.fill", "Instant Delivery"), ("crown.fill", "Trusted by Thousands")].enumerated()), id: \.offset) { _, e in
                HStack(spacing: 5 * u) {
                    Image(systemName: e.0).font(.system(size: 10 * u)).foregroundColor(.white.opacity(0.8))
                    Text(e.1).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.8))
                }
            }
            Spacer()
            if !note.isEmpty { Text(note).font(.jk(8.5 * u, .heavy)).foregroundColor(OW.gold) }
            Text(online.status).font(.jk(7 * u, .heavy)).foregroundColor(online.connected ? OW.green : .white.opacity(0.5))
            Text("YOUR COINS").font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.7))
            Text("\(game.s.ex.gems) ◎").font(.jk(9 * u, .heavy)).foregroundColor(OW.gold)
        }
        .padding(.horizontal, 14 * u).frame(height: 26 * u).owPanel(u)
    }

    var body: some View {
        OWScreen(t: t, u: u, selected: 4, act: act) {
            VStack(spacing: 6 * u) {
                HStack(alignment: .top, spacing: 8 * u) {
                    VStack(spacing: 6 * u) { sidebar; Spacer(minLength: 0); support }.frame(width: 128 * u)
                    center
                    VStack(spacing: 6 * u) { cartPanel; offers; Spacer(minLength: 0) }
                }
                footer
            }
            .padding(.horizontal, 12 * u).padding(.top, 8 * u).padding(.bottom, 8 * u)
        }
        .frame(width: size.width, height: size.height)
        .onAppear { online.connect() }
    }
}

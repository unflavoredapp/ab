import SwiftUI

// MARK: - MAP tab: territory map (districts, control, safehouses, contracts) with a detail panel

struct OWDistrict: Identifiable {
    enum Owner { case yours, enemy, contested }
    let id: Int
    let name: String
    let control: Int
    let owner: Owner
    let poly: [CGPoint]          // 0...1 inside the map area
    let label: CGPoint
    let income: Int
    let safehouses: (Int, Int)
    let contracts: (Int, Int)
    let enemies: Int
    let contract: CGPoint?
    let house: CGPoint?

    var color: Color { owner == .yours ? OW.cyan : (owner == .enemy ? OW.red : OW.gold) }

    static let all: [OWDistrict] = [
        OWDistrict(id: 0, name: "RIVERSIDE", control: 68, owner: .yours,
                   poly: [CGPoint(x: 0.13, y: 0.45), CGPoint(x: 0.27, y: 0.33), CGPoint(x: 0.43, y: 0.36), CGPoint(x: 0.40, y: 0.55), CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.13, y: 0.56)],
                   label: CGPoint(x: 0.27, y: 0.44), income: 3200, safehouses: (1, 1), contracts: (2, 4), enemies: 0,
                   contract: CGPoint(x: 0.32, y: 0.56), house: CGPoint(x: 0.25, y: 0.55)),
        OWDistrict(id: 1, name: "DOWNTOWN", control: 34, owner: .enemy,
                   poly: [CGPoint(x: 0.40, y: 0.14), CGPoint(x: 0.62, y: 0.10), CGPoint(x: 0.66, y: 0.32), CGPoint(x: 0.58, y: 0.44), CGPoint(x: 0.43, y: 0.40)],
                   label: CGPoint(x: 0.52, y: 0.22), income: 6100, safehouses: (0, 1), contracts: (0, 5), enemies: 3,
                   contract: CGPoint(x: 0.50, y: 0.33), house: nil),
        OWDistrict(id: 2, name: "INDUSTRIAL YARD", control: 52, owner: .contested,
                   poly: [CGPoint(x: 0.68, y: 0.34), CGPoint(x: 0.82, y: 0.30), CGPoint(x: 0.93, y: 0.42), CGPoint(x: 0.90, y: 0.60), CGPoint(x: 0.72, y: 0.62)],
                   label: CGPoint(x: 0.80, y: 0.40), income: 2800, safehouses: (1, 1), contracts: (1, 3), enemies: 1,
                   contract: CGPoint(x: 0.86, y: 0.50), house: CGPoint(x: 0.75, y: 0.52)),
        OWDistrict(id: 3, name: "OLD TOWN", control: 23, owner: .enemy,
                   poly: [CGPoint(x: 0.25, y: 0.64), CGPoint(x: 0.41, y: 0.58), CGPoint(x: 0.50, y: 0.66), CGPoint(x: 0.47, y: 0.80), CGPoint(x: 0.31, y: 0.84), CGPoint(x: 0.22, y: 0.75)],
                   label: CGPoint(x: 0.36, y: 0.68), income: 2100, safehouses: (0, 1), contracts: (0, 3), enemies: 2,
                   contract: CGPoint(x: 0.40, y: 0.76), house: nil),
        OWDistrict(id: 4, name: "THE PROJECTS", control: 71, owner: .yours,
                   poly: [CGPoint(x: 0.54, y: 0.60), CGPoint(x: 0.70, y: 0.65), CGPoint(x: 0.85, y: 0.70), CGPoint(x: 0.78, y: 0.88), CGPoint(x: 0.60, y: 0.92), CGPoint(x: 0.52, y: 0.78)],
                   label: CGPoint(x: 0.62, y: 0.70), income: 4800, safehouses: (2, 2), contracts: (4, 6), enemies: 1,
                   contract: CGPoint(x: 0.74, y: 0.78), house: CGPoint(x: 0.62, y: 0.82)),
        OWDistrict(id: 5, name: "HARBOR", control: 46, owner: .contested,
                   poly: [CGPoint(x: 0.27, y: 0.86), CGPoint(x: 0.47, y: 0.84), CGPoint(x: 0.51, y: 0.93), CGPoint(x: 0.40, y: 0.99), CGPoint(x: 0.27, y: 0.97)],
                   label: CGPoint(x: 0.38, y: 0.90), income: 1900, safehouses: (1, 1), contracts: (1, 2), enemies: 0,
                   contract: CGPoint(x: 0.45, y: 0.95), house: CGPoint(x: 0.32, y: 0.95)),
    ]
}

struct OWMapView: View {
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void

    @State private var pick = 4
    @State private var showYours = true
    @State private var showCrew = false
    @State private var showEnemy = true
    @State private var showContracts = true
    @State private var showHouses = true
    @State private var flat = false
    @State private var zoom: CGFloat = 1
    @State private var pan = CGSize.zero
    @State private var rot: CGFloat = 0
    @State private var pinchBase: CGFloat = 1
    @State private var panBase = CGSize.zero
    @State private var rotBase: CGFloat = 0
    @State private var filtersOpen = true

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }
    private var d: OWDistrict { OWDistrict.all[pick] }

    private func visible(_ x: OWDistrict) -> Bool {
        switch x.owner {
        case .yours: return showYours
        case .enemy: return showEnemy
        case .contested: return true
        }
    }

    // MARK: map

    private func pt(_ p: CGPoint, _ r: CGRect) -> CGPoint {
        // map point -> rotate about the centre -> tilt (3D squashes the depth) -> zoom -> pan
        let cx = r.midX, cy = r.midY
        let bx = (r.minX + p.x * r.width) - cx, by = (r.minY + p.y * r.height) - cy
        let a = rot
        let rx = bx * cos(a) - by * sin(a), ry = bx * sin(a) + by * cos(a)
        let ty = ry * (flat ? 1 : 0.68)
        return CGPoint(x: cx + rx * zoom + pan.width, y: cy + ty * zoom + pan.height)
    }

    private func path(_ x: OWDistrict, _ r: CGRect) -> Path {
        var p = Path()
        for (i, c) in x.poly.enumerated() { i == 0 ? p.move(to: pt(c, r)) : p.addLine(to: pt(c, r)) }
        p.closeSubpath()
        return p
    }

    private var mapCanvas: some View {
        GeometryReader { g in
            let r = CGRect(origin: .zero, size: g.size)
            ZStack {
                Canvas { ctx, sz in
                    let rr = CGRect(origin: .zero, size: sz)
                    // water and streets
                    ctx.fill(Path(rr), with: .linearGradient(Gradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.1), Color(red: 0.01, green: 0.03, blue: 0.07)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: sz.height)))
                    for k in 0..<14 {
                        var s = Path()
                        let y = rr.height * (0.05 + CGFloat(k) * 0.07)
                        s.move(to: CGPoint(x: 0, y: y)); s.addLine(to: CGPoint(x: rr.width, y: y + rr.height * 0.03))
                        ctx.stroke(s, with: .color(Color.white.opacity(0.025)), lineWidth: 1)
                    }
                    for x in OWDistrict.all where visible(x) {
                        let p = path(x, rr)
                        let on = x.id == pick
                        ctx.fill(p, with: .color(x.color.opacity(on ? 0.3 : 0.16)))
                        ctx.stroke(p, with: .color(x.color.opacity(0.35)), lineWidth: 7 * u)
                        ctx.stroke(p, with: .color(x.color.opacity(on ? 1 : 0.85)), lineWidth: on ? 2.2 * u : 1.4 * u)
                        // building blocks
                        let bb = p.boundingRect
                        for i in 0..<14 {
                            let fx = CGFloat((i * 37) % 13) / 13, fy = CGFloat((i * 53) % 11) / 11
                            let c = CGPoint(x: bb.minX + bb.width * (0.15 + 0.7 * fx), y: bb.minY + bb.height * (0.15 + 0.7 * fy))
                            guard p.contains(c) else { continue }
                            let b = CGRect(x: c.x - 6 * u, y: c.y - 5 * u, width: 12 * u * (0.7 + fx), height: (6 + 10 * fy) * u)
                            ctx.fill(Path(b), with: .color(x.color.opacity(0.28)))
                        }
                    }
                }
                ForEach(OWDistrict.all) { x in
                    if visible(x) {
                        let c = pt(x.label, r)
                        HStack(spacing: 5 * u) {
                            Image(systemName: x.owner == .yours ? "crown.fill" : (x.owner == .enemy ? "flame.fill" : "shield.lefthalf.filled"))
                                .font(.system(size: 14 * u)).foregroundColor(x.color)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(x.name).font(.jk(10 * u, .heavy)).foregroundColor(.white)
                                Text("\(x.control)% CONTROL").font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.75))
                            }
                        }
                        .padding(.horizontal, 6 * u).padding(.vertical, 3 * u)
                        .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.45)))
                        .position(c)
                        .allowsHitTesting(false)
                        if showContracts, let k = x.contract {
                            marker("doc.text.fill", OW.gold).position(pt(k, r))
                        }
                        if showHouses, let h = x.house {
                            marker("house.fill", OW.cyan).position(pt(h, r))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if hypot(v.translation.width, v.translation.height) > 6 {
                            pan = CGSize(width: panBase.width + v.translation.width, height: panBase.height + v.translation.height)
                        }
                    }
                    .onEnded { v in
                        if hypot(v.translation.width, v.translation.height) <= 6 {
                            for x in OWDistrict.all where visible(x) && path(x, r).contains(v.location) { pick = x.id }
                        }
                        panBase = pan
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { m in zoom = max(0.7, min(3, pinchBase * m)) }
                    .onEnded { _ in pinchBase = zoom }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { a in rot = rotBase + CGFloat(a.radians) }
                    .onEnded { _ in rotBase = rot }
            )
        }
    }

    private func marker(_ icon: String, _ col: Color) -> some View {
        Image(systemName: icon).font(.system(size: 9 * u, weight: .bold)).foregroundColor(col)
            .frame(width: 20 * u, height: 20 * u)
            .background(Circle().fill(Color.black.opacity(0.65)))
            .overlay(Circle().stroke(col, lineWidth: 1.2))
            .allowsHitTesting(false)
    }

    // MARK: panels

    private func filterRow(_ icon: String, _ title: String, _ on: Binding<Bool>, _ col: Color) -> some View {
        Button { on.wrappedValue.toggle() } label: {
            HStack(spacing: 8 * u) {
                Image(systemName: icon).font(.system(size: 12 * u)).foregroundColor(col).frame(width: 18 * u)
                Text(title).font(.jk(9 * u, .semibold)).foregroundColor(.white)
                Spacer(minLength: 0)
                ZStack(alignment: on.wrappedValue ? .trailing : .leading) {
                    Capsule().fill(on.wrappedValue ? OW.cyan.opacity(0.35) : Color.white.opacity(0.12)).frame(width: 24 * u, height: 12 * u)
                    Circle().fill(on.wrappedValue ? OW.cyan : Color.gray).frame(width: 9 * u, height: 9 * u).padding(.horizontal, 1.5 * u)
                }
            }
            .padding(.horizontal, 8 * u).frame(height: 23 * u)
        }.buttonStyle(.plain)
    }

    private var filters: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MAP FILTERS").font(.jk(11 * u, .heavy)).foregroundColor(.white)
                Spacer()
                Image(systemName: "xmark").font(.system(size: 8 * u, weight: .bold)).foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 9 * u).frame(height: 24 * u)
            filterRow("shield.lefthalf.filled", "ALL TERRITORIES", $showYours, OW.cyan)
            filterRow("person.3.fill", "MY CREW", $showCrew, .white)
            filterRow("flame.fill", "ENEMY CREWS", $showEnemy, OW.red)
            filterRow("doc.text.fill", "CONTRACTS", $showContracts, OW.gold)
            filterRow("house.fill", "SAFEHOUSES", $showHouses, .white)
        }
        .frame(width: 128 * u).owPanel(u)
    }

    private func infoRow(_ icon: String, _ k: String, _ v: String, _ col: Color = .white) -> some View {
        HStack(spacing: 7 * u) {
            Image(systemName: icon).font(.system(size: 10 * u)).foregroundColor(col).frame(width: 16 * u)
            Text(k).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.8))
            Spacer(minLength: 0)
            Text(v).font(.jk(8.5 * u, .heavy)).foregroundColor(.white).monospacedDigit()
        }
        .frame(height: 19 * u)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }

    private func feedRow(_ n: String, _ s: String, _ ago: String) -> some View {
        HStack(spacing: 7 * u) {
            OWAvatar(name: n, s: 18 * u)
            VStack(alignment: .leading, spacing: 0) {
                Text(s).font(.jk(7.5 * u, .medium)).foregroundColor(.white.opacity(0.9)).lineLimit(1)
                Text(ago).font(.jk(6.5 * u, .medium)).foregroundColor(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 22 * u)
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 5 * u) {
            ZStack(alignment: .bottomLeading) {
                OWArt(w: 166 * u, h: 50 * u, anchor: UnitPoint(x: 0.3, y: 0.15), zoom: 2.3)
                LinearGradient(colors: [.clear, Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                HStack(spacing: 6 * u) {
                    Image(systemName: "crown.fill").font(.system(size: 17 * u)).foregroundColor(d.color)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(d.name).font(.jk(11 * u, .heavy)).foregroundColor(.white)
                        Text("\(d.control)% CONTROL").font(.jk(8 * u, .semibold)).foregroundColor(d.color)
                        Text(d.owner == .yours ? "Your Crew" : (d.owner == .enemy ? "Enemy Crew" : "Contested")).font(.jk(7 * u, .medium)).foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.leading, 7 * u).padding(.bottom, 4 * u)
            }
            .frame(width: 166 * u, height: 50 * u).clipShape(RoundedRectangle(cornerRadius: 3 * u))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(d.color).frame(width: 166 * u * CGFloat(d.control) / 100)
            }
            .frame(width: 166 * u, height: 3.5 * u)
            Text("TERRITORY INFO").font(.jk(9 * u, .heavy)).foregroundColor(.white).padding(.top, 2 * u)
            infoRow("dollarsign.circle.fill", "Income (per hour)", "$\(d.income.formatted())", OW.gold)
            infoRow("house.fill", "Safehouses", "\(d.safehouses.0) / \(d.safehouses.1)")
            infoRow("doc.text.fill", "Contracts", "\(d.contracts.0) / \(d.contracts.1)", OW.gold)
            infoRow("flame.fill", "Enemy Crews", "\(d.enemies)", OW.red)
            Text("CREW ACTIVITY").font(.jk(9 * u, .heavy)).foregroundColor(.white).padding(.top, 2 * u)
            feedRow("Shadow", "Your crew captured this territory", "2h ago")
            feedRow("Rival", "Rival crew started a contract", "4h ago")
            feedRow("Rico", "Your crew completed a contract", "6h ago")
            OWButton(u: u, icon: "flag.2.crossed.fill", title: "LAUNCH TERRITORY WAR", sub: "Prepare your crew and take control.") { act(.launch(5)) }
        }
        .padding(8 * u).frame(width: 182 * u).owPanel(u)
    }

    private var legend: some View {
        HStack(spacing: 14 * u) {
            ForEach(Array([("crown.fill", "Your Territory", OW.cyan), ("flame.fill", "Enemy Territory", OW.red), ("shield.lefthalf.filled", "Contested", OW.gold),
                           ("house.fill", "Safehouse", OW.cyan), ("doc.text.fill", "Contract", OW.gold), ("bolt.fill", "Active War", OW.red)].enumerated()), id: \.offset) { _, e in
                HStack(spacing: 4 * u) {
                    Image(systemName: e.0).font(.system(size: 9 * u)).foregroundColor(e.2)
                    Text(e.1).font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.85)).fixedSize()
                }
            }
        }
        .padding(.horizontal, 12 * u).frame(height: 24 * u).owPanel(u)
    }

    private func tool(_ s: String, _ on: Bool = false, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            Group {
                if s.hasPrefix("sf:") { Image(systemName: String(s.dropFirst(3))).font(.system(size: 11 * u, weight: .bold)) }
                else { Text(s).font(.jk(10 * u, .heavy)) }
            }
            .foregroundColor(on ? OW.cyan : .white).frame(width: 26 * u, height: 24 * u)
            .background(RoundedRectangle(cornerRadius: 2 * u).fill(on ? OW.cyan.opacity(0.2) : OW.panel))
            .overlay(RoundedRectangle(cornerRadius: 2 * u).stroke(on ? OW.cyan : OW.edge, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private var tools: some View {
        VStack(spacing: 3 * u) {
            Image(systemName: "location.north.fill").font(.system(size: 12 * u)).foregroundColor(OW.cyan)
                .frame(width: 30 * u, height: 30 * u).background(Circle().fill(OW.panel)).overlay(Circle().stroke(OW.edge, lineWidth: 1))
            tool("sf:plus") { zoom = min(3, zoom + 0.2); pinchBase = zoom }
            tool("sf:minus") { zoom = max(0.7, zoom - 0.2); pinchBase = zoom }
            tool("3D", !flat) { flat = false }
            tool("2D", flat) { flat = true }
            tool("sf:scope") { zoom = 1; pinchBase = 1; pan = .zero; panBase = .zero; rot = 0; rotBase = 0; pick = 4 }
        }
    }

    private var thumbs: some View {
        HStack(spacing: 5 * u) {
            Button { pick = (pick + 5) % 6 } label: { Image(systemName: "chevron.left").font(.system(size: 10 * u)).foregroundColor(.white) }.buttonStyle(.plain)
            ForEach(-1...1, id: \.self) { o in
                let x = OWDistrict.all[(pick + o + 6) % 6]
                OWArt(w: 54 * u, h: 32 * u, anchor: UnitPoint(x: x.label.x, y: x.label.y * 0.5), zoom: 2.6, tint: x.color.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 2 * u))
                    .overlay(RoundedRectangle(cornerRadius: 2 * u).stroke(o == 0 ? OW.cyan : OW.edge, lineWidth: o == 0 ? 1.6 : 1))
                    .overlay(alignment: .bottom) { if o == 0 { Text(x.name).font(.jk(6 * u, .heavy)).foregroundColor(.white).padding(.bottom, 1) } }
                    .onTapGesture { pick = x.id }
            }
            Button { pick = (pick + 1) % 6 } label: { Image(systemName: "chevron.right").font(.system(size: 10 * u)).foregroundColor(.white) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 6 * u).padding(.vertical, 4 * u).owPanel(u)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            mapCanvas.padding(.top, 44 * u)
            VStack(spacing: 0) {
                LobbyTopBar(t: t, u: u, selected: 1, act: act)
                Spacer()
            }
            if filtersOpen { filters.padding(.leading, 12 * u).padding(.top, 52 * u) }
            tools.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(.leading, 14 * u).padding(.bottom, 14 * u)
            infoPanel.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(.trailing, 12 * u).padding(.top, 52 * u)
            legend.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 10 * u)
            thumbs.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(.trailing, 12 * u).padding(.bottom, 10 * u)
        }
        .frame(width: size.width, height: size.height)
        .background(Color(red: 0.01, green: 0.03, blue: 0.07))
    }
}

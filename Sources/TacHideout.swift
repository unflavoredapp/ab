import SwiftUI

/// AIRBLADE logotype shared by the lobby, the shell and character creation
struct AirbladeLogo: View {
    var size: CGFloat = 25

    var body: some View {
        Text("AIRBLADE")
            .font(.system(size: size, weight: .black, design: .serif).italic())
            .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.48, green: 0.72, blue: 1), .white], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: Color.blue.opacity(0.45), radius: size * 0.3)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The hideout behind the lobby: a rain-streaked night skyline with a bridge through steel windows,
/// a pinned-up evidence board, a weapon rack, a workbench with an ammo crate and an old rug.
struct HideoutBackdrop: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color { Color(red: r, green: g, blue: b).opacity(a) }

            // wall: warm, dusty gunmetal that darkens toward the floor
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: [col(0.27, 0.25, 0.22), col(0.2, 0.185, 0.165), col(0.12, 0.11, 0.1)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.8)))
            // plank seams on the wall
            for i in 0..<9 {
                let x = w * (0.37 + CGFloat(i) * 0.075)
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1.5, height: h * 0.8)), with: .color(col(0, 0, 0, 0.16)))
            }

            // ---- window with the night city
            let win = CGRect(x: w * 0.0, y: h * 0.07, width: w * 0.385, height: h * 0.64)
            ctx.fill(Path(win), with: .linearGradient(Gradient(colors: [col(0.05, 0.09, 0.15), col(0.1, 0.16, 0.22), col(0.2, 0.22, 0.26)]), startPoint: CGPoint(x: 0, y: win.minY), endPoint: CGPoint(x: 0, y: win.maxY)))
            // far skyline, then near skyline
            for layer in 0..<2 {
                let base = win.minY + win.height * (layer == 0 ? 0.74 : 0.86)
                let tone = layer == 0 ? col(0.07, 0.1, 0.15) : col(0.035, 0.05, 0.075)
                var x = win.minX
                var i = 0
                while x < win.maxX {
                    let bw = win.width * (0.045 + CGFloat((i * 7 + layer * 3) % 5) * 0.012)
                    let bh = win.height * (0.1 + CGFloat((i * 13 + layer * 5) % 7) * 0.045)
                    let r = CGRect(x: x, y: base - bh, width: bw, height: bh + win.height * 0.3)
                    ctx.fill(Path(r), with: .color(tone))
                    // lit windows
                    var wy = r.minY + 5
                    var k = 0
                    while wy < base - 3 {
                        var wx = r.minX + 3
                        while wx < r.maxX - 4 {
                            if (i * 31 + k * 17 + Int(wx / 4) * 7) % 5 < 2 {
                                ctx.fill(Path(CGRect(x: wx, y: wy, width: 2, height: 3)), with: .color(col(1, 0.82, 0.45, layer == 0 ? 0.35 : 0.6)))
                            }
                            wx += 6
                        }
                        wy += 8
                        k += 1
                    }
                    x += bw + 2
                    i += 1
                }
            }
            // suspension bridge
            let deck = win.minY + win.height * 0.8
            ctx.fill(Path(CGRect(x: win.minX, y: deck, width: win.width, height: 3)), with: .color(col(0.02, 0.03, 0.045)))
            for tx in [win.minX + win.width * 0.22, win.minX + win.width * 0.78] {
                ctx.fill(Path(CGRect(x: tx - 3, y: win.minY + win.height * 0.4, width: 6, height: deck - (win.minY + win.height * 0.4))), with: .color(col(0.02, 0.03, 0.045)))
            }
            var cable = Path()
            cable.move(to: CGPoint(x: win.minX, y: deck - 4))
            cable.addQuadCurve(to: CGPoint(x: win.minX + win.width * 0.22, y: win.minY + win.height * 0.4), control: CGPoint(x: win.minX + win.width * 0.1, y: deck - 8))
            cable.addQuadCurve(to: CGPoint(x: win.minX + win.width * 0.78, y: win.minY + win.height * 0.4), control: CGPoint(x: win.minX + win.width * 0.5, y: deck + 6))
            cable.addQuadCurve(to: CGPoint(x: win.maxX, y: deck - 4), control: CGPoint(x: win.minX + win.width * 0.92, y: deck - 8))
            ctx.stroke(cable, with: .color(col(0.02, 0.03, 0.045)), lineWidth: 1.4)
            for i in 0..<18 {
                let lx = win.minX + win.width * (0.03 + CGFloat(i) * 0.055)
                ctx.fill(Path(ellipseIn: CGRect(x: lx - 1.5, y: deck - 2, width: 3, height: 3)), with: .color(col(1, 0.85, 0.5, 0.8)))
            }
            // street lamp glow at the sill
            ctx.fill(Path(ellipseIn: CGRect(x: win.minX + win.width * 0.12 - 24, y: win.maxY - 70, width: 48, height: 48)), with: .radialGradient(Gradient(colors: [col(1, 0.75, 0.4, 0.45), .clear]), center: CGPoint(x: win.minX + win.width * 0.12, y: win.maxY - 46), startRadius: 1, endRadius: 24))
            // rain streaks
            for i in 0..<46 {
                let rx = win.minX + CGFloat((i * 53) % 97) / 97 * win.width
                let ry = win.minY + CGFloat((i * 29) % 83) / 83 * win.height * 0.9
                ctx.fill(Path(CGRect(x: rx, y: ry, width: 1, height: 14 + CGFloat((i * 7) % 20))), with: .color(Color.white.opacity(0.05)))
            }
            // steel frame: arched header row, mullions, transom
            let steel = col(0.12, 0.115, 0.11)
            let steelHi = col(0.3, 0.29, 0.27)
            for i in 0...6 {
                let x = win.minX + CGFloat(i) * win.width / 6
                ctx.fill(Path(CGRect(x: x - 3, y: win.minY, width: 6, height: win.height)), with: .color(steel))
                ctx.fill(Path(CGRect(x: x - 3, y: win.minY, width: 1.5, height: win.height)), with: .color(steelHi.opacity(0.5)))
            }
            for fy in [0.0, 0.2, 0.55, 1.0] {
                ctx.fill(Path(CGRect(x: win.minX, y: win.minY + win.height * CGFloat(fy) - 3, width: win.width, height: 6)), with: .color(steel))
            }
            for i in 0..<6 {
                var arc = Path()
                let ax = win.minX + CGFloat(i) * win.width / 6
                arc.addArc(center: CGPoint(x: ax + win.width / 12, y: win.minY + win.height * 0.2), radius: win.width / 12, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                ctx.stroke(arc, with: .color(steel), lineWidth: 3)
            }
            ctx.fill(Path(CGRect(x: win.minX, y: win.maxY, width: win.width + 16, height: 8)), with: .color(col(0.16, 0.15, 0.14)))

            // ---- shooting-range poster and wanted notices between window and board
            ctx.fill(Path(CGRect(x: w * 0.405, y: h * 0.2, width: w * 0.034, height: h * 0.13)), with: .color(col(0.2, 0.42, 0.24)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.41, y: h * 0.225, width: w * 0.024, height: w * 0.024)), with: .color(col(0.1, 0.25, 0.13)))
            ctx.fill(Path(CGRect(x: w * 0.445, y: h * 0.27, width: w * 0.034, height: h * 0.15)), with: .color(col(0.62, 0.55, 0.42)))
            ctx.fill(Path(CGRect(x: w * 0.452, y: h * 0.29, width: w * 0.02, height: h * 0.05)), with: .color(col(0.25, 0.2, 0.15)))

            // ---- evidence board
            let board = CGRect(x: w * 0.575, y: h * 0.16, width: w * 0.385, height: h * 0.36)
            ctx.fill(Path(board.insetBy(dx: -9, dy: -9)), with: .linearGradient(Gradient(colors: [col(0.05, 0.05, 0.055), col(0.14, 0.13, 0.12)]), startPoint: board.origin, endPoint: CGPoint(x: board.maxX, y: board.maxY)))
            ctx.fill(Path(board), with: .color(col(0.36, 0.3, 0.23)))
            for i in 0..<26 {
                let pw = CGFloat(20 + (i * 11) % 26), ph = CGFloat(15 + (i * 7) % 22)
                let px = board.minX + 6 + CGFloat((i * 37) % 97) / 100 * (board.width - pw - 12)
                let py = board.minY + 6 + CGFloat((i * 23) % 91) / 100 * (board.height - ph - 12)
                let paper = i % 3 == 0 ? col(0.84, 0.8, 0.7) : (i % 3 == 1 ? col(0.72, 0.7, 0.64) : col(0.9, 0.88, 0.82))
                ctx.fill(Path(CGRect(x: px, y: py, width: pw, height: ph)), with: .color(paper))
                ctx.fill(Path(CGRect(x: px + 2, y: py + 2, width: pw * 0.5, height: ph * 0.5)), with: .color(col(0.2, 0.2, 0.2, 0.55)))
                ctx.fill(Path(ellipseIn: CGRect(x: px + pw / 2 - 1.5, y: py - 1, width: 3, height: 3)), with: .color(col(0.75, 0.1, 0.1)))
            }
            var strings = Path()
            let pts: [(CGFloat, CGFloat)] = [(0.08, 0.12), (0.4, 0.5), (0.72, 0.2), (0.3, 0.82), (0.9, 0.7), (0.55, 0.3)]
            for (i, p) in pts.enumerated() {
                let q = CGPoint(x: board.minX + p.0 * board.width, y: board.minY + p.1 * board.height)
                if i == 0 { strings.move(to: q) } else { strings.addLine(to: q) }
            }
            ctx.stroke(strings, with: .color(col(0.7, 0.12, 0.1, 0.85)), lineWidth: 1.2)

            // ---- pipes and gauges on the right wall
            ctx.fill(Path(CGRect(x: w * 0.962, y: 0, width: 9, height: h * 0.78)), with: .color(col(0.22, 0.2, 0.17)))
            ctx.fill(Path(CGRect(x: w * 0.962, y: 0, width: 3, height: h * 0.78)), with: .color(col(0.5, 0.42, 0.3, 0.5)))
            ctx.fill(Path(CGRect(x: w * 0.8, y: h * 0.58, width: w * 0.2, height: 8)), with: .color(col(0.2, 0.18, 0.15)))
            for (gx, gy) in [(0.975, 0.23), (0.975, 0.33)] as [(CGFloat, CGFloat)] {
                let r = CGRect(x: w * gx - 13, y: h * gy - 13, width: 26, height: 26)
                ctx.fill(Path(ellipseIn: r.insetBy(dx: -3, dy: -3)), with: .color(col(0.55, 0.42, 0.22)))
                ctx.fill(Path(ellipseIn: r), with: .color(col(0.88, 0.85, 0.75)))
                var needle = Path()
                needle.move(to: CGPoint(x: r.midX, y: r.midY)); needle.addLine(to: CGPoint(x: r.midX + 7, y: r.midY - 6))
                ctx.stroke(needle, with: .color(col(0.5, 0.05, 0.05)), lineWidth: 1.4)
            }

            // ---- weapon rack
            ctx.fill(Path(CGRect(x: w * 0.75, y: h * 0.5, width: w * 0.2, height: 6)), with: .color(col(0.1, 0.09, 0.08)))
            ctx.fill(Path(CGRect(x: w * 0.75, y: h * 0.7, width: w * 0.2, height: 6)), with: .color(col(0.1, 0.09, 0.08)))
            for i in 0..<7 {
                let x = w * 0.765 + CGFloat(i) * w * 0.025
                var gun = Path()
                gun.move(to: CGPoint(x: x - CGFloat(i % 3) * 2, y: h * 0.76)); gun.addLine(to: CGPoint(x: x + 1 + CGFloat(i % 2) * 3, y: h * 0.4 + CGFloat((i * 13) % 4) * h * 0.02))
                ctx.stroke(gun, with: .color(col(0.045, 0.05, 0.055)), lineWidth: 5)
                ctx.fill(Path(CGRect(x: x - 3, y: h * 0.5 - 2, width: 8, height: 4)), with: .color(col(0.3, 0.3, 0.28)))
            }

            // ---- workbench with books and a lamp
            ctx.fill(Path(CGRect(x: 0, y: h * 0.71, width: w * 0.37, height: h * 0.04)), with: .color(col(0.16, 0.14, 0.12)))
            ctx.fill(Path(CGRect(x: 0, y: h * 0.75, width: w * 0.37, height: h * 0.16)), with: .color(col(0.075, 0.07, 0.065)))
            for i in 0..<5 {
                let bx = w * 0.03 + CGFloat(i) * w * 0.022
                ctx.fill(Path(CGRect(x: bx, y: h * 0.63 + CGFloat(i % 2) * 3, width: w * 0.02, height: h * 0.08 - CGFloat(i % 2) * 3)), with: .color(i % 2 == 0 ? col(0.28, 0.2, 0.13) : col(0.2, 0.22, 0.2)))
            }
            ctx.fill(Path(CGRect(x: w * 0.2, y: h * 0.69, width: w * 0.07, height: h * 0.02)), with: .color(col(0.5, 0.45, 0.35)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3 - 22, y: h * 0.58 - 22, width: 44, height: 44)), with: .radialGradient(Gradient(colors: [col(1, 0.7, 0.35, 0.4), .clear]), center: CGPoint(x: w * 0.3, y: h * 0.58), startRadius: 1, endRadius: 22))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3 - 3, y: h * 0.58 - 3, width: 6, height: 6)), with: .color(col(1, 0.8, 0.5)))

            // ---- floor with an old rug
            ctx.fill(Path(CGRect(x: 0, y: h * 0.8, width: w, height: h * 0.2)), with: .linearGradient(Gradient(colors: [col(0.15, 0.115, 0.09), col(0.05, 0.04, 0.04)]), startPoint: CGPoint(x: 0, y: h * 0.8), endPoint: CGPoint(x: 0, y: h)))
            var plank = Path()
            for i in 0..<12 {
                let x = CGFloat(i) * w / 11
                plank.move(to: CGPoint(x: w * 0.5, y: h * 0.8)); plank.addLine(to: CGPoint(x: x, y: h))
            }
            ctx.stroke(plank, with: .color(Color.black.opacity(0.28)), lineWidth: 1)
            let rug = CGRect(x: w * 0.2, y: h * 0.86, width: w * 0.6, height: h * 0.13)
            ctx.fill(Path(rug), with: .color(col(0.28, 0.14, 0.1)))
            ctx.fill(Path(rug.insetBy(dx: 7, dy: 5)), with: .color(col(0.17, 0.1, 0.09)))
            ctx.stroke(Path(rug.insetBy(dx: 14, dy: 9)), with: .color(col(0.7, 0.55, 0.3, 0.55)), lineWidth: 1.2)
            for i in 0..<9 {
                let dx = rug.minX + rug.width * (0.1 + CGFloat(i) * 0.1)
                var dia = Path()
                dia.move(to: CGPoint(x: dx, y: rug.midY - 6)); dia.addLine(to: CGPoint(x: dx + 6, y: rug.midY)); dia.addLine(to: CGPoint(x: dx, y: rug.midY + 6)); dia.addLine(to: CGPoint(x: dx - 6, y: rug.midY)); dia.closeSubpath()
                ctx.fill(dia, with: .color(col(0.7, 0.55, 0.3, 0.5)))
            }

            // ---- ammo crate and a steel locker
            let crate = CGRect(x: w * 0.1, y: h * 0.78, width: w * 0.17, height: h * 0.15)
            ctx.fill(Path(crate), with: .color(col(0.22, 0.26, 0.17)))
            ctx.stroke(Path(crate), with: .color(col(0.1, 0.12, 0.08)), lineWidth: 2)
            ctx.fill(Path(CGRect(x: crate.minX, y: crate.minY, width: crate.width, height: 5)), with: .color(col(0.3, 0.35, 0.22)))
            ctx.draw(Text("AMMO").font(.system(size: max(10, w * 0.016), weight: .heavy, design: .monospaced)).foregroundColor(col(0.8, 0.82, 0.7, 0.85)), at: CGPoint(x: crate.midX, y: crate.midY + 2), anchor: .center)
            let locker = CGRect(x: w * 0.83, y: h * 0.76, width: w * 0.17, height: h * 0.2)
            ctx.fill(Path(locker), with: .color(col(0.1, 0.105, 0.11)))
            ctx.stroke(Path(locker), with: .color(col(0.28, 0.28, 0.27)), lineWidth: 2)
            ctx.fill(Path(CGRect(x: locker.midX - 5, y: locker.minY + 14, width: 10, height: 14)), with: .color(col(0.75, 0.38, 0.12)))

            // ---- lighting: window spill, warm corners, vignette
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: [col(0, 0, 0, 0.22), .clear, col(0, 0, 0, 0.45)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .radialGradient(Gradient(colors: [.clear, col(0, 0, 0, 0.5)]), center: CGPoint(x: w * 0.5, y: h * 0.5), startRadius: min(w, h) * 0.55, endRadius: max(w, h) * 0.75))
        }
        .ignoresSafeArea()
    }
}

/// the viewfinder corner marks of the old look are gone: panels are plain rectangles now
extension View {
    func tacBrackets(_ col: Color = Color.white.opacity(0.55), len: CGFloat = 8) -> some View { self }
}

// MARK: - shell: top navigation around every lobby page

struct LobbyShell<Content: View>: View {
    @EnvironmentObject var game: Game
    let active: Int
    let size: CGSize
    let t: TacData
    let act: (LobbyAct) -> Void
    let content: Content

    init(active: Int, size: CGSize, t: TacData, act: @escaping (LobbyAct) -> Void, @ViewBuilder content: () -> Content) {
        self.active = active; self.size = size; self.t = t; self.act = act; self.content = content()
    }

    /// label, nav index understood by LobbyView
    private let items: [(String, Int)] = [("HIDEOUT", 0), ("LOADOUT", 2), ("ARMORY", 3), ("EDITOR", 8), ("OPERATORS", 1), ("BARRACKS", 4), ("SHOP", 6)]

    private func navItem(_ it: (String, Int)) -> some View {
        let on = it.1 == active
        return Button { act(.nav(it.1)) } label: {
            Text(it.0).font(.jk(10, .semibold)).foregroundColor(on ? LS.orange : .white.opacity(0.78)).lineLimit(1).fixedSize()
                .padding(.horizontal, 7).frame(height: LS.topH)
                .overlay(alignment: .bottom) { Rectangle().fill(on ? LS.orange : .clear).frame(height: 2).padding(.horizontal, 6).padding(.bottom, 6) }
        }
        .buttonStyle(TuiPress())
    }

    var body: some View {
        let W = size.width, H = size.height
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let a = LS.area(size)
        return ZStack {
            HideoutBackdrop()
            content
                .frame(width: a.width, height: a.height)
                .position(x: a.width / 2, y: LS.topH + a.height / 2)
            HStack(spacing: 6) {
                AirbladeLogo(size: 19)
                    .padding(.trailing, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) { ForEach(0..<items.count, id: \.self) { navItem(items[$0]) } }
                }
                Spacer(minLength: 0)
                Button { act(.ranks) } label: {
                    HStack(spacing: 7) {
                        PortraitAvatar(key: TacAvatar.myKey, size: 30, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)
                            .clipShape(Rectangle()).overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TacProfile.name).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1).frame(maxWidth: 70, alignment: .leading)
                            HStack(spacing: 4) {
                                Text("LVL \(ri + 1)").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.75)).fixedSize()
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.2))
                                    Rectangle().fill(Color.white).frame(width: 52 * CGFloat(TacRank.progress(xp)))
                                }
                                .frame(width: 52, height: 3)
                            }
                        }
                    }
                }
                .buttonStyle(TuiPress())
                HStack(spacing: 4) {
                    Circle().fill(Color(red: 1, green: 0.7, blue: 0.1)).frame(width: 13, height: 13).overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    Text(game.s.ex.gems.formatted()).font(.jk(11, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
                }
                Button { act(.screen(5)) } label: {
                    HStack(spacing: 4) {
                        SF("diamond.fill").font(.system(size: 12, weight: .bold)).foregroundColor(Color(red: 0.3, green: 0.7, blue: 1))
                        Text("\(t.rating)").font(.jk(11, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
                    }
                }
                .buttonStyle(TuiPress())
                Button { act(.stats) } label: { SF("gearshape.fill").font(.system(size: 14)).foregroundColor(.white.opacity(0.85)) }.buttonStyle(TuiPress())
            }
            .padding(.horizontal, 12).frame(width: W, height: LS.topH)
            .background(LinearGradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
            .position(x: W / 2, y: LS.topH / 2)
            .frame(height: H, alignment: .top)
        }
    }
}

// MARK: - small shared pieces

struct LSPanel<C: View>: View {
    var title: String? = nil
    var trailing: String? = nil
    @ViewBuilder let content: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                HStack {
                    Text(title).font(.jk(10, .heavy)).foregroundColor(.white)
                    Spacer()
                    if let tr = trailing { Text(tr).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7)) }
                }
                .padding(.horizontal, 8).frame(height: 22)
            }
            content()
        }
        .background(Color(red: 0.05, green: 0.055, blue: 0.06).opacity(0.9))
        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
        .tacBrackets()
    }
}

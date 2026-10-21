import SwiftUI

/// dusk battlefield behind the lobby: sunset sky, mountains, watchtower, helicopter, wet ground
struct BodycamBackdrop: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let wall = Color(red: 0.105, green: 0.105, blue: 0.11)
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(Color(red: 0.025, green: 0.03, blue: 0.045)))
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.78)), with: .linearGradient(Gradient(colors: [Color(red: 0.13, green: 0.14, blue: 0.16), wall, Color(red: 0.08, green: 0.075, blue: 0.07)]), startPoint: .zero, endPoint: CGPoint(x: w, y: h * 0.78)))
            // Rain-streaked hideout windows and distant city lights.
            let win = CGRect(x: w * 0.025, y: h * 0.11, width: w * 0.43, height: h * 0.58)
            ctx.fill(Path(win), with: .color(Color(red: 0.015, green: 0.035, blue: 0.065)))
            for i in 0..<7 {
                let x = win.minX + CGFloat(i) * win.width / 7
                ctx.fill(Path(CGRect(x: x, y: win.minY, width: win.width / 7 - 2, height: win.height)), with: .color(Color(red: 0.03, green: 0.065, blue: 0.105).opacity(0.7)))
                for j in 0..<9 {
                    let lx = x + CGFloat((i * 13 + j * 7) % 17) / 17 * (win.width / 7 - 4)
                    let ly = win.minY + CGFloat((i * 19 + j * 23) % 83) / 100 * win.height
                    ctx.fill(Path(CGRect(x: lx, y: ly, width: 2, height: 3)), with: .color(Color(red: 0.7, green: 0.66, blue: 0.48).opacity(0.25 + Double(j % 3) * 0.12)))
                }
            }
            for i in 0..<8 {
                let x = win.minX + CGFloat(i) * win.width / 8
                ctx.fill(Path(CGRect(x: x, y: win.minY, width: 5, height: win.height)), with: .color(Color(red: 0.19, green: 0.2, blue: 0.21)))
            }
            ctx.fill(Path(CGRect(x: win.minX, y: win.minY, width: win.width, height: 7)), with: .color(Color(red: 0.22, green: 0.22, blue: 0.22)))
            ctx.fill(Path(CGRect(x: win.minX, y: win.maxY - 7, width: win.width, height: 7)), with: .color(Color(red: 0.22, green: 0.22, blue: 0.22)))
            // Evidence board on the right wall.
            let board = CGRect(x: w * 0.59, y: h * 0.15, width: w * 0.32, height: h * 0.33)
            ctx.fill(Path(board.insetBy(dx: -8, dy: -8)), with: .color(Color(red: 0.035, green: 0.035, blue: 0.04)))
            ctx.fill(Path(board), with: .color(Color(red: 0.25, green: 0.22, blue: 0.18)))
            for i in 0..<22 {
                let px = board.minX + CGFloat((i * 37) % 97) / 100 * board.width
                let py = board.minY + CGFloat((i * 23) % 91) / 100 * board.height
                let pw = CGFloat(18 + (i * 11) % 32), ph = CGFloat(12 + (i * 7) % 22)
                ctx.fill(Path(CGRect(x: px, y: py, width: min(pw, board.maxX - px), height: min(ph, board.maxY - py))), with: .color(i % 3 == 0 ? Color(red: 0.63, green: 0.57, blue: 0.45) : Color(red: 0.36, green: 0.34, blue: 0.29)))
            }
            var strings = Path()
            strings.move(to: CGPoint(x: board.minX + 20, y: board.minY + 20)); strings.addLine(to: CGPoint(x: board.maxX - 25, y: board.maxY - 28))
            strings.move(to: CGPoint(x: board.minX + 55, y: board.maxY - 22)); strings.addLine(to: CGPoint(x: board.maxX - 40, y: board.minY + 28))
            ctx.stroke(strings, with: .color(Color(red: 0.55, green: 0.13, blue: 0.12).opacity(0.8)), lineWidth: 1.4)
            // Weapon rack silhouette.
            for i in 0..<7 {
                let x = w * 0.73 + CGFloat(i) * w * 0.025
                ctx.fill(Path(CGRect(x: x, y: h * 0.51, width: 5, height: h * 0.25)), with: .color(Color(red: 0.035, green: 0.04, blue: 0.045)))
                ctx.fill(Path(CGRect(x: x - 2, y: h * 0.49, width: 9, height: 4)), with: .color(Color(red: 0.24, green: 0.24, blue: 0.23)))
            }
            // Workbench, crates, pipes, and scuffed floor.
            ctx.fill(Path(CGRect(x: 0, y: h * 0.64, width: w * 0.42, height: h * 0.035)), with: .color(Color(red: 0.08, green: 0.085, blue: 0.09)))
            ctx.fill(Path(CGRect(x: 0, y: h * 0.675, width: w * 0.42, height: h * 0.12)), with: .color(Color(red: 0.045, green: 0.05, blue: 0.055)))
            ctx.fill(Path(CGRect(x: w * 0.82, y: h * 0.64, width: w * 0.16, height: h * 0.18)), with: .color(Color(red: 0.045, green: 0.05, blue: 0.055)))
            ctx.fill(Path(CGRect(x: 0, y: h * 0.78, width: w, height: h * 0.22)), with: .linearGradient(Gradient(colors: [Color(red: 0.12, green: 0.105, blue: 0.09), Color(red: 0.035, green: 0.035, blue: 0.04)]), startPoint: CGPoint(x: 0, y: h * 0.78), endPoint: CGPoint(x: 0, y: h)))
            var floorLines = Path()
            for i in 0..<12 {
                let x = CGFloat(i) * w / 11
                floorLines.move(to: CGPoint(x: w * 0.5, y: h * 0.78)); floorLines.addLine(to: CGPoint(x: x, y: h))
            }
            for i in 0..<5 { let y = h * (0.82 + CGFloat(i) * 0.04); floorLines.move(to: CGPoint(x: 0, y: y)); floorLines.addLine(to: CGPoint(x: w, y: y)) }
            ctx.stroke(floorLines, with: .color(Color.white.opacity(0.055)), lineWidth: 1)
            // Warm industrial lamps.
            for (x, y) in [(CGFloat(0.49), CGFloat(0.28)), (CGFloat(0.96), CGFloat(0.19)), (CGFloat(0.28), CGFloat(0.62))] {
                ctx.fill(Path(ellipseIn: CGRect(x: w * x - 20, y: h * y - 20, width: 40, height: 40)), with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.63, blue: 0.27).opacity(0.25), .clear]), center: CGPoint(x: w * x, y: h * y), startRadius: 1, endRadius: 20))
                ctx.fill(Path(ellipseIn: CGRect(x: w * x - 3, y: h * y - 3, width: 6, height: 6)), with: .color(Color(red: 1, green: 0.75, blue: 0.43)))
            }
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: [Color.black.opacity(0.16), .clear, Color.black.opacity(0.38)], startPoint: .top, endPoint: .bottom)))
        }
        .ignoresSafeArea()
    }
}

/// thin corner brackets, the viewfinder look used on panels
struct CornerBrackets: ViewModifier {
    var col: Color = Color.white.opacity(0.55)
    var len: CGFloat = 8
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { g in
                Path { p in
                    let w = g.size.width, h = g.size.height
                    for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                        p.move(to: CGPoint(x: x + dx * len, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy * len))
                    }
                }
                .stroke(col, lineWidth: 1.2)
            }
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func tacBrackets(_ col: Color = Color.white.opacity(0.55), len: CGFloat = 8) -> some View { modifier(CornerBrackets(col: col, len: len)) }
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
    private let items: [(String, Int)] = [("PLAY", 0), ("LOADOUT", 2), ("ARMORY", 3), ("EDITOR", 8), ("OPERATORS", 1), ("BARRACKS", 4), ("STORE", 6)]

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
            BodycamBackdrop()
            content
                .frame(width: a.width, height: a.height)
                .position(x: a.width / 2, y: LS.topH + a.height / 2)
            HStack(spacing: 6) {
                HStack(spacing: 8) {
                    SF("bolt.fill").font(.system(size: 15, weight: .heavy)).foregroundColor(LS.orange)
                    Text("AIRBLADE").font(.jk(15, .heavy)).foregroundColor(.white).lineLimit(1).fixedSize()
                }
                .padding(.trailing, 6)
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

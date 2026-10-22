import SwiftUI

// MARK: - Free Roam HUD extras: minimap, kill feed, weapon bar

struct RoamMinimap: View {
    let e: TacticalEngine
    var size: CGFloat = 92
    private let span: CGFloat = 640      // world units shown edge to edge

    var body: some View {
        TimelineView(.animation) { _ in
            let name = e.roam.lastDistrict >= 0 ? OWDistrict.all[e.roam.lastDistrict].name : "TOWN"
            VStack(spacing: 3) {
                Canvas { ctx, sz in draw(&ctx, sz) }
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color(red: 0.03, green: 0.06, blue: 0.1).opacity(0.85)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 0.3, green: 0.65, blue: 1).opacity(0.7), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                Text(name).font(.jk(7.5, .heavy)).tracking(0.8).foregroundColor(.white)
                    .padding(.horizontal, 6).frame(height: 13)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        let me = e.me
        let k = sz.width / span
        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
        func s(_ p: CGPoint) -> CGPoint { CGPoint(x: c.x + (p.x - me.pos.x) * k, y: c.y + (p.y - me.pos.y) * k) }
        let win = CGRect(x: me.pos.x - span / 2 - 40, y: me.pos.y - span / 2 - 40, width: span + 80, height: span + 80)
        var walls = Path()
        for r in TMap.solid where r.minX > -5000 && r.intersects(win) {
            walls.addRect(CGRect(x: s(r.origin).x, y: s(r.origin).y, width: r.width * k, height: r.height * k))
        }
        ctx.fill(walls, with: .color(Color(red: 0.32, green: 0.45, blue: 0.62).opacity(0.75)))
        // other people
        for p in e.players where p.alive && !p.isPlayer {
            let q = s(p.pos)
            let d = hypot(q.x - c.x, q.y - c.y)
            if d > sz.width / 2 - 3 { continue }
            let col: Color = p.civ ? Color.white.opacity(0.45) : (p.tier == 2 ? Color(red: 1, green: 0.25, blue: 0.3) : RoamCrew.cols[min(2, max(0, p.crew))])
            let r: CGFloat = p.tier == 2 ? 3.6 : (p.civ ? 1.7 : 2.6)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)), with: .color(col))
        }
        // objective
        if let m = e.roamMarker {
            var q = s(m)
            let dx = q.x - c.x, dy = q.y - c.y
            let d = hypot(dx, dy), lim = sz.width / 2 - 6
            if d > lim { q = CGPoint(x: c.x + dx / d * lim, y: c.y + dy / d * lim) }
            let gold = Color(red: 1, green: 0.8, blue: 0.25)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - 4, y: q.y - 4, width: 8, height: 8)), with: .color(gold))
            ctx.stroke(Path(ellipseIn: CGRect(x: q.x - 6, y: q.y - 6, width: 12, height: 12)), with: .color(gold.opacity(0.6)), lineWidth: 1)
        }
        // you: an arrow pointing where you aim
        var a = Path()
        let ang = me.aim
        func pt(_ r: CGFloat, _ off: CGFloat) -> CGPoint { CGPoint(x: c.x + cos(ang + off) * r, y: c.y + sin(ang + off) * r) }
        a.move(to: pt(7, 0)); a.addLine(to: pt(5, 2.5)); a.addLine(to: pt(1.5, .pi)); a.addLine(to: pt(5, -2.5)); a.closeSubpath()
        ctx.fill(a, with: .color(Color(red: 0.3, green: 0.85, blue: 1)))
        ctx.stroke(a, with: .color(.white), lineWidth: 0.8)
    }
}

struct RoamFeedView: View {
    let e: TacticalEngine
    private func icon(_ w: Int) -> String { ["hand.raised.fill", "figure.baseball", "scope"][min(2, max(0, w))] }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(e.roam.feed) { f in
                HStack(spacing: 5) {
                    Text(f.killer).foregroundColor(f.killer == "YOU" ? Color(red: 0.4, green: 0.8, blue: 1) : .white)
                    Image(systemName: icon(f.weapon)).font(.system(size: 8, weight: .bold)).foregroundColor(Color(red: 1, green: 0.8, blue: 0.25))
                    Text(f.victim).foregroundColor(f.victim == "YOU" ? Color(red: 1, green: 0.4, blue: 0.4) : (f.boss ? Color(red: 1, green: 0.3, blue: 0.3) : .white.opacity(0.9)))
                        .lineLimit(1)
                }
                .font(.jk(9, .semibold))
                .padding(.horizontal, 6).frame(height: 15)
                .background(Color.black.opacity(f.mine ? 0.55 : 0.35))
                .overlay(Rectangle().stroke(f.mine ? Color(red: 1, green: 0.8, blue: 0.25).opacity(0.7) : .clear, lineWidth: 1))
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: e.roam.feed.count)
    }
}

struct RoamWeaponBar: View {
    let e: TacticalEngine
    private let gold = Color(red: 1, green: 0.8, blue: 0.25)
    private let icons = ["hand.raised.fill", "figure.baseball", "scope"]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { w in
                let owned = e.roam.owned.contains(w)
                let on = e.roam.weapon == w
                Button { e.roamSelect(w) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: owned ? icons[w] : "lock.fill").font(.system(size: 13, weight: .bold))
                            .foregroundColor(on ? .black : (owned ? .white : .white.opacity(0.35))).frame(width: 18)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(TacticalEngine.armNames[w]).font(.jk(8, .heavy)).tracking(0.6)
                            if w == 2 && owned {
                                Text(e.roam.reloadT > 0 ? "RELOADING" : "\(e.roam.ammo) / \(e.roam.reserve)").font(.jk(7, .semibold)).monospacedDigit()
                            } else if !owned {
                                Text(w == 1 ? "$250 · PHONE" : "$900 · PHONE").font(.jk(6.5, .medium))
                            }
                        }
                        .foregroundColor(on ? .black : (owned ? .white : .white.opacity(0.4)))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 7).frame(width: 96, height: 30)
                    .background(RoundedRectangle(cornerRadius: 3).fill(on ? gold : Color.black.opacity(0.5)))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(on ? Color.white.opacity(0.6) : Color.white.opacity(0.18), lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 2)
    }
}

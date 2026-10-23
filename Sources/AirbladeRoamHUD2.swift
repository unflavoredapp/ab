import SwiftUI

// MARK: - Free Roam HUD extras: minimap, kill feed, weapon bar

struct RoamMinimap: View {
    let e: TacticalEngine
    var size: CGFloat = 92
    @Binding var big: Bool
    private var span: CGFloat { big ? 2400 : 1100 }
    private var dia: CGFloat { big ? 210 : size }

    /// rivals chasing you, or a war you are fighting in this district
    private var isHot: Bool {
        if e.players.contains(where: { !$0.isPlayer && !$0.civ && !$0.ally && $0.alive && $0.targetID == 0 }) { return true }
        if let j = e.roam.job, j.kind == .turf, j.district == e.roam.lastDistrict { return true }
        return false
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let dIdx = e.roam.lastDistrict
            let name = dIdx >= 0 ? OWDistrict.all[dIdx].name : "TOWN"
            let ring: Color = dIdx >= 0 ? OWDistrict.all[dIdx].color : Color(red: 0.3, green: 0.65, blue: 1)
            let pulse = isHot ? 0.5 + 0.5 * sin(tl.date.timeIntervalSinceReferenceDate * 5) : 0
            VStack(spacing: 3) {
                Canvas { ctx, sz in draw(&ctx, sz) }
                    .frame(width: dia, height: dia)
                    .background(Circle().fill(Color(red: 0.03, green: 0.06, blue: 0.1).opacity(0.85)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ring.opacity(0.75), lineWidth: 2))
                    .overlay(Circle().stroke(Color(red: 1, green: 0.3, blue: 0.26).opacity(pulse), lineWidth: 4))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .contentShape(Circle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { big.toggle() } }
                HStack(spacing: 4) {
                    Circle().fill(ring).frame(width: 5, height: 5)
                    Text(name).font(.jk(7.5, .heavy)).tracking(0.8).foregroundColor(.white)
                    if dIdx >= 0 { Text("\(OWDistrict.all[dIdx].control)%").font(.jk(7.5, .heavy)).foregroundColor(ring).monospacedDigit() }
                }
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
        func w(_ q: CGPoint) -> CGPoint { CGPoint(x: me.pos.x + (q.x - c.x) / k, y: me.pos.y + (q.y - c.y) / k) }
        let win = CGRect(x: me.pos.x - span / 2 - 40, y: me.pos.y - span / 2 - 40, width: span + 80, height: span + 80)
        if TMap.kind == 10 {
            // river and bridges
            let wx0 = TCity.riverX0 + TMap.off, wx1 = TCity.riverX1 + TMap.off
            let p0 = s(CGPoint(x: wx0, y: TCity.riverTop)), p1 = s(CGPoint(x: wx1, y: TCity.riverBot))
            ctx.fill(Path(CGRect(x: p0.x, y: p0.y, width: p1.x - p0.x, height: p1.y - p0.y)), with: .color(Color(red: 0.12, green: 0.42, blue: 0.72).opacity(0.9)))
            for j in TCity.bridgeRows {
                let a = s(CGPoint(x: wx0 - 60, y: TCity.ys[j] - TCity.roadW(j) / 2)), b2 = s(CGPoint(x: wx1 + 60, y: TCity.ys[j] + TCity.roadW(j) / 2))
                ctx.fill(Path(CGRect(x: a.x, y: a.y, width: b2.x - a.x, height: b2.y - a.y)), with: .color(Color(red: 0.55, green: 0.58, blue: 0.62)))
            }
        }
        var walls = Path()
        for r in TMap.solid where r.minX > -5000 && r.intersects(win) {
            walls.addRect(CGRect(x: s(r.origin).x, y: s(r.origin).y, width: r.width * k, height: r.height * k))
        }
        ctx.fill(walls, with: .color(Color(red: 0.32, green: 0.45, blue: 0.62).opacity(0.75)))
        // district boundaries in their control colour
        let st: CGFloat = big ? 7 : 6
        let n = Int(sz.width / st)
        let all = OWDistrict.all
        var grid = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: n + 1)
        for gx in 0...n { for gy in 0...n { grid[gx][gy] = OWWorld.districtAt(w(CGPoint(x: CGFloat(gx) * st, y: CGFloat(gy) * st))) } }
        for gx in 0..<n { for gy in 0..<n {
            let d0 = grid[gx][gy]
            let x = CGFloat(gx) * st, y = CGFloat(gy) * st
            if grid[gx + 1][gy] != d0 {
                ctx.fill(Path(CGRect(x: x + st - 0.7, y: y, width: 1.6, height: st)), with: .color(all[d0].color.opacity(0.9)))
            }
            if grid[gx][gy + 1] != d0 {
                ctx.fill(Path(CGRect(x: x, y: y + st - 0.7, width: st, height: 1.6)), with: .color(all[d0].color.opacity(0.9)))
            }
        } }
        // parked and wrecked cars
        for car in e.roam.cars where !car.wrecked {
            let q = s(car.pos)
            if hypot(q.x - c.x, q.y - c.y) > sz.width / 2 - 3 { continue }
            ctx.fill(Path(roundedRect: CGRect(x: q.x - 2.2, y: q.y - 1.5, width: 4.4, height: 3), cornerRadius: 0.8), with: .color(car.mine ? Color(red: 1, green: 0.55, blue: 0.16) : Color.white.opacity(0.7)))
        }
        // other people
        for p in e.players where p.alive && !p.isPlayer {
            let q = s(p.pos)
            let d = hypot(q.x - c.x, q.y - c.y)
            if d > sz.width / 2 - 3 { continue }
            let col: Color = p.civ ? Color.white.opacity(0.45) : (p.ally ? Color(red: 0.3, green: 0.75, blue: 1) : (p.tier == 2 ? Color(red: 1, green: 0.25, blue: 0.3) : RoamCrew.cols[min(2, max(0, p.crew))]))
            let r: CGFloat = p.tier == 2 ? 3.6 : (p.civ ? 1.7 : 2.6)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)), with: .color(col))
            if p.ally { ctx.stroke(Path(ellipseIn: CGRect(x: q.x - r - 1.5, y: q.y - r - 1.5, width: r * 2 + 3, height: r * 2 + 3)), with: .color(col.opacity(0.7)), lineWidth: 0.8) }
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
        TimelineView(.animation) { _ in content }
    }

    private var content: some View {
        HStack(spacing: 4) {
            ForEach((0..<3).filter { e.roam.owned.contains($0) }, id: \.self) { w in
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

/// ENTER / EXIT button and, while driving, speed and car health
struct RoamCarHUD: View {
    let e: TacticalEngine
    private let gold = Color(red: 1, green: 0.8, blue: 0.25)

    var body: some View {
        TimelineView(.animation) { _ in content }
    }

    private var content: some View {
        let driving = e.roam.driving >= 0
        let car: RoamCar? = driving ? e.roam.cars[e.roam.driving] : nil
        return VStack(alignment: .trailing, spacing: 6) {
            if let c = car {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(Int(abs(c.speed) * 0.11))").font(.jk(26, .heavy)).monospacedDigit().foregroundColor(.white)
                        Text("KM/H").font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.6))
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(c.hp > c.maxHP / 3 ? Color(red: 0.3, green: 0.85, blue: 0.45) : Color(red: 1, green: 0.3, blue: 0.26)).frame(width: 90 * max(0, c.hp) / max(1, c.maxHP))
                    }.frame(width: 90, height: 4)
                }
                .padding(8).background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.5)))
                if c.hp < c.maxHP / 3 {
                    Text(c.hp < c.maxHP / 6 ? "NEAR WRECK" : "ENGINE DAMAGED").font(.jk(8, .heavy)).tracking(1)
                        .foregroundColor(Color(red: 1, green: 0.3, blue: 0.26))
                        .padding(.horizontal, 8).frame(height: 18)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .overlay(Capsule().stroke(Color(red: 1, green: 0.3, blue: 0.26), lineWidth: 1))
                }
            }
            if driving || e.roamNearCar != nil {
                Button { e.roamInteract() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: driving ? "figure.walk" : "car.fill").font(.system(size: 13, weight: .bold))
                        Text(driving ? "EXIT" : "ENTER CAR").font(.jk(10, .heavy)).tracking(0.8)
                    }
                    .foregroundColor(.black).padding(.horizontal, 12).frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 4).fill(gold))
                    .shadow(color: gold.opacity(0.5), radius: 6)
                }.buttonStyle(.plain)
            }
        }
    }
}

import SwiftUI

// MARK: - HoodBlok city (kind 10): the open-world map for Free Roam
//
// 9000 x 9000 units, an 8 x 8 grid of city blocks cut by streets. Each block is decided by the district it sits in
// (the same nearest-label rule the map screen uses): parks, yards, courtyards, blocks cut by alleys, or solid
// buildings. Everything that is not walkable becomes a building front, like the Town. Deterministic: same city every run.

enum TCity {
    static let W: CGFloat = 9000
    static let xs: [CGFloat] = (0..<9).map { 600 + CGFloat($0) * 1000 }
    static let ys: [CGFloat] = (0..<9).map { 600 + CGFloat($0) * 1000 }
    static func roadW(_ i: Int) -> CGFloat { i % 4 == 0 ? 300 : 200 }
    static let alleyW: CGFloat = 120

    // the river: a north-south band between the second and third avenues, crossed by bridges on every other street
    static let riverCol = 2
    static var riverX0: CGFloat { xs[2] + roadW(2) / 2 }
    static var riverX1: CGFloat { xs[3] - roadW(3) / 2 }
    static var riverTop: CGFloat { ys.first! - roadW(0) / 2 }
    static var riverBot: CGFloat { ys.last! + roadW(ys.count - 1) / 2 }
    static let bridgeRows = [0, 2, 4, 6, 8]

    /// plan coordinates: water, bridges excluded
    static func inWaterPlan(_ p: CGPoint) -> Bool {
        guard p.x > riverX0, p.x < riverX1, p.y > riverTop, p.y < riverBot else { return false }
        for j in bridgeRows where abs(p.y - ys[j]) < roadW(j) / 2 { return false }
        return true
    }

    /// world coordinates (with the floor offset), only in the city
    static func inWater(_ p: CGPoint) -> Bool {
        guard TMap.kind == 10 else { return false }
        return inWaterPlan(CGPoint(x: p.x - TMap.off, y: p.y))
    }

    /// where parked cars start (position, heading) for the drivable cars
    static var carSpots: [(CGPoint, CGFloat)] = []
    /// one street junction per district, used for spawns and the player's hideout
    static var hubs: [CGPoint] = []
    static let shared: MapData = build()

    private static func rnd(_ a: Int, _ b: Int, _ k: Int) -> CGFloat {
        var h = UInt32(truncatingIfNeeded: a &* 73856093 ^ b &* 19349663 ^ k &* 83492791)
        h ^= h >> 13; h = h &* 1274126177; h ^= h >> 16
        return CGFloat(h % 10000) / 10000
    }

    /// (open, alleyV/alleyH, cross) chances per district
    private static func mix(_ d: Int) -> (open: CGFloat, alley: CGFloat, cross: CGFloat) {
        switch d {
        case 0: return (0.22, 0.35, 0.10)
        case 1: return (0.08, 0.25, 0.25)
        case 2: return (0.50, 0.15, 0.05)
        case 3: return (0.03, 0.35, 0.45)
        case 4: return (0.30, 0.25, 0.20)
        default: return (0.65, 0.10, 0.05)
        }
    }

    private static func build() -> MapData {
        let b = MapBuilder(cols: Int(W / 25), rows: Int(W / 25))
        let rc = b.rc
        let off = TMap.off
        let st = 8
        var props: [(PropKind, CGRect)] = []
        carSpots = []

        // streets
        let top = ys.first! - roadW(0) / 2, bot = ys.last! + roadW(ys.count - 1) / 2
        let left = xs.first! - roadW(0) / 2, right = xs.last! + roadW(xs.count - 1) / 2
        for (i, x) in xs.enumerated() { b.gap(1, rc(x - roadW(i) / 2, top, roadW(i), bot - top), st) }
        for (j, y) in ys.enumerated() { b.gap(1, rc(left, y - roadW(j) / 2, right - left, roadW(j)), st) }

        // blocks
        for i in 0..<(xs.count - 1) {
            for j in 0..<(ys.count - 1) {
                if i == riverCol { continue }
                let x0 = xs[i] + roadW(i) / 2, x1 = xs[i + 1] - roadW(i + 1) / 2
                let y0 = ys[j] + roadW(j) / 2, y1 = ys[j + 1] - roadW(j + 1) / 2
                let blk = rc(x0, y0, x1 - x0, y1 - y0)
                let d = OWWorld.districtAt(CGPoint(x: blk.midX, y: blk.midY))
                let m = mix(d)
                let r = rnd(i, j, 1)
                if r < m.open {
                    b.gap(1, blk, st)
                    scatter(blk, d, i, j, &props)
                } else if r < m.open + m.alley {
                    let vertical = rnd(i, j, 2) < 0.5
                    carve(b, blk, vertical: vertical, at: rnd(i, j, 3))
                } else if r < m.open + m.alley + m.cross {
                    carve(b, blk, vertical: true, at: 0.3 + rnd(i, j, 4) * 0.4)
                    carve(b, blk, vertical: false, at: 0.3 + rnd(i, j, 5) * 0.4)
                }
            }
        }

        // the river itself: open ground that the scene floods
        b.gap(1, rc(riverX0, riverTop, riverX1 - riverX0, riverBot - riverTop), st)

        // parked cars along the street edges (these are the drivable ones)
        for i in 0..<xs.count {
            for j in 0..<ys.count where rnd(i, j, 9) < 0.33 {
                let horizontal = rnd(i, j, 10) < 0.5
                let side: CGFloat = rnd(i, j, 11) < 0.5 ? -1 : 1
                if horizontal {
                    let y = ys[j] + side * (roadW(j) / 2 - 38)
                    carSpots.append((CGPoint(x: xs[i] + 260 + rnd(i, j, 12) * 300, y: y), side > 0 ? 0 : CGFloat.pi))
                } else {
                    let x = xs[i] + side * (roadW(i) / 2 - 38)
                    carSpots.append((CGPoint(x: x, y: ys[j] + 260 + rnd(i, j, 13) * 300), side > 0 ? CGFloat.pi / 2 : -CGFloat.pi / 2))
                }
            }
        }
        carSpots = carSpots.filter { $0.0.x < right - 100 && $0.0.y < bot - 100 && !inWaterPlan($0.0) }

        b.rooms.append(TRoom(name: "HoodBlok", r: MapBuilder.R(1, rc(0, 0, W, W)), mat: 0, fl: 1))
        b.doors = []
        let layout = b.layout([.concrete, .brick, .concrete])
        for (k, r) in props { b.p(1, k, r.minX, r.minY, r.width, r.height) }

        // hubs: the junction nearest to each district's label
        hubs = OWDistrict.base.map { d in
            let c = CGPoint(x: d.label.x * W, y: d.label.y * W)
            var best = CGPoint(x: xs[0], y: ys[0]), bd = CGFloat.greatestFiniteMagnitude
            for x in xs { for y in ys { let dd = hypot(x - c.x, y - c.y); if dd < bd { bd = dd; best = CGPoint(x: x, y: y) } } }
            return best
        }
        func P(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + off, y: p.y) }
        var spawns: [CGPoint] = []
        for x in xs { for y in ys { spawns.append(P(CGPoint(x: x, y: y))) } }
        for i in 0..<(xs.count - 1) { for j in 0..<ys.count { spawns.append(P(CGPoint(x: (xs[i] + xs[i + 1]) / 2, y: ys[j]))) } }
        for i in 0..<xs.count { for j in 0..<(ys.count - 1) { spawns.append(P(CGPoint(x: xs[i], y: (ys[j] + ys[j + 1]) / 2))) } }
        spawns = spawns.filter { !inWaterPlan(CGPoint(x: $0.x - off, y: $0.y)) }
        let h0 = hubs[0], h5 = hubs[5]
        let atk = (0..<5).map { P(CGPoint(x: h0.x + 40 + CGFloat($0) * 30, y: h0.y)) }
        let def = (0..<5).map { P(CGPoint(x: h5.x + 40 + CGFloat($0) * 30, y: h5.y)) }
        let packs = hubs.map { P($0) }
        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: [], stairLo: [],
                         siteA: MapBuilder.R(1, rc(hubs[1].x - 150, hubs[1].y - 150, 300, 300)),
                         siteB: MapBuilder.R(1, rc(hubs[2].x - 150, hubs[2].y - 150, 300, 300)),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(hubs[4].x - 150, hubs[4].y - 150, 300, 300)),
                         floorNames: ["", "CITY", ""], loot: [], roofs: [], spawns: spawns)
        md.siteNames = ["A · DOWNTOWN", "B · INDUSTRIAL YARD"]
        // car spots are in plan coordinates; the vehicle system adds the floor offset
        return md
    }

    /// cut a walkable alley through a block (the rest stays solid and becomes two buildings)
    private static func carve(_ b: MapBuilder, _ blk: CGRect, vertical: Bool, at t: CGFloat) {
        let rc = b.rc
        if vertical {
            let x = blk.minX + 160 + (blk.width - 320) * t
            b.gap(1, rc(x - alleyW / 2, blk.minY - 20, alleyW, blk.height + 40), 8)
        } else {
            let y = blk.minY + 160 + (blk.height - 320) * t
            b.gap(1, rc(blk.minX - 20, y - alleyW / 2, blk.width + 40, alleyW), 8)
        }
    }

    /// props for an open block, themed by district
    private static func scatter(_ blk: CGRect, _ d: Int, _ i: Int, _ j: Int, _ out: inout [(PropKind, CGRect)]) {
        let inner = blk.insetBy(dx: 90, dy: 90)
        let n: Int
        switch d { case 2: n = 14; case 5: n = 12; case 4: n = 11; case 0: n = 10; default: n = 7 }
        var centres: [CGPoint] = []
        var tries = 0
        while centres.count < n && tries < n * 12 {
            tries += 1
            let c = CGPoint(x: inner.minX + rnd(i, j, 100 + tries) * inner.width, y: inner.minY + rnd(i, j, 300 + tries) * inner.height)
            if centres.contains(where: { hypot($0.x - c.x, $0.y - c.y) < 190 }) { continue }
            centres.append(c)
            let r = rnd(i, j, 500 + tries)
            let kind: PropKind, w: CGFloat, h: CGFloat
            switch d {
            case 2, 5:   // yards and piers: containers, crates, barrels, a few cars
                if r < 0.4 { kind = .shelf; w = 190; h = 56 }
                else if r < 0.65 { kind = .crate; w = 76; h = 76 }
                else if r < 0.85 { kind = .barrel; w = 36; h = 36 }
                else { kind = .car; w = 110; h = 56 }
            case 0:      // park: trees and planters
                if r < 0.55 { kind = .tree; w = 34; h = 34 }
                else if r < 0.8 { kind = .plant; w = 34; h = 34 }
                else { kind = .rock; w = 50; h = 40 }
            default:     // courtyards: cover
                if r < 0.35 { kind = .sandbag; w = 140; h = 32 }
                else if r < 0.65 { kind = .crate; w = 70; h = 70 }
                else if r < 0.85 { kind = .car; w = 110; h = 56 }
                else { kind = .barrel; w = 36; h = 36 }
            }
            let horizontal = rnd(i, j, 700 + tries) < 0.5
            let ww = horizontal ? w : h, hh = horizontal ? h : w
            out.append((kind, CGRect(x: c.x - ww / 2, y: c.y - hh / 2, width: ww, height: hh)))
        }
    }
}

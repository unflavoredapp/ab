import CoreGraphics

extension TMap {
    /// Nearest solid along `ang` within `maxD`: its distance and the height of its top
    /// (used by TMove for wall-running). Nothing hit -> (maxD, 0).
    static func rayHit(_ from: CGPoint, _ ang: CGFloat, _ maxD: CGFloat) -> (dist: CGFloat, top: CGFloat) {
        let b = CGPoint(x: from.x + cos(ang) * maxD, y: from.y + sin(ang) * maxD)
        var best: CGFloat = 1
        var hitK = -1
        TGrid.forEachSeg(from, b) { k in
            if solidMat[k] != .glass, let t = tSegT(from, b, solid[k]), t < best { best = t; hitK = k }
            return false
        }
        if hitK < 0 { return (maxD, 0) }
        var top = wallTop
        if hitK < solidKind.count, let kind = solidKind[hitK] { top = propH(kind) }
        return (maxD * best, top)
    }

    /// Height you stand on at `p`: the top of a prop (crate, car, sandbag...) under you whose top is at or
    /// just above your feet, else 0 (the street). Walls are never stood on.
    static func groundTop(_ p: CGPoint, feet: CGFloat, r: CGFloat = 10) -> CGFloat {
        var best: CGFloat = 0
        TGrid.forEachNear(p, r + 2) { k in
            guard k < solidKind.count, let kind = solidKind[k] else { return false }
            guard solid[k].insetBy(dx: -r * 0.6, dy: -r * 0.6).contains(p) else { return false }
            let top = propH(kind)
            if top <= feet + TMove.stepUp && top > best { best = top }
            return false
        }
        return best
    }
}

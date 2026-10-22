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
        var top = wallH
        if hitK < solidKind.count, let kind = solidKind[hitK] { top = propH(kind) }
        return (maxD * best, top)
    }
}

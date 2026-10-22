import SwiftUI

// MARK: - Shared world state: who controls which district
// The map, the phone and Free Roam all read and write this, so what you do in the streets changes the map.

final class OWWorld {
    static let shared = OWWorld()
    private let key = "ab.world.v1"
    private var overrides: [String: Int]

    /// set by the map just before it launches Free Roam; Free Roam starts that contract and spawns you there
    struct Pending { let district: Int; let capture: Bool; let kind: RoamJob.Kind }
    static var pending: Pending? = nil

    private init() {
        overrides = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    func control(_ id: Int, base: Int) -> Int { overrides[String(id)] ?? base }

    @discardableResult
    func add(_ id: Int, _ delta: Int) -> (old: Int, new: Int) {
        let base = OWDistrict.base[id].control
        let old = control(id, base: base)
        let new = max(0, min(100, old + delta))
        overrides[String(id)] = new
        UserDefaults.standard.set(overrides, forKey: key)
        if new != old { OWOnline.shared.pushDelta(id, new - old) }
        return (old, new)
    }

    func set(_ id: Int, _ v: Int) {
        overrides[String(id)] = max(0, min(100, v))
        UserDefaults.standard.set(overrides, forKey: key)
    }

    static func owner(_ c: Int) -> OWDistrict.Owner { c >= 55 ? .yours : (c <= 35 ? .enemy : .contested) }

    /// which district a Town position belongs to: nearest district centre on the map layout
    static func districtAt(_ p: CGPoint) -> Int {
        let n = CGPoint(x: p.x / max(1, TMap.W), y: p.y / max(1, TMap.H))
        var best = 0, bd = CGFloat.greatestFiniteMagnitude
        for d in OWDistrict.base {
            let dd = hypot(d.label.x - n.x, d.label.y - n.y)
            if dd < bd { bd = dd; best = d.id }
        }
        return best
    }

    /// Town position of a district's centre
    static func townPoint(_ id: Int) -> CGPoint {
        let l = OWDistrict.base[id].label
        return CGPoint(x: l.x * TMap.W, y: l.y * TMap.H)
    }
}

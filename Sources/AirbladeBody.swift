import SwiftUI

/// The in-match body of every fighter: the AIRBLADE hero (Resources/airblade_hero_game.glb, built by
/// blender-scripts/hero_build.py) holding the rifle, with legs that swing and cloth that blows.
enum HeroBody {
    static var url: URL? {
        Bundle.main.url(forResource: "airblade_hero_game", withExtension: "glb")
            ?? Bundle.main.url(forResource: "airblade_hero_game", withExtension: "glb", subdirectory: "models")
    }
    static var available: Bool { url != nil }

    /// metres -> game units (the old soldier stood about 50 units tall)
    private static let S: Float = 29.5

    private static func collect(_ n: MXNode, _ into: inout [String: MXNode]) {
        if let nm = n.name { into[nm] = n }
        for c in n.childNodes { collect(c, &into) }
    }

    static func make(team: UIColor) -> (sol: TwSoldier, cloth: HeroCloth)? {
        guard let u = url, let model = MXGLTF.load(u) else { return nil }
        var nodes: [String: MXNode] = [:]
        collect(model, &nodes)
        guard let legA = nodes["leg_L"], let legB = nodes["leg_R"] else { return nil }

        let root = MXNode()
        // the model faces +Z; the game's soldiers face +X
        let yaw = Float.pi / 2
        model.eulerAngles = MXVector3(0, yaw, 0)
        model.scale = MXVector3(S, S, S)
        model.position = MXVector3(0, 0.6, 0)
        root.addChildNode(model)

        // each leg hangs from its own hip node in the game frame so the scene can swing it like before
        var hips: [MXNode] = []
        for leg in [legA, legB] {
            let mx = leg.position.x, my = leg.position.y
            leg.removeFromParentNode()
            leg.position = MXVector3(0, 0, 0)
            leg.eulerAngles = MXVector3(0, yaw, 0)
            leg.scale = MXVector3(S, S, S)
            let hip = MXNode()
            hip.position = MXVector3(0, my * S + 0.6, -mx * S)
            hip.addChildNode(leg)
            root.addChildNode(hip)
            hips.append(hip)
        }

        // team colour patches on the shoulders
        for z: Float in [-5.6, 5.6] {
            let p = TwRig.box(0.8, 0.35, 1.8, team.withAlphaComponent(0.9))
            p.position = MXVector3(0, 43.6, z)
            root.addChildNode(p)
        }

        // rifle in both hands
        let holder = MXNode()
        holder.position = MXVector3(9, 33.5, -0.7)
        var variants: [MXNode] = []
        for (k, w) in TWeapons.all.enumerated() {
            let gm = TwGunLib.worldGun(w.id)
            gm.isHidden = k != 0
            holder.addChildNode(gm)
            variants.append(gm)
        }
        let fl = TwRig.box(6, 5, 5, TwRig.col(1, 0.85, 0.3), glow: true)
        fl.position = MXVector3(TwGunLib.muzzleX(TWeapons.all[0].id) + 1, 1, 0)
        fl.isHidden = true
        holder.addChildNode(fl)
        root.addChildNode(holder)

        let face = MXNode()
        face.isHidden = true
        root.addChildNode(face)
        let sol = TwSoldier(root: root, legL: hips[0], legR: hips[1], holder: holder, variants: variants, flash: fl, shirt: MXMaterial(),
                            face: face, faceMat: MXMaterial(), kev: MXNode(), helm: MXNode(), heavy: MXNode(), hat: MXNode())
        return (sol, HeroCloth(nodes))
    }
}

/// Wind and motion for the hero's cloth panels (used in the hideout and in matches).
final class HeroCloth {
    private let nodes: [String: MXNode]
    init(_ nodes: [String: MXNode]) { self.nodes = nodes }

    /// t: seconds, run: 0 standing ... 1 running, yawVel: how fast the body is turning (cloth lags behind)
    func update(t tt: Float, run: Float, yawVel: Float) {
        let wind: Float = 0.6 * sin(tt * 1.1) + 0.4 * sin(tt * 2.3 + 1.3)
        let lift: Float = 0.22 * run
        for k in 0..<3 {
            let kf = Float(k)
            let swing: Float = (0.07 + 0.05 * kf) * sin(tt * 1.5 - 0.8 * kf)
            let gust: Float = 0.05 * (kf + 1) * wind
            let drag: Float = -0.1 * yawVel * (kf + 1)
            nodes["coat_back_\(k)"]?.eulerAngles = MXVector3(swing + gust + lift * (kf + 1) * 0.5, 0, drag)
        }
        let sides: [(String, Float)] = [("L", -1), ("R", 1)]
        for (name, sgn) in sides {
            for k in 0..<2 {
                let kf = Float(k)
                let phase: Float = sgn > 0 ? 0.5 : 0
                let swing: Float = 0.08 * (kf + 1) * sin(tt * 1.7 + 0.6 * kf + phase)
                let gust: Float = 0.03 * wind
                let base: Float = k == 0 ? sgn * 0.12 : 0
                let billow: Float = sgn * (0.04 + 0.10 * run) * (kf + 1) * (0.5 + 0.5 * sin(tt * 1.3 + kf))
                let drag: Float = -0.08 * yawVel * sgn * (kf + 1)
                nodes["coat_\(name)_\(k)"]?.eulerAngles = MXVector3(swing + gust + lift * (kf + 1) * 0.4, 0, base + billow + drag)
            }
        }
        for k in 0..<2 {
            let kf = Float(k)
            let flapX: Float = -0.07 * (kf + 1) * (0.6 + 0.4 * sin(tt * 1.9 - 0.8 * kf)) - 0.03 * wind - 0.12 * run * (kf + 1)
            let flapZ: Float = 0.05 * (kf + 1) * sin(tt * 1.2 + kf)
            nodes["flap_\(k)"]?.eulerAngles = MXVector3(flapX, 0, flapZ)
            let veilX: Float = 0.07 * (kf + 1) * sin(tt * 1.4 - 0.9 * kf) + 0.05 * wind + 0.25 * run * (kf + 1) * 0.5
            let veilZ: Float = 0.04 * (kf + 1) * sin(tt * 1.1 + kf) - 0.1 * yawVel
            nodes["veil_\(k)"]?.eulerAngles = MXVector3(veilX, 0, veilZ)
        }
        if let b = nodes["body"] { b.scale = MXVector3(1, 1 + 0.004 * sin(tt * 1.7), 1) }
    }
}

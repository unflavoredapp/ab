import SwiftUI
import UIKit
import simd

/// The Special Task Force operator as a real skinned character.
/// `stf_rig.glb` is one skeleton (68 bones) with six skinned parts (body, head, vest, helmet, NVG, lenses). The MX engine deforms it
/// on the CPU every frame. `stfpose.json` holds, per gun, the solved arm / torso pose (a rotation and head position per bone, exported
/// from Blender's pose solver) and where that gun sits in the hands. Legs are driven live (walk cycle), so bots and previews share one model.
/// Textures are not baked in: `stf_body_<i>.jpg` (uniform), `stf_gear_<i>.jpg` (vest), `stf_helm_<i>.jpg` (helmet), `stf_head_<i>.jpg` (face)
/// are applied here, so face, uniform, vest, helmet and lenses change live. Returns nil whenever a piece is missing so callers fall back
/// to the code-built soldier.
enum TacOperator {
    private static var imgs: [String: UIImage?] = [:]

    private static func url(_ n: String, _ e: String) -> URL? {
        Bundle.main.url(forResource: n, withExtension: e) ?? Bundle.main.url(forResource: n, withExtension: e, subdirectory: "models")
    }

    struct GunPose {
        var al: Float
        var phi: Float
        var pos: SIMD3<Float>
        var bones: [String: MXBonePose]
    }

    static let poses: [String: GunPose] = {
        guard let u = url("stfpose", "json"), let d = try? Data(contentsOf: u),
              let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: [String: Any]] else { return [:] }
        var out: [String: GunPose] = [:]
        for (gid, v) in j {
            guard let al = v["al"] as? Double, let phi = v["phi"] as? Double, let p = v["pos"] as? [Double], p.count == 3,
                  let bs = v["bones"] as? [String: [Double]] else { continue }
            var bones: [String: MXBonePose] = [:]
            for (name, a) in bs where a.count >= 4 {
                let q = simd_quatf(ix: Float(a[0]), iy: Float(a[1]), iz: Float(a[2]), r: Float(a[3]))
                let pp: SIMD3<Float>? = a.count >= 7 ? SIMD3<Float>(Float(a[4]), Float(a[5]), Float(a[6])) : nil
                bones[name] = MXBonePose(q: q, p: pp)
            }
            out[gid] = GunPose(al: Float(al), phi: Float(phi), pos: SIMD3<Float>(Float(p[0]), Float(p[1]), Float(p[2])), bones: bones)
        }
        return out
    }()

    static var available: Bool { !poses.isEmpty && url("stf_rig", "glb") != nil }

    private static func image(_ name: String) -> UIImage? {
        if let c = imgs[name] { return c }
        var im: UIImage? = nil
        if let u = url(name, "jpg") { im = UIImage(contentsOfFile: u.path) }
        imgs[name] = im
        return im
    }

    fileprivate static func walk(_ n: MXNode, _ f: (MXNode) -> Void) {
        f(n)
        for c in n.childNodes { walk(c, f) }
    }

    private static func paint(_ n: MXNode, _ contents: Any?) {
        for m in n.geometry?.materials ?? [] { m.diffuse.contents = contents }
    }

    fileprivate static func rx(_ a: Float) -> simd_quatf { simd_quatf(angle: a, axis: SIMD3<Float>(1, 0, 0)) }

    /// one live operator: skinned body, current gun, pose layers
    final class Bot {
        /// attach this to the scene. Modelled facing -z, rotated here so it faces +x like every other character.
        let root = MXNode()
        let gunHolder = MXNode()
        let flash: MXNode
        let bodyMat: MXMaterial?
        private let rig: MXRig
        private let model: MXNode
        private var gunNodes: [String: MXNode] = [:]
        private(set) var gun = ""
        private var base: [String: MXBonePose] = [:]
        private var failed = Set<String>()

        fileprivate init(model: MXNode, rig: MXRig, bodyMat: MXMaterial?) {
            self.model = model
            self.rig = rig
            self.bodyMat = bodyMat
            let fm = MXMaterial()
            fm.diffuse.contents = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
            fm.emission.contents = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
            fm.lightingModel = .constant
            let fn = MXNode(geometry: MXBox(width: 22, height: 20, length: 22, chamferRadius: 0))
            fn.geometry?.firstMaterial = fm
            fn.castsShadow = false
            fn.isHidden = true
            flash = fn
            let wrap = MXNode()
            wrap.addChildNode(model)
            wrap.addChildNode(gunHolder)
            gunHolder.addChildNode(fn)
            let s: Float = 0.24                      // Blender centimetres -> game units
            wrap.scale = MXVector3(s, s, s)
            wrap.eulerAngles = MXVector3(0, -Float.pi / 2, 0)
            root.addChildNode(wrap)
        }

        /// put `id` in the hands (arms re-pose to its grips). `showcase` adds the gunsmith attachments and camo (lobby previews).
        /// False when that gun has no solved pose or model.
        @discardableResult
        func setGun(_ id: String, showcase: Bool = false) -> Bool {
            guard let p = TacOperator.poses[id], !failed.contains(id) else { return false }
            if id == gun { return true }
            for (_, n) in gunNodes { n.isHidden = true }
            if let c = gunNodes[id] { c.isHidden = false }
            else {
                TwGunLib.load()
                if showcase { TwGunLib.setIdx = 2 }
                guard let gg = TwGunLib.glbGun(id, arms: false) else { TwGunLib.setIdx = 0; failed.insert(id); return false }
                let h = MXNode()
                h.addChildNode(gg.node)
                if showcase {
                    let att = TAttBuild.build(id, into: h, magHolder: nil)
                    att.apply(id)
                    TAtt.applyCamo(id, set: 2)
                    TwGunLib.setIdx = 0
                }
                TacOperator.walk(h) { $0.castsShadow = false }
                gunHolder.addChildNode(h)
                gunNodes[id] = h
            }
            gunHolder.eulerAngles = MXVector3(p.al, p.phi, 0)
            gunHolder.position = MXVector3(p.pos.x, p.pos.y, p.pos.z)
            if let mz = TwGunLib.gmeta[id]?["mz"] as? [Double], mz.count == 3 {
                // the flash node lives in the holder's frame: muzzle point in gun-local space
                flash.position = MXVector3(Float(mz[0]), Float(mz[1]), Float(mz[2]) - 8)
            }
            base = p.bones
            gun = id
            pose(walk: 0, mv: 0)
            return true
        }

        /// walk cycle on the legs over the gun's aim pose. `walk` = phase in radians, `mv` = 0 standing ... 1 full stride.
        func pose(walk ph: Float, mv: Float) {
            var d = base
            let a = 0.62 * mv
            for (s, off) in [("l", Float(0)), ("r", Float.pi)] {
                let p = ph + off
                let th = a * sin(p)
                let lift = 0.95 * mv * max(0, cos(p))
                d["thigh_stretch." + s] = MXBonePose(q: TacOperator.rx(th))
                d["leg_stretch." + s] = MXBonePose(q: TacOperator.rx(th - lift))
                d["foot." + s] = MXBonePose(q: TacOperator.rx(-0.12 * lift))
            }
            rig.apply(d)
        }
    }

    static func bot(style: TwStyle) -> Bot? {
        guard let k = TacGear.resolve(style.look), available, let u = url("stf_rig", "glb"), let model = MXGLTF.load(u) else { return nil }
        func tex(_ name: String, _ fallback: UIColor) -> Any {
            if let i = image(name) { return i }
            return fallback
        }
        let bodyTex = tex("stf_body_\(k.sBody)", TacGear.c(k.uni))
        let gearTex = tex("stf_gear_\(k.sGear)", TacGear.c(k.rigCol))
        let helmTex = tex("stf_helm_\(k.sHelmCol)", TacGear.c(k.rigCol))
        let faceTex = tex("stf_head_\(k.sFace)", style.skin)
        let lens = TacGear.c(TacGear.stfLens[max(0, min(TacGear.stfLens.count - 1, k.sLens))])
        var bodyMat: MXMaterial? = nil
        var joints: [MXNode] = []
        walk(model) { n in
            if let sk = n.geometry?.skin { joints += sk.joints }
            guard let nm = n.name, nm.hasSuffix("_STF") else { return }
            n.castsShadow = false
            switch String(nm.dropLast(4)) {
            case "body": paint(n, bodyTex); bodyMat = n.geometry?.materials.first
            case "gear": paint(n, gearTex); n.isHidden = !k.sVest
            case "head": paint(n, faceTex)
            case "helm": paint(n, helmTex); n.isHidden = k.sHead == 0
            case "nvg": paint(n, helmTex); n.isHidden = k.sHead < 2
            case "glass":
                n.isHidden = k.sLens == 0
                for m in n.geometry?.materials ?? [] { m.diffuse.contents = lens; m.transparency = 0.84 }
            default: break
            }
        }
        guard let rig = MXRig(root: model, joints: joints) else { return nil }
        return Bot(model: model, rig: rig, bodyMat: bodyMat)
    }

    /// a posed operator for lobby, customize and loadout previews
    static func node(style: TwStyle, gun: String) -> MXNode? {
        guard let b = bot(style: style), b.setGun(gun, showcase: true) else { return nil }
        return b.root
    }
}

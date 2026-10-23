import SwiftUI

/// Procedural 3D lobby for HoodBlok, rendered live by the MX engine (no texture files needed).
/// Rooftop at night: skyline with lit windows, a neon HOOD BLOK sign, string lights, a water tank, the hero with
/// the equipped weapon and your crew standing beside him in their crew colour, and a camera that drifts slowly.
/// `preview` is the small version used on the ready-up screen: just the hero, turning slowly, on a transparent background.
struct HoodLobbyStage: UIViewRepresentable {
    var hero = true
    var preview = false
    var weapon = 0
    var crew = true
    var version = 0

    static let crewBlue = UIColor(red: 0.25, green: 0.65, blue: 1, alpha: 1)
    static let heroOrange = UIColor(red: 1, green: 0.55, blue: 0.16, alpha: 1)

    final class Coord {
        var scene: MXScene? = nil
        var heroSpin: MXNode? = nil
        var crewSpin: [MXNode] = []
        var cam: MXNode? = nil
        var builtKey = ""
        var preview = false
    }
    func makeCoordinator() -> Coord { Coord() }

    // MARK: helpers

    private static func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    private static func mat(_ c: UIColor, glow: Bool = false, spec: CGFloat = 0.05) -> MXMaterial {
        let m = MXMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant } else { m.lightingModel = .blinn; m.specular.contents = UIColor(white: spec, alpha: 1) }
        return m
    }

    private static func imgMat(_ img: UIImage, tileX: CGFloat = 1, tileY: CGFloat = 1) -> MXMaterial {
        let m = MXMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = img
        m.emission.contents = img
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = MXMatrix4MakeScale(Float(tileX), Float(tileY), 1)
        return m
    }

    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ x: Float, _ y: Float, _ z: Float, _ ms: [MXMaterial]) -> MXNode {
        let g = MXBox(width: w, height: h, length: l, chamferRadius: 0)
        g.materials = ms.count == 6 ? ms : Array(repeating: ms[0], count: 6)
        let n = MXNode(geometry: g)
        n.position = MXVector3(x, y, z)
        return n
    }

    private static func windowTexture(warm: Bool, seed: Int) -> UIImage {
        let size = CGSize(width: 96, height: 192)
        let r = UIGraphicsImageRenderer(size: size)
        var s = UInt64(seed) &* 6364136223846793005 &+ 1442695040888963407
        func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) & 0xFFFF) / 65535 }
        return r.image { ctx in
            UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for row in 0..<16 { for col in 0..<6 {
                let on = rnd() < 0.42
                let c: UIColor = on ? (warm ? UIColor(red: 1, green: 0.78 + 0.15 * rnd(), blue: 0.4, alpha: 1) : UIColor(red: 0.55, green: 0.8, blue: 1, alpha: 1)) : UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1)
                c.setFill()
                ctx.fill(CGRect(x: CGFloat(col) * 16 + 3, y: CGFloat(row) * 12 + 3, width: 10, height: 7))
            } }
        }
    }

    private static func signTexture() -> UIImage {
        let size = CGSize(width: 512, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let orange = UIColor(red: 1, green: 0.55, blue: 0.16, alpha: 1)
            orange.setStroke()
            let b = UIBezierPath(roundedRect: CGRect(x: 6, y: 6, width: 500, height: 116), cornerRadius: 10)
            b.lineWidth = 4; b.stroke()
            let para = NSMutableParagraphStyle(); para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 78, weight: .black), .foregroundColor: orange, .paragraphStyle: para, .kern: 6]
            ("HOOD BLOK" as NSString).draw(in: CGRect(x: 0, y: 17, width: 512, height: 100), withAttributes: attrs)
        }
    }

    /// one standing character in the game's soldier frame, scaled to metres
    static func actor(key: String, team: UIColor, arm: Int, ring: UIColor, useHero: Bool) -> (spin: MXNode, rt: MXNode) {
        let spin = MXNode()
        spin.scale = MXVector3(0.035, 0.035, 0.035)
        let rt = MXNode()
        if useHero, let h = HeroBody.make(team: team) {
            rt.addChildNode(h.sol.root)
        } else {
            rt.addChildNode(TwRig.soldier(team: team, style: TacAvatar.style(key), rank: 0).root)
        }
        let ringM = MXMaterial(); ringM.lightingModel = .constant; ringM.diffuse.contents = ring; ringM.emission.contents = ring
        let rg = MXNode(geometry: MXCylinder(radius: 24, height: 0.6))
        rg.geometry?.firstMaterial = ringM
        rg.position = MXVector3(0, 0.4, 0); rg.castsShadow = false
        rt.addChildNode(rg)
        if arm == 1 {
            let bm = MXMaterial(); bm.diffuse.contents = UIColor(red: 0.55, green: 0.36, blue: 0.18, alpha: 1)
            let bat = MXNode(geometry: MXCylinder(radius: 1.3, height: 25))
            bat.geometry?.firstMaterial = bm
            bat.position = MXVector3(9, 16, 6); bat.eulerAngles = MXVector3(0, 0, -0.6)
            rt.addChildNode(bat)
        } else if arm == 2 {
            let pm = MXMaterial(); pm.diffuse.contents = UIColor(white: 0.12, alpha: 1)
            let pis = MXNode(geometry: MXBox(width: 9, height: 4.5, length: 2.4, chamferRadius: 0.4))
            pis.geometry?.firstMaterial = pm
            pis.position = MXVector3(12, 17, 6)
            rt.addChildNode(pis)
        }
        spin.addChildNode(rt)
        return (spin, rt)
    }

    // MARK: rooftop

    private static func buildRoof(_ root: MXNode) {
        let concrete = mat(C(0.11, 0.115, 0.13), spec: 0.12)
        let dark = mat(C(0.05, 0.055, 0.07))
        root.addChildNode(box(15, 0.2, 11, 0, -0.1, -0.5, [dark, dark, dark, dark, concrete, dark]))
        // painted crew circle on the floor
        let paint = MXMaterial(); paint.lightingModel = .constant
        paint.diffuse.contents = UIColor(red: 1, green: 0.55, blue: 0.16, alpha: 0.5)
        paint.emission.contents = UIColor(red: 0.5, green: 0.27, blue: 0.08, alpha: 1)
        let circ = MXNode(geometry: MXCylinder(radius: 1.6, height: 0.012))
        circ.geometry?.firstMaterial = paint
        circ.position = MXVector3(0, 0.006, 0); circ.castsShadow = false
        root.addChildNode(circ)
        let hole = MXNode(geometry: MXCylinder(radius: 1.45, height: 0.014))
        hole.geometry?.firstMaterial = concrete
        hole.position = MXVector3(0, 0.008, 0); hole.castsShadow = false
        root.addChildNode(hole)
        // parapets
        let par = mat(C(0.13, 0.135, 0.15))
        root.addChildNode(box(15, 1.1, 0.3, 0, 0.55, -5.9, [par]))
        root.addChildNode(box(0.3, 1.1, 11, -7.4, 0.55, -0.5, [par]))
        root.addChildNode(box(0.3, 1.1, 11, 7.4, 0.55, -0.5, [par]))
        // water tank on legs, ac units, crates
        let metal = mat(C(0.16, 0.17, 0.2), spec: 0.3)
        let tank = MXNode(geometry: MXCylinder(radius: 0.9, height: 1.6))
        tank.geometry?.firstMaterial = metal
        tank.position = MXVector3(-5.2, 2.4, -4.4)
        root.addChildNode(tank)
        for (lx, lz) in [(-5.8, -5.0), (-4.6, -5.0), (-5.8, -3.8), (-4.6, -3.8)] as [(Float, Float)] {
            root.addChildNode(box(0.1, 1.6, 0.1, lx, 0.8, lz, [metal]))
        }
        root.addChildNode(box(1.3, 0.8, 0.9, 5.3, 0.4, -4.8, [metal]))
        root.addChildNode(box(0.8, 0.6, 0.8, 4.2, 0.3, -4.9, [mat(C(0.2, 0.15, 0.1))]))
        root.addChildNode(box(0.7, 0.5, 0.7, 6.2, 0.25, -3.6, [mat(C(0.2, 0.15, 0.1))]))
        // neon sign
        let sign = MXNode(geometry: MXPlane(width: 4.4, height: 1.1))
        sign.geometry?.materials = [imgMat(signTexture())]
        sign.position = MXVector3(0.2, 2.5, -5.7)
        sign.castsShadow = false
        root.addChildNode(sign)
        // string lights
        let bulb = mat(C(1, 0.82, 0.5), glow: true)
        for i in 0..<15 {
            let f = Float(i) / 14
            let x = -6.8 + 13.6 * f
            let y = 3.0 - 0.45 * sin(Float.pi * f)
            let b = box(0.12, 0.12, 0.12, x, y, -5.2, [bulb])
            b.castsShadow = false
            root.addChildNode(b)
        }
        // skyline
        var s: UInt64 = 987654321
        func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) & 0xFFFF) / 65535 }
        let wins = [imgMat(windowTexture(warm: true, seed: 1)), imgMat(windowTexture(warm: false, seed: 2)), imgMat(windowTexture(warm: true, seed: 3))]
        let roofM = mat(C(0.04, 0.045, 0.06))
        for i in 0..<30 {
            let w = 3 + rnd() * 5, h = 9 + rnd() * 30, d = 4 + rnd() * 4
            let x = Float(-34 + 68 * rnd()), z = Float(-14 - 38 * rnd())
            let wm = wins[i % 3]
            let tx = max(1, Int(w / 1.6)), ty = max(1, Int(h / 2.4))
            let m = imgMat(i % 2 == 0 ? windowTexture(warm: i % 3 != 1, seed: i + 10) : windowTexture(warm: false, seed: i + 40), tileX: CGFloat(tx) / 6, tileY: CGFloat(ty) / 16)
            _ = wm
            root.addChildNode(box(w, h, d, x, Float(h / 2) - 1, z, [m, m, roofM, m, roofM, roofM]))
        }
        // moon
        let moon = MXNode(geometry: MXPlane(width: 5, height: 5))
        moon.geometry?.firstMaterial = mat(C(0.85, 0.9, 1), glow: true)
        moon.position = MXVector3(16, 26, -58)
        moon.castsShadow = false
        root.addChildNode(moon)
    }

    // MARK: build

    private func buildActors(_ co: Coord, _ root: MXNode) {
        co.heroSpin?.removeFromParentNode()
        co.crewSpin.forEach { $0.removeFromParentNode() }
        co.crewSpin = []
        let h = Self.actor(key: TacAvatar.myKey, team: Self.heroOrange, arm: weapon, ring: Self.heroOrange, useHero: !preview)
        h.spin.position = MXVector3(0, 0, 0.2)
        h.spin.isHidden = !hero
        root.addChildNode(h.spin)
        co.heroSpin = h.spin
        if !preview && crew {
            for (i, nm) in ["rico", "dee"].enumerated() {
                let a = Self.actor(key: nm, team: Self.crewBlue, arm: i == 0 ? 1 : 2, ring: Self.crewBlue, useHero: false)
                a.spin.position = MXVector3(i == 0 ? -1.55 : 1.55, 0, -0.55)
                root.addChildNode(a.spin)
                co.crewSpin.append(a.spin)
            }
        }
    }

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = preview ? .clear : .black
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc
        let co = context.coordinator
        co.scene = sc
        co.preview = preview
        let root = sc.rootNode
        if !preview {
            sc.background.contents = Self.C(0.02, 0.03, 0.06)
            sc.fogColor = Self.C(0.03, 0.04, 0.09)
            sc.fogStartDistance = 14
            sc.fogEndDistance = 70
            Self.buildRoof(root)
        }

        let camN = MXNode()
        let cam = MXCamera()
        cam.fieldOfView = preview ? 30 : 34
        cam.zNear = 0.1
        cam.zFar = 120
        if !preview {
            cam.wantsHDR = true
            cam.bloomIntensity = 0.55
            cam.bloomThreshold = 0.8
            cam.bloomBlurRadius = 7
            cam.vignettingIntensity = 0.45
            cam.vignettingPower = 1.3
            cam.exposure = 1.25
        }
        camN.camera = cam
        camN.position = preview ? MXVector3(0, 1.0, 3.4) : MXVector3(0, 1.25, 5.2)
        root.addChildNode(camN)
        v.pointOfView = camN
        camN.look(at: preview ? MXVector3(0, 0.88, 0) : MXVector3(0, 1.1, 0))
        co.cam = camN

        func light(_ type: MXLightType, _ col: UIColor, _ i: CGFloat, _ p: MXVector3, start: CGFloat = 0, end: CGFloat = 0) -> MXNode {
            let n = MXNode(); let l = MXLight()
            l.type = type; l.color = col; l.intensity = i
            l.attenuationStartDistance = start; l.attenuationEndDistance = end
            n.light = l; n.position = p
            root.addChildNode(n)
            return n
        }
        if preview {
            _ = light(.ambient, Self.C(0.8, 0.82, 0.9), 650, MXVector3(0, 0, 0))
            _ = light(.directional, Self.C(1, 0.95, 0.9), 900, MXVector3(-2, 4, 4)).look(at: MXVector3(0, 0.8, 0))
        } else {
            _ = light(.ambient, Self.C(0.4, 0.46, 0.7), 420, MXVector3(0, 0, 0))
            let moon = light(.directional, Self.C(0.62, 0.72, 1), 560, MXVector3(-3, 6, 4))
            moon.light?.castsShadow = true
            moon.light?.shadowMode = .deferred
            moon.light?.shadowRadius = 4
            moon.light?.shadowSampleCount = 8
            moon.light?.shadowColor = UIColor(white: 0, alpha: 0.6)
            moon.light?.maximumShadowDistance = 14
            moon.look(at: MXVector3(0, 0, -1))
            _ = light(.omni, Self.C(1, 0.8, 0.5), 950, MXVector3(-3, 2.8, -4.6), start: 0.5, end: 8)
            _ = light(.omni, Self.C(1, 0.8, 0.5), 950, MXVector3(3, 2.8, -4.6), start: 0.5, end: 8)
            _ = light(.omni, Self.C(1, 0.5, 0.15), 800, MXVector3(0.2, 2.4, -4.8), start: 0.5, end: 7)
            _ = light(.omni, Self.C(0.7, 0.8, 1), 320, MXVector3(0, 2.2, 5), start: 1, end: 11)
        }
        buildActors(co, root)
        co.builtKey = "\(weapon)-\(crew)-\(version)"

        v.preRender = { [weak co] t in
            guard let co = co else { return }
            let tt = Float(t)
            if let h = co.heroSpin {
                let yaw: Float = co.preview ? tt * 0.55 : 0.28 * sin(tt * 0.4)
                h.eulerAngles = MXVector3(0, yaw - Float.pi / 2, 0)
                let br = 0.035 * (1 + 0.008 * sin(tt * 1.7))
                h.scale = MXVector3(0.035, br, 0.035)
            }
            for (i, c) in co.crewSpin.enumerated() {
                let side: Float = i == 0 ? 1 : -1
                c.eulerAngles = MXVector3(0, 0.5 * side + 0.05 * sin(tt * 0.5 + Float(i)) - Float.pi / 2, 0)
                c.scale = MXVector3(0.035, 0.035 * (1 + 0.008 * sin(tt * 1.5 + Float(i) * 2)), 0.035)
            }
            if !co.preview, let cam = co.cam {
                // slow drift through the rooftop: an arc left and right, a little rise and fall
                cam.position = MXVector3(1.3 * sin(tt * 0.12), 1.25 + 0.12 * sin(tt * 0.19), 5.2 + 0.5 * sin(tt * 0.09))
                cam.look(at: MXVector3(0.15 * sin(tt * 0.12), 1.1, 0))
            }
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        let co = context.coordinator
        co.heroSpin?.isHidden = !hero
        let key = "\(weapon)-\(crew)-\(version)"
        if key != co.builtKey, let sc = co.scene {
            co.builtKey = key
            buildActors(co, sc.rootNode)
        }
    }
}

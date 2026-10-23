import SwiftUI

/// The hideout as a real 3D room rendered live by the MX (Metal) engine, with the 3D hero standing in it.
/// Layout (metres, the hero at the origin facing the camera on +Z):
///  - back wall at z = -2.8 with a tall steel-framed window on the left onto a rainy night city,
///  - a desk with books and a brass lamp in front of the window, an ammo crate beside it,
///  - pipes, a valve wheel, gauges, posters, a cork evidence board and a rifle rack on the right,
///  - a steel chest in the right foreground, plank floor, ornate rug, beamed ceiling.
/// Textures come from blender-scripts/hideout_textures.py (Resources/hideout_*.jpg).
struct HideoutStage: UIViewRepresentable {
    var hero = true

    static var available: Bool { Bundle.main.path(forResource: "hideout_wall", ofType: "jpg") != nil }

    final class Coord {
        var heroRoot: MXNode? = nil
        var cloth: HeroCloth? = nil
    }

    func makeCoordinator() -> Coord { Coord() }

    // MARK: materials

    private static func tex(_ name: String, _ ext: String = "jpg") -> UIImage? {
        Bundle.main.path(forResource: name, ofType: ext).flatMap { UIImage(contentsOfFile: $0) }
    }

    private static func mat(_ img: UIImage?, _ color: UIColor = .gray, sx: CGFloat = 1, sy: CGFloat = 1,
                            bump: CGFloat = 0.45, spec: CGFloat = 0.05, shine: CGFloat = 0.2) -> MXMaterial {
        let useBump = false   // bump from the colour texture made every surface sparkle on device
        let m = MXMaterial()
        m.lightingModel = .blinn
        if let i = img {
            m.diffuse.contents = i
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = MXMatrix4MakeScale(Float(sx), Float(sy), 1)
            if useBump && bump > 0 {
                m.normal.contents = i
                m.normal.intensity = bump
                m.normal.wrapS = .repeat; m.normal.wrapT = .repeat
                m.normal.contentsTransform = MXMatrix4MakeScale(Float(sx), Float(sy), 1)
            }
        } else {
            m.diffuse.contents = color
        }
        m.specular.contents = UIColor(white: spec, alpha: 1)
        m.shininess = shine
        return m
    }

    private static func glowMat(_ img: UIImage?, _ color: UIColor) -> MXMaterial {
        let m = MXMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = img ?? color
        m.emission.contents = img ?? color
        return m
    }

    private static func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    // MARK: building blocks

    /// box centred at (x, y, z); `mats` in face order front(+z) right(+x) back(-z) left(-x) top(+y) bottom(-y)
    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ x: Float, _ y: Float, _ z: Float,
                            _ mats: [MXMaterial], chamfer: CGFloat = 0) -> MXNode {
        let g = MXBox(width: w, height: h, length: l, chamferRadius: chamfer)
        g.materials = mats.count == 6 ? mats : Array(repeating: mats[0], count: 6)
        let n = MXNode(geometry: g)
        n.position = MXVector3(x, y, z)
        return n
    }

    private static func cyl(_ r: CGFloat, _ h: CGFloat, _ m: MXMaterial) -> MXNode {
        let g = MXCylinder(radius: r, height: h)
        g.materials = [m]
        return MXNode(geometry: g)
    }

    private static func plane(_ w: CGFloat, _ h: CGFloat, _ m: MXMaterial, _ x: Float, _ y: Float, _ z: Float) -> MXNode {
        let g = MXPlane(width: w, height: h)
        g.materials = [m]
        let n = MXNode(geometry: g)
        n.position = MXVector3(x, y, z)
        return n
    }

    // MARK: room

    private static func buildRoom(_ root: MXNode) {
        let wallT = tex("hideout_wall"), sideT = tex("hideout_side"), floorT = tex("hideout_floor")
        let woodT = tex("hideout_wood"), steelT = tex("hideout_steel"), ceilT = tex("hideout_ceiling")
        let wallZ: Float = -2.8
        let side = mat(sideT, sx: 1, sy: 1)
        let dark = mat(nil, C(0.08, 0.075, 0.07))

        // floor and rug
        root.addChildNode(box(12, 0.1, 9, 0, -0.05, 0.5, [dark, dark, dark, dark, mat(floorT, sx: 3, sy: 2.2, bump: 0.5, spec: 0.2, shine: 0.4), dark]))
        let rug = mat(tex("hideout_rug"), bump: 0.25, spec: 0.03)
        let rugN = box(3.4, 0.014, 2.2, 0.0, 0.007, 0.45, [rug, rug, rug, rug, rug, rug])
        rugN.castsShadow = false
        root.addChildNode(rugN)

        // back wall with the window hole on the left (window x -4.5 ... -0.95, y 0.8 ... 3.5)
        let wx0: Float = -4.5, wx1: Float = -0.95, wy0: Float = 0.8, wy1: Float = 3.3
        let wallMat = mat(wallT, bump: 0.5)
        root.addChildNode(box(CGFloat(5.6 - wx1), 4.2, 0.3, (wx1 + 5.6) / 2, 2.1, wallZ - 0.15, [wallMat, side, side, side, dark, dark]))
        let sideMat = mat(sideT, sx: 0.35, sy: 1)
        root.addChildNode(box(CGFloat(wx0 + 5.6), 4.2, 0.3, (-5.6 + wx0) / 2, 2.1, wallZ - 0.15, [sideMat, side, side, side, dark, dark]))
        let lowMat = mat(woodT, sx: 3, sy: 0.6, bump: 0.4)
        root.addChildNode(box(CGFloat(wx1 - wx0), CGFloat(wy0), 0.3, (wx0 + wx1) / 2, wy0 / 2, wallZ - 0.15, [lowMat, side, side, side, dark, dark]))
        let topMat = mat(sideT, sx: 0.8, sy: 0.2)
        root.addChildNode(box(CGFloat(wx1 - wx0), CGFloat(4.2 - wy1), 0.3, (wx0 + wx1) / 2, (wy1 + 4.2) / 2, wallZ - 0.15, [topMat, side, side, side, dark, dark]))
        // side walls
        root.addChildNode(box(0.3, 4.2, 9, -5.6, 2.1, 1.7, [side, mat(sideT, sx: 2, sy: 1), side, side, dark, dark]))
        root.addChildNode(box(0.3, 4.2, 9, 5.6, 2.1, 1.7, [side, side, side, mat(sideT, sx: 2, sy: 1), dark, dark]))
        // ceiling and beams
        let ceil = mat(ceilT, sx: 2, sy: 2, bump: 0.3)
        root.addChildNode(box(12, 0.2, 9, 0, 4.25, 0.5, [dark, dark, dark, dark, dark, ceil]))
        let beam = mat(woodT, sx: 0.3, sy: 4, bump: 0.5)
        for bx in [-3.6, -1.2, 1.2, 3.6] as [Float] {
            root.addChildNode(box(0.28, 0.32, 9, bx, 3.98, 0.5, [beam, beam, beam, beam, beam, beam]))
        }

        // the window: city behind the glass, a steel frame with a transom and mullions, a sill
        let city = glowMat(tex("hideout_city"), C(0.1, 0.12, 0.18))
        root.addChildNode(plane(CGFloat(wx1 - wx0) + 0.4, CGFloat(wy1 - wy0) + 0.4, city, (wx0 + wx1) / 2, (wy0 + wy1) / 2, wallZ - 0.9))
        let steelM = mat(nil, C(0.13, 0.125, 0.12), spec: 0.4, shine: 0.5)
        let fw: CGFloat = 0.09
        root.addChildNode(box(CGFloat(wx1 - wx0), fw, 0.12, (wx0 + wx1) / 2, wy1 - Float(fw) / 2, wallZ + 0.02, [steelM]))
        root.addChildNode(box(CGFloat(wx1 - wx0), fw, 0.12, (wx0 + wx1) / 2, wy0 + Float(fw) / 2, wallZ + 0.02, [steelM]))
        root.addChildNode(box(CGFloat(wx1 - wx0), 0.07, 0.1, (wx0 + wx1) / 2, wy0 + (wy1 - wy0) * 0.72, wallZ + 0.02, [steelM]))
        root.addChildNode(box(CGFloat(wx1 - wx0), 0.05, 0.08, (wx0 + wx1) / 2, wy0 + (wy1 - wy0) * 0.38, wallZ + 0.02, [steelM]))
        for i in 0...7 {
            let x = wx0 + (wx1 - wx0) * Float(i) / 7
            root.addChildNode(box(i == 0 || i == 7 ? fw : 0.055, CGFloat(wy1 - wy0), 0.1, x, (wy0 + wy1) / 2, wallZ + 0.02, [steelM]))
        }
        // fan-light spokes in the top panes
        for k in 0..<2 {
            let cx = wx0 + (wx1 - wx0) * (0.25 + 0.5 * Float(k))
            let cy = wy1 - 0.05
            for s in 1..<6 {
                let a = Float.pi * Float(s) / 6
                let spoke = box(0.03, 0.7, 0.05, cx + cos(a) * 0.35, cy - sin(a) * 0.35, wallZ + 0.03, [steelM])
                spoke.eulerAngles = MXVector3(0, 0, Float.pi / 2 - a)
                root.addChildNode(spoke)
            }
        }
        root.addChildNode(box(CGFloat(wx1 - wx0) + 0.3, 0.06, 0.34, (wx0 + wx1) / 2, wy0 - 0.03, wallZ + 0.12, [mat(woodT, sx: 3, sy: 0.3)]))

        // pipes: a riser right of the window, a header along the top, a riser at the right corner
        let brass = mat(nil, C(0.42, 0.33, 0.22), spec: 0.55, shine: 0.6)
        let pipeDark = mat(nil, C(0.3, 0.24, 0.17), spec: 0.4, shine: 0.5)
        func vpipe(_ x: Float, _ z: Float, _ y0: Float, _ y1: Float, _ r: CGFloat) {
            let p = cyl(r, CGFloat(y1 - y0), pipeDark)
            p.position = MXVector3(x, (y0 + y1) / 2, z)
            root.addChildNode(p)
            var y = y0 + 0.5
            while y < y1 - 0.2 {
                let c = cyl(r * 1.35, 0.07, brass); c.position = MXVector3(x, y, z); root.addChildNode(c)
                y += 1.1
            }
        }
        func hpipe(_ y: Float, _ z: Float, _ x0: Float, _ x1: Float, _ r: CGFloat) {
            let p = cyl(r, CGFloat(x1 - x0), pipeDark)
            p.eulerAngles = MXVector3(0, 0, Float.pi / 2)
            p.position = MXVector3((x0 + x1) / 2, y, z)
            root.addChildNode(p)
        }
        vpipe(-0.72, wallZ + 0.12, 0, 4.1, 0.075)
        hpipe(3.62, wallZ + 0.1, -0.72, 5.5, 0.055)
        vpipe(5.25, wallZ + 0.12, 0, 3.62, 0.065)
        vpipe(0.75, wallZ + 0.08, 1.4, 3.62, 0.04)
        hpipe(1.4, wallZ + 0.08, 0.75, 1.05, 0.04)
        // valve wheel
        let red = mat(nil, C(0.45, 0.07, 0.05), spec: 0.4, shine: 0.5)
        let wheel = MXNode(geometry: MXTorus(ringRadius: 0.15, pipeRadius: 0.018))
        wheel.geometry?.materials = [red]
        wheel.eulerAngles = MXVector3(Float.pi / 2, 0, 0)
        wheel.position = MXVector3(-0.72, 1.7, wallZ + 0.3)
        root.addChildNode(wheel)
        for k in 0..<3 {
            let sp = box(0.3, 0.02, 0.02, -0.72, 1.7, wallZ + 0.3, [red])
            sp.eulerAngles = MXVector3(0, 0, Float(k) * Float.pi / 3)
            root.addChildNode(sp)
        }
        // gauges: brass rim, cream face, red needle
        let face = mat(nil, C(0.86, 0.83, 0.74), spec: 0.5, shine: 0.7)
        for (gx, gy, s) in [(-0.45, 3.1, 0.22), (5.05, 2.4, 0.3), (5.05, 1.95, 0.3)] as [(Float, Float, CGFloat)] {
            let rim = MXNode(geometry: MXTorus(ringRadius: s * 0.47, pipeRadius: 0.018))
            rim.geometry?.materials = [brass]
            rim.eulerAngles = MXVector3(Float.pi / 2, 0, 0)
            rim.position = MXVector3(gx, gy, wallZ + 0.04)
            root.addChildNode(rim)
            let disc = cyl(s * 0.47, 0.02, face)
            disc.eulerAngles = MXVector3(Float.pi / 2, 0, 0)
            disc.position = MXVector3(gx, gy, wallZ + 0.03)
            root.addChildNode(disc)
            let needle = box(0.012, s * 0.38, 0.006, gx, gy, wallZ + 0.045, [red])
            needle.eulerAngles = MXVector3(0, 0, 0.7)
            root.addChildNode(needle)
        }
        // posters
        let pt = mat(tex("hideout_poster_target"), bump: 0.2, spec: 0.05)
        let pw = mat(tex("hideout_poster_wanted"), bump: 0.2, spec: 0.05)
        root.addChildNode(plane(0.5, 0.72, pt, -0.25, 2.25, wallZ + 0.012))
        root.addChildNode(plane(0.55, 0.8, pw, 0.35, 2.05, wallZ + 0.012))
        root.addChildNode(plane(0.4, 0.58, pw, -0.3, 1.45, wallZ + 0.012))

        // evidence board in a wooden frame
        let frameM = mat(woodT, sx: 2, sy: 0.4, bump: 0.5)
        root.addChildNode(box(2.75, 1.75, 0.07, 2.55, 2.3, wallZ + 0.035, [frameM]))
        root.addChildNode(plane(2.55, 1.55, mat(tex("hideout_board"), bump: 0.35, spec: 0.04), 2.55, 2.3, wallZ + 0.075))

        // wall lamps (warm), the lights themselves are added in makeUIView
        let bulb = glowMat(nil, C(1, 0.86, 0.6))
        for lx in [1.0, 4.2] as [Float] {
            root.addChildNode(box(0.05, 0.25, 0.12, lx, 3.35, wallZ + 0.06, [pipeDark]))
            let shade = MXNode(geometry: MXCone(topRadius: 0.05, bottomRadius: 0.12, height: 0.14))
            shade.geometry?.materials = [brass]
            shade.position = MXVector3(lx, 3.22, wallZ + 0.16)
            root.addChildNode(shade)
            let b = MXNode(geometry: MXSphere(radius: 0.04)); b.geometry?.materials = [bulb]
            b.position = MXVector3(lx, 3.16, wallZ + 0.16); b.castsShadow = false
            root.addChildNode(b)
        }

        // desk in front of the window: top, legs, books, papers, lamp
        let deskTop = mat(woodT, sx: 3, sy: 1, bump: 0.5, spec: 0.25, shine: 0.45)
        let deskX: Float = -3.25, deskZ: Float = -2.15
        root.addChildNode(box(2.3, 0.07, 0.85, deskX, 0.8, deskZ, [deskTop]))
        root.addChildNode(box(2.2, 0.16, 0.06, deskX, 0.68, deskZ + 0.38, [mat(woodT, sx: 3, sy: 0.3)]))
        for (lx, lz) in [(-1.08, -0.36), (1.08, -0.36), (-1.08, 0.36), (1.08, 0.36)] as [(Float, Float)] {
            root.addChildNode(box(0.07, 0.77, 0.07, deskX + lx, 0.385, deskZ + lz, [mat(woodT, sx: 0.2, sy: 1)]))
        }
        let bookCols: [UIColor] = [C(0.42, 0.14, 0.11), C(0.26, 0.22, 0.16), C(0.16, 0.22, 0.19), C(0.47, 0.36, 0.22), C(0.3, 0.1, 0.1), C(0.15, 0.15, 0.22)]
        var bxp: Float = deskX - 1.05
        for i in 0..<11 {
            let bw = Float(0.05 + Double((i * 7) % 4) * 0.012), bh = Float(0.22 + Double((i * 5) % 5) * 0.025)
            let bm = mat(nil, bookCols[i % bookCols.count], spec: 0.1)
            root.addChildNode(box(CGFloat(bw), CGFloat(bh), 0.17, bxp + bw / 2, 0.835 + bh / 2, deskZ - 0.2, [bm]))
            bxp += bw + 0.006
        }
        for k in 0..<4 {
            let bm = mat(nil, bookCols[(k + 2) % bookCols.count], spec: 0.1)
            let b = box(0.3 - CGFloat(k) * 0.02, 0.05, 0.22, deskX - 0.15, 0.86 + Float(k) * 0.05, deskZ + 0.05, [bm])
            b.eulerAngles = MXVector3(0, Float(k) * 0.2 - 0.3, 0)
            root.addChildNode(b)
        }
        let paper = mat(nil, C(0.86, 0.83, 0.75), spec: 0.02)
        let pp = box(0.42, 0.006, 0.3, deskX + 0.35, 0.838, deskZ + 0.12, [paper]); pp.eulerAngles = MXVector3(0, 0.25, 0); root.addChildNode(pp)
        // brass lamp with a green shade
        let lampX = deskX + 0.85, lampZ = deskZ - 0.1
        let lb = cyl(0.11, 0.03, brass); lb.position = MXVector3(lampX, 0.85, lampZ); root.addChildNode(lb)
        let lp = cyl(0.012, 0.45, brass); lp.position = MXVector3(lampX, 1.07, lampZ); root.addChildNode(lp)
        let green = mat(nil, C(0.1, 0.32, 0.18), spec: 0.6, shine: 0.7)
        let ls = MXNode(geometry: MXCone(topRadius: 0.07, bottomRadius: 0.17, height: 0.15))
        ls.geometry?.materials = [green]
        ls.position = MXVector3(lampX, 1.32, lampZ); root.addChildNode(ls)
        let lbulb = MXNode(geometry: MXSphere(radius: 0.05)); lbulb.geometry?.materials = [bulb]
        lbulb.position = MXVector3(lampX, 1.25, lampZ); lbulb.castsShadow = false; root.addChildNode(lbulb)

        // ammo crate next to the desk
        let crateFront = mat(tex("hideout_crate"), bump: 0.4, spec: 0.08)
        let crateSide = mat(nil, C(0.24, 0.29, 0.17), spec: 0.08)
        let crate = box(1.0, 0.55, 0.55, -2.35, 0.275, -1.45, [crateFront, crateSide, crateSide, crateSide, crateSide, crateSide], chamfer: 0.01)
        crate.eulerAngles = MXVector3(0, 0.12, 0)
        root.addChildNode(crate)

        // steel chest, right foreground
        let chestFront = mat(steelT, bump: 0.35, spec: 0.5, shine: 0.55)
        let chestSide = mat(steelT, sx: 0.6, sy: 1, bump: 0.35, spec: 0.5, shine: 0.55)
        let chest = box(1.3, 0.78, 0.75, 2.3, 0.39, 1.3, [chestFront, chestSide, chestSide, chestSide, chestSide, chestSide], chamfer: 0.02)
        chest.eulerAngles = MXVector3(0, -0.5, 0)
        root.addChildNode(chest)

        // rifle rack against the back wall, with the game's real 3D guns standing in it
        let rackM = mat(woodT, sx: 2, sy: 0.3, bump: 0.5)
        let rackX: Float = 2.45, rackZ = wallZ + 0.35
        root.addChildNode(box(1.7, 0.1, 0.4, rackX, 0.05, rackZ, [rackM]))
        root.addChildNode(box(1.7, 0.08, 0.12, rackX, 1.05, rackZ - 0.12, [rackM]))
        for sx in [-0.82, 0.82] as [Float] {
            root.addChildNode(box(0.08, 1.15, 0.1, rackX + sx, 0.58, rackZ - 0.12, [rackM]))
        }
        let ids = ["rifle", "ak", "m4", "awp", "shotgun", "mp7"]
        for (i, id) in ids.enumerated() {
            let g = TwGunLib.worldGun(id)
            let holder = MXNode()
            holder.addChildNode(g)
            let s: Float = 1 / 33
            holder.scale = MXVector3(s, s, s)
            holder.eulerAngles = MXVector3(0, Float.pi / 2, Float.pi / 2 - 0.08 + Float(i % 2) * 0.05)
            holder.position = MXVector3(rackX - 0.65 + Float(i) * 0.26, 0.12, rackZ)
            root.addChildNode(holder)
        }
    }

    // MARK: view

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc
        sc.background.contents = UIColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1)
        let root = sc.rootNode
        Self.buildRoom(root)

        // camera: low and centred on the hero, a longer lens like a game lobby shot
        let camN = MXNode()
        let cam = MXCamera()
        cam.fieldOfView = 31
        cam.zNear = 0.1
        cam.zFar = 40
        cam.wantsHDR = true
        cam.bloomIntensity = 0.5
        cam.bloomThreshold = 0.82
        cam.bloomBlurRadius = 7
        cam.vignettingIntensity = 0.45
        cam.vignettingPower = 1.3
        cam.screenSpaceAmbientOcclusionIntensity = 0   // SSAO was noisy on device
        cam.screenSpaceAmbientOcclusionRadius = 0.35
        cam.saturation = 1.0
        cam.contrast = 0.08
        cam.exposure = 1.3
        camN.camera = cam
        camN.position = MXVector3(-0.15, 1.05, 4.6)
        root.addChildNode(camN)
        v.pointOfView = camN
        camN.look(at: MXVector3(-0.15, 1.0, 0))

        // lights: dim warm ambient, a soft key from the front-left that casts the shadows,
        // the desk lamp and wall lamps (warm), cool window light, a faint fill
        func light(_ type: MXLightType, _ col: UIColor, _ i: CGFloat, _ p: MXVector3, start: CGFloat = 0, end: CGFloat = 0) -> MXNode {
            let n = MXNode(); let l = MXLight()
            l.type = type; l.color = col; l.intensity = i
            l.attenuationStartDistance = start; l.attenuationEndDistance = end
            n.light = l; n.position = p
            root.addChildNode(n)
            return n
        }
        _ = light(.ambient, Self.C(0.62, 0.66, 0.78), 520, MXVector3(0, 0, 0))
        let key = light(.directional, Self.C(0.95, 0.95, 1.0), 650, MXVector3(-2.5, 4.5, 4))
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowRadius = 4
        key.light?.shadowSampleCount = 8
        key.light?.shadowColor = UIColor(white: 0, alpha: 0.62)
        key.light?.maximumShadowDistance = 14
        key.look(at: MXVector3(0.3, 0, -1))
        _ = light(.omni, Self.C(1, 0.8, 0.55), 1100, MXVector3(-2.4, 1.22, -2.25), start: 0.3, end: 4.5)      // desk lamp
        _ = light(.omni, Self.C(1, 0.84, 0.62), 750, MXVector3(1.0, 3.05, -2.4), start: 0.3, end: 5.5)
        _ = light(.omni, Self.C(1, 0.84, 0.62), 750, MXVector3(4.2, 3.05, -2.4), start: 0.3, end: 5.5)
        _ = light(.omni, Self.C(0.5, 0.65, 1.0), 900, MXVector3(-2.7, 2.2, -2.2), start: 0.5, end: 8)       // window
        _ = light(.omni, Self.C(0.75, 0.8, 0.95), 420, MXVector3(0, 2.2, 4.5), start: 1, end: 10)               // fill

        // the hero, standing on the rug
        let co = context.coordinator
        if let u = HeroModelView.url, let model = MXGLTF.load(u) {
            let holder = MXNode()
            holder.addChildNode(model)
            holder.position = MXVector3(0, 0.014, 0.35)
            holder.isHidden = !hero
            root.addChildNode(holder)
            co.heroRoot = holder
            var nodes: [String: MXNode] = [:]
            func collect(_ n: MXNode) { if let nm = n.name { nodes[nm] = n }; for c in n.childNodes { collect(c) } }
            collect(model)
            co.cloth = HeroCloth(nodes)
        }
        v.preRender = { [weak co] t in
            guard let co = co else { return }
            let tt = Float(t)
            let yaw = 0.18 * sin(tt * 0.45)
            co.heroRoot?.eulerAngles = MXVector3(0, yaw, 0)
            co.cloth?.update(t: tt, run: 0, yawVel: 0.18 * 0.45 * cos(tt * 0.45))
            camN.position = MXVector3(-0.15 + 0.45 * sin(tt * 0.11), 1.05 + 0.07 * sin(tt * 0.17), 4.6 + 0.35 * sin(tt * 0.08))
            camN.look(at: MXVector3(-0.15 + 0.1 * sin(tt * 0.11), 1.0, 0))
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        context.coordinator.heroRoot?.isHidden = !hero
    }
}

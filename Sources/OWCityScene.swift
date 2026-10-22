import SwiftUI

// MARK: - Street-level 3D city for the MAP tab (Metal engine)
// A procedural city built from the district layout: blocks of towers inside each district, glowing borders in the
// owner's colour, beacons over each district, street lamps. Pinch from the whole city down to street level.

final class CityCam {
    var tx: CGFloat = 0, tz: CGFloat = 60
    var yaw: CGFloat = 0.5
    var dist: CGFloat = 520
    var cx: CGFloat = 0, cz: CGFloat = 60, cyaw: CGFloat = 0.5, cdist: CGFloat = 520
    weak var view: MXView?

    static let halfW: CGFloat = 700, halfD: CGFloat = 500
    static func world(_ n: CGPoint) -> CGPoint { CGPoint(x: (n.x - 0.5) * halfW * 2, y: (n.y - 0.5) * halfD * 2) }

    func focus(_ n: CGPoint, dist d: CGFloat) {
        let w = Self.world(n)
        tx = w.x; tz = w.y; dist = max(30, min(900, d))
    }

    var streetLevel: Bool { dist < 120 }

    /// camera pitch follows the distance: flat to the street up close, high above the city when far
    static func pitch(_ d: CGFloat) -> CGFloat {
        let t = max(0, min(1, (d - 35) / 620))
        return 0.12 + 0.95 * t * t * (3 - 2 * t)
    }

    func clampTarget() {
        tx = max(-Self.halfW, min(Self.halfW, tx))
        tz = max(-Self.halfD, min(Self.halfD, tz))
    }

    /// screen point of a world position, nil when it is behind the camera
    func screen(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint? {
        guard let v = view else { return nil }
        let p = v.projectPoint(MXVector3(Float(x), Float(y), Float(z)))
        if p.z > 1.5 { return nil }
        return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    }
}

struct CityView3D: UIViewRepresentable {
    let cam: CityCam

    final class Coord { var camNode = MXNode() }
    func makeCoordinator() -> Coord { Coord() }

    private static func mat(_ c: UIColor, emission: UIColor? = nil, glow: Bool = false) -> MXMaterial {
        let m = MXMaterial()
        m.diffuse.contents = c
        if let e = emission { m.emission.contents = e }
        if glow {
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.transparency = 0.38
            m.writesToDepthBuffer = false
        }
        return m
    }

    private static func inside(_ p: CGPoint, _ poly: [CGPoint]) -> Bool {
        var c = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { c.toggle() }
            j = i
        }
        return c
    }

    private static func ui(_ c: OWDistrict.Owner) -> UIColor {
        switch c {
        case .yours: return UIColor(red: 0.1, green: 0.62, blue: 1, alpha: 1)
        case .enemy: return UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1)
        case .contested: return UIColor(red: 1, green: 0.75, blue: 0.22, alpha: 1)
        }
    }

    private static func rnd(_ a: Int, _ b: Int, _ k: Int) -> CGFloat {
        var h = UInt32(truncatingIfNeeded: a &* 73856093 ^ b &* 19349663 ^ k &* 83492791)
        h ^= h >> 13; h = h &* 1274126177; h ^= h >> 16
        return CGFloat(h % 10000) / 10000
    }

    private static func buildCity(_ root: MXNode) {
        let ds = OWDistrict.all
        let hw = CityCam.halfW, hd = CityCam.halfD

        let ground = MXNode(geometry: MXBox(width: hw * 3, height: 1, length: hd * 3, chamferRadius: 0))
        ground.geometry?.firstMaterial = mat(UIColor(red: 0.03, green: 0.045, blue: 0.075, alpha: 1))
        ground.position = MXVector3(0, -0.5, 0)
        ground.castsShadow = false
        root.addChildNode(ground)

        var mats: [Int: [MXMaterial]] = [:]
        for d in ds {
            let col = ui(d.owner)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            col.getRed(&r, green: &g, blue: &b, alpha: &a)
            mats[d.id] = (0..<3).map { k in
                let lit = 0.10 + 0.10 * CGFloat(k)
                return mat(UIColor(red: 0.05 + r * 0.12, green: 0.06 + g * 0.12, blue: 0.09 + b * 0.12, alpha: 1),
                           emission: UIColor(red: r * lit, green: g * lit, blue: b * lit, alpha: 1))
            }
        }

        let step: CGFloat = 44
        var lamps = 0
        let lampMat = mat(UIColor(white: 0.2, alpha: 1), emission: UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 1))
        for ix in -16...16 {
            for iz in -12...12 {
                let x = CGFloat(ix) * step, z = CGFloat(iz) * step
                let n = CGPoint(x: x / (hw * 2) + 0.5, y: z / (hd * 2) + 0.5)
                guard let d = ds.first(where: { inside(n, $0.poly) }) else { continue }
                let r1 = rnd(ix, iz, 1), r2 = rnd(ix, iz, 2), r3 = rnd(ix, iz, 3)
                if r3 < 0.1 { continue }                       // an empty lot
                let w = 22 + r1 * 14, l = 22 + r2 * 14
                var h: CGFloat
                switch d.id {
                case 1: h = 70 + r1 * r2 * 170                 // downtown towers
                case 2: h = 14 + r3 * 26
                case 5: h = 10 + r3 * 22
                default: h = 22 + r1 * 54
                }
                if d.id == 2 { h = max(h, 16) }
                let b = MXNode(geometry: MXBox(width: w, height: h, length: l, chamferRadius: 0.6))
                b.geometry?.firstMaterial = mats[d.id]![Int(r2 * 2.99)]
                b.position = MXVector3(Float(x), Float(h / 2), Float(z))
                b.castsShadow = false
                root.addChildNode(b)
                // street lamp at the corner of the lot
                if lamps < 140, r1 > 0.45 {
                    let p = MXNode(geometry: MXBox(width: 0.6, height: 7, length: 0.6, chamferRadius: 0))
                    p.geometry?.firstMaterial = lampMat
                    p.position = MXVector3(Float(x + step / 2 - 2), 3.5, Float(z + step / 2 - 2))
                    p.castsShadow = false
                    root.addChildNode(p)
                    lamps += 1
                }
            }
        }

        // borders and beacons
        for d in ds {
            let col = ui(d.owner)
            let glow = mat(col, emission: col, glow: true)
            for i in 0..<d.poly.count {
                let a = CityCam.world(d.poly[i]), b = CityCam.world(d.poly[(i + 1) % d.poly.count])
                let len = hypot(b.x - a.x, b.y - a.y)
                let n = MXNode(geometry: MXBox(width: len, height: 26, length: 1.6, chamferRadius: 0))
                n.geometry?.firstMaterial = glow
                n.position = MXVector3(Float((a.x + b.x) / 2), 13, Float((a.y + b.y) / 2))
                n.eulerAngles = MXVector3(0, Float(-atan2(b.y - a.y, b.x - a.x)), 0)
                n.castsShadow = false
                n.renderingOrder = 9
                root.addChildNode(n)
            }
            let c = CityCam.world(d.label)
            let beam = MXNode(geometry: MXCylinder(radius: 2.5, height: 340))
            beam.geometry?.firstMaterial = glow
            beam.position = MXVector3(Float(c.x), 170, Float(c.y))
            beam.castsShadow = false
            beam.renderingOrder = 9
            root.addChildNode(beam)
        }
    }

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        sc.background.contents = UIColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1)
        v.scene = sc

        let camNode = MXNode()
        camNode.camera = MXCamera()
        camNode.camera?.fieldOfView = 55
        camNode.camera?.zNear = 0.5
        camNode.camera?.zFar = 4500
        sc.rootNode.addChildNode(camNode)
        v.pointOfView = camNode
        context.coordinator.camNode = camNode

        let amb = MXNode(); amb.light = MXLight(); amb.light?.type = .ambient; amb.light?.intensity = 520
        sc.rootNode.addChildNode(amb)
        for (inten, pos) in [(CGFloat(760), MXVector3(-300, 500, 200)), (CGFloat(260), MXVector3(300, 200, -300))] {
            let n = MXNode(); n.light = MXLight(); n.light?.type = .directional; n.light?.intensity = inten
            n.position = pos
            sc.rootNode.addChildNode(n)
            n.look(at: MXVector3(0, 0, 0))
        }
        Self.buildCity(sc.rootNode)

        let c = cam
        c.view = v
        v.preRender = { [weak camNode] _ in
            guard let camNode = camNode else { return }
            let k: CGFloat = 0.14
            c.cx += (c.tx - c.cx) * k
            c.cz += (c.tz - c.cz) * k
            c.cdist += (c.dist - c.cdist) * k
            var dy = c.yaw - c.cyaw
            while dy > CGFloat.pi { dy -= 2 * CGFloat.pi }
            while dy < -CGFloat.pi { dy += 2 * CGFloat.pi }
            c.cyaw += dy * k
            let p = CityCam.pitch(c.cdist)
            let r = c.cdist * cos(p)
            let h = max(3, c.cdist * sin(p))
            camNode.position = MXVector3(Float(c.cx + sin(c.cyaw) * r), Float(h), Float(c.cz + cos(c.cyaw) * r))
            camNode.look(at: MXVector3(Float(c.cx), 4, Float(c.cz)))
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {}
}

/// the 3D map with labels, drag to pan, pinch to zoom, twist to rotate, tap a district to select it
struct OWCityMapLayer: View {
    let cam: CityCam
    @Binding var pick: Int
    let u: CGFloat
    let visible: (OWDistrict) -> Bool

    @State private var lastDrag = CGSize.zero
    @State private var pinchBase: CGFloat = 0
    @State private var twistBase: CGFloat = 0

    private func hit(_ pt: CGPoint) -> Int? {
        var found: Int? = nil
        var bestArea = CGFloat.greatestFiniteMagnitude
        for d in OWDistrict.all where visible(d) {
            var poly: [CGPoint] = []
            for p in d.poly {
                let w = CityCam.world(p)
                guard let s = cam.screen(w.x, 0, w.y) else { poly = []; break }
                poly.append(s)
            }
            guard poly.count >= 3 else { continue }
            var inside = false
            var j = poly.count - 1
            for i in 0..<poly.count {
                let a = poly[i], b = poly[j]
                if (a.y > pt.y) != (b.y > pt.y), pt.x < (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
                j = i
            }
            if inside {
                let xs = poly.map { $0.x }, ys = poly.map { $0.y }
                let area = ((xs.max() ?? 0) - (xs.min() ?? 0)) * ((ys.max() ?? 0) - (ys.min() ?? 0))
                if area < bestArea { bestArea = area; found = d.id }
            }
        }
        return found
    }

    var body: some View {
        ZStack {
            CityView3D(cam: cam)
            TimelineView(.animation) { _ in
                ZStack {
                    ForEach(OWDistrict.all) { d in
                        if visible(d) {
                            let w = CityCam.world(d.label)
                            if let s = cam.screen(w.x, cam.streetLevel ? 70 : 150, w.y), cam.cdist > 60 {
                                HStack(spacing: 4 * u) {
                                    Image(systemName: d.owner == .yours ? "crown.fill" : (d.owner == .enemy ? "flame.fill" : "shield.lefthalf.filled"))
                                        .font(.system(size: 12 * u)).foregroundColor(d.color)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(d.name).font(.jk(9 * u, .heavy)).foregroundColor(.white)
                                        Text("\(d.control)% CONTROL").font(.jk(7 * u, .semibold)).foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 6 * u).padding(.vertical, 3 * u)
                                .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.black.opacity(0.55)))
                                .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(d.id == pick ? d.color : .clear, lineWidth: 1.4))
                                .position(s)
                            }
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let dx = v.translation.width - lastDrag.width, dy = v.translation.height - lastDrag.height
                    lastDrag = v.translation
                    let k = cam.dist * 0.0022
                    let fx = -sin(cam.yaw), fz = -cos(cam.yaw)
                    let rx = cos(cam.yaw), rz = -sin(cam.yaw)
                    if hypot(v.translation.width, v.translation.height) > 5 {
                        cam.tx += (-rx * dx + fx * dy) * k
                        cam.tz += (-rz * dx + fz * dy) * k
                        cam.clampTarget()
                    }
                }
                .onEnded { v in
                    lastDrag = .zero
                    if hypot(v.translation.width, v.translation.height) <= 5, let id = hit(v.location) { pick = id }
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { m in
                    if pinchBase == 0 { pinchBase = cam.dist }
                    cam.dist = max(30, min(900, pinchBase / m))
                }
                .onEnded { _ in pinchBase = 0 }
        )
        .simultaneousGesture(
            RotationGesture()
                .onChanged { a in
                    if twistBase == 0 { twistBase = cam.yaw + 1000 }
                    cam.yaw = (twistBase - 1000) - CGFloat(a.radians)
                }
                .onEnded { _ in twistBase = 0 }
        )
    }
}

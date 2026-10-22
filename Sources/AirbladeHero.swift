import SwiftUI

/// The AIRBLADE hero: a 3D model (Resources/airblade_hero.glb, built by blender-scripts/hero_build.py)
/// whose coat, skirt flap and hood veil sway in the hideout. Falls back to the flat art if the model is missing.
struct AirbladeHero: View {
    var back = false

    var body: some View {
        if HeroModelView.available {
            HeroModelView()
        } else {
            Image(back ? "HeroBack" : "HeroFront")
                .resizable().interpolation(.high).scaledToFit()
                .shadow(color: .black.opacity(0.55), radius: 10, y: 4)
        }
    }
}

struct HeroModelView: UIViewRepresentable {
    static var url: URL? {
        Bundle.main.url(forResource: "airblade_hero", withExtension: "glb")
            ?? Bundle.main.url(forResource: "airblade_hero", withExtension: "glb", subdirectory: "models")
    }
    static var available: Bool { url != nil }

    final class Coord {
        var nodes: [String: MXNode] = [:]
        var root = MXNode()
        var cloth: HeroCloth? = nil
    }

    func makeCoordinator() -> Coord { Coord() }

    private static func collect(_ n: MXNode, _ into: inout [String: MXNode]) {
        if let nm = n.name { into[nm] = n }
        for c in n.childNodes { collect(c, &into) }
    }

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc

        let cam = MXNode()
        cam.camera = MXCamera()
        cam.camera?.fieldOfView = 32
        cam.camera?.zNear = 0.1
        cam.camera?.zFar = 40
        cam.position = MXVector3(0, 0.92, 3.5)
        sc.rootNode.addChildNode(cam)
        v.pointOfView = cam
        cam.look(at: MXVector3(0, 0.86, 0))

        let amb = MXNode()
        amb.light = MXLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 700
        sc.rootNode.addChildNode(amb)
        let sun = MXNode()
        sun.light = MXLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = MXVector3(-0.5, 0.5, 0)
        sc.rootNode.addChildNode(sun)

        let co = context.coordinator
        if let u = Self.url, let model = MXGLTF.load(u) {
            co.root = model
            sc.rootNode.addChildNode(model)
            Self.collect(model, &co.nodes)
            co.cloth = HeroCloth(co.nodes)
        }
        v.preRender = { [weak co] t in
            guard let co = co else { return }
            let tt = Float(t)
            let yaw = 0.24 * sin(tt * 0.5)
            let yawVel = 0.24 * 0.5 * cos(tt * 0.5)
            co.root.eulerAngles = MXVector3(0, yaw, 0)
            co.cloth?.update(t: tt, run: 0, yawVel: yawVel)
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {}
}

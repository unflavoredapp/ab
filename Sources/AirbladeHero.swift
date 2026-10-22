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

/// Drag / pinch state shared between SwiftUI gestures and a 3D view's render loop (read every frame).
final class ABOrbit {
    var yaw: Float = 0
    var pitch: Float = 0
    var zoom: Float = 1          // 1 = default framing, up to ~2.4 close-up
    var touched = false          // stops the idle turn while the player is handling it
    var spin: Float = 0          // one-off intro spin (radians left), eases out
}

struct HeroModelView: UIViewRepresentable {
    /// set for the inspection screen: yaw / zoom come from the player's drag and pinch
    var orbit: ABOrbit? = nil

    static var url: URL? {
        Bundle.main.url(forResource: "airblade_hero", withExtension: "glb")
            ?? Bundle.main.url(forResource: "airblade_hero", withExtension: "glb", subdirectory: "models")
    }
    static var available: Bool { url != nil }

    final class Coord {
        var nodes: [String: MXNode] = [:]
        var root = MXNode()
        var cloth: HeroCloth? = nil
        var cam = MXNode()
        var lastYaw: Float = 0
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
        context.coordinator.cam = cam

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
        let orbit = self.orbit
        v.preRender = { [weak co] t in
            guard let co = co else { return }
            let tt = Float(t)
            if let o = orbit {
                // inspection: the player's yaw, a slow idle turn when untouched, zoom toward the chest / face
                if !o.touched { o.yaw += 0.0035 }
                let yaw = o.yaw + 0.06 * sin(tt * 0.5)
                let yawVel = (yaw - co.lastYaw) * 60
                co.lastYaw = yaw
                co.root.eulerAngles = MXVector3(0, yaw, 0)
                co.cloth?.update(t: tt, run: 0, yawVel: max(-3, min(3, yawVel)))
                let z = max(0.0, min(1.0, (o.zoom - 1) / 1.4))
                let lookY: Float = 0.86 + 0.5 * z
                co.cam.position = MXVector3(0, 0.92 + 0.5 * z, 3.5 - 2.2 * z)
                co.cam.look(at: MXVector3(0, lookY, 0))
            } else {
                let yaw = 0.24 * sin(tt * 0.5)
                let yawVel = 0.24 * 0.5 * cos(tt * 0.5)
                co.root.eulerAngles = MXVector3(0, yaw, 0)
                co.cloth?.update(t: tt, run: 0, yawVel: yawVel)
            }
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {}
}

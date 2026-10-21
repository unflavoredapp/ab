import UIKit
import Metal
import simd

/// glTF skin: joint nodes + inverse bind matrices. The renderer deforms the bind-pose vertices on the CPU every
/// time the owning node is gathered (linear blend, 4 influences) and writes them into a rotating set of GPU buffers.
final class MXSkin {
    let joints: [MXNode]
    let ibm: [simd_float4x4]
    private var jm: [simd_float4x4]

    init(joints: [MXNode], ibm: [simd_float4x4]) {
        self.joints = joints
        self.ibm = ibm
        self.jm = [simd_float4x4](repeating: matrix_identity_float4x4, count: joints.count)
    }

    /// deform `md.bind` into the mesh's next vertex buffer
    func update(_ md: MXMeshData, _ mesh: MXGPUMesh, meshNode: MXNode) {
        let n = md.bind.count
        guard n > 0, md.skinJ.count == n, md.skinW.count == n else { return }
        let inv = simd_inverse(meshNode.worldTransform())
        for i in 0..<joints.count { jm[i] = inv * joints[i].worldTransform() * ibm[i] }
        let buf = mesh.nextSkinBuffer()
        let out = buf.contents().bindMemory(to: MXVertex.self, capacity: n)
        let cnt = jm.count
        md.bind.withUnsafeBufferPointer { bp in
            md.skinJ.withUnsafeBufferPointer { jp in
                md.skinW.withUnsafeBufferPointer { wp in
                    for i in 0..<n {
                        let w = wp[i], j = jp[i], b = bp[i]
                        var m = simd_float4x4()
                        var any = false
                        for k in 0..<4 {
                            let wk = w[k]
                            if wk <= 0 { continue }
                            let ji = Int(j[k])
                            if ji >= cnt { continue }
                            let mj: simd_float4x4 = jm[ji] * wk
                            if any { m = m + mj } else { m = mj }
                            any = true
                        }
                        if !any {
                            out[i] = b
                            continue
                        }
                        let p = m * SIMD4<Float>(b.px, b.py, b.pz, 1)
                        let nm = simd_float3x3(SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                                               SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                               SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z))
                        var nv = nm * SIMD3<Float>(b.nx, b.ny, b.nz)
                        let l = simd_length(nv)
                        nv = l > 1e-8 ? nv / l : SIMD3<Float>(0, 1, 0)
                        out[i] = MXVertex(px: p.x, py: p.y, pz: p.z, nx: nv.x, ny: nv.y, nz: nv.z, u: b.u, v: b.v)
                    }
                }
            }
        }
        mesh.vbuf = buf
    }
}

/// A posable skeleton found in a loaded glTF: bones by name, with rest rotations captured at load.
/// Poses are given as world-space (model-space) rotation deltas from the rest pose, one per bone; bones left out keep
/// the rest pose. This is what the Blender pose solver exports (`stfpose.json`), plus procedural walk / aim layers.
struct MXBonePose {
    var q: simd_quatf
    var p: SIMD3<Float>? = nil
}

final class MXRig {
    let bones: [String: MXNode]
    let order: [MXNode]                       // parents before children
    private var restLocal: [ObjectIdentifier: simd_quatf] = [:]
    private var restWorld: [ObjectIdentifier: simd_quatf] = [:]
    private var restPos: [ObjectIdentifier: SIMD3<Float>] = [:]
    private var restT: [ObjectIdentifier: SIMD3<Float>] = [:]
    private let root: MXNode

    /// `root` is the node that holds the whole model; `skinned` the nodes that carry a skin (to find joints).
    init?(root: MXNode, joints: [MXNode]) {
        guard !joints.isEmpty else { return nil }
        self.root = root
        var map: [String: MXNode] = [:]
        var seen = Set<ObjectIdentifier>()
        var list: [MXNode] = []
        for j in joints where !seen.contains(ObjectIdentifier(j)) {
            seen.insert(ObjectIdentifier(j)); list.append(j)
            if let nm = j.name { map[nm] = j }
        }
        // depth order
        func depth(_ n: MXNode) -> Int { var d = 0; var p = n.parentNode; while let q = p { d += 1; p = q.parentNode }; return d }
        list.sort { depth($0) < depth($1) }
        bones = map
        order = list
        for n in list {
            let id = ObjectIdentifier(n)
            restLocal[id] = n.rotationQuat
            restT[id] = n.positionSIMD
        }
        // world rotations / positions relative to root
        for n in list {
            let w = MXRig.relWorld(n, root)
            let id = ObjectIdentifier(n)
            let r = simd_float3x3(SIMD3<Float>(w.columns.0.x, w.columns.0.y, w.columns.0.z) / max(simd_length(SIMD3<Float>(w.columns.0.x, w.columns.0.y, w.columns.0.z)), 1e-6),
                                  SIMD3<Float>(w.columns.1.x, w.columns.1.y, w.columns.1.z) / max(simd_length(SIMD3<Float>(w.columns.1.x, w.columns.1.y, w.columns.1.z)), 1e-6),
                                  SIMD3<Float>(w.columns.2.x, w.columns.2.y, w.columns.2.z) / max(simd_length(SIMD3<Float>(w.columns.2.x, w.columns.2.y, w.columns.2.z)), 1e-6))
            restWorld[id] = simd_normalize(simd_quatf(r))
            restPos[id] = SIMD3<Float>(w.columns.3.x, w.columns.3.y, w.columns.3.z)
        }
    }

    private static func rotOf(_ w: simd_float4x4) -> simd_quatf {
        func col(_ c: SIMD4<Float>) -> SIMD3<Float> { let v = SIMD3<Float>(c.x, c.y, c.z); return v / max(simd_length(v), 1e-6) }
        return simd_normalize(simd_quatf(simd_float3x3(col(w.columns.0), col(w.columns.1), col(w.columns.2))))
    }

    private static func relWorld(_ n: MXNode, _ root: MXNode) -> simd_float4x4 {
        var m = n.localTransform
        var p = n.parentNode
        while let q = p, q !== root { m = q.localTransform * m; p = q.parentNode }
        return m
    }

    func restPosition(_ bone: String) -> SIMD3<Float>? { bones[bone].flatMap { restPos[ObjectIdentifier($0)] } }

    /// apply a pose. Each entry sets one bone's rotation in model space (relative to rest, rotating about the bone head) and,
    /// optionally, the bone head's model-space position. Bones left out follow their parent rigidly (rest local offset).
    func apply(_ pose: [String: MXBonePose]) {
        var curWorld: [ObjectIdentifier: simd_quatf] = [:]
        var curPos: [ObjectIdentifier: SIMD3<Float>] = [:]
        let ident = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        for n in order {
            let id = ObjectIdentifier(n)
            let rw = restWorld[id] ?? ident
            let rl = restLocal[id] ?? ident
            var parentW = ident
            var parentP = SIMD3<Float>(0, 0, 0)
            if let p = n.parentNode {
                if let pw = curWorld[ObjectIdentifier(p)], let pp = curPos[ObjectIdentifier(p)] { parentW = pw; parentP = pp }
                else if p !== root {
                    let w = MXRig.relWorld(p, root)
                    parentW = MXRig.rotOf(w); parentP = SIMD3<Float>(w.columns.3.x, w.columns.3.y, w.columns.3.z)
                }
            }
            let bp = n.name.flatMap { pose[$0] }
            let targetW: simd_quatf = bp != nil ? bp!.q * rw : parentW * rl
            let localT: SIMD3<Float>
            if let bp = bp, let tp = bp.p { localT = parentW.inverse.act(tp - parentP) } else { localT = restT[id] ?? SIMD3<Float>(0, 0, 0) }
            n.position = MXVector3(localT.x, localT.y, localT.z)
            n.setRotationQuat(simd_normalize(parentW.inverse * targetW))
            curWorld[id] = targetW
            curPos[id] = parentP + parentW.act(localT)
        }
    }

    func reset() { apply([:]) }
}

extension MXNode {
    var parentNode: MXNode? { parent }
    var rotationQuat: simd_quatf { let o = orientation; return simd_quatf(ix: o.x, iy: o.y, iz: o.z, r: o.w) }
    var positionSIMD: SIMD3<Float> { let p = position; return SIMD3<Float>(p.x, p.y, p.z) }
    func setRotationQuat(_ q: simd_quatf) { orientation = MXVector4(q.imag.x, q.imag.y, q.imag.z, q.real) }
}

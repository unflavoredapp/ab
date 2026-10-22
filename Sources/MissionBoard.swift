import SwiftUI

/// One operation on the hideout's mission board.
struct ABOperation: Identifiable {
    let id: Int
    let code: String
    let name: String
    let mode: Int          // TacticalEngine game mode
    let map: Int           // TMap kind
    let brief: String
    let objectives: [String]
    let gun: String        // recommended primary
    let side: String       // recommended sidearm
    let tip: String

    static let all: [ABOperation] = [
        ABOperation(id: 0, code: "OP-01", name: "STREET SWEEP", mode: 1, map: 3,
                    brief: "Two squads, one town. Clear the market streets and hold the rooftops.",
                    objectives: ["Reach the kill target before the enemy team", "Respawn after 3 seconds", "Rooftops give the high ground"],
                    gun: "ak", side: "pistol", tip: "Wall-run onto the roofs, then drop in with a sword jump."),
        ABOperation(id: 1, code: "OP-02", name: "HOLD THE SQUARE", mode: 5, map: 3,
                    brief: "Capture and hold the control points across Town. Standing on a point scores for your team.",
                    objectives: ["Capture the control points", "Hold them to score", "Clear defenders off the zone"],
                    gun: "m4", side: "eagle", tip: "Dash in, slash the defender, then hold the point."),
        ABOperation(id: 2, code: "OP-03", name: "LAST FUSE", mode: 0, map: 3,
                    brief: "Attackers plant the charge on site A or B. Defenders stop them or defuse it.",
                    objectives: ["Plant the bomb on site A or B", "Defend the planted bomb", "Or defuse it in time"],
                    gun: "awp", side: "pistol", tip: "Long streets favour the AWP-X. Keep the blade for close corners."),
        ABOperation(id: 3, code: "OP-04", name: "BLADE TRIAL", mode: 8, map: 9,
                    brief: "One arena, no way out. Pillars, lane walls and crates to climb. Blades out.",
                    objectives: ["Win the duel", "Use the crates to reach the high ground", "Air slashes and backstabs deal extra damage"],
                    gun: "smg", side: "pistol", tip: "Chain slashes inside 1.6 s to build a combo."),
        ABOperation(id: 4, code: "OP-05", name: "MOVEMENT LAB", mode: 9, map: 9,
                    brief: "90 seconds of practice. Seven targets stand in the arena and pop back up when you drop them. Nothing shoots back.",
                    objectives: ["Drop as many targets as you can", "Wall-run and sword-jump between them", "Chain slashes inside 1.6 s for a combo", "Score counts targets, best chain, air kills and accuracy"],
                    gun: "smg", side: "pistol", tip: "Slash in the air for a sword jump, then slash again to keep your combo going."),
        ABOperation(id: 5, code: "OP-06", name: "FREE ROAM", mode: 10, map: 3,
                    brief: "No timer, no teams. Walk Town with your hands up: pedestrians, two rival crews and jobs on your phone. Cash is banked as coins when you leave.",
                    objectives: ["Take jobs from the phone: Dead Drop, Turf War, Take Down Razor", "Fight with fists: jab, cross, kick finisher", "Air kicks and rush punches hit harder", "Getting knocked out costs 15% of your cash"],
                    gun: "pistol", side: "pistol", tip: "Wall-run and jump-kick: an air kick hits for 26.")
    ]
}

/// Top-down sketch of a map from its layout: floor, walls, props, both spawns and the objectives.
struct MapPreview: View {
    let op: ABOperation
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let blue = Color(red: 0.25, green: 0.65, blue: 1)

    private var data: MapData { op.map == 9 ? TArena.shared : TDesert.shared }

    var body: some View {
        Canvas { ctx, size in
            let d = data
            var b = CGRect.null
            for r in d.rooms where r.fl == 1 || d.rooms.count < 3 { b = b.union(r.r) }
            if b.isNull { b = d.rooms.reduce(CGRect.null) { $0.union($1.r) } }
            guard !b.isNull, b.width > 0, b.height > 0 else { return }
            b = b.insetBy(dx: -40, dy: -40)
            let s = min(size.width / b.width, size.height / b.height)
            let ox = (size.width - b.width * s) / 2, oy = (size.height - b.height * s) / 2
            func M(_ r: CGRect) -> CGRect { CGRect(x: ox + (r.minX - b.minX) * s, y: oy + (r.minY - b.minY) * s, width: r.width * s, height: r.height * s) }
            func P(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + (p.x - b.minX) * s, y: oy + (p.y - b.minY) * s) }
            let clip = M(b)
            ctx.clip(to: Path(clip))
            for r in d.rooms where b.intersects(r.r) {
                ctx.fill(Path(M(r.r)), with: .color(Color(red: 0.12, green: 0.15, blue: 0.21)))
            }
            for r in d.layout.walls where b.intersects(r) {
                ctx.fill(Path(M(r)), with: .color(Color(red: 0.32, green: 0.36, blue: 0.44)))
            }
            for pr in d.props where b.intersects(pr.r) {
                ctx.fill(Path(roundedRect: M(pr.r), cornerRadius: 1.5), with: .color(Color(red: 0.55, green: 0.5, blue: 0.42).opacity(0.8)))
            }
            // objectives
            if op.mode == 0 {
                for (i, r) in [d.siteA, d.siteB].enumerated() where b.intersects(r) {
                    let m = M(r)
                    ctx.stroke(Path(m), with: .color(orange), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    ctx.draw(Text(i == 0 ? "A" : "B").font(.system(size: 14, weight: .heavy)).foregroundColor(orange), at: CGPoint(x: m.midX, y: m.midY))
                }
            }
            if op.mode == 5 && b.intersects(d.hubZone) {
                let m = M(d.hubZone)
                ctx.stroke(Path(ellipseIn: m), with: .color(orange), lineWidth: 1.5)
                ctx.draw(Text("CP").font(.system(size: 11, weight: .heavy)).foregroundColor(orange), at: CGPoint(x: m.midX, y: m.midY))
            }
            let spawnSets: [([CGPoint], Color)] = op.mode == 9 ? [(Array(d.atkSpawn.dropFirst(2).prefix(1)), blue), (d.spawns, orange)] : (op.mode == 8 ? [(Array(d.spawns.prefix(1)), blue), (Array(d.spawns.dropFirst(10).prefix(1)), orange)] : [(d.atkSpawn, blue), (d.defSpawn, orange)])
            for (pts, c) in spawnSets {
                for p in pts where b.contains(p) {
                    let q = P(p)
                    ctx.fill(Path(ellipseIn: CGRect(x: q.x - 3.5, y: q.y - 3.5, width: 7, height: 7)), with: .color(c))
                }
            }
            // scan lines for the monitor look
            var y: CGFloat = clip.minY
            while y < clip.maxY {
                ctx.fill(Path(CGRect(x: clip.minX, y: y, width: clip.width, height: 1)), with: .color(Color.black.opacity(0.18)))
                y += 3
            }
        }
    }
}

/// The evidence board, made functional: pick an operation, read the brief and objectives, see the map and the
/// recommended loadout, then launch.
struct MissionBoardView: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void
    let launch: (ABOperation) -> Void

    @State private var pick = 0
    @State private var equipped = false

    private let orange = Color(red: 1, green: 0.55, blue: 0.16)
    private let glass = Color(red: 0.04, green: 0.06, blue: 0.11).opacity(0.84)
    private let card = Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.92)
    private let edge = Color(red: 0.55, green: 0.7, blue: 1).opacity(0.2)
    private let paper = Color(red: 0.86, green: 0.81, blue: 0.7)

    private var u: CGFloat { min(size.width / 1024, size.height / 470) }
    private var op: ABOperation { ABOperation.all[pick] }

    private func opCard(_ o: ABOperation) -> some View {
        let on = o.id == pick
        return Button { pick = o.id; equipped = false } label: {
            HStack(spacing: 8 * u) {
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text(o.code).font(.jk(8.5 * u, .heavy)).tracking(1.5 * u).foregroundColor(on ? orange : .white.opacity(0.45))
                    Text(o.name).font(.jk(13 * u, .heavy)).italic().foregroundColor(.white).lineLimit(1)
                    Text("\(TWeapons.modeNames[o.mode].capitalized) · \(TacLobbyMaps.title(o.map).capitalized)")
                        .font(.jk(8.5 * u, .semibold)).foregroundColor(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10 * u, weight: .bold)).foregroundColor(on ? orange : .white.opacity(0.3))
            }
            .padding(.horizontal, 10 * u).frame(height: 46 * u)
            .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
            .overlay(alignment: .leading) { Rectangle().fill(on ? orange : .clear).frame(width: 3 * u) }
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(on ? orange : edge, lineWidth: on ? 1.4 : 1))
            .shadow(color: on ? orange.opacity(0.4) : .clear, radius: 6 * u)
        }.buttonStyle(.plain)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6 * u) {
            HStack(spacing: 6 * u) {
                Image(systemName: "pin.fill").font(.system(size: 10 * u)).foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
                Text("OPERATIONS").font(.jk(11 * u, .heavy)).tracking(2 * u).foregroundColor(.white.opacity(0.8))
            }
            ForEach(ABOperation.all) { opCard($0) }
            Spacer(minLength: 0)
        }
        .frame(width: 210 * u)
    }

    private var dossier: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                MapPreview(op: op).id(op.id)
                    .background(Color(red: 0.03, green: 0.04, blue: 0.07))
                Text(TacLobbyMaps.title(op.map)).font(.jk(9 * u, .heavy)).tracking(2 * u).foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 7 * u).frame(height: 18 * u).background(Color.black.opacity(0.6)).padding(6 * u)
                HStack(spacing: 10 * u) {
                    legend(Color(red: 0.25, green: 0.65, blue: 1), op.mode >= 8 ? "You" : "Your spawn")
                    legend(orange, op.mode == 9 ? "Targets" : (op.mode == 10 ? "Crew corners" : (op.mode == 8 ? "Rival" : "Enemy spawn")))
                }
                .padding(.horizontal, 7 * u).frame(height: 18 * u).background(Color.black.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(6 * u)
            }
            .frame(height: 170 * u)
            .clipShape(RoundedRectangle(cornerRadius: 3 * u))
            VStack(alignment: .leading, spacing: 4 * u) {
                Text(op.name).font(.jk(18 * u, .heavy)).italic().foregroundColor(.white)
                Text(op.brief).font(.jk(10 * u, .medium)).foregroundColor(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                Text("OBJECTIVES").font(.jk(9 * u, .heavy)).tracking(2 * u).foregroundColor(orange).padding(.top, 4 * u)
                ForEach(op.objectives, id: \.self) { o in
                    HStack(alignment: .top, spacing: 6 * u) {
                        Rectangle().fill(orange).frame(width: 5 * u, height: 5 * u).rotationEffect(.degrees(45)).padding(.top, 4 * u)
                        Text(o).font(.jk(10 * u, .semibold)).foregroundColor(.white.opacity(0.85))
                    }
                }
            }
            .padding(.top, 8 * u)
            Spacer(minLength: 0)
        }
        .padding(10 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private func legend(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 4 * u) {
            Circle().fill(c).frame(width: 6 * u, height: 6 * u)
            Text(s).font(.jk(8 * u, .semibold)).foregroundColor(.white.opacity(0.75))
        }
    }

    private func gear(_ title: String, _ id: String?) -> some View {
        HStack(spacing: 8 * u) {
            Group {
                if let i = id {
                    Image(uiImage: GunSprites.icon(TWeapons.rig(i))).renderingMode(.template).resizable().scaledToFit()
                        .foregroundColor(.white.opacity(0.92)).frame(height: 16 * u)
                } else {
                    BladeGlyph().fill(Color.white).frame(width: 42 * u, height: 14 * u)
                }
            }
            .frame(width: 56 * u)
            VStack(alignment: .leading, spacing: 1 * u) {
                Text(title).font(.jk(8 * u, .heavy)).tracking(1 * u).foregroundColor(.white.opacity(0.45))
                Text(id.map { TWeapons.w($0).name } ?? "AIRBLADE").font(.jk(11 * u, .heavy)).foregroundColor(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8 * u).frame(height: 38 * u)
        .background(RoundedRectangle(cornerRadius: 3 * u).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(edge, lineWidth: 1))
    }

    private var loadout: some View {
        let ready = nav.tacGun == op.gun && TacticalEngine.secondary == op.side
        return VStack(alignment: .leading, spacing: 6 * u) {
            Text("RECOMMENDED LOADOUT").font(.jk(10 * u, .heavy)).tracking(1.5 * u).foregroundColor(.white.opacity(0.8))
            gear("MELEE", nil)
            gear("PRIMARY", op.gun)
            gear("SIDEARM", op.side)
            Button {
                nav.tacGun = op.gun
                TacticalEngine.secondary = op.side
                equipped = true
            } label: {
                HStack(spacing: 6 * u) {
                    Image(systemName: ready || equipped ? "checkmark" : "arrow.down.to.line").font(.system(size: 10 * u, weight: .bold))
                    Text(ready || equipped ? "EQUIPPED" : "EQUIP LOADOUT").font(.jk(11 * u, .heavy)).tracking(1 * u)
                }
                .foregroundColor(ready || equipped ? .black : orange).frame(maxWidth: .infinity).frame(height: 28 * u)
                .background(RoundedRectangle(cornerRadius: 3 * u).fill(ready || equipped ? orange : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(orange, lineWidth: 1.2))
            }.buttonStyle(.plain)
            HStack(alignment: .top, spacing: 6 * u) {
                Image(systemName: "lightbulb.fill").font(.system(size: 9 * u)).foregroundColor(orange).padding(.top, 1 * u)
                Text(op.tip).font(.jk(9 * u, .medium)).foregroundColor(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2 * u)
            Spacer(minLength: 0)
            Text("DIFFICULTY").font(.jk(9 * u, .heavy)).tracking(1.5 * u).foregroundColor(.white.opacity(0.5))
            HStack(spacing: 4 * u) {
                ForEach(0..<3, id: \.self) { i in
                    Button { diff = i } label: {
                        Text(["EASY", "NORMAL", "HARD"][i]).font(.jk(10 * u, .heavy)).foregroundColor(diff == i ? .black : .white.opacity(0.75))
                            .frame(maxWidth: .infinity).frame(height: 24 * u)
                            .background(RoundedRectangle(cornerRadius: 2 * u).fill(diff == i ? Color.white : Color.white.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(10 * u)
        .frame(width: 230 * u)
        .background(RoundedRectangle(cornerRadius: 4 * u).fill(glass))
        .overlay(RoundedRectangle(cornerRadius: 4 * u).stroke(edge, lineWidth: 1))
    }

    private var launchButton: some View {
        Button { launch(op) } label: {
            HStack(spacing: 8 * u) {
                Text("LAUNCH").font(.jk(17 * u, .heavy)).italic().tracking(2 * u)
                Image(systemName: "chevron.right.2").font(.system(size: 13 * u, weight: .heavy))
            }
            .foregroundColor(.white).frame(width: 230 * u, height: 40 * u)
            .background(ChamferShape(cut: 10 * u).fill(LinearGradient(colors: [Color(red: 0.95, green: 0.48, blue: 0.1), Color(red: 0.62, green: 0.24, blue: 0.03)], startPoint: .top, endPoint: .bottom)))
            .overlay(ChamferShape(cut: 10 * u).stroke(Color(red: 1, green: 0.72, blue: 0.4), lineWidth: 1))
            .shadow(color: orange.opacity(0.55), radius: 10 * u)
        }.buttonStyle(.plain)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 0) {
                LobbyTopBar(t: t, u: u, selected: 1, act: act)
                HStack(spacing: 8 * u) {
                    Button { act(.nav(0)) } label: {
                        HStack(spacing: 4 * u) {
                            Image(systemName: "chevron.left").font(.system(size: 10 * u, weight: .bold))
                            Text("HIDEOUT").font(.jk(10 * u, .heavy)).tracking(1 * u)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }.buttonStyle(.plain)
                    Text("/").foregroundColor(.white.opacity(0.25)).font(.jk(10 * u, .heavy))
                    Text("MISSION BOARD").font(.jk(11 * u, .heavy)).tracking(2 * u).foregroundColor(orange)
                    Spacer()
                }
                .padding(.leading, 27 * u).frame(height: 30 * u)
                HStack(alignment: .top, spacing: 10 * u) {
                    list
                    dossier
                    VStack(spacing: 10 * u) {
                        loadout
                        launchButton
                    }
                }
                .padding(.horizontal, 22 * u).padding(.bottom, 14 * u)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

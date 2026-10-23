import SwiftUI

// MARK: - Context HUD pieces: compass, threat, event card

/// compass strip: heading ticks, N/E/S/W, objective diamond
struct RoamCompass: View {
    let e: TacticalEngine
    private let gold = Color(red: 1, green: 0.8, blue: 0.25)
    private let orange = Color(red: 1, green: 0.55, blue: 0.16)

    var body: some View {
        TimelineView(.animation) { _ in strip }
    }

    private func wrap(_ d: Double) -> Double {
        var x = d.truncatingRemainder(dividingBy: 360)
        if x > 180 { x -= 360 }
        if x < -180 { x += 360 }
        return x
    }

    private var strip: some View {
        let heading = Double(e.me.aim) * 180 / .pi + 90   // 0 = north
        let w: CGFloat = 180, ppd: CGFloat = 1.35
        var objDelta: Double? = nil
        if let t = e.roamMarker {
            let b = Double(atan2(t.y - e.me.pos.y, t.x - e.me.pos.x)) * 180 / .pi + 90
            objDelta = wrap(b - heading)
        }
        return ZStack {
            ForEach(Array(stride(from: 0, to: 360, by: 15)), id: \.self) { m in
                let dd = wrap(Double(m) - heading)
                if abs(dd) < 62 {
                    let card = m % 90 == 0
                    VStack(spacing: 1) {
                        if card {
                            Text(["N", "E", "S", "W"][m / 90]).font(.jk(9, .heavy)).foregroundColor(m == 0 ? orange : .white)
                        }
                        Rectangle().fill(Color.white.opacity(card ? 0.9 : 0.45)).frame(width: 1, height: card ? 5 : 3)
                    }
                    .offset(x: CGFloat(dd) * ppd, y: card ? 0 : 3)
                    .opacity(1 - abs(dd) / 80)
                }
            }
            if let od = objDelta {
                Image(systemName: "diamond.fill").font(.system(size: 8, weight: .bold)).foregroundColor(gold)
                    .offset(x: CGFloat(max(-62, min(62, od))) * ppd, y: 10)
            }
            Image(systemName: "triangle.fill").font(.system(size: 5)).foregroundColor(orange)
                .rotationEffect(.degrees(180)).offset(y: -9)
        }
        .frame(width: w, height: 22)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.28)))
        .clipped()
        .overlay(alignment: .trailing) {
            if let t = e.roamMarker {
                Text("\(Int(tDist(t, e.me.pos) / 33)) m").font(.jk(9, .heavy)).foregroundColor(gold).monospacedDigit()
                    .padding(.horizontal, 5).background(Color.black.opacity(0.5)).offset(x: 40)
            }
        }
    }
}

/// threat from real AI state: rivals chasing you / searching for you
struct RoamThreat: View {
    let e: TacticalEngine
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { tl in
            let rivals = e.players.filter { !$0.isPlayer && !$0.civ && $0.crew > 0 && !$0.ally && $0.alive }
            let chasing = rivals.filter { $0.targetID == 0 }.count
            let searching = rivals.filter { $0.targetID < 0 && $0.hunt > 0 }.count
            let pulse = 0.5 + 0.5 * sin(tl.date.timeIntervalSinceReferenceDate * 6)
            if chasing > 0 || searching > 0 {
                let hot = chasing > 0
                let col = hot ? Color(red: 1, green: 0.3, blue: 0.26) : Color(red: 1, green: 0.75, blue: 0.2)
                HStack(spacing: 6) {
                    Image(systemName: hot ? "exclamationmark.triangle.fill" : "eye.fill").font(.system(size: 10, weight: .bold))
                    Text(hot ? "PURSUED ×\(chasing)" : "RIVALS SEARCHING").font(.jk(9, .heavy)).tracking(1)
                }
                .foregroundColor(col)
                .padding(.horizontal, 10).frame(height: 22)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .overlay(Capsule().stroke(col.opacity(hot ? 0.5 + 0.5 * pulse : 0.6), lineWidth: 1.4))
                .transition(.opacity)
            }
        }
    }
}

/// shown while you are in the river
struct RoamSwim: View {
    let e: TacticalEngine
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { _ in
            if e.roam.swim {
                HStack(spacing: 5) {
                    Image(systemName: "drop.fill").font(.system(size: 9, weight: .bold))
                    Text("SWIMMING · SLOW").font(.jk(8.5, .heavy)).tracking(1)
                }
                .foregroundColor(Color(red: 0.5, green: 0.85, blue: 1))
                .padding(.horizontal, 9).frame(height: 20)
                .background(Capsule().fill(Color.black.opacity(0.55)))
            }
        }
    }
}

/// one event → one card: consequences of a major event (district, REP, phone)
struct RoamEventCard: View {
    @ObservedObject var net = BlokNet.shared
    var body: some View {
        Group {
            if let c = net.card {
                HStack(spacing: 10) {
                    Rectangle().fill(c.color).frame(width: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title).font(.jk(12, .heavy)).tracking(1).foregroundColor(.white)
                        ForEach(c.lines, id: \.self) { l in
                            Text(l).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 7)
                    Spacer(minLength: 0)
                }
                .frame(width: 230)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.04, green: 0.05, blue: 0.08).opacity(0.88)))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(c.color.opacity(0.5), lineWidth: 1))
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(c.id)
            }
        }
        .animation(.easeOut(duration: 0.25), value: net.card?.id)
    }
}

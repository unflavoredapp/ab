import SwiftUI

// MARK: - Shared look for the open-world screens (Map, Crew, Inventory, Shop, Events)

enum OW {
    static let cyan = Color(red: 0.1, green: 0.62, blue: 1)
    static let gold = Color(red: 1, green: 0.75, blue: 0.22)
    static let red = Color(red: 1, green: 0.25, blue: 0.3)
    static let green = Color(red: 0.25, green: 0.85, blue: 0.45)
    static let purple = Color(red: 0.62, green: 0.32, blue: 1)
    static let panel = Color(red: 0.025, green: 0.05, blue: 0.1).opacity(0.88)
    static let panel2 = Color(red: 0.05, green: 0.09, blue: 0.16).opacity(0.9)
    static let edge = Color(red: 0.3, green: 0.6, blue: 1).opacity(0.32)

    static func rarity(_ r: String) -> Color {
        switch r.uppercased() {
        case "LEGENDARY": return gold
        case "EPIC": return purple
        case "RARE": return cyan
        case "UNCOMMON": return green
        default: return Color(white: 0.6)
        }
    }
}

extension View {
    /// dark glass panel with a thin blue edge
    func owPanel(_ u: CGFloat, r: CGFloat = 4, hot: Color? = nil) -> some View {
        self.background(RoundedRectangle(cornerRadius: r * u).fill(OW.panel))
            .overlay(RoundedRectangle(cornerRadius: r * u).stroke(hot ?? OW.edge, lineWidth: hot == nil ? 1 : 1.4))
    }
}

/// page shell: dimmed hideout art, the shared top bar, then the page content
struct OWScreen<Content: View>: View {
    let t: TacData
    let u: CGFloat
    let selected: Int
    let act: (LobbyAct) -> Void
    var dim: Double = 0.72
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(dim).ignoresSafeArea()
            VStack(spacing: 0) {
                LobbyTopBar(t: t, u: u, selected: selected, act: act)
                content()
            }
        }
    }
}

/// big cyan call-to-action used on the map, shop and events screens
struct OWButton: View {
    let u: CGFloat
    let icon: String?
    let title: String
    var sub: String? = nil
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * u) {
                if let i = icon { Image(systemName: i).font(.system(size: 14 * u, weight: .bold)) }
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.jk(11.5 * u, .heavy)).tracking(0.5 * u)
                    if let s = sub { Text(s).font(.jk(6.5 * u, .medium)).opacity(0.85) }
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(filled ? .black : .white)
            .padding(.horizontal, 12 * u).frame(maxWidth: .infinity).frame(height: 30 * u)
            .background(RoundedRectangle(cornerRadius: 3 * u).fill(filled ? OW.cyan : OW.panel2))
            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(filled ? Color.white.opacity(0.4) : OW.edge, lineWidth: 1))
            .shadow(color: filled ? OW.cyan.opacity(0.5) : .clear, radius: 7 * u)
        }.buttonStyle(.plain)
    }
}

/// small round letter avatar used where the mockups show member portraits
struct OWAvatar: View {
    let name: String
    let s: CGFloat
    var online: Color? = nil
    var body: some View {
        let hues: [Double] = [0.58, 0.02, 0.1, 0.75, 0.35, 0.92]
        let h = hues[name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % hues.count]
        Text(String(name.prefix(1)).uppercased()).font(.jk(s * 0.45, .heavy)).foregroundColor(.white)
            .frame(width: s, height: s)
            .background(Circle().fill(Color(hue: h, saturation: 0.55, brightness: 0.45)))
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                if let o = online { Circle().fill(o).frame(width: s * 0.27, height: s * 0.27).overlay(Circle().stroke(Color.black, lineWidth: 1)) }
            }
    }
}

/// soft city-art strip cropped from the hideout picture (placeholder until real banners exist)
struct OWArt: View {
    let w: CGFloat
    let h: CGFloat
    var anchor = UnitPoint.center
    var zoom: CGFloat = 1
    var tint: Color = .clear
    var body: some View {
        ZStack {
            if let bg = HideoutBackdrop.userBg {
                Image(uiImage: bg).resizable().scaledToFill().frame(width: w, height: h)
                    .scaleEffect(zoom, anchor: anchor).clipped()
            } else {
                LinearGradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.22), Color(red: 0.03, green: 0.04, blue: 0.08)], startPoint: .top, endPoint: .bottom)
            }
            tint.blendMode(.plusLighter).opacity(0.5)
        }
        .frame(width: w, height: h).clipped()
    }
}

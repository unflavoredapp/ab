import SwiftUI

// MARK: - HoodBlok login / title screen
// Dark skyline, big wordmark, spaced gradient tagline. "Accounts" are a callsign stored on the device (and sent to the
// crew server when one is set); there is no password system.

struct HoodLogin: View {
    let done: () -> Void
    @State private var name = UserDefaults.standard.string(forKey: "ab.playername") ?? ""
    @State private var shown = false
    @FocusState private var focus: Bool

    private let tagline = Array("OWN THE BLOCK")
    private let ramp: [Color] = [Color(red: 1, green: 0.82, blue: 0.3), Color(red: 1, green: 0.65, blue: 0.22), Color(red: 1, green: 0.5, blue: 0.2), Color(red: 0.95, green: 0.3, blue: 0.2)]

    private func skyline(_ ctx: inout GraphicsContext, _ sz: CGSize) {
        var seed: UInt64 = 7
        func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
        var x: CGFloat = -10
        while x < sz.width {
            let w = 28 + rnd() * 60, h = sz.height * (0.18 + rnd() * 0.42)
            ctx.fill(Path(CGRect(x: x, y: sz.height * 0.78 - h, width: w, height: h + sz.height)), with: .color(Color(white: 0.07 + rnd() * 0.03)))
            x += w + 2 + rnd() * 6
        }
        ctx.fill(Path(CGRect(x: 0, y: sz.height * 0.78, width: sz.width, height: sz.height)), with: .linearGradient(Gradient(colors: [Color(white: 0.05), .black]), startPoint: CGPoint(x: 0, y: sz.height * 0.78), endPoint: CGPoint(x: 0, y: sz.height)))
    }

    var body: some View {
        GeometryReader { g in
            let u = min(g.size.width / 1024, g.size.height / 470)
            ZStack {
                Color.black.ignoresSafeArea()
                Canvas { ctx, sz in skyline(&ctx, sz) }.opacity(0.55).ignoresSafeArea()
                LinearGradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.25), Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                VStack(spacing: 0) {
                    Image("HoodLogo").resizable().scaledToFit().frame(height: 62 * u).padding(.bottom, 8 * u)
                    Text("HOODBLOK").font(.jk(64 * u, .heavy)).tracking(2 * u).foregroundColor(.white).minimumScaleFactor(0.5).lineLimit(1)
                    HStack(spacing: 11 * u) {
                        ForEach(0..<tagline.count, id: \.self) { i in
                            Text(String(tagline[i])).font(.jk(19 * u, .heavy)).foregroundColor(tagline[i] == " " ? .clear : ramp[min(ramp.count - 1, i * ramp.count / tagline.count)])
                        }
                    }
                    .padding(.top, 2 * u).padding(.bottom, 22 * u)
                    TextField("", text: $name, prompt: Text("YOUR CALLSIGN").foregroundColor(.white.opacity(0.35)))
                        .font(.jk(13 * u, .heavy)).tracking(1.5 * u).multilineTextAlignment(.center).foregroundColor(.white)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled(true).focused($focus)
                        .frame(width: 230 * u, height: 32 * u)
                        .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(Color.white.opacity(focus ? 0.7 : 0.25), lineWidth: 1))
                        .onSubmit { go() }
                    Button { go() } label: {
                        Text("ENTER THE BLOCK").font(.jk(12.5 * u, .heavy)).tracking(1.5 * u).foregroundColor(.white)
                            .frame(width: 230 * u, height: 34 * u)
                            .background(RoundedRectangle(cornerRadius: 3 * u).fill(Color(red: 0.8, green: 0.2, blue: 0.16)))
                            .overlay(RoundedRectangle(cornerRadius: 3 * u).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }.buttonStyle(.plain).padding(.top, 8 * u)
                    Button { name = ""; go() } label: {
                        Text("PLAY AS GUEST").font(.jk(8.5 * u, .heavy)).tracking(1.2 * u).foregroundColor(.white.opacity(0.6))
                    }.buttonStyle(.plain).padding(.top, 9 * u)
                }
                .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 10 * u)
                Text("v1.0").font(.jk(8 * u, .medium)).foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(10 * u)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { shown = true } }
    }

    private func go() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(n.isEmpty ? "GUEST\(Int.random(in: 100...999))" : String(n.prefix(16)), forKey: "ab.playername")
        UserDefaults.standard.set(true, forKey: "ab.loggedin")
        done()
    }
}

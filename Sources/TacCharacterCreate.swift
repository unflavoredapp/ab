import SwiftUI

/// "Create a character": shown the first time the game loads (and again after a character reset).
/// The hideout, the new character standing in it, and a small dialog with a nickname and a gender.
struct CharacterCreateView: View {
    let done: () -> Void

    @State private var nick = ""
    @State private var gender = 0
    @State private var variant = Int.random(in: 0..<6)
    @State private var warn = ""
    @FocusState private var focused: Bool

    private let blue = Color(red: 0.16, green: 0.42, blue: 0.78)

    private var look: AvatarLook { TacProfile.newLook(gender: gender, variant: variant) }
    private var trimmed: String { TacProfile.cleanName(nick) }
    private var valid: Bool { TacProfile.nameRange.contains(trimmed.count) }

    private func submit() {
        guard valid else {
            warn = "Nickname must be \(TacProfile.nameRange.lowerBound)-\(TacProfile.nameRange.upperBound) characters."
            return
        }
        focused = false
        TacProfile.create(name: trimmed, gender: gender, variant: variant)
        done()
    }

    private func cancel() {
        focused = false
        nick = ""
        gender = 0
        warn = ""
    }

    private func flip() {
        gender = 1 - gender
        warn = ""
    }

    private func arrow(_ name: String) -> some View {
        Button(action: flip) {
            SF(name).font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.75))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(TuiPress())
    }

    private func actionButton(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.jk(13, .heavy)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 26)
                .background(fill)
                .overlay(Rectangle().stroke(Color.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private var dialog: some View {
        VStack(spacing: 0) {
            Text("Create a character").font(.jk(14, .heavy)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 24)
                .background(Color.white.opacity(0.08))
            VStack(spacing: 5) {
                HStack(spacing: 8) {
                    Text("Nick name").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.85)).frame(width: 58, alignment: .leading)
                    TextField("", text: $nick, prompt: Text("Enter nickname").foregroundColor(.white.opacity(0.35)))
                        .font(.jk(13, .semibold)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                        .focused($focused)
                        .onSubmit { focused = false }
                        .frame(height: 24)
                        .background(Color.black.opacity(0.5))
                        .overlay(Rectangle().stroke(focused ? blue : Color.white.opacity(0.25), lineWidth: 1))
                }
                HStack(spacing: 10) {
                    Text("Gender").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.85)).frame(width: 58, alignment: .leading)
                    HStack(spacing: 0) {
                        arrow("chevron.left")
                        Text(TacProfile.genderNames[gender]).font(.jk(13, .semibold)).foregroundColor(.white).frame(maxWidth: .infinity)
                        arrow("chevron.right")
                    }
                    .frame(height: 24)
                    .background(Color.white.opacity(0.1))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                Text(warn).font(.jk(10, .medium)).foregroundColor(TUI.red).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(height: 10)
                HStack(spacing: 8) {
                    actionButton("OK", fill: blue, action: submit)
                    actionButton("Cancel", fill: Color.white.opacity(0.12), action: cancel)
                }
            }
            .padding(.horizontal, 10).padding(.top, 7).padding(.bottom, 9)
        }
        .frame(width: 250)
        .background(Color(red: 0.07, green: 0.075, blue: 0.085).opacity(0.94))
        .overlay(Rectangle().stroke(Color.white.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
    }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            ZStack {
                // the hero stands in the 3D hideout behind this screen (HideoutBackdrop in Lobby.swift)
                HStack(spacing: 10) {
                    AirbladeLogo(size: 17)
                    Rectangle().fill(Color.white.opacity(0.3)).frame(width: 1, height: 16)
                    Text("CharacterCreation").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.black.opacity(0.55))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 12).padding(.top, 10)
                dialog
                    .position(x: W / 2, y: focused ? H * 0.34 : H - 76)
                    .animation(.easeOut(duration: 0.2), value: focused)
            }
            .frame(width: W, height: H)
            .contentShape(Rectangle())
            .onTapGesture { focused = false }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: nick) { v in
            if v.count > TacProfile.nameRange.upperBound { nick = String(v.prefix(TacProfile.nameRange.upperBound)) }
            if !warn.isEmpty { warn = "" }
        }
    }
}

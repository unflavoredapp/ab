import SwiftUI

/// The AIRBLADE hero shown in the hideout, the character creation screen and the search screen.
/// For now this is the single character art (front view; the back view is kept for the chase view).
struct AirbladeHero: View {
    var back = false

    var body: some View {
        Image(back ? "HeroBack" : "HeroFront")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .shadow(color: .black.opacity(0.55), radius: 10, y: 4)
    }
}

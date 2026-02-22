import SwiftUI

struct LiquidProgressBar: View {
    let progress: Double
    var isActive = false

    private var clampedProgress: Double {
        max(0, min(1, progress))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fill = max(isActive ? 8 : 0, width * clampedProgress)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.18))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    )

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.68, blue: 0.58),
                                Color(red: 0.20, green: 0.82, blue: 0.89),
                                Color(red: 0.17, green: 0.56, blue: 0.90)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fill)
                    .shadow(color: Color(red: 0.18, green: 0.68, blue: 0.80).opacity(0.35), radius: 8, y: 4)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.25))
                            .frame(height: 6)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3),
                        alignment: .top
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: clampedProgress)
            }
        }
        .frame(height: 18)
    }
}

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

extension View {
    func glassPanel(radius: CGFloat = 24) -> some View {
        modifier(GlassPanel(radius: radius))
    }
}

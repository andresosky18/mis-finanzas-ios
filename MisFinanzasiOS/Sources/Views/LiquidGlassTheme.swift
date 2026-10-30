import SwiftUI
import UIKit

// MARK: - Sistema de Diseño "Liquid Glass" (iOS 26 / iOS 27 UIKit + SwiftUI)

struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base profunda espacial
            (colorScheme == .dark ? Color(hex: "#06070D") : Color(hex: "#EEF2FF"))
                .ignoresSafeArea()

            // Orbes de luz líquida para refracción del cristal (Liquid Glass)
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#6366F1").opacity(colorScheme == .dark ? 0.38 : 0.22),
                                    Color(hex: "#4F46E5").opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: geo.size.width * 0.65
                            )
                        )
                        .frame(width: geo.size.width * 1.1, height: geo.size.width * 1.1)
                        .offset(x: -geo.size.width * 0.32, y: -geo.size.height * 0.18)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#8B5CF6").opacity(colorScheme == .dark ? 0.30 : 0.18),
                                    Color(hex: "#EC4899").opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
                        .offset(x: geo.size.width * 0.38, y: geo.size.height * 0.12)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#10B981").opacity(colorScheme == .dark ? 0.22 : 0.15),
                                    Color(hex: "#06B6D4").opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: geo.size.width * 0.55
                            )
                        )
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.48)
                }
                .blur(radius: 40)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Modificador de Tarjeta Liquid Glass con Refracción y Borde Especular
struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 26
    var tint: Color = .clear
    var tintOpacity: Double = 0.12
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Material nativo translúcido de iOS
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Tinte líquido sutil
                    if tint != .clear {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(colorScheme == .dark ? tintOpacity : tintOpacity * 0.8),
                                        tint.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Brillo superficial diagonal (efecto lente húmedo iOS 27)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55),
                                    Color.white.opacity(0.01),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                // Borde especular de cristal líquido (más brillante arriba/izquierda, suave abajo/derecha)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.38 : 0.85),
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.30),
                                tint == .clear
                                    ? Color.white.opacity(colorScheme == .dark ? 0.05 : 0.20)
                                    : tint.opacity(0.35),
                                Color.white.opacity(colorScheme == .dark ? 0.20 : 0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.07),
                radius: 18,
                x: 0,
                y: 10
            )
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 26,
        tint: Color = .clear,
        tintOpacity: Double = 0.14
    ) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, tint: tint, tintOpacity: tintOpacity))
    }
}

// MARK: - Botón Cápsula Liquid Glass con Física Elástica
struct LiquidScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - Barra de Progreso Liquid Glass con Brillo Neón Suave
struct LiquidProgressBar: View {
    let progress: Double // 0.0 ... 1.0
    var colors: [Color] = [Color(hex: "#6366F1"), Color(hex: "#06B6D4")]
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let clamped = min(1.0, max(0.0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.09))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )

                if clamped > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(height, geo.size.width * clamped))
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.42), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .padding(1.5)
                        )
                        .shadow(color: (colors.first ?? .blue).opacity(0.45), radius: 6, y: 2)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: clamped)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Anillo Circular Liquid Glass (Gauge Nativo)
struct LiquidCircularRing: View {
    let progress: Double
    var color: Color = Color(hex: "#6366F1")
    var size: CGFloat = 52
    var lineWidth: CGFloat = 6

    var body: some View {
        let clamped = min(1.0, max(0.0, progress))
        ZStack {
            Circle()
                .stroke(color.opacity(0.16), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.75), color, color.opacity(0.9)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 4)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clamped)

            Text("\(Int(round(clamped * 100)))%")
                .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Logo Oficial AW (favicon.ico + aw.png embebido y en Bundle)
struct AWLogoView: View {
    var size: CGFloat = 78
    var cornerRadius: CGFloat = 24

    // Base64 exacto del favicon.ico (64x64 PNG #CD1713 con emblema AW blanco)
    private static let faviconBase64 = "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"

    private var logoUIImage: UIImage? {
        if let path = Bundle.main.path(forResource: "AppIcon60x60@3x", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        if let data = Data(base64Encoded: Self.faviconBase64),
           let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let uiImage = logoUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.65), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(1.0, size * 0.018)
                            )
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(hex: "#CD1713"))
                    .frame(width: size, height: size)
                    .overlay(
                        Text("AW")
                            .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

struct AWDesignBannerView: View {
    var height: CGFloat = 22

    private var bannerUIImage: UIImage? {
        if let path = Bundle.main.path(forResource: "aw_banner", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        return nil
    }

    var body: some View {
        if let uiImage = bannerUIImage {
            Image(uiImage: uiImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: height)
        } else {
            HStack(spacing: 4) {
                AWLogoView(size: height, cornerRadius: height * 0.28)
                Text("AW design")
                    .font(.system(size: height * 0.65, weight: .heavy, design: .rounded))
            }
        }
    }
}

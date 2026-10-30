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

import SwiftUI

@main
struct MisFinanzasApp: App {
    @StateObject private var vm = FinanzasViewModel()
    @AppStorage("ios_dark_mode") private var isDarkMode: Bool = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if vm.isUnlocked {
                    MainTabView()
                        .environmentObject(vm)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    LockScreenView()
                        .environmentObject(vm)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// MARK: - Pantalla de Desbloqueo iOS 27 "Liquid Glass" (Face ID + Teclado Circular de Cristal)
struct LockScreenView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var enteredPin: String = ""
    @State private var shakeOffset: CGFloat = 0

    private let keypadRows: [[ KeypadKey ]] = [
        [.init(digit: "1", letters: " "), .init(digit: "2", letters: "ABC"), .init(digit: "3", letters: "DEF")],
        [.init(digit: "4", letters: "GHI"), .init(digit: "5", letters: "JKL"), .init(digit: "6", letters: "MNO")],
        [.init(digit: "7", letters: "PQRS"), .init(digit: "8", letters: "TUV"), .init(digit: "9", letters: "WXYZ")]
    ]

    struct KeypadKey: Identifiable {
        var id: String { digit }
        let digit: String
        let letters: String
    }

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 26) {
                Spacer(minLength: 20)

                // Emblema Liquid Glass con refracción especular
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "#6366F1").opacity(0.55), Color.clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 54
                            )
                        )
                        .frame(width: 108, height: 108)

                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .frame(width: 78, height: 78)

                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#6366F1").opacity(0.65),
                                        Color(hex: "#4F46E5").opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 78, height: 78)

                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.75), Color.white.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                            .frame(width: 78, height: 78)

                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
                    }
                    .shadow(color: Color(hex: "#6366F1").opacity(0.45), radius: 20, y: 10)
                }

                // Saludo y estado
                VStack(spacing: 6) {
                    Text("Hola, Andrés")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    Text(vm.errorMessage ?? "Ingresa tu código o usa Face ID")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(vm.errorMessage != nil ? Color(hex: "#F87171") : .secondary)
                }

                // Indicadores de PIN de Cristal Líquido (4 Orbes)
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        let isFilled = index < enteredPin.count
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 18, height: 18)

                            Circle()
                                .fill(
                                    isFilled
                                        ? LinearGradient(
                                            colors: [Color(hex: "#818CF8"), Color(hex: "#06B6D4")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.clear, Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .frame(width: 18, height: 18)

                            Circle()
                                .strokeBorder(
                                    isFilled ? Color.white.opacity(0.85) : Color.primary.opacity(0.28),
                                    lineWidth: 1.3
                                )
                                .frame(width: 18, height: 18)
                        }
                        .scaleEffect(isFilled ? 1.15 : 1.0)
                        .shadow(color: isFilled ? Color(hex: "#6366F1").opacity(0.65) : .clear, radius: 8)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: enteredPin.count)
                    }
                }
                .offset(x: shakeOffset)
                .padding(.vertical, 6)

                // Teclado Numérico Circular Liquid Glass (Estilo iOS Lock Screen)
                VStack(spacing: 16) {
                    ForEach(0..<keypadRows.count, id: \.self) { rowIdx in
                        HStack(spacing: 24) {
                            ForEach(keypadRows[rowIdx]) { key in
                                LiquidKeypadButton(digit: key.digit, letters: key.letters) {
                                    appendDigit(key.digit)
                                }
                            }
                        }
                    }

                    // Fila inferior: Face ID | 0 | Borrar
                    HStack(spacing: 24) {
                        Button {
                            vm.triggerHaptic(.light)
                            vm.authenticateWithBiometrics()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 76, height: 76)
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.42), Color.white.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.1
                                    )
                                    .frame(width: 76, height: 76)
                                Image(systemName: "faceid")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(Color(hex: "#818CF8"))
                            }
                        }
                        .buttonStyle(LiquidScaleButtonStyle())

                        LiquidKeypadButton(digit: "0", letters: "+") {
                            appendDigit("0")
                        }

                        Button {
                            guard !enteredPin.isEmpty else { return }
                            vm.triggerHaptic(.light)
                            enteredPin.removeLast()
                            vm.errorMessage = nil
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 76, height: 76)
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.06)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.1
                                    )
                                    .frame(width: 76, height: 76)
                                Image(systemName: enteredPin.isEmpty ? "lock.shield.fill" : "delete.left.fill")
                                    .font(.system(size: 23, weight: .semibold))
                                    .foregroundColor(.primary.opacity(0.8))
                            }
                        }
                        .buttonStyle(LiquidScaleButtonStyle())
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            vm.errorMessage = nil
        }
    }

    private func appendDigit(_ digit: String) {
        guard enteredPin.count < 4 else { return }
        vm.triggerHaptic(.light)
        vm.errorMessage = nil
        enteredPin.append(digit)

        if enteredPin.count == 4 {
            let code = enteredPin
            Task {
                try? await Task.sleep(nanoseconds: 110_000_000)
                let ok = await vm.unlockWithPin(code)
                if !ok {
                    triggerShake()
                    enteredPin = ""
                }
            }
        }
    }

    private func triggerShake() {
        withAnimation(.default) { shakeOffset = 14 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) { shakeOffset = -14 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { shakeOffset = 0 }
        }
    }
}

// MARK: - Botón Individual del Teclado Circular Liquid Glass
struct LiquidKeypadButton: View {
    let digit: String
    let letters: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.65),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.45 : 0.90),
                                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: 76, height: 76)

                VStack(spacing: 0) {
                    Text(digit)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    if !letters.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(letters)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 10, y: 5)
        }
        .buttonStyle(LiquidScaleButtonStyle())
    }
}

import SwiftUI

@main
struct MisFinanzasApp: App {
    @StateObject private var vm = FinanzasViewModel()
    @AppStorage("ios_dark_mode") private var isDarkMode: Bool = true

    var body: some Scene {
        WindowGroup {
            Group {
                if vm.isUnlocked {
                    MainTabView()
                        .environmentObject(vm)
                } else {
                    LockScreenView()
                        .environmentObject(vm)
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// MARK: - Pantalla de Desbloqueo Nativa con Face ID y PIN
struct LockScreenView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var pinInput: String = ""
    @State private var showServerSheet: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 76, height: 76)
                        .shadow(color: Color(hex: "#4F46E5").opacity(0.45), radius: 16, y: 8)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("Mis Finanzas Pro")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(.white)

                    Text("Ingresa tu PIN o usa Face ID para sincronizar con tu servidor.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .multilineTextAlignment(.center)
                }

                SecureField("••••", text: $pinInput)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .frame(width: 220)
                    .background(Color(white: 0.11))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(white: 0.22), lineWidth: 1)
                    )
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            let code = pinInput.isEmpty ? vm.savedPin : pinInput
                            _ = await vm.unlockWithPin(code)
                        }
                    } label: {
                        HStack {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "lock.open.fill")
                                Text("Entrar")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(width: 150, height: 50)
                        .background(LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    Button {
                        vm.authenticateWithBiometrics()
                    } label: {
                        Image(systemName: "faceid")
                            .font(.system(size: 24))
                            .frame(width: 54, height: 50)
                            .background(Color(white: 0.14))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                }

                Spacer()

                Button {
                    showServerSheet = true
                } label: {
                    Label("Configurar URL de InfinityFree", systemImage: "server.rack")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#818CF8"))
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            pinInput = vm.savedPin
        }
        .sheet(isPresented: $showServerSheet) {
            ServerSettingsSheet()
                .environmentObject(vm)
        }
    }
}

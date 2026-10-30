import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @AppStorage("ios_dark_mode") private var isDarkMode: Bool = true
    @State private var showServerSettings = false
    @State private var selectedTab: Int = 0

    init() {
        // Configurar UIKit TabBar y NavigationBar con blur translúcido Liquid Glass
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ResumenView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Resumen", systemImage: "square.grid.2x2.fill")
            }
            .tag(0)

            NavigationStack {
                QuincenaView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Quincena", systemImage: "checklist")
            }
            .tag(1)

            NavigationStack {
                DeudasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Deudas", systemImage: "creditcard.fill")
            }
            .tag(2)

            NavigationStack {
                MetasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Metas", systemImage: "sparkles")
            }
            .tag(3)
        }
        .tint(Color(hex: "#818CF8"))
        .onChange(of: selectedTab) { _ in
            vm.triggerHaptic(.light)
        }
        .sheet(isPresented: $showServerSettings) {
            ServerSettingsSheet()
                .environmentObject(vm)
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6366F1"), Color(hex: "#06B6D4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.9)
                        )
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Finance.")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                vm.triggerHaptic(.light)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isDarkMode.toggle()
                }
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 15, weight: .semibold))
            }

            Menu {
                Section(vm.syncStatusText) {
                    Button {
                        showServerSettings = true
                    } label: {
                        Label("Seguridad y Nube (Opcional)", systemImage: "icloud.and.arrow.up")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        vm.triggerHaptic(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            vm.isUnlocked = false
                        }
                    } label: {
                        Label("Bloquear Billetera", systemImage: "lock.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
}

// MARK: - Hoja Opcional de Seguridad (PIN) y Sincronización en la Nube
struct ServerSettingsSheet: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Código PIN de 4 dígitos (ej. 1234)", text: $vm.savedPin)
                        .keyboardType(.numberPad)
                } header: {
                    Text("PIN de Desbloqueo")
                } footer: {
                    Text("Este código protege tu app junto con Face ID. Por defecto es 1234.")
                }

                Section {
                    TextField("Opcional: https://tusitio.rf.gd/api_finanzas.php", text: $vm.apiURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Sincronización Web (Opcional)")
                } footer: {
                    Text("Tus datos ya funcionan y se guardan 100% en tu iPhone automáticamente. Solo llena este campo si deseas sincronizar también con tu página web.")
                }

                Section {
                    Button {
                        Task {
                            await vm.fetchAllData()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Guardar Ajustes", systemImage: "checkmark.circle.fill")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Seguridad y Nube")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

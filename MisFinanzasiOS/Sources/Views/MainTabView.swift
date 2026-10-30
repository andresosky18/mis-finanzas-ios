import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @AppStorage("ios_dark_mode") private var isDarkMode: Bool = true
    @State private var showServerSettings = false
    @State private var selectedTab: Int = 0

    // IMPORTANTE: No sobreescribir UITabBar.appearance() ni UINavigationBar.appearance()
    // para que iOS 26 / iOS 27 active automáticamente la barra TabView flotante en cápsula
    // Liquid Glass y los botones superiores flotantes nativos del sistema.

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
        .tint(Color(hex: "#6366F1"))
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
                AWLogoView(size: 28, cornerRadius: 8)
                Text("Mis Finanzas")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                Task { await vm.fetchAllData() }
            } label: {
                if vm.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }

            Button {
                vm.triggerHaptic(.light)
                isDarkMode.toggle()
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.stars.fill")
            }

            Menu {
                Section(vm.syncStatusText) {
                    Button {
                        Task { await vm.fetchAllData() }
                    } label: {
                        Label("Sincronizar con pagos.xo.je", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button {
                        showServerSettings = true
                    } label: {
                        Label("Ajustes de Servidor y PIN", systemImage: "server.rack")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        vm.triggerHaptic(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            vm.isUnlocked = false
                        }
                    } label: {
                        Label("Bloquear App", systemImage: "lock.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Hoja de Ajustes de Servidor (Preconfigurada con pagos.xo.je)
struct ServerSettingsSheet: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://pagos.xo.je/mis_finanzas.php?i=1", text: $vm.apiURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Servidor Conectado en Vivo")
                } footer: {
                    Text("Conectado directamente a tu base de datos real en pagos.xo.je.")
                }

                Section("PIN de Desbloqueo") {
                    SecureField("Código PIN (por defecto 1234)", text: $vm.savedPin)
                        .keyboardType(.numberPad)
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
                            Label("Sincronizar Ahora", systemImage: "checkmark.circle.fill")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Conexión pagos.xo.je")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

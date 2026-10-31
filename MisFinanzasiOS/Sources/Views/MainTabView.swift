import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @AppStorage("ios_dark_mode") private var isDarkMode: Bool = false
    @State private var showServerSettings = false
    @State private var selectedTab: Int = 0

    // iOS 26 / iOS 27 activa automáticamente la barra TabView flotante en cápsula Liquid Glass
    // cuando el binario está estampado con SDK 26.0 y UIDesignRequiresCompatibility = false.

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ResumenView(selectedTab: $selectedTab)
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Inicio", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                QuincenaView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Pagos", systemImage: "checklist")
            }
            .tag(1)

            NavigationStack {
                TarjetasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Tarjetas", systemImage: "applewatch")
            }
            .tag(2)

            NavigationStack {
                DeudasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Deudas", systemImage: "creditcard.fill")
            }
            .tag(3)

            NavigationStack {
                MetasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Ahorro", systemImage: "chart.bar.fill")
            }
            .tag(4)
        }
        .tint(Color(hex: "#4F46E5"))
        .onChange(of: selectedTab) { _ in
            vm.triggerHaptic(.light)
        }
        .onChange(of: vm.navigateToTab) { newTab in
            if let tab = newTab {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedTab = tab
                }
                vm.navigateToTab = nil
            }
        }
        .sheet(isPresented: $showServerSettings) {
            ServerSettingsSheet()
                .environmentObject(vm)
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        // Cápsula Izquierda estilo "Household / Good Morning" con Logo Oficial AW
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 9) {
                AWLogoView(size: 30, cornerRadius: 15)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Hola, Andrés")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("Mis Finanzas")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }

        // Cápsula Derecha Unida "+  •••" (Idéntica a la referencia iOS 27 Household)
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

            Menu {
                Section("Apariencia y Seguridad") {
                    Button {
                        vm.triggerHaptic(.light)
                        isDarkMode.toggle()
                    } label: {
                        Label(
                            isDarkMode ? "Cambiar a Modo Claro" : "Cambiar a Modo Oscuro",
                            systemImage: isDarkMode ? "sun.max.fill" : "moon.stars.fill"
                        )
                    }

                    Button {
                        showServerSettings = true
                    } label: {
                        Label("Configurar PIN y Conexión", systemImage: "slider.horizontal.3")
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
                Image(systemName: "ellipsis")
            }
        }
    }
}

struct ServerSettingsSheet: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("PIN de Seguridad") {
                    SecureField("Código PIN (4 dígitos)", text: $vm.savedPin)
                        .keyboardType(.numberPad)
                }

                Section("Servidor en la Nube") {
                    TextField("URL de sincronización", text: $vm.apiURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
                            Label("Guardar y Sincronizar", systemImage: "checkmark.circle.fill")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
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

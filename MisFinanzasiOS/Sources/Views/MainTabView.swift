import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @AppStorage("ios_dark_mode") private var isDarkMode: Bool = true
    @State private var showServerSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                ResumenView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Resumen", systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                QuincenaView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Quincena", systemImage: "checklist.checked")
            }

            NavigationStack {
                DeudasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Deudas", systemImage: "creditcard.fill")
            }

            NavigationStack {
                MetasView()
                    .toolbar { toolbarButtons }
            }
            .tabItem {
                Label("Metas", systemImage: "target")
            }
        }
        .tint(Color(hex: "#6366F1"))
        .task {
            await vm.fetchAllData()
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Finance.")
                    .font(.system(size: 17, weight: .heavy))
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
                isDarkMode.toggle()
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
            }

            Menu {
                Button {
                    showServerSettings = true
                } label: {
                    Label("Conexión InfinityFree", systemImage: "server.rack")
                }

                Button(role: .destructive) {
                    vm.isUnlocked = false
                } label: {
                    Label("Bloquear App", systemImage: "lock.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Hoja de Configuración de URL de InfinityFree y PIN
struct ServerSettingsSheet: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Servidor InfinityFree (MySQL + PHP)") {
                    TextField("https://tudominio.infinityfreeapp.com/api_finanzas.php", text: $vm.apiURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("PIN de Seguridad") {
                    SecureField("PIN (por defecto 1234)", text: $vm.savedPin)
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
                            Text("Guardar y Sincronizar Ahora")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Conexión al Servidor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}

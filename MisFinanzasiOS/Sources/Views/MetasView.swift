import SwiftUI
import UIKit

struct MetasView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAbonoCorvanca = false
    @State private var montoCorvanca = "75000"

    @State private var metaSeleccionada: MetaItem?
    @State private var montoMeta = ""

    @State private var showNuevaMeta = false
    @State private var nombreNuevaMeta = ""
    @State private var totalNuevaMeta = ""
    @State private var iconoNuevaMeta = "target"

    var body: some View {
        let f = vm.finanzas
        let aportesCorvanca = f.historial.filter { $0.concepto.localizedCaseInsensitiveContains("corvanca") }

        List {
            // 1. FONDO DE AHORRO BASE (CORVANCA) EN VIVO ($1,575,000)
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("AHORRO BASE (CORVANCA)", systemImage: "building.columns.fill")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.88))
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Text(f.ahorroCorvanca.copFormatted)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("Aporte quincenal en nómina: $75.000")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))

                    Button {
                        montoCorvanca = "75000"
                        showAbonoCorvanca = true
                    } label: {
                        Label("Abonar a Corvanca", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .foregroundColor(Color(hex: "#4F46E5"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#4F46E5"), Color(hex: "#7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
            }

            // 2. WISHLIST & METAS
            Section {
                if f.metasLista.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#8B5CF6"))
                        Text("No tienes metas en tu Wishlist ahora mismo")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("Crea una nueva meta personal para empezar a fondearla poco a poco.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            nombreNuevaMeta = ""
                            totalNuevaMeta = ""
                            iconoNuevaMeta = "target"
                            showNuevaMeta = true
                        } label: {
                            Label("Crear Nueva Meta", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#8B5CF6"))
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(f.metasLista) { meta in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: SFIconMapper.symbol(for: meta.icono))
                                    .foregroundColor(Color(hex: "#8B5CF6"))
                                Text(meta.nombre)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                Spacer()
                                if meta.completada {
                                    Text("¡Logrado! 🎉")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundColor(Color(hex: "#10B981"))
                                } else {
                                    Button {
                                        montoMeta = "100000"
                                        metaSeleccionada = meta
                                    } label: {
                                        Text("Fondear")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(Color(hex: "#8B5CF6").opacity(0.18))
                                            .foregroundColor(Color(hex: "#8B5CF6"))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            ProgressView(value: meta.porcentaje)
                                .tint(Color(hex: "#8B5CF6"))

                            HStack {
                                Text(meta.actual.copFormatted)
                                Spacer()
                                Text(meta.total.copFormatted)
                            }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await vm.sendAction([
                                        "accion": "eliminar_meta",
                                        "meta_eliminar": meta.nombre
                                    ])
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash.fill")
                            }
                        }
                    }

                    Button {
                        nombreNuevaMeta = ""
                        totalNuevaMeta = ""
                        iconoNuevaMeta = "target"
                        showNuevaMeta = true
                    } label: {
                        Label("Añadir Otra Meta", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                }
            } header: {
                Text("Wishlist & Metas")
            }

            // 3. HISTORIAL DE APORTES CORVANCA
            if !aportesCorvanca.isEmpty {
                Section("Últimos Aportes a Corvanca") {
                    ForEach(aportesCorvanca.prefix(8)) { h in
                        HStack {
                            Label(h.fecha, systemImage: "leaf.fill")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("+\(h.monto.copFormatted)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Metas y Ahorro")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showAbonoCorvanca) {
            NavigationStack {
                Form {
                    Section("Aporte a Corvanca") {
                        TextField("Monto a sumar ($)", text: $montoCorvanca)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickAmountChip(title: "$75.000") { montoCorvanca = "75000" }
                                QuickAmountChip(title: "$150.000") { montoCorvanca = "150000" }
                                QuickAmountChip(title: "$300.000") { montoCorvanca = "300000" }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Section {
                        Button {
                            guard let val = Double(montoCorvanca), val > 0 else { return }
                            Task {
                                await vm.sendAction(["accion": "abonar_ahorro", "monto": val])
                                showAbonoCorvanca = false
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Abonar en pagos.xo.je", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Aporte Corvanca")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAbonoCorvanca = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $metaSeleccionada) { m in
            NavigationStack {
                Form {
                    Section("Fondear \(m.nombre)") {
                        TextField("Monto a inyectar ($)", text: $montoMeta)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                    }
                    Section {
                        Button {
                            guard let val = Double(montoMeta), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_meta",
                                    "meta": m.nombre,
                                    "monto": val
                                ])
                                metaSeleccionada = nil
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Fondear Meta", systemImage: "sparkles")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Fondear Meta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { metaSeleccionada = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNuevaMeta) {
            NavigationStack {
                Form {
                    Section("Nueva Meta de Ahorro") {
                        TextField("¿Qué quieres lograr?", text: $nombreNuevaMeta)
                        TextField("Costo Total ($)", text: $totalNuevaMeta)
                            .keyboardType(.numberPad)
                        Picker("Ícono", selection: $iconoNuevaMeta) {
                            Text("🎯 Objetivo").tag("target")
                            Text("✈️ Viaje").tag("plane")
                            Text("🏠 Casa / Hogar").tag("home")
                            Text("🚗 Vehículo").tag("car")
                            Text("📱 Tecnología").tag("smartphone")
                        }
                    }
                    Section {
                        Button {
                            guard !nombreNuevaMeta.isEmpty, let tot = Double(totalNuevaMeta), tot > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "agregar_meta",
                                    "nombre_meta": nombreNuevaMeta,
                                    "total_meta": tot,
                                    "icono_meta": iconoNuevaMeta
                                ])
                                showNuevaMeta = false
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Crear Meta", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Crear Meta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showNuevaMeta = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

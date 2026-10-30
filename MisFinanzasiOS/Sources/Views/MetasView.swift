import SwiftUI

struct MetasView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAbonoCorvanca = false
    @State private var montoCorvanca = "75000"

    @State private var metaSeleccionada: MetaItem?
    @State private var montoMeta = ""

    @State private var showNuevaMeta = false
    @State private var nombreNuevaMeta = ""
    @State private var totalNuevaMeta = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let f = vm.finanzas {
                    // AHORRO BASE CORVANCA
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FONDO DE AHORRO BASE (CORVANCA)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white.opacity(0.85))

                        HStack(alignment: .bottom) {
                            Text(f.ahorroCorvanca.copFormatted)
                                .font(.system(size: 32, weight: .heavy))
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                montoCorvanca = "75000"
                                showAbonoCorvanca = true
                            } label: {
                                Label("Abonar", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .foregroundColor(Color(hex: "#4F46E5"))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(colors: [Color(hex: "#4F46E5"), Color(hex: "#7C3AED")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(22)

                    // WISHLIST & METAS
                    HStack {
                        Text("WISHLIST & METAS")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            nombreNuevaMeta = ""
                            totalNuevaMeta = ""
                            showNuevaMeta = true
                        } label: {
                            Label("Nueva Meta", systemImage: "plus")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .padding(.top, 4)

                    ForEach(f.metasLista) { meta in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: SFIconMapper.symbol(for: meta.icono))
                                    .foregroundColor(Color(hex: "#8B5CF6"))
                                Text(meta.nombre)
                                    .font(.system(size: 16, weight: .heavy))
                                Spacer()
                                if meta.completada {
                                    Text("¡Logrado! 🎉")
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(Color(hex: "#10B981"))
                                } else {
                                    Button {
                                        montoMeta = ""
                                        metaSeleccionada = meta
                                    } label: {
                                        Text("Fondear")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .background(Color(hex: "#8B5CF6").opacity(0.18))
                                            .foregroundColor(Color(hex: "#8B5CF6"))
                                            .clipShape(Capsule())
                                    }
                                }
                            }

                            ProgressView(value: meta.porcentaje)
                                .tint(Color(hex: "#8B5CF6"))

                            HStack {
                                Text(meta.actual.copFormatted)
                                Spacer()
                                Text(meta.total.copFormatted)
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        }
                        .padding(18)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Metas y Ahorros")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showAbonoCorvanca) {
            NavigationStack {
                Form {
                    Section("Aporte a Corvanca") {
                        TextField("Monto a sumar ($)", text: $montoCorvanca)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Abonar al Ahorro") {
                            guard let val = Double(montoCorvanca), val > 0 else { return }
                            Task {
                                await vm.sendAction(["accion": "abonar_ahorro", "monto": val])
                                showAbonoCorvanca = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Ahorro Corvanca")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $metaSeleccionada) { m in
            NavigationStack {
                Form {
                    Section("Fondear \(m.nombre)") {
                        TextField("Monto a inyectar ($)", text: $montoMeta)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Inyectar Capital") {
                            guard let val = Double(montoMeta), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_meta",
                                    "meta": m.nombre,
                                    "monto": val
                                ])
                                metaSeleccionada = nil
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Fondear Meta")
                .navigationBarTitleDisplayMode(.inline)
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
                    }
                    Section {
                        Button("Crear Meta") {
                            guard !nombreNuevaMeta.isEmpty, let tot = Double(totalNuevaMeta), tot > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "agregar_meta",
                                    "nombre_meta": nombreNuevaMeta,
                                    "total_meta": tot
                                ])
                                showNuevaMeta = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Crear Meta")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }
}

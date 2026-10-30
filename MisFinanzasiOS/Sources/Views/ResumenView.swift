import SwiftUI

struct ResumenView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showEditNomina = false
    @State private var nuevoSueldo = ""
    @State private var nuevoBono = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let f = vm.finanzas {
                    // HERO CARD: INGRESOS Y DEUDA TOTAL
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("INGRESOS MENSUALES")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Button {
                                nuevoSueldo = String(Int(f.sueldoBase))
                                nuevoBono = String(Int(f.bonoQ1))
                                showEditNomina = true
                            } label: {
                                Label("Ajustar Nómina", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.2))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(f.totalIngresosMensual.copFormatted)
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEUDA CONSOLIDADA")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.75))
                                Text(f.totalDeudaPendiente.copFormatted)
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color(hex: "#FCA5A5"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider().background(Color.white.opacity(0.3))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("AHORRO CORVANCA")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.75))
                                Text(f.ahorroCorvanca.copFormatted)
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(Color(hex: "#6EE7B7"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.22))
                        .cornerRadius(14)
                    }
                    .padding(20)
                    .background(
                        LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(22)

                    // FLUJO DE CAJA QUINCENAL Q1 Y Q2
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FLUJO DE CAJA QUINCENAL")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            QuincenaMetricCard(
                                titulo: "Quincena 1 (Día 10)",
                                neto: f.netoQ1,
                                libre: f.flujoQ1
                            )
                            QuincenaMetricCard(
                                titulo: "Quincena 2 (Día 30)",
                                neto: f.netoQ2,
                                libre: f.flujoQ2
                            )
                        }
                    }

                    // ACTIVIDAD RECIENTE (HISTORIAL CON DESHACER)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ACTIVIDAD RECIENTE")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Toca ↩ para revertir")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        if f.historial.isEmpty {
                            Text("Sin abonos registrados todavía.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(Array(f.historial.prefix(15).enumerated()), id: \.offset) { idx, item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.concepto)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(item.fecha)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("+\(item.monto.copFormatted)")
                                        .font(.system(size: 14, weight: .heavy))
                                        .foregroundColor(Color(hex: "#10B981"))

                                    Button {
                                        Task {
                                            await vm.sendAction([
                                                "accion": "reversar_historial",
                                                "index": idx
                                            ])
                                        }
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                Divider()
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                } else {
                    ProgressView("Cargando tus finanzas...")
                        .padding(.top, 60)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Hola, Andrés")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showEditNomina) {
            NavigationStack {
                Form {
                    Section("Configurar Nómina") {
                        TextField("Sueldo Base ($)", text: $nuevoSueldo)
                            .keyboardType(.numberPad)
                        TextField("Bono Q1 ($)", text: $nuevoBono)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Guardar Cambios") {
                            Task {
                                await vm.sendAction([
                                    "accion": "editar_sueldo",
                                    "nuevo_sueldo": Double(nuevoSueldo) ?? 2500000,
                                    "nuevo_bono": Double(nuevoBono) ?? 160000
                                ])
                                showEditNomina = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Ajustar Nómina")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showEditNomina = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct QuincenaMetricCard: View {
    let titulo: String
    let neto: Double
    let libre: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(neto.copFormatted)
                .font(.system(size: 19, weight: .heavy))
            Text("Libre: \(libre.copFormatted)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(libre >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

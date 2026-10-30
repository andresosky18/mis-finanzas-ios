import SwiftUI
import UIKit
import Charts

struct ResumenView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showEditNomina = false
    @State private var nuevoSueldo = ""
    @State private var nuevoBono = ""
    @State private var selectedSection: Int = 0

    struct ChartSlice: Identifiable {
        var id: String { label }
        let label: String
        let amount: Double
        let color: Color
    }

    var body: some View {
        let f = vm.finanzas
        let slices: [ChartSlice] = [
            .init(label: "Fijos", amount: max(1, f.totalFijosQuincenal), color: Color(hex: "#6366F1")),
            .init(label: "Deudas", amount: max(1, f.totalDeudasQuincenal), color: Color(hex: "#EF4444")),
            .init(label: "Ahorro", amount: max(1, f.totalAhorroQuincenal), color: Color(hex: "#10B981"))
        ]

        List {
            // 1. HERO CARD NATIVO CON BALANCE EN VIVO DE PAGOS.XO.JE
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 7, height: 7)
                            Text(vm.syncStatusText.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .foregroundColor(.white.opacity(0.92))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())

                        Spacer()

                        Button {
                            vm.triggerHaptic(.light)
                            nuevoSueldo = String(Int(f.sueldoBase))
                            nuevoBono = String(Int(f.bonoQ1))
                            showEditNomina = true
                        } label: {
                            Label("Ajustes", systemImage: "slider.horizontal.3")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("INGRESOS DEL MES")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                        Text(f.totalIngresosMensual.copFormatted)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("Sueldo \(f.sueldoBase.copFormatted) + Auxilios + Extras")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("DEUDA PENDIENTE", systemImage: "creditcard.fill")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                            Text(f.totalDeudaPendiente.copFormatted)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#FECDD3"))
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.black.opacity(0.24))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Label("CORVANCA", systemImage: "building.columns.fill")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                            Text(f.ahorroCorvanca.copFormatted)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#A7F3D0"))
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.black.opacity(0.24))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#4F46E5"), Color(hex: "#6366F1"), Color(hex: "#0EA5E9")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
            }

            // 2. FLUJO DE CAJA QUINCENAL (Q1 & Q2)
            Section("Flujo de Caja Quincenal") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Quincena 1")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Día 10")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#6366F1").opacity(0.15))
                                .foregroundColor(Color(hex: "#6366F1"))
                                .clipShape(Capsule())
                        }
                        Text(f.netoQ1.copFormatted)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Label(
                            "Libre: \(f.flujoQ1 >= 0 ? "" : "-")\(abs(f.flujoQ1).copFormatted)",
                            systemImage: f.flujoQ1 >= 0 ? "arrow.up.right.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(f.flujoQ1 >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Quincena 2")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Día 30")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#06B6D4").opacity(0.15))
                                .foregroundColor(Color(hex: "#06B6D4"))
                                .clipShape(Capsule())
                        }
                        Text(f.netoQ2.copFormatted)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Label(
                            "Libre: \(f.flujoQ2 >= 0 ? "" : "-")\(abs(f.flujoQ2).copFormatted)",
                            systemImage: f.flujoQ2 >= 0 ? "arrow.up.right.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(f.flujoQ2 >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
            }

            // 3. GRÁFICO NATIVO DE APPLE CHARTS (DISTRIBUCIÓN QUINCENAL)
            Section("Distribución del Presupuesto") {
                HStack(spacing: 16) {
                    Chart(slices) { slice in
                        BarMark(
                            x: .value("Monto", slice.amount),
                            y: .value("Categoría", slice.label)
                        )
                        .foregroundStyle(slice.color.gradient)
                        .cornerRadius(6)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 105)

                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(slices) { s in
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(s.label)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(s.color)
                                Text(s.amount.copFormatted)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            // 4. CONTROL SEGMENTADO NATIVO DE iOS (HISTORIAL vs NÓMINA)
            Section {
                Picker("Vista", selection: $selectedSection) {
                    Text("Actividad Reciente (\(f.historial.count))").tag(0)
                    Text("Descuentos Nómina").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            if selectedSection == 0 {
                Section {
                    if f.historial.isEmpty {
                        Text("Sin abonos registrados.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(f.historial.enumerated()), id: \.offset) { idx, item in
                            HStack(spacing: 12) {
                                Image(systemName: item.tipo == "ahorro" ? "building.columns.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(item.tipo == "ahorro" ? Color(hex: "#6366F1") : Color(hex: "#10B981"))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.concepto)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    Text(item.fecha)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("+\(item.monto.copFormatted)")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }
                            .padding(.vertical, 2)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await vm.sendAction([
                                            "accion": "reversar_historial",
                                            "index": idx
                                        ])
                                    }
                                } label: {
                                    Label("Deshacer", systemImage: "arrow.uturn.backward")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await vm.sendAction([
                                            "accion": "reversar_historial",
                                            "index": idx
                                        ])
                                    }
                                } label: {
                                    Label("Revertir este abono (\(item.monto.copFormatted))", systemImage: "arrow.uturn.backward")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Historial Sincronizado")
                } footer: {
                    Text("Desliza hacia la izquierda o mantén presionado un movimiento para deshacer el abono.")
                }
            } else {
                Section("Deducciones Automáticas de Nómina") {
                    ForEach(f.deduccionesNomina.keys.sorted(), id: \.self) { key in
                        let val = f.deduccionesNomina[key] ?? 0
                        LabeledContent {
                            Text("-\(val.copFormatted)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#EF4444"))
                        } label: {
                            Label(
                                key,
                                systemImage: key.localizedCaseInsensitiveContains("corvanca") ? "leaf.fill" : "building.2.fill"
                            )
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hola, Andrés")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showEditNomina) {
            NavigationStack {
                Form {
                    Section("Configurar Ingresos de Nómina") {
                        LabeledContent("Sueldo Base ($)") {
                            TextField("2500000", text: $nuevoSueldo)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Bono Q1 ($)") {
                            TextField("160000", text: $nuevoBono)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Section {
                        Button {
                            Task {
                                await vm.sendAction([
                                    "accion": "editar_sueldo",
                                    "nuevo_sueldo": Double(nuevoSueldo) ?? f.sueldoBase,
                                    "nuevo_bono": Double(nuevoBono) ?? f.bonoQ1
                                ])
                                showEditNomina = false
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Guardar Cambios", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Configurar Nómina")
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

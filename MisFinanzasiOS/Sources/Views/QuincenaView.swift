import SwiftUI
import UIKit

struct QuincenaView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAddGasto = false
    @State private var gastoEditar: GastoQuincenalItem?
    @State private var nombreGasto = ""
    @State private var valorGasto = ""
    @State private var labelGasto = ""
    @State private var deudaVinculada = ""
    @State private var filtroEstado: Int = 0 // 0 = Todos, 1 = Pendientes, 2 = Pagados

    var body: some View {
        let f = vm.finanzas
        let pagadosMonto = f.gastosLista.filter { $0.pagado }.reduce(0.0) { $0 + $1.valor }
        let porPagarMonto = max(0, f.totalGastosQuincena - pagadosMonto)

        let gastosFiltrados = f.gastosLista.filter { g in
            switch filtroEstado {
            case 1: return !g.pagado
            case 2: return g.pagado
            default: return true
            }
        }

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // 1. CHIPS DE FILTRO HORIZONTALES (Idénticos a "All | Meat | Vegetables" de Referencia #3 Household)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            HouseholdFilterChip(
                                title: "Todos (\(f.gastosLista.count))",
                                isSelected: filtroEstado == 0
                            ) { filtroEstado = 0 }

                            HouseholdFilterChip(
                                title: "Pendientes (\(f.gastosLista.filter { !$0.pagado }.count))",
                                isSelected: filtroEstado == 1
                            ) { filtroEstado = 1 }

                            HouseholdFilterChip(
                                title: "Pagados (\(f.gastosLista.filter { $0.pagado }.count))",
                                isSelected: filtroEstado == 2
                            ) { filtroEstado = 2 }

                            Button {
                                nombreGasto = ""
                                valorGasto = ""
                                labelGasto = ""
                                deudaVinculada = ""
                                showAddGasto = true
                            } label: {
                                Label("Nuevo Gasto", systemImage: "plus")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .foregroundColor(Color(hex: "#4F46E5"))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // 2. TARJETA RESUMEN PAGADO vs PENDIENTE
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pagado en esta quincena")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(pagadosMonto.copFormatted)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Falta por cubrir")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(porPagarMonto.copFormatted)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "#F43F5E"))
                        }
                    }
                    .padding(18)
                    .liquidGlass(cornerRadius: 26)

                    // 3. TARJETAS FLOTANTES INDIVIDUALES ESTILO "HOUSEHOLD" (Referencia #3)
                    ForEach(gastosFiltrados) { gasto in
                        HStack(spacing: 14) {
                            Button {
                                vm.triggerHaptic(.light)
                                Task {
                                    await vm.sendAction([
                                        "accion": "toggle_gasto",
                                        "gasto": gasto.nombre
                                    ])
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(gasto.pagado ? Color(hex: "#10B981").opacity(0.16) : Color.primary.opacity(0.06))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: gasto.pagado ? "checkmark" : "checklist")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(gasto.pagado ? Color(hex: "#10B981") : .secondary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(gasto.nombre)
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .strikethrough(gasto.pagado)
                                            .foregroundColor(gasto.pagado ? .secondary : .primary)

                                        Text(gasto.pagado ? "Pagado en quincena" : (gasto.label.isEmpty ? "Pendiente por pagar" : gasto.label))
                                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(
                                                gasto.pagado
                                                    ? Color(hex: "#10B981").opacity(0.15)
                                                    : Color(hex: "#F43F5E").opacity(0.14)
                                            )
                                            .foregroundColor(
                                                gasto.pagado ? Color(hex: "#10B981") : Color(hex: "#F43F5E")
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            HStack(spacing: 8) {
                                Text(gasto.valor.copFormatted)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(.secondary)

                                Button {
                                    nombreGasto = gasto.nombre
                                    valorGasto = String(Int(gasto.valor))
                                    labelGasto = gasto.label
                                    deudaVinculada = gasto.deudaDetectada ?? ""
                                    gastoEditar = gasto
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(Color.primary.opacity(0.07))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .liquidGlass(cornerRadius: 24)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 105)
            }
            .refreshable {
                await vm.fetchAllData()
            }
        }
        .sheet(item: $gastoEditar) { g in
            NavigationStack {
                Form {
                    Section("Editar Gasto Quincenal") {
                        LabeledContent("Concepto") {
                            TextField("Concepto", text: $nombreGasto)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Valor ($)") {
                            TextField("Valor", text: $valorGasto)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Etiqueta / Día") {
                            TextField("Día 10", text: $labelGasto)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Section {
                        Button("Guardar Cambios") {
                            guard !nombreGasto.isEmpty, let val = Double(valorGasto), val > 0 else { return }
                            Task {
                                if nombreGasto != g.nombre {
                                    await vm.sendAction([
                                        "accion": "eliminar_gasto",
                                        "gasto_eliminar": g.nombre
                                    ])
                                }
                                await vm.sendAction([
                                    "accion": "agregar_gasto",
                                    "nombre_gasto": nombreGasto,
                                    "valor_gasto": val,
                                    "label_gasto": labelGasto,
                                    "deuda_vinculada": deudaVinculada
                                ])
                                gastoEditar = nil
                            }
                        }
                        .fontWeight(.bold)

                        Button("Eliminar Gasto", role: .destructive) {
                            Task {
                                await vm.sendAction([
                                    "accion": "eliminar_gasto",
                                    "gasto_eliminar": g.nombre
                                ])
                                gastoEditar = nil
                            }
                        }
                    }
                }
                .navigationTitle("Editar \(g.nombre)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { gastoEditar = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddGasto) {
            NavigationStack {
                Form {
                    Section("Nuevo Gasto Quincenal") {
                        TextField("Concepto (ej. Comida, Gasolina)", text: $nombreGasto)
                        TextField("Valor ($)", text: $valorGasto)
                            .keyboardType(.numberPad)
                        TextField("Día o etiqueta (ej. Vence Día 10)", text: $labelGasto)
                    }
                    Section {
                        Button("Guardar Gasto") {
                            guard !nombreGasto.isEmpty, let val = Double(valorGasto), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "agregar_gasto",
                                    "nombre_gasto": nombreGasto,
                                    "valor_gasto": val,
                                    "label_gasto": labelGasto,
                                    "deuda_vinculada": deudaVinculada
                                ])
                                showAddGasto = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Añadir Gasto")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAddGasto = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct HouseholdFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyShapeStyle(Color(hex: "#4F46E5"))
                        : AnyShapeStyle(.ultraThinMaterial)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(LiquidScaleButtonStyle())
    }
}

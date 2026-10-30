import SwiftUI
import UIKit

struct QuincenaView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAddGasto = false
    @State private var nombreGasto = ""
    @State private var valorGasto = ""
    @State private var labelGasto = ""
    @State private var deudaVinculada = ""
    @State private var searchText = ""
    @State private var filtroEstado: Int = 0 // 0 = Todos, 1 = Pendientes, 2 = Pagados

    var body: some View {
        let f = vm.finanzas
        let pagadosMonto = f.gastosLista.filter { $0.pagado }.reduce(0.0) { $0 + $1.valor }
        let porPagarMonto = max(0, f.totalGastosQuincena - pagadosMonto)
        let progreso = f.totalGastosQuincena > 0 ? pagadosMonto / f.totalGastosQuincena : 0
        let pagadosCount = f.gastosLista.filter { $0.pagado }.count

        let gastosFiltrados = f.gastosLista.filter { g in
            let matchesSearch = searchText.isEmpty ||
                g.nombre.localizedCaseInsensitiveContains(searchText) ||
                g.label.localizedCaseInsensitiveContains(searchText)
            let matchesState: Bool
            switch filtroEstado {
            case 1: matchesState = !g.pagado
            case 2: matchesState = g.pagado
            default: matchesState = true
            }
            return matchesSearch && matchesState
        }

        List {
            // 1. CABECERA DE PROGRESO QUINCENAL NATIVA
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        LiquidCircularRing(
                            progress: progreso,
                            color: Color(hex: "#10B981"),
                            size: 60,
                            lineWidth: 6.5
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("TOTAL PRESUPUESTO FIJO")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(f.totalGastosQuincena.copFormatted)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                            Text("\(pagadosCount) de \(f.gastosLista.count) gastos pagados")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))
                        }

                        Spacer()
                    }

                    ProgressView(value: progreso)
                        .tint(Color(hex: "#10B981"))

                    HStack {
                        Label("Pagado: \(pagadosMonto.copFormatted)", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#10B981"))
                        Spacer()
                        Label("Pendiente: \(porPagarMonto.copFormatted)", systemImage: "clock.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(porPagarMonto > 0 ? Color(hex: "#EF4444") : .secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            nombreGasto = ""
                            valorGasto = ""
                            labelGasto = ""
                            deudaVinculada = ""
                            showAddGasto = true
                        } label: {
                            Label("Añadir Gasto", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#6366F1"))

                        Button(role: .destructive) {
                            Task {
                                await vm.sendAction(["accion": "reset_quincena"])
                            }
                        } label: {
                            Label("Limpiar", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 6)
            }

            // 2. FILTRO SEGMENTADO NATIVO DE iOS
            Section {
                Picker("Filtro", selection: $filtroEstado) {
                    Text("Todos (\(f.gastosLista.count))").tag(0)
                    Text("Pendientes (\(f.gastosLista.filter { !$0.pagado }.count))").tag(1)
                    Text("Pagados (\(pagadosCount))").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            // 3. CHECKLIST DE GASTOS QUINCENALES CON SWIPE ACTIONS Y CONTEXT MENU
            Section {
                ForEach(gastosFiltrados) { gasto in
                    Button {
                        Task {
                            await vm.sendAction([
                                "accion": "toggle_gasto",
                                "gasto": gasto.nombre
                            ])
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: gasto.pagado ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(gasto.pagado ? Color(hex: "#10B981") : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(gasto.nombre)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .strikethrough(gasto.pagado)
                                    .foregroundColor(gasto.pagado ? .secondary : .primary)

                                HStack(spacing: 6) {
                                    if !gasto.label.isEmpty {
                                        Text(gasto.label)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.14))
                                            .foregroundColor(.secondary)
                                            .clipShape(Capsule())
                                    }
                                    if let deuda = gasto.deudaDetectada, !deuda.isEmpty {
                                        Text("⚡ -Deuda \(deuda)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "#6366F1").opacity(0.16))
                                            .foregroundColor(Color(hex: "#6366F1"))
                                            .clipShape(Capsule())
                                    }
                                }
                            }

                            Spacer()

                            Text("-\(gasto.valor.copFormatted)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(gasto.pagado ? .secondary : .primary)
                        }
                        .padding(.vertical, 3)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                await vm.sendAction([
                                    "accion": "toggle_gasto",
                                    "gasto": gasto.nombre
                                ])
                            }
                        } label: {
                            Label(
                                gasto.pagado ? "Desmarcar" : "Marcar Pagado",
                                systemImage: gasto.pagado ? "arrow.uturn.backward" : "checkmark.circle.fill"
                            )
                        }
                        .tint(Color(hex: "#10B981"))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await vm.sendAction([
                                    "accion": "eliminar_gasto",
                                    "gasto_eliminar": gasto.nombre
                                ])
                            }
                        } label: {
                            Label("Eliminar", systemImage: "trash.fill")
                        }
                    }
                    .contextMenu {
                        Button {
                            Task {
                                await vm.sendAction([
                                    "accion": "toggle_gasto",
                                    "gasto": gasto.nombre
                                ])
                            }
                        } label: {
                            Label(
                                gasto.pagado ? "Desmarcar como pagado" : "Marcar como pagado",
                                systemImage: gasto.pagado ? "circle" : "checkmark.circle.fill"
                            )
                        }

                        Button(role: .destructive) {
                            Task {
                                await vm.sendAction([
                                    "accion": "eliminar_gasto",
                                    "gasto_eliminar": gasto.nombre
                                ])
                            }
                        } label: {
                            Label("Eliminar Gasto", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Gastos de la Quincena")
            } footer: {
                Text("⚡ Al marcar Moto, Cuota Celular o Universidad, el pago se descuenta automáticamente de la deuda en pagos.xo.je.")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Buscar gasto fijo...")
        .navigationTitle("Presupuesto Fijo")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showAddGasto) {
            NavigationStack {
                Form {
                    Section("Datos del Gasto Quincenal") {
                        TextField("Nombre (ej. Gimnasio o Parqueadero U)", text: $nombreGasto)
                        TextField("Valor ($)", text: $valorGasto)
                            .keyboardType(.numberPad)
                        TextField("Día de pago (ej. Día 10)", text: $labelGasto)
                    }

                    Section("Descuento Automático de Deuda") {
                        Picker("Vincular a Deuda", selection: $deudaVinculada) {
                            Text("Ninguna (Gasto normal)").tag("")
                            ForEach(f.deudasLista) { d in
                                Text("Descontar de: \(d.nombre)").tag(d.nombre)
                            }
                        }
                    }

                    Section {
                        Button {
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
                        } label: {
                            HStack {
                                Spacer()
                                Label("Guardar Gasto", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Añadir Gasto Fijo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAddGasto = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

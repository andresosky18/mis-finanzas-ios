import SwiftUI
import UIKit

struct QuincenaView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAddGasto = false
    @State private var nombreGasto = ""
    @State private var valorGasto = ""
    @State private var labelGasto = ""
    @State private var deudaVinculada = ""

    var body: some View {
        List {
            if let f = vm.finanzas {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Presupuesto Fijo")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(f.totalGastosQuincena.copFormatted)
                                .font(.system(size: 24, weight: .heavy))
                        }
                        Spacer()
                        Button {
                            Task {
                                await vm.sendAction(["accion": "reset_quincena"])
                            }
                        } label: {
                            Label("Limpiar", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("⚡ Al marcar un gasto vinculado a una deuda (ej. Moto, Cuota Celular, Universidad), el monto se descuenta automáticamente del saldo pendiente de esa deuda.")
                }

                Section("Checklist de Gastos Quincenales") {
                    ForEach(f.gastosLista) { gasto in
                        Button {
                            Task {
                                await vm.sendAction([
                                    "accion": "toggle_gasto",
                                    "gasto": gasto.nombre
                                ])
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: gasto.pagado ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 22))
                                    .foregroundColor(gasto.pagado ? Color(hex: "#10B981") : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(gasto.nombre)
                                        .font(.system(size: 15, weight: .semibold))
                                        .strikethrough(gasto.pagado)
                                        .foregroundColor(gasto.pagado ? .secondary : .primary)

                                    HStack(spacing: 6) {
                                        if !gasto.label.isEmpty {
                                            Text(gasto.label)
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.secondary.opacity(0.15))
                                                .cornerRadius(5)
                                                .foregroundColor(.secondary)
                                        }
                                        if let deuda = gasto.deudaDetectada, !deuda.isEmpty {
                                            Text("⚡ -Deuda \(deuda)")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "#6366F1").opacity(0.16))
                                                .foregroundColor(Color(hex: "#818CF8"))
                                                .cornerRadius(5)
                                        }
                                    }
                                }

                                Spacer()

                                Text("-\(gasto.valor.copFormatted)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
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
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Presupuesto Fijo")
        .refreshable {
            await vm.fetchAllData()
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                nombreGasto = ""
                valorGasto = ""
                labelGasto = ""
                deudaVinculada = ""
                showAddGasto = true
            } label: {
                Label("Añadir Gasto", systemImage: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#6366F1"))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
            }
            .padding(20)
        }
        .sheet(isPresented: $showAddGasto) {
            NavigationStack {
                Form {
                    Section("Datos del Gasto Quincenal") {
                        TextField("Nombre (ej. Gimnasio o Cuota Moto)", text: $nombreGasto)
                        TextField("Valor ($)", text: $valorGasto)
                            .keyboardType(.numberPad)
                        TextField("Día de pago (ej. Día 15)", text: $labelGasto)
                    }

                    if let deudas = vm.finanzas?.deudasLista {
                        Section("Descuento Automático de Deuda") {
                            Picker("Vincular a Deuda", selection: $deudaVinculada) {
                                Text("Ninguna (Gasto normal)").tag("")
                                ForEach(deudas) { d in
                                    Text("Descontar de: \(d.nombre)").tag(d.nombre)
                                }
                            }
                        }
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
                .navigationTitle("Nuevo Gasto Fijo")
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

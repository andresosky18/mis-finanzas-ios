import SwiftUI
import UIKit

struct DeudasView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var deudaSeleccionada: DeudaItem?
    @State private var montoAbono: String = ""
    @State private var showNuevaDeuda = false
    @State private var deudaEditar: DeudaItem?

    // Campos para nueva / editar deuda
    @State private var formNombre = ""
    @State private var formTotal = ""
    @State private var formPendiente = ""
    @State private var formCuota = ""
    @State private var formIcono = "credit-card"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let f = vm.finanzas {
                    ForEach(f.deudasLista) { deuda in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: "#6366F1").opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: SFIconMapper.symbol(for: deuda.icono))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#6366F1"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(deuda.nombre)
                                        .font(.system(size: 16, weight: .heavy))
                                    Text(deuda.mesesRestantes > 0 ? "Faltan ~\(deuda.mesesRestantes) cuotas (\(deuda.cuota.copFormatted))" : "¡Deuda Liquidada! 🎉")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(deuda.pendiente.copFormatted)
                                        .font(.system(size: 17, weight: .heavy))
                                        .foregroundColor(deuda.pendiente > 0 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))

                                    HStack(spacing: 8) {
                                        Button {
                                            formNombre = deuda.nombre
                                            formTotal = String(Int(deuda.total))
                                            formPendiente = String(Int(deuda.pendiente))
                                            formCuota = String(Int(deuda.cuota))
                                            formIcono = deuda.icono
                                            deudaEditar = deuda
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 12, weight: .bold))
                                                .padding(6)
                                                .background(Color.secondary.opacity(0.15))
                                                .clipShape(Circle())
                                        }

                                        if deuda.pendiente > 0 {
                                            Button {
                                                montoAbono = String(Int(deuda.cuota))
                                                deudaSeleccionada = deuda
                                            } label: {
                                                Text("Abonar")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color(hex: "#6366F1"))
                                                    .foregroundColor(.white)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }

                            ProgressView(value: deuda.porcentaje)
                                .tint(deuda.pendiente <= 0 ? Color(hex: "#10B981") : Color(hex: "#6366F1"))

                            HStack {
                                Text("Pagado: \(deuda.pagado.copFormatted) de \(deuda.total.copFormatted)")
                                Spacer()
                                Text("\(Int(deuda.porcentaje * 100))%")
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
        .navigationTitle("Auditoría de Deudas")
        .refreshable {
            await vm.fetchAllData()
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                formNombre = ""
                formTotal = ""
                formCuota = ""
                formIcono = "credit-card"
                showNuevaDeuda = true
            } label: {
                Label("Nueva Deuda", systemImage: "plus")
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
        // SHEET ABONAR A DEUDA
        .sheet(item: $deudaSeleccionada) { d in
            NavigationStack {
                Form {
                    Section("Abonar a \(d.nombre)") {
                        Text("Saldo actual: \(d.pendiente.copFormatted)")
                            .foregroundColor(.secondary)
                        TextField("Monto a abonar ($)", text: $montoAbono)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Confirmar Abono y Bajar Deuda") {
                            guard let val = Double(montoAbono), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_deuda",
                                    "deuda": d.nombre,
                                    "monto": val
                                ])
                                deudaSeleccionada = nil
                            }
                        }
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#10B981"))
                    }
                }
                .navigationTitle("Registrar Abono")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { deudaSeleccionada = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        // SHEET EDITAR DEUDA
        .sheet(item: $deudaEditar) { d in
            NavigationStack {
                Form {
                    Section("Editar \(d.nombre)") {
                        TextField("Nombre", text: $formNombre)
                        TextField("Deuda Total Inicial ($)", text: $formTotal)
                            .keyboardType(.numberPad)
                        TextField("Saldo Pendiente Actual ($)", text: $formPendiente)
                            .keyboardType(.numberPad)
                        TextField("Cuota Mensual ($)", text: $formCuota)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Guardar Cambios") {
                            Task {
                                await vm.sendAction([
                                    "accion": "editar_deuda",
                                    "nombre_original": d.nombre,
                                    "nombre_deuda_nuevo": formNombre,
                                    "total_deuda": Double(formTotal) ?? d.total,
                                    "pendiente_deuda": Double(formPendiente) ?? d.pendiente,
                                    "cuota_deuda": Double(formCuota) ?? d.cuota,
                                    "icono_deuda": formIcono
                                ])
                                deudaEditar = nil
                            }
                        }
                        .fontWeight(.bold)

                        Button("Eliminar Deuda", role: .destructive) {
                            Task {
                                await vm.sendAction([
                                    "accion": "eliminar_deuda",
                                    "deuda_eliminar": d.nombre
                                ])
                                deudaEditar = nil
                            }
                        }
                    }
                }
                .navigationTitle("Editar Deuda")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { deudaEditar = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        // SHEET NUEVA DEUDA
        .sheet(isPresented: $showNuevaDeuda) {
            NavigationStack {
                Form {
                    Section("Crear Nueva Deuda") {
                        TextField("Nombre del crédito", text: $formNombre)
                        TextField("Deuda Total Inicial ($)", text: $formTotal)
                            .keyboardType(.numberPad)
                        TextField("Cuota Mensual ($)", text: $formCuota)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Añadir Deuda") {
                            guard !formNombre.isEmpty, let tot = Double(formTotal), tot > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "agregar_deuda",
                                    "nombre_deuda": formNombre,
                                    "total_deuda": tot,
                                    "cuota_deuda": Double(formCuota) ?? 0,
                                    "icono_deuda": formIcono
                                ])
                                showNuevaDeuda = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Nueva Deuda")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showNuevaDeuda = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

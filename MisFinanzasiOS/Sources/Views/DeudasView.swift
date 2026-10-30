import SwiftUI
import UIKit

struct DeudasView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var deudaSeleccionada: DeudaItem?
    @State private var montoAbono: String = ""
    @State private var showNuevaDeuda = false
    @State private var deudaEditar: DeudaItem?

    @State private var formNombre = ""
    @State private var formTotal = ""
    @State private var formPendiente = ""
    @State private var formCuota = ""
    @State private var formIcono = "credit-card"

    var body: some View {
        let f = vm.finanzas
        let totalInicial = f.deudasLista.reduce(0.0) { $0 + $1.total }
        let totalPagado = max(0, totalInicial - f.totalDeudaPendiente)
        let progresoGlobal = totalInicial > 0 ? totalPagado / totalInicial : 0

        List {
            // 1. RESUMEN CONSOLIDADO DE DEUDAS
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        LiquidCircularRing(
                            progress: progresoGlobal,
                            color: Color(hex: "#6366F1"),
                            size: 60,
                            lineWidth: 6.5
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("DEUDA PENDIENTE CONSOLIDADA")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(f.totalDeudaPendiente.copFormatted)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#EF4444"))
                            Text("Ya pagaste \(totalPagado.copFormatted) de \(totalInicial.copFormatted)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))
                        }

                        Spacer()
                    }

                    ProgressView(value: progresoGlobal)
                        .tint(Color(hex: "#6366F1"))

                    Button {
                        formNombre = ""
                        formTotal = ""
                        formCuota = ""
                        formIcono = "credit-card"
                        showNuevaDeuda = true
                    } label: {
                        Label("Añadir Deuda Activa", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#6366F1"))
                }
                .padding(.vertical, 6)
            }

            // 2. AUDITORÍA DE DEUDAS (MOTO, UNIVERSIDAD, CELULAR, TV)
            Section {
                ForEach(f.deudasLista) { deuda in
                    let accent = SFIconMapper.accentColor(for: deuda.nombre)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(accent.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: SFIconMapper.symbol(for: deuda.icono))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(deuda.nombre)
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                Text("ETA: \(deuda.etaTexto) (Cuota: \(deuda.cuota.copFormatted))")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(deuda.pendiente.copFormatted)
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .foregroundColor(deuda.pendiente > 0 ? Color(hex: "#EF4444") : Color(hex: "#10B981"))

                                HStack(spacing: 6) {
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
                                            .background(Color.secondary.opacity(0.14))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)

                                    if deuda.pendiente > 0 {
                                        Button {
                                            montoAbono = String(Int(deuda.cuota))
                                            deudaSeleccionada = deuda
                                        } label: {
                                            Text("Abonar")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(accent)
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        ProgressView(value: deuda.porcentaje)
                            .tint(deuda.pendiente <= 0 ? Color(hex: "#10B981") : accent)

                        HStack {
                            Text("Pagado: \(deuda.pagado.copFormatted) de \(deuda.total.copFormatted)")
                            Spacer()
                            Text(String(format: "%.1f%%", deuda.porcentaje * 100))
                                .fontWeight(.heavy)
                                .foregroundColor(accent)
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            montoAbono = String(Int(deuda.cuota))
                            deudaSeleccionada = deuda
                        } label: {
                            Label("Abonar", systemImage: "arrow.down.circle.fill")
                        }
                        .tint(Color(hex: "#10B981"))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await vm.sendAction([
                                    "accion": "eliminar_deuda",
                                    "deuda_eliminar": deuda.nombre
                                ])
                            }
                        } label: {
                            Label("Eliminar", systemImage: "trash.fill")
                        }

                        Button {
                            formNombre = deuda.nombre
                            formTotal = String(Int(deuda.total))
                            formPendiente = String(Int(deuda.pendiente))
                            formCuota = String(Int(deuda.cuota))
                            formIcono = deuda.icono
                            deudaEditar = deuda
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(Color(hex: "#6366F1"))
                    }
                    .contextMenu {
                        Button {
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_deuda",
                                    "deuda": deuda.nombre,
                                    "monto": deuda.cuota
                                ])
                            }
                        } label: {
                            Label("Abonar Cuota Rápida (\(deuda.cuota.copFormatted))", systemImage: "bolt.fill")
                        }

                        Button {
                            montoAbono = String(Int(deuda.cuota))
                            deudaSeleccionada = deuda
                        } label: {
                            Label("Abonar Otro Monto...", systemImage: "banknote.fill")
                        }

                        Button {
                            formNombre = deuda.nombre
                            formTotal = String(Int(deuda.total))
                            formPendiente = String(Int(deuda.pendiente))
                            formCuota = String(Int(deuda.cuota))
                            formIcono = deuda.icono
                            deudaEditar = deuda
                        } label: {
                            Label("Editar Deuda", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task {
                                await vm.sendAction([
                                    "accion": "eliminar_deuda",
                                    "deuda_eliminar": deuda.nombre
                                ])
                            }
                        } label: {
                            Label("Eliminar Deuda", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Auditoría de Deudas")
            } footer: {
                Text("Desliza una deuda a la derecha para abonar o mantén presionado para abono rápido de cuota.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mis Deudas")
        .refreshable {
            await vm.fetchAllData()
        }
        // SHEET ABONAR A DEUDA
        .sheet(item: $deudaSeleccionada) { d in
            NavigationStack {
                Form {
                    Section("Abonar a \(d.nombre)") {
                        LabeledContent("Saldo Pendiente", value: d.pendiente.copFormatted)
                        TextField("Monto a descontar ($)", text: $montoAbono)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickAmountChip(title: "Cuota (\(d.cuota.copFormatted))") {
                                    montoAbono = String(Int(d.cuota))
                                }
                                QuickAmountChip(title: "$100.000") {
                                    montoAbono = "100000"
                                }
                                QuickAmountChip(title: "$226.500") {
                                    montoAbono = "226500"
                                }
                                QuickAmountChip(title: "Liquidar Total") {
                                    montoAbono = String(Int(d.pendiente))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section {
                        Button {
                            guard let val = Double(montoAbono), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_deuda",
                                    "deuda": d.nombre,
                                    "monto": val
                                ])
                                deudaSeleccionada = nil
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Confirmar Abono en pagos.xo.je", systemImage: "checkmark.seal.fill")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#10B981"))
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Registrar Pago")
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
                        LabeledContent("Nombre") {
                            TextField("Nombre", text: $formNombre)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Total Inicial ($)") {
                            TextField("Total", text: $formTotal)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Saldo Pendiente ($)") {
                            TextField("Pendiente", text: $formPendiente)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Cuota Mensual ($)") {
                            TextField("Cuota", text: $formCuota)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
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
                    Section("Añadir Deuda Activa") {
                        TextField("Nombre del crédito (ej. Tarjeta o TV)", text: $formNombre)
                        TextField("Deuda Total Inicial ($)", text: $formTotal)
                            .keyboardType(.numberPad)
                        TextField("Cuota Mensual ($)", text: $formCuota)
                            .keyboardType(.numberPad)
                        Picker("Ícono", selection: $formIcono) {
                            Text("🏍️ Moto").tag("bike")
                            Text("📱 Celular").tag("phone")
                            Text("📺 TV").tag("tv")
                            Text("🎓 Universidad").tag("graduation-cap")
                            Text("💳 Tarjeta / Otro").tag("credit-card")
                        }
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

struct QuickAmountChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#6366F1").opacity(0.16))
                .foregroundColor(Color(hex: "#818CF8"))
                .clipShape(Capsule())
        }
        .buttonStyle(LiquidScaleButtonStyle())
    }
}

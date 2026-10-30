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
        let f = vm.finanzas
        let totalInicial = f.deudasLista.reduce(0.0) { $0 + $1.total }
        let totalPagado = max(0, totalInicial - f.totalDeudaPendiente)
        let progresoGlobal = totalInicial > 0 ? totalPagado / totalInicial : 0

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. RESUMEN GLOBAL DE DEUDAS LIQUID GLASS
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SALDO PENDIENTE TOTAL")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundColor(.secondary)

                                Text(f.totalDeudaPendiente.copFormatted)
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color(hex: "#F87171"))
                            }

                            Spacer()

                            LiquidCircularRing(
                                progress: progresoGlobal,
                                color: Color(hex: "#6366F1"),
                                size: 58,
                                lineWidth: 6.5
                            )
                        }

                        LiquidProgressBar(
                            progress: progresoGlobal,
                            colors: [Color(hex: "#6366F1"), Color(hex: "#10B981")],
                            height: 10
                        )

                        HStack {
                            Text("Abonado: \(totalPagado.copFormatted)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))
                            Spacer()
                            Text("Inicial: \(totalInicial.copFormatted)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Button {
                            formNombre = ""
                            formTotal = ""
                            formCuota = ""
                            formIcono = "credit-card"
                            showNuevaDeuda = true
                        } label: {
                            Label("Registrar Nueva Deuda", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#6366F1"), Color(hex: "#4F46E5")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(LiquidScaleButtonStyle())
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 28, tint: Color(hex: "#F43F5E"), tintOpacity: 0.09)

                    // 2. TARJETAS INDIVIDUALES DE DEUDA ESTILO APPLE WALLET LIQUID GLASS
                    ForEach(f.deudasLista) { deuda in
                        let accent = SFIconMapper.accentColor(for: deuda.nombre)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [accent.opacity(0.28), accent.opacity(0.10)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                                        )

                                    Image(systemName: SFIconMapper.symbol(for: deuda.icono))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(accent)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(deuda.nombre)
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))

                                    Text(
                                        deuda.mesesRestantes > 0
                                            ? "~\(deuda.mesesRestantes) cuotas restantes de \(deuda.cuota.copFormatted)"
                                            : "¡Deuda Liquidada! 🎉"
                                    )
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                LiquidCircularRing(
                                    progress: deuda.porcentaje,
                                    color: deuda.pendiente <= 0 ? Color(hex: "#10B981") : accent,
                                    size: 46,
                                    lineWidth: 5
                                )
                            }

                            LiquidProgressBar(
                                progress: deuda.porcentaje,
                                colors: deuda.pendiente <= 0
                                    ? [Color(hex: "#10B981"), Color(hex: "#059669")]
                                    : [accent, accent.opacity(0.75)],
                                height: 9
                            )

                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PENDIENTE")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text(deuda.pendiente.copFormatted)
                                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                                        .foregroundColor(deuda.pendiente > 0 ? .primary : Color(hex: "#10B981"))
                                    Text("Pagado: \(deuda.pagado.copFormatted) de \(deuda.total.copFormatted)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Button {
                                        formNombre = deuda.nombre
                                        formTotal = String(Int(deuda.total))
                                        formPendiente = String(Int(deuda.pendiente))
                                        formCuota = String(Int(deuda.cuota))
                                        formIcono = deuda.icono
                                        deudaEditar = deuda
                                    } label: {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 13, weight: .bold))
                                            .padding(10)
                                            .background(Color.primary.opacity(0.08))
                                            .foregroundColor(.primary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(LiquidScaleButtonStyle())

                                    if deuda.pendiente > 0 {
                                        Button {
                                            montoAbono = String(Int(deuda.cuota))
                                            deudaSeleccionada = deuda
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "arrow.down.circle.fill")
                                                Text("Abonar")
                                            }
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(
                                                LinearGradient(
                                                    colors: [accent, accent.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                            .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
                                        }
                                        .buttonStyle(LiquidScaleButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .liquidGlass(cornerRadius: 26, tint: accent, tintOpacity: 0.12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Mis Deudas")
        .refreshable {
            await vm.fetchAllData()
        }
        // SHEET ABONAR A DEUDA CON CHIPS RÁPIDOS
        .sheet(item: $deudaSeleccionada) { d in
            NavigationStack {
                Form {
                    Section("Abonar a \(d.nombre)") {
                        HStack {
                            Text("Saldo actual")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(d.pendiente.copFormatted)
                                .fontWeight(.bold)
                        }

                        TextField("Monto a abonar ($)", text: $montoAbono)
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
                                QuickAmountChip(title: "$250.000") {
                                    montoAbono = "250000"
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
                                Label("Confirmar Abono y Descontar", systemImage: "checkmark.seal.fill")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#10B981"))
                                Spacer()
                            }
                        }
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

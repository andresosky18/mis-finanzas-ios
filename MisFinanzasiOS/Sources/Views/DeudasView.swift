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

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // 1. TARJETA CORAL SIGNATURE ESTILO "monzo" (Referencia #4)
                    VStack(spacing: 20) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("mis deudas")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Label(
                                    "\(String(format: "%.1f%%", progresoGlobal * 100)) pagado (\(totalPagado.copFormatted))",
                                    systemImage: "creditcard.fill"
                                )
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(f.totalDeudaPendiente.copFormatted)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1)
                                Text("Saldo Pendiente")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        // Botones Píldora Oscuros Translúcidos estilo "+ Add money | Cards | •••" de Monzo
                        HStack(spacing: 8) {
                            Button {
                                formNombre = ""
                                formTotal = ""
                                formCuota = ""
                                formIcono = "credit-card"
                                showNuevaDeuda = true
                            } label: {
                                Label("Nueva deuda", systemImage: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.32))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }

                            if let primera = f.deudasLista.first {
                                Button {
                                    montoAbono = String(Int(primera.cuota))
                                    deudaSeleccionada = primera
                                } label: {
                                    Label("Abonar cuota", systemImage: "creditcard.fill")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.black.opacity(0.32))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#E11D48"), Color(hex: "#CD1713"), Color(hex: "#EA580C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color(hex: "#CD1713").opacity(0.28), radius: 16, y: 8)

                    // 2. TARJETAS FLOTANTES INDIVIDUALES DE CADA DEUDA (Estilo Household Referencia #3)
                    ForEach(f.deudasLista) { deuda in
                        let accent = SFIconMapper.accentColor(for: deuda.nombre)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(accent.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: SFIconMapper.symbol(for: deuda.icono))
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(accent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deuda.nombre)
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))

                                    Text("\(String(format: "%.1f%%", deuda.porcentaje * 100)) abonado · Cuota \(deuda.cuota.copFormatted)")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 3)
                                        .background(accent.opacity(0.14))
                                        .foregroundColor(accent)
                                        .clipShape(Capsule())
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(deuda.pendiente.copFormatted)
                                        .font(.system(size: 15, weight: .black, design: .rounded))

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
                                                .font(.system(size: 11, weight: .bold))
                                                .frame(width: 26, height: 26)
                                                .background(Color.primary.opacity(0.08))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)

                                        if deuda.pendiente > 0 {
                                            Button {
                                                montoAbono = String(Int(deuda.cuota))
                                                deudaSeleccionada = deuda
                                            } label: {
                                                Text("+ Abonar")
                                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
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

                            LiquidProgressBar(
                                progress: deuda.porcentaje,
                                colors: [accent, accent.opacity(0.75)],
                                height: 7
                            )
                        }
                        .padding(16)
                        .liquidGlass(cornerRadius: 26)
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
                                Label("Confirmar Abono", systemImage: "checkmark.seal.fill")
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
                            Label("Motocicleta", systemImage: "bicycle").tag("bike")
                            Label("Celular", systemImage: "iphone").tag("phone")
                            Label("Televisor", systemImage: "tv.fill").tag("tv")
                            Label("Universidad", systemImage: "graduationcap.fill").tag("graduation-cap")
                            Label("Crédito / Tarjeta", systemImage: "creditcard.fill").tag("credit-card")
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
                .foregroundColor(Color(hex: "#6366F1"))
                .clipShape(Capsule())
        }
        .buttonStyle(LiquidScaleButtonStyle())
    }
}

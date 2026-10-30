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
        let f = vm.finanzas
        let pagadosMonto = f.gastosLista.filter { $0.pagado }.reduce(0.0) { $0 + $1.valor }
        let porPagarMonto = max(0, f.totalGastosQuincena - pagadosMonto)
        let progreso = f.totalGastosQuincena > 0 ? pagadosMonto / f.totalGastosQuincena : 0
        let pagadosCount = f.gastosLista.filter { $0.pagado }.count

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. CABECERA LIQUID GLASS CON MEDIDOR CIRCULAR DE QUINCENA
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            LiquidCircularRing(
                                progress: progreso,
                                color: Color(hex: "#10B981"),
                                size: 64,
                                lineWidth: 7
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("PRESUPUESTO QUINCENAL")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundColor(.secondary)

                                Text(f.totalGastosQuincena.copFormatted)
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))

                                Text("\(pagadosCount) de \(f.gastosLista.count) pagos completados")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }

                            Spacer()
                        }

                        LiquidProgressBar(
                            progress: progreso,
                            colors: [Color(hex: "#10B981"), Color(hex: "#06B6D4")],
                            height: 10
                        )

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ya Pagado")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Text(pagadosMonto.copFormatted)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Falta por Pagar")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Text(porPagarMonto.copFormatted)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(porPagarMonto > 0 ? Color(hex: "#F87171") : .secondary)
                            }
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

                            Button {
                                Task {
                                    await vm.sendAction(["accion": "reset_quincena"])
                                }
                            } label: {
                                Label("Limpiar", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.primary.opacity(0.08))
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(LiquidScaleButtonStyle())
                        }
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 28, tint: Color(hex: "#10B981"), tintOpacity: 0.10)

                    // 2. BANNER INFORMATIVO DE DESCUENTO AUTOMÁTICO
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#818CF8"))
                        Text("Al marcar un gasto con **⚡ -Deuda**, se descuenta automáticamente del saldo pendiente de tu crédito.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .liquidGlass(cornerRadius: 18, tint: Color(hex: "#6366F1"), tintOpacity: 0.08)

                    // 3. LISTA DE GASTOS QUINCENALES EN CÁPSULAS LIQUID GLASS
                    VStack(spacing: 10) {
                        ForEach(f.gastosLista) { gasto in
                            HStack(spacing: 14) {
                                // Botón de check interactivo
                                Button {
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
                                                .fill(
                                                    gasto.pagado
                                                        ? LinearGradient(
                                                            colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                        : LinearGradient(
                                                            colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.04)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                )
                                                .frame(width: 34, height: 34)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(
                                                            gasto.pagado ? Color.white.opacity(0.6) : Color.primary.opacity(0.25),
                                                            lineWidth: 1.3
                                                        )
                                                )
                                                .shadow(color: gasto.pagado ? Color(hex: "#10B981").opacity(0.45) : .clear, radius: 6)

                                            if gasto.pagado {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .heavy))
                                                    .foregroundColor(.white)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(gasto.nombre)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .strikethrough(gasto.pagado, color: .secondary)
                                                .foregroundColor(gasto.pagado ? .secondary : .primary)

                                            HStack(spacing: 6) {
                                                if !gasto.label.isEmpty {
                                                    Text(gasto.label)
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2.5)
                                                        .background(Color.primary.opacity(0.08))
                                                        .foregroundColor(.secondary)
                                                        .clipShape(Capsule())
                                                }
                                                if let deuda = gasto.deudaDetectada, !deuda.isEmpty {
                                                    Text("⚡ -Deuda \(deuda)")
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2.5)
                                                        .background(Color(hex: "#6366F1").opacity(0.18))
                                                        .foregroundColor(Color(hex: "#818CF8"))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }

                                        Spacer()

                                        Text("-\(gasto.valor.copFormatted)")
                                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                                            .foregroundColor(gasto.pagado ? .secondary : .primary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(LiquidScaleButtonStyle())

                                // Botón eliminar gasto
                                Button(role: .destructive) {
                                    Task {
                                        await vm.sendAction([
                                            "accion": "eliminar_gasto",
                                            "gasto_eliminar": gasto.nombre
                                        ])
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .opacity(gasto.pagado ? 0.68 : 1.0)
                            .liquidGlass(
                                cornerRadius: 22,
                                tint: gasto.pagado ? Color(hex: "#10B981") : .clear,
                                tintOpacity: 0.08
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Presupuesto Fijo")
        .refreshable {
            await vm.fetchAllData()
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

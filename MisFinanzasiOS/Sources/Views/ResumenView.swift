import SwiftUI
import UIKit

struct ResumenView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showEditNomina = false
    @State private var nuevoSueldo = ""
    @State private var nuevoBono = ""

    var body: some View {
        let f = vm.finanzas

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 1. HERO CARD LIQUID GLASS: INGRESOS, DEUDA Y AHORRO
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#6EE7B7"))
                                Text("INGRESOS MENSUALES")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())

                            Spacer()

                            Button {
                                vm.triggerHaptic(.light)
                                nuevoSueldo = String(Int(f.sueldoBase))
                                nuevoBono = String(Int(f.bonoQ1))
                                showEditNomina = true
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Nómina")
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(LiquidScaleButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.totalIngresosMensual.copFormatted)
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)

                            Text("Sueldo \(f.sueldoBase.copFormatted) + Auxilios + Extras")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                        }

                        HStack(spacing: 12) {
                            // Sub-tarjeta Deuda Consolidada
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 5) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#FDA4AF"))
                                    Text("DEUDA TOTAL")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white.opacity(0.75))
                                }
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                            )

                            // Sub-tarjeta Ahorro Corvanca
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 5) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#6EE7B7"))
                                    Text("CORVANCA")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white.opacity(0.75))
                                }
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(22)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(hex: "#4F46E5"),
                                    Color(hex: "#6366F1"),
                                    Color(hex: "#0EA5E9")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            LinearGradient(
                                colors: [Color.white.opacity(0.24), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.65), Color.white.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.3
                            )
                    )
                    .shadow(color: Color(hex: "#4F46E5").opacity(0.38), radius: 22, y: 12)

                    // 2. FLUJO DE CAJA QUINCENAL (Q1 & Q2 LIQUID GLASS TILES)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("FLUJO DE CAJA QUINCENAL", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(0.7)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        HStack(spacing: 12) {
                            QuincenaLiquidTile(
                                badge: "DÍA 10",
                                titulo: "Quincena 1",
                                neto: f.netoQ1,
                                libre: f.flujoQ1,
                                tint: Color(hex: "#6366F1")
                            )

                            QuincenaLiquidTile(
                                badge: "DÍA 30",
                                titulo: "Quincena 2",
                                neto: f.netoQ2,
                                libre: f.flujoQ2,
                                tint: Color(hex: "#06B6D4")
                            )
                        }
                    }

                    // 3. DISTRIBUCIÓN DEL PRESUPUESTO (DONUT CHART NATIVO LIQUID GLASS)
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DISTRIBUCIÓN QUINCENA")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .foregroundColor(.secondary)

                            DistributionLegendRow(
                                color: Color(hex: "#6366F1"),
                                label: "Fijos",
                                amount: f.totalFijosQuincenal
                            )
                            DistributionLegendRow(
                                color: Color(hex: "#F43F5E"),
                                label: "Deudas",
                                amount: f.totalDeudasQuincenal
                            )
                            DistributionLegendRow(
                                color: Color(hex: "#10B981"),
                                label: "Ahorro",
                                amount: f.totalAhorroQuincenal
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        BudgetDonutRingView(
                            fijos: f.totalFijosQuincenal,
                            deudas: f.totalDeudasQuincenal,
                            ahorro: f.totalAhorroQuincenal
                        )
                        .frame(width: 96, height: 96)
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 26, tint: Color(hex: "#6366F1"), tintOpacity: 0.08)

                    // 4. NÓMINA Y DESCUENTOS FIJOS
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("NÓMINA & DESCUENTOS", systemImage: "building.2.crop.circle.fill")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Por Quincena")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        ForEach(f.deduccionesNomina.keys.sorted(), id: \.self) { key in
                            let val = f.deduccionesNomina[key] ?? 0
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#6366F1").opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: key.localizedCaseInsensitiveContains("corvanca") ? "leaf.fill" : "minus.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(key.localizedCaseInsensitiveContains("corvanca") ? Color(hex: "#10B981") : Color(hex: "#818CF8"))
                                }
                                Text(key)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Spacer()
                                Text("-\(val.copFormatted)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#F87171"))
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 26)

                    // 5. ACTIVIDAD RECIENTE CON REVERSIÓN EN 1 TOQUE
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("ACTIVIDAD RECIENTE", systemImage: "clock.arrow.circlepath")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .foregroundColor(.secondary)
                            Spacer()
                            if !f.historial.isEmpty {
                                Text("Toca ↩ para deshacer")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if f.historial.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(Color(hex: "#818CF8"))
                                Text("Tus abonos y pagos quincenales aparecerán aquí.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                        } else {
                            ForEach(Array(f.historial.prefix(15).enumerated()), id: \.offset) { idx, item in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#10B981").opacity(0.16))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: item.tipo == "ahorro" ? "sparkles" : "arrow.down.right.circle.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color(hex: "#10B981"))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.concepto)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                        Text(item.fecha)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text("+\(item.monto.copFormatted)")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
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
                                            .font(.system(size: 22))
                                            .foregroundStyle(Color.secondary.opacity(0.8))
                                    }
                                    .buttonStyle(LiquidScaleButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 26)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Hola, Andrés")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showEditNomina) {
            NavigationStack {
                Form {
                    Section("Configurar Ingresos de Nómina") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sueldo Base Mensual ($)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("2500000", text: $nuevoSueldo)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bono Quincena 1 ($)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("160000", text: $nuevoBono)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
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
                                Label("Guardar Nómina", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
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

// MARK: - Tarjeta Quincenal Liquid Glass
struct QuincenaLiquidTile: View {
    let badge: String
    let titulo: String
    let neto: Double
    let libre: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titulo)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text(badge)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.18))
                    .foregroundColor(tint)
                    .clipShape(Capsule())
            }

            Text(neto.copFormatted)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            HStack(spacing: 4) {
                Circle()
                    .fill(libre >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                    .frame(width: 7, height: 7)
                Text("Libre: \(libre.copFormatted)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(libre >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((libre >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444")).opacity(0.12))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(cornerRadius: 24, tint: tint, tintOpacity: 0.12)
    }
}

struct DistributionLegendRow: View {
    let color: Color
    let label: String
    let amount: Double

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
            Text(amount.copFormatted)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }
}

// MARK: - Gráfico Donut Vectorial Nativo Liquid Glass
struct BudgetDonutRingView: View {
    let fijos: Double
    let deudas: Double
    let ahorro: Double

    var body: some View {
        let total = max(1, fijos + deudas + ahorro)
        let pFijos = fijos / total
        let pDeudas = deudas / total
        let pAhorro = ahorro / total

        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 13)

            // Segmento Fijos
            Circle()
                .trim(from: 0, to: pFijos)
                .stroke(
                    Color(hex: "#6366F1"),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Segmento Deudas
            Circle()
                .trim(from: pFijos, to: pFijos + pDeudas)
                .stroke(
                    Color(hex: "#F43F5E"),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Segmento Ahorro
            Circle()
                .trim(from: pFijos + pDeudas, to: min(1.0, pFijos + pDeudas + pAhorro))
                .stroke(
                    Color(hex: "#10B981"),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#818CF8"))
                Text("100%")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

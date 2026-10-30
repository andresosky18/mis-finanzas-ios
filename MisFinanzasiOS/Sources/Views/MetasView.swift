import SwiftUI
import UIKit

struct MetasView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAbonoCorvanca = false
    @State private var montoCorvanca = "75000"
    @State private var selectedPeriod = "1Q"

    var body: some View {
        let f = vm.finanzas
        let periods = ["1Q", "1M", "6M", "1A", "Futuro+"]

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // TARJETA HERO DE AHORRO CORVANCA CON BARRAS VERTICALES (Idéntica a Referencia #5 "$18,912.45")
                    VStack(spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("Fondo Corvanca · Creciendo cada quincena")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        // Balance Gigante Centrado con Decimales ",00"
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(f.ahorroCorvanca.copFormatted)
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.75)
                                .lineLimit(1)
                            Text(",00")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.6))
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 8, height: 8)
                            Text("+$150.000 ahorrados")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))
                            Text("este mes")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        // Callout Flotante estilo "Added $2,000 / Withdrew $40" de Referencia #5
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#10B981"))
                                        .frame(width: 18, height: 18)
                                    Text("$")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Text("Aporte Quincenal: +$75.000")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }

                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#4F46E5"))
                                        .frame(width: 18, height: 18)
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.white)
                                }
                                Text("Proyección Anual: \((f.ahorroCorvanca + 1_800_000).copFormatted)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 4)

                        // Gráfico de Barras Píldora Verticales Lavanda/Índigo (Idéntico a Referencia #5)
                        HStack(alignment: .bottom, spacing: 10) {
                            SavingsBarColumn(label: "Ene", ratio: 0.46, isHighlighted: false)
                            SavingsBarColumn(label: "Feb", ratio: 0.58, isHighlighted: false)
                            SavingsBarColumn(label: "Actual", ratio: 0.85, isHighlighted: true)
                            SavingsBarColumn(label: "Q1", ratio: 0.72, isHighlighted: false)
                            SavingsBarColumn(label: "Q2", ratio: 0.88, isHighlighted: false)
                            SavingsBarColumn(label: "Meta+", ratio: 1.0, isHighlighted: false)
                        }
                        .frame(height: 155)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)

                        // Selector de Periodo 1Q / 1M / 6M / 1A / Futuro+
                        HStack {
                            ForEach(periods, id: \.self) { p in
                                Button {
                                    selectedPeriod = p
                                } label: {
                                    Text(p)
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedPeriod == p ? Color.primary.opacity(0.09) : Color.clear)
                                        .foregroundColor(selectedPeriod == p ? .primary : .secondary)
                                        .clipShape(Capsule())
                                }
                                if p != periods.last { Spacer() }
                            }
                        }
                        .padding(.top, 4)

                        Button {
                            montoCorvanca = "75000"
                            showAbonoCorvanca = true
                        } label: {
                            Label("Sumar Depósito Quincenal ($75.000)", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#4F46E5"))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(LiquidScaleButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(22)
                    .liquidGlass(cornerRadius: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 105)
            }
            .refreshable {
                await vm.fetchAllData()
            }
        }
        .sheet(isPresented: $showAbonoCorvanca) {
            NavigationStack {
                Form {
                    Section("Aporte a Corvanca") {
                        TextField("Monto a sumar ($)", text: $montoCorvanca)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                    }
                    Section {
                        Button("Confirmar Depósito") {
                            guard let val = Double(montoCorvanca), val > 0 else { return }
                            Task {
                                await vm.sendAction(["accion": "abonar_ahorro", "monto": val])
                                showAbonoCorvanca = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Depósito Corvanca")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAbonoCorvanca = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct SavingsBarColumn: View {
    let label: String
    let ratio: CGFloat
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                isHighlighted
                                    ? LinearGradient(
                                        colors: [Color(hex: "#818CF8"), Color(hex: "#4F46E5")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [Color(hex: "#6366F1").opacity(0.18), Color(hex: "#6366F1").opacity(0.12)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                            .frame(height: max(24, geo.size.height * ratio))

                        if isHighlighted {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                Text("$")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
            }
            Text(label)
                .font(.system(size: 10, weight: isHighlighted ? .heavy : .semibold, design: .rounded))
                .foregroundColor(isHighlighted ? Color(hex: "#4F46E5") : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

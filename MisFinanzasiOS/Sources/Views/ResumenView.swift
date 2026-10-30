import SwiftUI
import UIKit

struct ResumenView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @Binding var selectedTab: Int
    @State private var privacyHidden = false
    @State private var showEditNomina = false
    @State private var showAllHistorial = false
    @State private var nuevoSueldo = ""
    @State private var nuevoBono = ""

    private func formatAmount(_ val: Double) -> String {
        privacyHidden ? "$ •••••••" : val.copFormatted
    }

    var body: some View {
        let f = vm.finanzas

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // 1. HERO BALANCE CARD + 3 QUICK ACTIONS (Inspirado en Referencias #1 y #2 Algbra)
                    VStack(spacing: 16) {
                        HStack {
                            Text("COP · Mensual")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#CD1713").opacity(0.14))
                                .foregroundColor(Color(hex: "#CD1713"))
                                .clipShape(Capsule())

                            Spacer()

                            Button {
                                vm.triggerHaptic(.light)
                                nuevoSueldo = String(Int(f.sueldoBase))
                                nuevoBono = String(Int(f.bonoQ1))
                                showEditNomina = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Nómina")
                                    Image(systemName: "pencil")
                                }
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            }
                        }

                        // Balance Gigante Centrado con Botón Ojo de Privacidad
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Ingresos Totales del Mes")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Button {
                                    vm.triggerHaptic(.light)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        privacyHidden.toggle()
                                    }
                                } label: {
                                    Image(systemName: privacyHidden ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text(formatAmount(f.totalIngresosMensual))
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1)
                                if !privacyHidden {
                                    Text(",00")
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                                        .foregroundColor(.secondary.opacity(0.65))
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        // 3 Quick Action Squircle Tiles (Idénticos a Send / QR / Receive de Referencia #1)
                        HStack(spacing: 10) {
                            QuickActionTile(
                                title: "Abonar",
                                icon: "arrow.up.circle"
                            ) {
                                selectedTab = 2
                            }

                            QuickActionTile(
                                title: "Quincena",
                                icon: "checklist"
                            ) {
                                selectedTab = 1
                            }

                            QuickActionTile(
                                title: "+Ahorro",
                                icon: "arrow.down.circle"
                            ) {
                                Task {
                                    await vm.sendAction(["accion": "abonar_ahorro", "monto": 75000])
                                }
                            }
                        }
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 30)

                    // 2. SAVING CUBE "FONDO CORVANCA" (Idéntico a "Cubes -> Emergency Fund" de Referencia #2 Algbra)
                    Button {
                        selectedTab = 3
                    } label: {
                        VStack(spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("Fondo de Ahorro")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("1")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .frame(width: 20, height: 20)
                                        .background(Color.primary.opacity(0.08))
                                        .clipShape(Circle())
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#F43F5E").opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: "#F43F5E"))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ahorro Corvanca")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("+$75.000 cada quincena")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(formatAmount(f.ahorroCorvanca))
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(18)
                        .liquidGlass(cornerRadius: 28)
                    }
                    .buttonStyle(LiquidScaleButtonStyle())

                    // 3. BENTO GRID 2 COLUMNAS: ANALYTICS BARRAS + LIQUIDEZ Q1/Q2 (Referencia #2 Algbra)
                    HStack(spacing: 14) {
                        // Tarjeta Izquierda: Analytics con 5 Barras Píldora Verticales
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Presupuesto")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))

                            HStack(alignment: .bottom, spacing: 7) {
                                VerticalPillBar(ratio: 0.45, color: Color(hex: "#38BDF8"))
                                VerticalPillBar(ratio: 0.82, color: Color(hex: "#2563EB"))
                                VerticalPillBar(ratio: 0.56, color: Color(hex: "#38BDF8"))
                                VerticalPillBar(ratio: 0.94, color: Color(hex: "#4F46E5"))
                                VerticalPillBar(ratio: 0.68, color: Color(hex: "#10B981"))
                            }
                            .frame(height: 78)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatAmount(f.totalGastosQuincena))
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1)
                                Text("Gastos por quincena")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .liquidGlass(cornerRadius: 28)

                        // Tarjeta Derecha: Liquidez Q1 vs Q2
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Liquidez Q1/Q2")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("1ra Quincena (Neto)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Text(formatAmount(f.netoQ1))
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                Text("\(f.flujoQ1 >= 0 ? "+" : "-")\(abs(f.flujoQ1).copFormatted) libre")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "#10B981").opacity(0.16))
                                    .foregroundColor(Color(hex: "#10B981"))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("2da Quincena (Base)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Text("\(f.flujoQ2 >= 0 ? "+" : "-")\(abs(f.flujoQ2).copFormatted) \(f.flujoQ2 >= 0 ? "libre" : "déficit")")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(Color(hex: "#F43F5E"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(Color(hex: "#F43F5E").opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .liquidGlass(cornerRadius: 28)
                    }

                    // 4. ACTIVIDAD RECIENTE (3 MOVIMIENTOS + "Ver todos" estilo Referencia #4 Monzo)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Actividad")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                            Button {
                                showAllHistorial = true
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#4F46E5"))
                            }
                        }

                        ForEach(Array(f.historial.prefix(3).enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(item.tipo == "ahorro" ? Color(hex: "#10B981") : Color(hex: "#4F46E5"))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: item.tipo == "ahorro" ? "plus" : "checkmark")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.concepto)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text(item.fecha)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(item.tipo == "ahorro" ? "+" : "-")\(formatAmount(item.monto))")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(item.tipo == "ahorro" ? Color(hex: "#10B981") : .primary)
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            vm.triggerHaptic(.light)
                            showAllHistorial = true
                        } label: {
                            Text("Ver todos los \(f.historial.count) movimientos")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#0284C7"))
                                .padding(.top, 4)
                        }
                    }
                    .padding(18)
                    .liquidGlass(cornerRadius: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 105)
            }
            .refreshable {
                await vm.fetchAllData()
            }
        }
        .sheet(isPresented: $showEditNomina) {
            NavigationStack {
                Form {
                    Section("Configurar Ingresos de Nómina") {
                        LabeledContent("Sueldo Base ($)") {
                            TextField("2500000", text: $nuevoSueldo)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Bono Q1 ($)") {
                            TextField("160000", text: $nuevoBono)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Section {
                        Button("Guardar Cambios") {
                            Task {
                                await vm.sendAction([
                                    "accion": "editar_sueldo",
                                    "nuevo_sueldo": Double(nuevoSueldo) ?? f.sueldoBase,
                                    "nuevo_bono": Double(nuevoBono) ?? f.bonoQ1
                                ])
                                showEditNomina = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Configurar Nómina")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { showEditNomina = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAllHistorial) {
            NavigationStack {
                List {
                    ForEach(Array(f.historial.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 12) {
                            Image(systemName: item.tipo == "ahorro" ? "building.columns.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(item.tipo == "ahorro" ? Color(hex: "#10B981") : Color(hex: "#4F46E5"))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.concepto)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text(item.fecha)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(item.monto.copFormatted)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await vm.sendAction(["accion": "reversar_historial", "index": idx])
                                }
                            } label: {
                                Label("Revertir", systemImage: "arrow.uturn.backward")
                            }
                        }
                    }
                }
                .navigationTitle("Actividad (\(f.historial.count))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { showAllHistorial = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct QuickActionTile: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(LiquidScaleButtonStyle())
    }
}

struct VerticalPillBar: View {
    let ratio: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.07))
                Capsule()
                    .fill(color)
                    .frame(height: max(10, geo.size.height * ratio))
            }
        }
    }
}

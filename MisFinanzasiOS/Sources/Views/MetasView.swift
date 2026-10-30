import SwiftUI
import UIKit

struct MetasView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAbonoCorvanca = false
    @State private var montoCorvanca = "75000"

    @State private var metaSeleccionada: MetaItem?
    @State private var montoMeta = ""

    @State private var showNuevaMeta = false
    @State private var nombreNuevaMeta = ""
    @State private var totalNuevaMeta = ""
    @State private var iconoNuevaMeta = "plane"

    var body: some View {
        let f = vm.finanzas

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // 1. BÓVEDA DE AHORRO BASE CORVANCA (LIQUID GLASS HERO)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("FONDO DE AHORRO CORVANCA")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                            }
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())

                            Spacer()

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.ahorroCorvanca.copFormatted)
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)

                            Text("Aporte automático de $75.000 cada quincena en nómina")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        HStack {
                            Button {
                                montoCorvanca = "75000"
                                showAbonoCorvanca = true
                            } label: {
                                Label("Abonar al Fondo", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .foregroundColor(Color(hex: "#4F46E5"))
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                            }
                            .buttonStyle(LiquidScaleButtonStyle())

                            Spacer()
                        }
                    }
                    .padding(22)
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(hex: "#4F46E5"),
                                    Color(hex: "#7C3AED"),
                                    Color(hex: "#10B981")
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
                                    colors: [Color.white.opacity(0.65), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.3
                            )
                    )
                    .shadow(color: Color(hex: "#7C3AED").opacity(0.35), radius: 20, y: 10)

                    // 2. CABECERA WISHLIST & METAS
                    HStack {
                        Label("WISHLIST & METAS", systemImage: "sparkles")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            nombreNuevaMeta = ""
                            totalNuevaMeta = ""
                            iconoNuevaMeta = "plane"
                            showNuevaMeta = true
                        } label: {
                            Label("Nueva Meta", systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#8B5CF6").opacity(0.18))
                                .foregroundColor(Color(hex: "#A78BFA"))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(LiquidScaleButtonStyle())
                    }
                    .padding(.horizontal, 4)

                    // 3. TARJETAS DE METAS LIQUID GLASS
                    ForEach(f.metasLista) { meta in
                        let falta = max(0, meta.total - meta.actual)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: "#8B5CF6").opacity(0.28),
                                                    Color(hex: "#06B6D4").opacity(0.14)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(Color(hex: "#8B5CF6").opacity(0.45), lineWidth: 1)
                                        )

                                    Image(systemName: SFIconMapper.symbol(for: meta.icono))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "#A78BFA"))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(meta.nombre)
                                        .font(.system(size: 17, weight: .heavy, design: .rounded))

                                    Text(meta.completada ? "¡Meta alcanzada! 🎉" : "Faltan \(falta.copFormatted)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(meta.completada ? Color(hex: "#10B981") : .secondary)
                                }

                                Spacer()

                                LiquidCircularRing(
                                    progress: meta.porcentaje,
                                    color: meta.completada ? Color(hex: "#10B981") : Color(hex: "#8B5CF6"),
                                    size: 46,
                                    lineWidth: 5
                                )
                            }

                            LiquidProgressBar(
                                progress: meta.porcentaje,
                                colors: meta.completada
                                    ? [Color(hex: "#10B981"), Color(hex: "#059669")]
                                    : [Color(hex: "#8B5CF6"), Color(hex: "#06B6D4")],
                                height: 9
                            )

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AHORRADO")
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text("\(meta.actual.copFormatted) de \(meta.total.copFormatted)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Button(role: .destructive) {
                                        Task {
                                            await vm.sendAction([
                                                "accion": "eliminar_meta",
                                                "meta_eliminar": meta.nombre
                                            ])
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(9)
                                            .background(Color.primary.opacity(0.07))
                                            .foregroundColor(.secondary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(LiquidScaleButtonStyle())

                                    if !meta.completada {
                                        Button {
                                            montoMeta = "100000"
                                            metaSeleccionada = meta
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "sparkles")
                                                Text("Fondear")
                                            }
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "#8B5CF6"), Color(hex: "#6366F1")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(LiquidScaleButtonStyle())
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .liquidGlass(cornerRadius: 26, tint: Color(hex: "#8B5CF6"), tintOpacity: 0.11)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Metas y Ahorro")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showAbonoCorvanca) {
            NavigationStack {
                Form {
                    Section("Aporte a Fondo Corvanca") {
                        TextField("Monto a sumar ($)", text: $montoCorvanca)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickAmountChip(title: "$75.000") { montoCorvanca = "75000" }
                                QuickAmountChip(title: "$150.000") { montoCorvanca = "150000" }
                                QuickAmountChip(title: "$300.000") { montoCorvanca = "300000" }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Section {
                        Button {
                            guard let val = Double(montoCorvanca), val > 0 else { return }
                            Task {
                                await vm.sendAction(["accion": "abonar_ahorro", "monto": val])
                                showAbonoCorvanca = false
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Sumar al Ahorro Corvanca", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Ahorro Corvanca")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAbonoCorvanca = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $metaSeleccionada) { m in
            NavigationStack {
                Form {
                    Section("Fondear \(m.nombre)") {
                        TextField("Monto a inyectar ($)", text: $montoMeta)
                            .keyboardType(.numberPad)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickAmountChip(title: "$50.000") { montoMeta = "50000" }
                                QuickAmountChip(title: "$100.000") { montoMeta = "100000" }
                                QuickAmountChip(title: "$250.000") { montoMeta = "250000" }
                                QuickAmountChip(title: "Completar Meta") {
                                    montoMeta = String(Int(max(0, m.total - m.actual)))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Section {
                        Button {
                            guard let val = Double(montoMeta), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_meta",
                                    "meta": m.nombre,
                                    "monto": val
                                ])
                                metaSeleccionada = nil
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Inyectar Capital", systemImage: "sparkles")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Fondear Meta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { metaSeleccionada = nil }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNuevaMeta) {
            NavigationStack {
                Form {
                    Section("Nueva Meta de Ahorro") {
                        TextField("¿Qué quieres lograr?", text: $nombreNuevaMeta)
                        TextField("Costo Total ($)", text: $totalNuevaMeta)
                            .keyboardType(.numberPad)
                        Picker("Ícono", selection: $iconoNuevaMeta) {
                            Text("✈️ Viaje").tag("plane")
                            Text("🪖 Moto / Casco").tag("shield")
                            Text("📱 Tecnología").tag("smartphone")
                            Text("🚗 Vehículo").tag("car")
                            Text("🎯 General").tag("target")
                        }
                    }
                    Section {
                        Button {
                            guard !nombreNuevaMeta.isEmpty, let tot = Double(totalNuevaMeta), tot > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "agregar_meta",
                                    "nombre_meta": nombreNuevaMeta,
                                    "total_meta": tot,
                                    "icono_meta": iconoNuevaMeta
                                ])
                                showNuevaMeta = false
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Crear Meta", systemImage: "checkmark.circle.fill")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Crear Meta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showNuevaMeta = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

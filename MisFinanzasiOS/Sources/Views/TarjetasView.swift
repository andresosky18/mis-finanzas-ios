import SwiftUI
import UIKit

struct TarjetasView: View {
    @EnvironmentObject var vm: FinanzasViewModel

    @State private var selectedCardFilter: String = "Todas"
    @State private var selectedCategoryFilter: String = "Todas"

    // Sheets
    @State private var showAddCompraSheet = false
    @State private var showShortcutGuideSheet = false
    @State private var copiedToast = false

    // Formulario nueva compra con tarjeta / Apple Watch
    @State private var comercioInput = ""
    @State private var montoInput = ""
    @State private var categoriaSeleccionada: CategoriaTarjeta = .comida
    @State private var tarjetaSeleccionada = "Débito"
    @State private var metodoSeleccionado = "Apple Watch"

    private let filtrosTarjeta = ["Todas", "Débito", "Crédito Nu", "Apple Watch"]
    private let tarjetasDisponibles = ["Débito", "Crédito Nu", "Nequi / Débito", "Efectivo"]
    private let metodosDisponibles = ["Apple Watch", "Apple Pay (iPhone)", "Tarjeta Física", "PSE / QR"]

    private var filteredMovimientos: [GastoTarjetaItem] {
        vm.finanzas.gastosTarjeta.filter { item in
            let passCard: Bool
            switch selectedCardFilter {
            case "Débito":
                passCard = !item.esCredito
            case "Crédito Nu":
                passCard = item.esCredito
            case "Apple Watch":
                passCard = item.metodo.localizedCaseInsensitiveContains("watch")
            default:
                passCard = true
            }

            let passCat = (selectedCategoryFilter == "Todas") ||
                          (item.categoriaEnum.rawValue == selectedCategoryFilter)
            return passCard && passCat
        }
    }

    private var resumenPorCategoria: [(categoria: CategoriaTarjeta, total: Double, porcentaje: Double)] {
        let totalGeneral = max(1, vm.finanzas.totalGastadoTarjetas)
        var resultados: [(CategoriaTarjeta, Double, Double)] = []
        for cat in CategoriaTarjeta.allCases {
            let suma = vm.finanzas.gastosTarjeta
                .filter { $0.categoriaEnum == cat }
                .reduce(0) { $0 + $1.monto }
            if suma > 0 {
                resultados.append((cat, suma, suma / totalGeneral))
            }
        }
        return resultados.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        let f = vm.finanzas

        ZStack {
            LiquidGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // Toast automático cuando llega un pago desde Apple Watch / Apple Pay
                    if let toast = vm.lastApplePayToast {
                        HStack(spacing: 10) {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text(toast)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 1. HERO CARD ESTILO LUKAS: GASTOS CON TARJETAS + APPLE PAY / WATCH
                    VStack(spacing: 16) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "applewatch")
                                    .font(.system(size: 12, weight: .heavy))
                                Text("APPLE PAY · WATCH · TARJETAS")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(0.6)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#4F46E5").opacity(0.14))
                            .foregroundColor(Color(hex: "#4F46E5"))
                            .clipShape(Capsule())

                            Spacer()

                            Button {
                                vm.triggerHaptic(.light)
                                showShortcutGuideSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                    Text("Auto-Watch")
                                }
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#10B981").opacity(0.15))
                                .foregroundColor(Color(hex: "#10B981"))
                                .clipShape(Capsule())
                            }
                        }

                        VStack(spacing: 4) {
                            Text("Total Gastado con Tarjetas")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)

                            Text(f.totalGastadoTarjetas.copFormatted)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                        }

                        // Sub-tarjetas Débito vs Crédito Nu
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#10B981"))
                                    Text("Tarjeta Débito")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                Text(f.totalGastadoDebito.copFormatted)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(hex: "#10B981").opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles.rectangle.stack.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#8B5CF6"))
                                    Text("Tarjeta Crédito")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                Text(f.totalGastadoCredito.copFormatted)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(hex: "#8B5CF6").opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        // Botones de Acción Rápida: Anotar Compra + Configurar Atajo Apple Watch
                        HStack(spacing: 10) {
                            Button {
                                vm.triggerHaptic(.light)
                                comercioInput = ""
                                montoInput = ""
                                categoriaSeleccionada = .comida
                                showAddCompraSheet = true
                            } label: {
                                Label("Anotar Pago", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.primary)
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(LiquidScaleButtonStyle())

                            Button {
                                vm.triggerHaptic(.light)
                                showShortcutGuideSheet = true
                            } label: {
                                Label("Conectar Watch / Pay", systemImage: "applewatch.watchface")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.primary.opacity(0.08))
                                    .foregroundColor(.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(LiquidScaleButtonStyle())
                        }
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 30)

                    // 2. DESGLOSE POR CATEGORÍAS (ESTILO LUKAS CON BARRAS MULTICOLOR Y % DE GASTO)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Gastos por Categoría")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                            if selectedCategoryFilter != "Todas" {
                                Button("Ver todas") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedCategoryFilter = "Todas"
                                    }
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#4F46E5"))
                            }
                        }

                        // Barra horizontal segmentada multicolor estilo Lukas
                        GeometryReader { geo in
                            HStack(spacing: 4) {
                                ForEach(resumenPorCategoria, id: \.categoria.id) { item in
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(item.categoria.color)
                                        .frame(width: max(12, (geo.size.width - CGFloat(max(0, resumenPorCategoria.count - 1) * 4)) * item.porcentaje))
                                }
                            }
                        }
                        .frame(height: 12)
                        .clipShape(Capsule())

                        // Lista de Categorías Interactivas (Toca una para filtrar movimientos)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(resumenPorCategoria, id: \.categoria.id) { item in
                                let isSelected = selectedCategoryFilter == item.categoria.rawValue
                                Button {
                                    vm.triggerHaptic(.light)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                        selectedCategoryFilter = isSelected ? "Todas" : item.categoria.rawValue
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(item.categoria.color.opacity(0.16))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: item.categoria.sfSymbol)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(item.categoria.color)
                                        }

                                        VStack(alignment: .leading, spacing: 1) {
                                            HStack(spacing: 4) {
                                                Text(item.categoria.rawValue)
                                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text("\(Int(round(item.porcentaje * 100)))%")
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(item.total.copFormatted)
                                                .font(.system(size: 13, weight: .black, design: .rounded))
                                                .foregroundColor(item.categoria.color)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(10)
                                    .background(
                                        isSelected
                                            ? item.categoria.color.opacity(0.15)
                                            : Color.primary.opacity(0.05)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                isSelected ? item.categoria.color : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(LiquidScaleButtonStyle())
                            }
                        }
                    }
                    .padding(18)
                    .liquidGlass(cornerRadius: 28)

                    // 3. PÍLDORAS DE FILTRO POR TARJETA / DISPOSITIVO
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filtrosTarjeta, id: \.self) { filtro in
                                let active = selectedCardFilter == filtro
                                Button {
                                    vm.triggerHaptic(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedCardFilter = filtro
                                    }
                                } label: {
                                    Text(filtro)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(
                                            active
                                                ? Color.primary.opacity(0.14)
                                                : Color.white.opacity(0.55)
                                        )
                                        .foregroundColor(.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(LiquidScaleButtonStyle())
                            }
                        }
                    }

                    // 4. LISTA DE MOVIMIENTOS CON TARJETA / APPLE WATCH
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Movimientos con Tarjeta (\(filteredMovimientos.count))")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                        }

                        if filteredMovimientos.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "applewatch.side.right")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                Text("No hay compras en este filtro")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(filteredMovimientos) { mov in
                                let cat = mov.categoriaEnum
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(cat.color.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: cat.sfSymbol)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(cat.color)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mov.comercio)
                                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                                            .lineLimit(1)

                                        HStack(spacing: 6) {
                                            Text(cat.rawValue)
                                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(cat.color.opacity(0.15))
                                                .foregroundColor(cat.color)
                                                .clipShape(Capsule())

                                            Text("\(mov.tarjeta) · \(mov.metodo)")
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("-\(mov.monto.copFormatted)")
                                            .font(.system(size: 15, weight: .black, design: .rounded))
                                            .foregroundColor(.primary)

                                        Button(role: .destructive) {
                                            Task {
                                                await vm.sendAction([
                                                    "accion": "eliminar_gasto_tarjeta",
                                                    "id": mov.id
                                                ])
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary.opacity(0.6))
                                        }
                                    }
                                }
                                .padding(14)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                        }
                    }
                    .padding(18)
                    .liquidGlass(cornerRadius: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 105)
            }
        }
        // MODAL 1: ANOTAR PAGO CON TARJETA / WATCH MANUALMENTE
        .sheet(isPresented: $showAddCompraSheet) {
            NavigationStack {
                Form {
                    Section("Detalle del Pago") {
                        TextField("Comercio (Ej: McDonald's, Terpel, D1, Uber)", text: $comercioInput)
                            .onChange(of: comercioInput) { nuevo in
                                if !nuevo.isEmpty {
                                    categoriaSeleccionada = CategoriaTarjeta.detectar(desde: nuevo)
                                }
                            }
                        TextField("Monto en COP ($)", text: $montoInput)
                            .keyboardType(.numberPad)
                    }

                    Section("Categoría Automática (Estilo Lukas)") {
                        Picker("Categoría", selection: $categoriaSeleccionada) {
                            ForEach(CategoriaTarjeta.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.sfSymbol)
                                    .tag(cat)
                            }
                        }
                    }

                    Section("Tarjeta y Dispositivo") {
                        Picker("Tarjeta usada", selection: $tarjetaSeleccionada) {
                            ForEach(tarjetasDisponibles, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        }
                        Picker("Pagado desde", selection: $metodoSeleccionado) {
                            ForEach(metodosDisponibles, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                    }

                    Section {
                        Button("Registrar Movimiento") {
                            guard let valor = Double(montoInput), valor > 0 else { return }
                            let comercioFinal = comercioInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Compra \(categoriaSeleccionada.rawValue)"
                                : comercioInput
                            Task {
                                await vm.sendAction([
                                    "accion": "registrar_gasto_tarjeta",
                                    "comercio": comercioFinal,
                                    "monto": valor,
                                    "categoria": categoriaSeleccionada.rawValue,
                                    "tarjeta": tarjetaSeleccionada,
                                    "metodo": metodoSeleccionado,
                                    "es_credito": tarjetaSeleccionada.localizedCaseInsensitiveContains("crédito") || tarjetaSeleccionada.localizedCaseInsensitiveContains("nu")
                                ])
                                showAddCompraSheet = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Nuevo Pago con Tarjeta")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { showAddCompraSheet = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
        // MODAL 2: GUÍA PASO A PASO PARA CONECTAR APPLE PAY & APPLE WATCH (COMO LUKAS)
        .sheet(isPresented: $showShortcutGuideSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#4F46E5").opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "applewatch.radiowaves.left.and.right")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(hex: "#4F46E5"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-Registro con Apple Pay y Watch")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                Text("Igual que Lukas · 100% Automático al pagar")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("Cada vez que acerques tu **iPhone** o tu **Apple Watch** a un datáfono para pagar con tu tarjeta Débito o Crédito, iOS anotará el gasto automáticamente en **Mis Finanzas** y detectará la categoría por el nombre del comercio.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 14) {
                            ShortcutStepRow(
                                step: "1",
                                title: "Abre la app 'Atajos' (Shortcuts) en tu iPhone",
                                subtitle: "Toca la pestaña 'Automatización' abajo en el centro y presiona el botón '+'."
                            )
                            ShortcutStepRow(
                                step: "2",
                                title: "Elige 'Transacción' (Wallet / Apple Pay)",
                                subtitle: "Selecciona tus tarjetas Débito y Crédito, marca 'Ejecutar inmediatamente' y toca Siguiente."
                            )
                            ShortcutStepRow(
                                step: "3",
                                title: "Agrega la acción 'Abrir URLs'",
                                subtitle: "Pega este enlace mágico (reemplazando Monto, Comercio y Tarjeta con las variables de Entrada del Atajo):"
                            )
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        // Caja con el URL Scheme listo para copiar
                        VStack(alignment: .leading, spacing: 10) {
                            Text("URL PARA PEGAR EN ATAJOS:")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.secondary)

                            Text("misfinanzas://pay?monto=25000&comercio=Comercio&tarjeta=Debito&metodo=AppleWatch")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = "misfinanzas://pay?monto=25000&comercio=McDonalds&tarjeta=Debito&metodo=AppleWatch"
                                    vm.triggerHaptic(.success)
                                    copiedToast = true
                                } label: {
                                    Label(copiedToast ? "¡Copiado al Portapapeles!" : "Copiar Enlace URL", systemImage: copiedToast ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(hex: "#4F46E5"))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }

                                Button {
                                    if let testURL = URL(string: "misfinanzas://pay?monto=18500&comercio=Starbucks%20Cafe&tarjeta=Debito&metodo=Apple%20Watch") {
                                        showShortcutGuideSheet = false
                                        vm.handleIncomingURL(testURL)
                                    }
                                } label: {
                                    Label("Simular Pago Watch", systemImage: "play.fill")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(hex: "#10B981"))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .padding(20)
                }
                .navigationTitle("Apple Pay & Watch")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { showShortcutGuideSheet = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
}

struct ShortcutStepRow: View {
    let step: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Color(hex: "#4F46E5"))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}

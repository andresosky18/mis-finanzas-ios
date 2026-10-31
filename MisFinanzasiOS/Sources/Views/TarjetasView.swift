import SwiftUI
import UIKit

struct TarjetasView: View {
    @EnvironmentObject var vm: FinanzasViewModel

    @State private var selectedCardFilter: String = "Todas"
    @State private var selectedCategoryFilter: String = "Todas"

    // Sheets
    @State private var showAddCompraSheet = false
    @State private var showPasteBankTextSheet = false
    @State private var showShortcutGuideSheet = false

    // Formulario nueva compra con cualquiera de tus tarjetas / Apple Watch / Celular
    @State private var comercioInput = ""
    @State private var montoInput = ""
    @State private var categoriaSeleccionada: CategoriaTarjeta = .comida
    @State private var tarjetaSeleccionada = "Débito Bancolombia"
    @State private var tarjetaPersonalizada = ""
    @State private var metodoSeleccionado = "Apple Watch"

    // Pegar SMS / Notificación bancaria de cualquier banco
    @State private var bankMessageInput = ""

    // Todas las tarjetas colombianas (Débito y Crédito) + opción de escribir cualquier otra
    private let tarjetasDisponibles = [
        "Débito Bancolombia",
        "Crédito Bancolombia",
        "Débito Nu",
        "Crédito Nu",
        "Tarjeta Nequi",
        "Débito Davivienda",
        "Crédito Davivienda",
        "Débito Lulo Bank",
        "RappiCard",
        "Tarjeta BBVA",
        "Banco de Bogotá",
        "Otra Tarjeta..."
    ]

    private let metodosDisponibles = [
        "Apple Watch",
        "Apple Pay (Celular)",
        "Tarjeta Física (Datáfono)",
        "PSE / Compra Online"
    ]

    // Filtros dinámicos basados en las tarjetas reales que has usado + Débito / Crédito / Watch
    private var filtrosTarjetaDinamicos: [String] {
        var base = ["Todas", "Todas Débito", "Todas Crédito", "Apple Watch"]
        let tarjetasUsadas = Set(vm.finanzas.gastosTarjeta.map { $0.tarjeta })
        for t in tarjetasUsadas.sorted() where !base.contains(t) {
            base.append(t)
        }
        return base
    }

    private var filteredMovimientos: [GastoTarjetaItem] {
        vm.finanzas.gastosTarjeta.filter { item in
            let passCard: Bool
            switch selectedCardFilter {
            case "Todas":
                passCard = true
            case "Todas Débito":
                passCard = !item.esCredito
            case "Todas Crédito":
                passCard = item.esCredito
            case "Apple Watch":
                passCard = item.metodo.localizedCaseInsensitiveContains("watch")
            default:
                passCard = item.tarjeta.caseInsensitiveCompare(selectedCardFilter) == .orderedSame
            }

            let passCat = (selectedCategoryFilter == "Todas") ||
                          (item.categoriaEnum.rawValue == selectedCategoryFilter)
            return passCard && passCat
        }
    }

    private var resumenPorCategoria: [(categoria: CategoriaTarjeta, total: Double, porcentaje: Double, cantidad: Int)] {
        let totalGeneral = max(1, vm.finanzas.totalGastadoTarjetas)
        var resultados: [(CategoriaTarjeta, Double, Double, Int)] = []
        for cat in CategoriaTarjeta.allCases {
            let itemsCat = vm.finanzas.gastosTarjeta.filter { $0.categoriaEnum == cat }
            let suma = itemsCat.reduce(0) { $0 + $1.monto }
            if suma > 0 {
                resultados.append((cat, suma, suma / totalGeneral, itemsCat.count))
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

                    // Toast en vivo cuando entra un pago real desde tu Apple Watch, iPhone o SMS
                    if let toast = vm.lastApplePayToast {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
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
                    }

                    // 1. HERO CARD: TODAS TUS TARJETAS DÉBITO Y CRÉDITO (APPLE WATCH + CELULAR)
                    VStack(spacing: 16) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "applewatch.radiowaves.left.and.right")
                                    .font(.system(size: 12, weight: .heavy))
                                Text("TODAS MIS TARJETAS · WATCH & CEL")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .tracking(0.5)
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
                                    Image(systemName: "bolt.fill")
                                    Text("Activar Auto-Registro")
                                }
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#10B981").opacity(0.16))
                                .foregroundColor(Color(hex: "#10B981"))
                                .clipShape(Capsule())
                            }
                        }

                        VStack(spacing: 4) {
                            Text("Gasto Acumulado con Tarjetas")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)

                            Text(f.totalGastadoTarjetas.copFormatted)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                        }

                        // Resumen Todas tus Tarjetas Débito vs Todas tus Tarjetas Crédito
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#10B981"))
                                    Text("Tarjetas Débito")
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
                                    Image(systemName: "creditcard.and.123")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#8B5CF6"))
                                    Text("Tarjetas Crédito")
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

                        // 3 Botones Reales: Registrar Compra | Leer SMS/Notificación | Configurar Atajo Watch/Cel
                        HStack(spacing: 8) {
                            Button {
                                vm.triggerHaptic(.light)
                                comercioInput = ""
                                montoInput = ""
                                categoriaSeleccionada = .comida
                                showAddCompraSheet = true
                            } label: {
                                Label("Nuevo Pago", systemImage: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.primary)
                                    .foregroundColor(Color(UIColor.systemBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(LiquidScaleButtonStyle())

                            Button {
                                vm.triggerHaptic(.light)
                                // Si hay texto en el portapapeles, pre-cargarlo
                                if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                    bankMessageInput = clip
                                } else {
                                    bankMessageInput = ""
                                }
                                showPasteBankTextSheet = true
                            } label: {
                                Label("Leer SMS Banco", systemImage: "message.badge.waveform.fill")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#4F46E5").opacity(0.14))
                                    .foregroundColor(Color(hex: "#4F46E5"))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(LiquidScaleButtonStyle())
                        }
                    }
                    .padding(20)
                    .liquidGlass(cornerRadius: 30)

                    // 2. DESGLOSE POR CATEGORÍAS (ESTILO LUKAS)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Categorías de tus Pagos")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                            if selectedCategoryFilter != "Todas" {
                                Button("Mostrar todas") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedCategoryFilter = "Todas"
                                    }
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#4F46E5"))
                            }
                        }

                        if resumenPorCategoria.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: "#4F46E5"))
                                Text("Cuando pagues con tu Apple Watch o Celular, aquí verás cuánto gastas en Comida, Gasolina, Mercado, Suscripciones y más.")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        } else {
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
                    }
                    .padding(18)
                    .liquidGlass(cornerRadius: 28)

                    // 3. PÍLDORAS DE FILTRO POR TARJETA (TODAS TUS TARJETAS DÉBITO / CRÉDITO / WATCH)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filtrosTarjetaDinamicos, id: \.self) { filtro in
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

                    // 4. LISTA DE MOVIMIENTOS REALES CON TUS TARJETAS
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Mis Compras con Tarjeta (\(filteredMovimientos.count))")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                            Spacer()
                            Button {
                                showShortcutGuideSheet = true
                            } label: {
                                Text("¿Cómo automatizar?")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#4F46E5"))
                            }
                        }

                        if filteredMovimientos.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "applewatch.watchface")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "#4F46E5"))
                                Text("Aún no tienes compras registradas en este filtro")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                Text("Activa el Atajo nativo de iOS 'Registrar Pago con Tarjeta o Apple Watch' para que cada compra real se guarde sola con su categoría.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Button {
                                    showShortcutGuideSheet = true
                                } label: {
                                    Text("Configurar Mi Apple Watch y Tarjetas")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: "#4F46E5"))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
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

                                        Text(mov.fecha)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary.opacity(0.8))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 6) {
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
        // MODAL 1: REGISTRAR COMPRA CON CUALQUIERA DE TUS TARJETAS DÉBITO O CRÉDITO
        .sheet(isPresented: $showAddCompraSheet) {
            NavigationStack {
                Form {
                    Section("¿Dónde pagaste y cuánto fue?") {
                        TextField("Comercio (Ej: Terpel, D1, McDonald's, Uber...)", text: $comercioInput)
                            .onChange(of: comercioInput) { nuevo in
                                if !nuevo.isEmpty {
                                    categoriaSeleccionada = CategoriaTarjeta.detectar(desde: nuevo)
                                }
                            }
                        TextField("Monto en COP ($)", text: $montoInput)
                            .keyboardType(.numberPad)
                    }

                    Section("Categoría Detectada (Puedes cambiarla)") {
                        Picker("Categoría", selection: $categoriaSeleccionada) {
                            ForEach(CategoriaTarjeta.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.sfSymbol)
                                    .tag(cat)
                            }
                        }
                    }

                    Section("¿Con cuál de tus tarjetas pagaste?") {
                        Picker("Tarjeta", selection: $tarjetaSeleccionada) {
                            ForEach(tarjetasDisponibles, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        }
                        if tarjetaSeleccionada == "Otra Tarjeta..." {
                            TextField("Escribe el nombre de tu tarjeta (Ej: Débito Colpatria)", text: $tarjetaPersonalizada)
                        }
                        Picker("Dispositivo", selection: $metodoSeleccionado) {
                            ForEach(metodosDisponibles, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                    }

                    Section {
                        Button("Guardar Movimiento") {
                            let valor = RegistroPagosWalletEngine.limpiarNumeroCOP(montoInput)
                            guard valor > 0 else { return }
                            let comercioFinal = comercioInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Compra \(categoriaSeleccionada.rawValue)"
                                : comercioInput
                            let tarjetaFinal = (tarjetaSeleccionada == "Otra Tarjeta..." && !tarjetaPersonalizada.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ? tarjetaPersonalizada.trimmingCharacters(in: .whitespacesAndNewlines)
                                : tarjetaSeleccionada

                            Task {
                                await vm.sendAction([
                                    "accion": "registrar_gasto_tarjeta",
                                    "comercio": comercioFinal,
                                    "monto": valor,
                                    "categoria": categoriaSeleccionada.rawValue,
                                    "tarjeta": tarjetaFinal,
                                    "metodo": metodoSeleccionado,
                                    "es_credito": tarjetaFinal.localizedCaseInsensitiveContains("crédito") ||
                                                  tarjetaFinal.localizedCaseInsensitiveContains("credito") ||
                                                  tarjetaFinal.localizedCaseInsensitiveContains("rappicard")
                                ])
                                showAddCompraSheet = false
                            }
                        }
                        .fontWeight(.bold)
                    }
                }
                .navigationTitle("Registrar Pago")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { showAddCompraSheet = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
        // MODAL 2: LECTOR INTELIGENTE DE SMS / NOTIFICACIÓN DE CUALQUIER BANCO
        .sheet(isPresented: $showPasteBankTextSheet) {
            NavigationStack {
                Form {
                    Section("Pega el SMS o Notificación de tu Banco") {
                        TextEditor(text: $bankMessageInput)
                            .frame(minHeight: 110)
                        Text("Funciona con Bancolombia, Nu, Davivienda, Nequi, Lulo, BBVA, Banco de Bogotá, etc. Ej: 'Bancolombia le informa compra por $28.500 en TERPEL con su T.Debito'")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if let detectado = RegistroPagosWalletEngine.extraerDatosDeTextoBancario(bankMessageInput) {
                        let cat = CategoriaTarjeta.detectar(desde: detectado.comercio)
                        Section("Datos Detectados Automáticamente") {
                            LabeledContent("Comercio", value: detectado.comercio)
                            LabeledContent("Monto", value: detectado.monto.copFormatted)
                            LabeledContent("Tarjeta", value: detectado.tarjeta)
                            LabeledContent("Categoría", value: cat.rawValue)
                        }

                        Section {
                            Button("Guardar Compra Detectada") {
                                Task {
                                    await vm.sendAction([
                                        "accion": "registrar_gasto_tarjeta",
                                        "comercio": detectado.comercio,
                                        "monto": detectado.monto,
                                        "categoria": cat.rawValue,
                                        "tarjeta": detectado.tarjeta,
                                        "metodo": "Notificación Bancaria",
                                        "es_credito": detectado.tarjeta.localizedCaseInsensitiveContains("crédito") || detectado.tarjeta.localizedCaseInsensitiveContains("credito")
                                    ])
                                    showPasteBankTextSheet = false
                                }
                            }
                            .fontWeight(.bold)
                        }
                    }
                }
                .navigationTitle("Leer SMS / Notificación")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { showPasteBankTextSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        // MODAL 3: CONFIGURACIÓN REAL DE ATAJOS NATIVOS (APPLE WATCH, APPLE PAY Y SMS DE BANCOS)
        .sheet(isPresented: $showShortcutGuideSheet) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#10B981").opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "applewatch.radiowaves.left.and.right")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Conexión Real con Todas tus Tarjetas")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                Text("Acción nativa integrada en iOS Atajos (Sin simulaciones)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("Esta app ya incluye el módulo nativo de Apple **`Registrar Pago con Tarjeta o Apple Watch`** dentro de la app **Atajos (Shortcuts)** de tu iPhone. Funciona en segundo plano sin abrir pantallas falsas y sirve para **todas tus tarjetas Débito y Crédito**.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)

                        // OPCIÓN A: APPLE PAY & APPLE WATCH (TRANSACCIÓN DE WALLET)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPCIÓN 1 · CUANDO PAGUES CON APPLE WATCH O IPHONE (APPLE PAY)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#4F46E5"))

                            ShortcutStepRow(
                                step: "1",
                                title: "Abre 'Atajos' en tu iPhone → pestaña 'Automatización' → botón '+'",
                                subtitle: "Baja y selecciona 'Transacción' (Cuando toque para pagar con Wallet)."
                            )
                            ShortcutStepRow(
                                step: "2",
                                title: "Marca TODAS tus tarjetas (Débito y Crédito)",
                                subtitle: "Elige 'Ejecutar inmediatamente' para que no te pida confirmación."
                            )
                            ShortcutStepRow(
                                step: "3",
                                title: "Busca la acción de Mis Finanzas: 'Registrar Pago con Tarjeta o Apple Watch'",
                                subtitle: "En 'Monto' pon la variable [Monto], en 'Comercio' pon [Comercio / Nombre] y en 'Tarjeta' pon [Tarjeta o Pase]."
                            )
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        // OPCIÓN B: PARA TARJETAS FÍSICAS O BANCOS QUE ENVÍAN SMS (BANCOLOMBIA, DAVIVIENDA, ETC.)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPCIÓN 2 · AUTOMÁTICO POR SMS DE TU BANCO (CUALQUIER TARJETA)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#10B981"))

                            ShortcutStepRow(
                                step: "1",
                                title: "En 'Automatización' → '+' → elige 'Mensaje' (SMS)",
                                subtitle: "En 'Mensaje contiene' escribe la palabra: compra (o el código de tu banco, ej. 85432)."
                            )
                            ShortcutStepRow(
                                step: "2",
                                title: "Agrega la acción 'Registrar Pago con Tarjeta o Apple Watch'",
                                subtitle: "Pasa el [Contenido del mensaje] en el campo 'Comercio o Texto'. La app extrae sola el valor ($), el comercio, el banco y la categoría."
                            )
                        }
                        .padding(16)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        Button {
                            if let shortcutsURL = URL(string: "shortcuts://") {
                                UIApplication.shared.open(shortcutsURL)
                            }
                        } label: {
                            Label("Abrir App 'Atajos' de mi iPhone Ahora", systemImage: "arrow.up.forward.app.fill")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#4F46E5"))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(20)
                }
                .navigationTitle("Conectar Mis Tarjetas")
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

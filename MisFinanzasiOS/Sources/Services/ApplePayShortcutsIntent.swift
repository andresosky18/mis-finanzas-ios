import Foundation
import AppIntents

// MARK: - Motor Compartido de Registro Real de Pagos (AppIntents en Background + URL Scheme + UI)
enum RegistroPagosWalletEngine {
    static let storageKey = "finanzas_personal_cache_v4_xoje"
    static let notificationName = Notification.Name("MisFinanzasDidReceiveWalletPayment")

    // Parseador Inteligente de SMS / Notificación Bancaria o Texto libre de Apple Pay
    // Soporta Bancolombia, Nu, Davivienda, Nequi, BBVA, Banco de Bogotá, Lulo, RappiPay y texto directo de Wallet
    static func extraerDatosDeTextoBancario(_ texto: String) -> (comercio: String, monto: Double, tarjeta: String)? {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return nil }

        // 1. Extraer monto ($25.000, $ 120,500, COP 45.000, 38000)
        var montoDetectado: Double = 0
        let regexMonto = try? NSRegularExpression(
            pattern: #"(?:\$|COP|por|valor\s+de)\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{3,10})"#,
            options: [.caseInsensitive]
        )
        if let match = regexMonto?.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
           match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: limpio) {
            montoDetectado = limpiarNumeroCOP(String(limpio[r]))
        } else {
            // Buscar cualquier número de al menos 4 dígitos
            let fallbackNum = try? NSRegularExpression(pattern: #"\b([0-9]{1,3}(?:[.,][0-9]{3})+|[0-9]{4,9})\b"#)
            if let m = fallbackNum?.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
               let r = Range(m.range(at: 1), in: limpio) {
                montoDetectado = limpiarNumeroCOP(String(limpio[r]))
            }
        }

        // 2. Detectar banco / tarjeta del texto
        var tarjetaDetectada = "Apple Pay / Tarjeta"
        let lower = limpio.lowercased()
        if lower.contains("bancolombia") {
            tarjetaDetectada = lower.contains("crédito") || lower.contains("credito") || lower.contains("t.cred") ? "Crédito Bancolombia" : "Débito Bancolombia"
        } else if lower.contains("nu") || lower.contains("nubank") {
            tarjetaDetectada = lower.contains("débito") || lower.contains("debito") ? "Débito Nu" : "Crédito Nu"
        } else if lower.contains("nequi") {
            tarjetaDetectada = "Tarjeta Nequi"
        } else if lower.contains("davivienda") || lower.contains("daviplata") {
            tarjetaDetectada = lower.contains("crédito") || lower.contains("credito") ? "Crédito Davivienda" : "Débito Davivienda"
        } else if lower.contains("lulo") {
            tarjetaDetectada = "Débito Lulo Bank"
        } else if lower.contains("rappipay") || lower.contains("rappiCard") {
            tarjetaDetectada = "RappiCard"
        } else if lower.contains("bbva") {
            tarjetaDetectada = "Tarjeta BBVA"
        } else if lower.contains("bogota") || lower.contains("bogotá") {
            tarjetaDetectada = "Banco de Bogotá"
        }

        // 3. Extraer nombre del comercio (ej: "en MCDONALDS", "en TERPEL", "en D1")
        var comercioDetectado = limpio
        let regexComercio = try? NSRegularExpression(
            pattern: #"(?:compra\s+en|pagaste\s+en|en\s+el\s+comercio|en)\s+([A-Za-z0-9ÁÉÍÓÚáéíóúÑñ\s\.\-\*\/]{2,35}?)(?:\s+por|\s+con|\s+el\s+\d|\s+\$|\.|,|$)"#,
            options: [.caseInsensitive]
        )
        if let m = regexComercio?.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
           m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: limpio) {
            comercioDetectado = String(limpio[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard montoDetectado > 0 else { return nil }
        return (comercio: comercioDetectado, monto: montoDetectado, tarjeta: tarjetaDetectada)
    }

    static func limpiarNumeroCOP(_ raw: String) -> Double {
        var s = raw
            .replacingOccurrences(of: "COP", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Si termina en ,00 o .00 (centavos), quitar los centavos
        if s.hasSuffix(",00") || s.hasSuffix(".00") {
            s = String(s.dropLast(3))
        }
        let soloDigitos = s
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(soloDigitos) ?? 0
    }

    @discardableResult
    static func guardarPagoReal(
        comercio: String,
        monto: Double,
        tarjeta: String,
        dispositivo: String = "Apple Watch / Pay",
        categoriaManual: String? = nil
    ) -> GastoTarjetaItem {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy - HH:mm"
        formatter.locale = Locale(identifier: "es_CO")
        let fechaActual = formatter.string(from: Date())

        let comercioLimpio = comercio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Pago Contactless"
            : comercio.trimmingCharacters(in: .whitespacesAndNewlines)

        let tarjetaLimpia = tarjeta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Tarjeta Wallet"
            : tarjeta.trimmingCharacters(in: .whitespacesAndNewlines)

        let cat = CategoriaTarjeta.detectar(desde: comercioLimpio, categoriaExplicita: categoriaManual)
        let lowerCard = tarjetaLimpia.lowercased()
        let esCredito = lowerCard.contains("crédito") ||
                        lowerCard.contains("credito") ||
                        lowerCard.contains("tc") ||
                        lowerCard.contains("mastercard") && !lowerCard.contains("débito") && !lowerCard.contains("debito") && lowerCard.contains("nu")

        let nuevoMovimiento = GastoTarjetaItem(
            id: UUID().uuidString,
            fecha: fechaActual,
            comercio: comercioLimpio,
            monto: monto,
            categoria: cat.rawValue,
            tarjeta: tarjetaLimpia,
            metodo: dispositivo,
            esCredito: esCredito
        )

        // 1. Actualizar almacenamiento persistente local de la App (UserDefaults)
        var finanzas: FinanzasData
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(FinanzasData.self, from: data) {
            finanzas = decoded
        } else {
            finanzas = FinanzasData.defaultAndresData()
        }

        finanzas.gastosTarjeta.insert(nuevoMovimiento, at: 0)
        finanzas.historial.insert(
            HistorialItem(
                fecha: fechaActual,
                concepto: "[\(cat.rawValue)] \(comercioLimpio) • \(tarjetaLimpia)",
                monto: monto,
                tipo: "tarjeta",
                deudaKey: nil,
                gastoOrigen: dispositivo
            ),
            at: 0
        )
        if finanzas.historial.count > 40 {
            finanzas.historial = Array(finanzas.historial.prefix(40))
        }
        finanzas.recalculateAll()

        if let encoded = try? JSONEncoder().encode(finanzas) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }

        // Notificar a la UI si está abierta
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notificationName, object: nuevoMovimiento)
        }

        return nuevoMovimiento
    }
}

// MARK: - Acción Nativa de iOS AppIntents para la app Atajos ("Registrar Pago de Wallet / Apple Watch")
@available(iOS 16.0, *)
struct RegistrarPagoWalletIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Pago con Tarjeta o Apple Watch"
    static var description = IntentDescription(
        "Registra automáticamente en Mis Finanzas cualquier compra pagada con tus tarjetas Débito o Crédito en Apple Pay, Apple Watch o SMS bancario y detecta su categoría."
    )
    // Se ejecuta en 2do plano al pagar con el reloj o el celular sin siquiera obligarte a desbloquear la app
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Comercio o Texto de la Compra", default: "Compra Apple Pay")
    var comercio: String

    @Parameter(title: "Monto Pagado (COP)", default: 0)
    var monto: Double

    @Parameter(title: "Nombre de la Tarjeta (Cualquier Débito o Crédito)", default: "Tarjeta Wallet")
    var tarjeta: String

    @Parameter(title: "Dispositivo (Apple Watch o iPhone)", default: "Apple Watch / Pay")
    var dispositivo: String

    static var parameterSummary: some ParameterSummary {
        Summary("Anotar pago de \(\.$monto) en \(\.$comercio) con \(\.$tarjeta) (\(\.$dispositivo))")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var comercioFinal = comercio
        var montoFinal = monto
        var tarjetaFinal = tarjeta

        // Si el usuario pasó un mensaje completo del banco o notificación en el campo comercio
        if montoFinal <= 0, let extraido = RegistroPagosWalletEngine.extraerDatosDeTextoBancario(comercio) {
            comercioFinal = extraido.comercio
            montoFinal = extraido.monto
            if tarjetaFinal == "Tarjeta Wallet" || tarjetaFinal.isEmpty {
                tarjetaFinal = extraido.tarjeta
            }
        }

        guard montoFinal > 0 else {
            return .result(dialog: "No se detectó un monto mayor a $0 para registrar.")
        }

        let item = RegistroPagosWalletEngine.guardarPagoReal(
            comercio: comercioFinal,
            monto: montoFinal,
            tarjeta: tarjetaFinal,
            dispositivo: dispositivo
        )

        return .result(
            dialog: "✅ Guardado en Mis Finanzas: \(item.comercio) por \(item.monto.copFormatted) en la categoría \(item.categoria) (\(item.tarjeta))."
        )
    }
}

// MARK: - Proveedor de Atajos Automáticos de Mis Finanzas en iOS y Siri / Apple Watch
@available(iOS 16.0, *)
struct MisFinanzasShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegistrarPagoWalletIntent(),
            phrases: [
                "Registrar pago en \(.applicationName)",
                "Anotar gasto con tarjeta en \(.applicationName)",
                "Guardar compra de Apple Watch en \(.applicationName)"
            ],
            shortTitle: "Registrar Pago Tarjeta",
            systemImageName: "applewatch.radiowaves.left.and.right"
        )
    }
}

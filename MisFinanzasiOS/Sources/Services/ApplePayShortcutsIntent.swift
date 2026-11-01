import Foundation
import AppIntents
import UserNotifications

// MARK: - Motor Compartido de Registro Real de Pagos (Apple Watch, Tarjeta Física, QR, Correo, SMS, Push)
enum RegistroPagosWalletEngine {
    static let storageKey = "finanzas_personal_cache_v4_xoje"
    static let notificationName = Notification.Name("MisFinanzasDidReceiveWalletPayment")
    static let liveWebhookURL = "http://pagos.xo.je/mis_finanzas.php?i=1"

    // Solicitar permiso de notificaciones locales en iPhone y Apple Watch para avisar la categoría al instante
    static func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Enviar Notificación Push Local inmediata al iPhone y Apple Watch con la Categoría detectada
    static func dispararNotificacionCategoria(_ item: GastoTarjetaItem) {
        let content = UNMutableNotificationContent()
        content.title = "💳 Pago guardado en \(item.categoria)"
        content.subtitle = "\(item.comercio) • \(item.monto.copFormatted)"
        content.body = "Pagado con \(item.tarjeta) (\(item.metodo)). Ya quedó anotado en Mis Finanzas."
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "misfinanzas-pay-\(item.id)",
            content: content,
            trigger: nil // Inmediato
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // Parseador Universal Inteligente:
    // Soporta:
    // 1. Notificaciones Push / Correos / SMS de Bancolombia, Nu, Nequi, Davivienda, DaviPlata, Lulo, BBVA, Banco de Bogotá, Scotiabank Colpatria, RappiPay
    // 2. Comprobantes de pago por QR (Transferencia QR, Bre-B, Nequi QR, Bancolombia A la mano)
    // 3. Texto libre o OCR de pantalla ("Compra en D1 por $45.000")
    static func extraerDatosDeTextoBancario(_ texto: String) -> (comercio: String, monto: Double, tarjeta: String, metodo: String)? {
        let limpio = texto
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return nil }

        // 1. Extraer monto ($25.000, $ 120,500.00, COP 45.000, por valor de $38.000)
        var montoDetectado: Double = 0
        let patronesMonto = [
            #"(?:\$|COP|valor\s+de|compra\s+por|transferencia\s+por|pagaste|enviaste|pago\s+exitoso\s+por)\s*\$?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{4,10})"#,
            #"\$([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{3,10})"#,
            #"\b([0-9]{1,3}(?:\.[0-9]{3})+)\b"#
        ]

        for pat in patronesMonto {
            if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
               match.numberOfRanges >= 2,
               let r = Range(match.range(at: 1), in: limpio) {
                let candidato = limpiarNumeroCOP(String(limpio[r]))
                if candidato >= 500 {
                    montoDetectado = candidato
                    break
                }
            }
        }

        // 2. Detectar si fue QR, Transferencia, Apple Watch, Tarjeta Física o Push
        let lower = limpio.lowercased()
        var metodoDetectado = "Automático"
        if lower.contains("qr") || lower.contains("código qr") || lower.contains("codigo qr") || lower.contains("bre-b") {
            metodoDetectado = "Pago con QR"
        } else if lower.contains("apple pay") || lower.contains("apple watch") || lower.contains("wallet") {
            metodoDetectado = "Apple Watch / Pay"
        } else if lower.contains("transferencia") || lower.contains("enviaste") || lower.contains("pse") {
            metodoDetectado = "Transferencia / QR"
        } else {
            metodoDetectado = "Tarjeta Física / Push"
        }

        // 3. Detectar Banco y si es Débito o Crédito
        var tarjetaDetectada = "Tarjeta Débito"
        let esCreditoTexto = lower.contains("crédito") || lower.contains("credito") || lower.contains("t.cred") || lower.contains("tc ") || lower.contains("mastercard") && lower.contains("nu")

        if lower.contains("bancolombia") {
            if metodoDetectado.contains("QR") {
                tarjetaDetectada = "QR Bancolombia"
            } else {
                tarjetaDetectada = esCreditoTexto ? "Crédito Bancolombia" : "Débito Bancolombia"
            }
        } else if lower.contains("nu") || lower.contains("nubank") || lower.contains("nu colombia") {
            tarjetaDetectada = (lower.contains("débito") || lower.contains("debito") || lower.contains("cuenta nu")) ? "Débito Nu" : "Crédito Nu"
        } else if lower.contains("nequi") {
            tarjetaDetectada = metodoDetectado.contains("QR") ? "QR Nequi" : "Tarjeta Nequi"
        } else if lower.contains("davivienda") || lower.contains("daviplata") {
            tarjetaDetectada = esCreditoTexto ? "Crédito Davivienda" : "Débito Davivienda"
        } else if lower.contains("lulo") {
            tarjetaDetectada = "Débito Lulo Bank"
        } else if lower.contains("rappipay") || lower.contains("rappicard") {
            tarjetaDetectada = "RappiCard"
        } else if lower.contains("bbva") {
            tarjetaDetectada = esCreditoTexto ? "Crédito BBVA" : "Débito BBVA"
        } else if lower.contains("bogota") || lower.contains("bogotá") {
            tarjetaDetectada = esCreditoTexto ? "Crédito Banco de Bogotá" : "Débito Banco de Bogotá"
        } else if lower.contains("colpatria") || lower.contains("scotiabank") {
            tarjetaDetectada = esCreditoTexto ? "Crédito Colpatria" : "Débito Colpatria"
        } else if esCreditoTexto {
            tarjetaDetectada = "Tarjeta Crédito"
        }

        // 4. Extraer el nombre del Comercio o Destinatario QR
        var comercioDetectado = "Compra con \(tarjetaDetectada)"
        let patronesComercio = [
            #"(?:compra\s+en|pagaste\s+en|en\s+el\s+comercio|establecimiento|comercio:?|a\s+nombre\s+de|transferencia\s+a|enviaste\s+a|pago\s+a|en)\s+([A-Za-z0-9ÁÉÍÓÚáéíóúÑñ\s\.\-\*\/&]{2,36}?)(?:\s+por\s+|\s+con\s+tu|\s+con\s+su|\s+el\s+\d|\s+exitos|\s+desde|\s+\$|\.|,|$)"#
        ]
        for patC in patronesComercio {
            if let regexC = try? NSRegularExpression(pattern: patC, options: [.caseInsensitive]),
               let m = regexC.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
               m.numberOfRanges >= 2,
               let r = Range(m.range(at: 1), in: limpio) {
                let candidato = String(limpio[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                if candidato.count >= 2 {
                    comercioDetectado = candidato
                    break
                }
            }
        }

        guard montoDetectado > 0 else { return nil }
        return (comercio: comercioDetectado, monto: montoDetectado, tarjeta: tarjetaDetectada, metodo: metodoDetectado)
    }

    static func limpiarNumeroCOP(_ raw: String) -> Double {
        var s = raw
            .replacingOccurrences(of: "COP", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            ? "Compra Automática"
            : comercio.trimmingCharacters(in: .whitespacesAndNewlines)

        let tarjetaLimpia = tarjeta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Tarjeta Wallet"
            : tarjeta.trimmingCharacters(in: .whitespacesAndNewlines)

        let cat = CategoriaTarjeta.detectar(desde: comercioLimpio, categoriaExplicita: categoriaManual)
        let lowerCard = tarjetaLimpia.lowercased()
        let esCredito = lowerCard.contains("crédito") ||
                        lowerCard.contains("credito") ||
                        lowerCard.contains("tc") ||
                        lowerCard.contains("rappicard") ||
                        (lowerCard.contains("nu") && !lowerCard.contains("débito") && !lowerCard.contains("debito"))

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

        // 1. Guardar inmediatamente en almacenamiento local de la App
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

        // 2. Disparar notificación local en el iPhone / Apple Watch indicando la categoría
        dispararNotificacionCategoria(nuevoMovimiento)

        // 3. Notificar a la UI si está abierta
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notificationName, object: nuevoMovimiento)
        }

        return nuevoMovimiento
    }
}

// MARK: - 1. AppIntent para Transacciones de Apple Watch / Apple Pay (Wallet)
@available(iOS 16.0, *)
struct RegistrarPagoWalletIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Pago con Tarjeta o Apple Watch"
    static var description = IntentDescription(
        "Se ejecuta en segundo plano cuando pagas con Apple Watch, Apple Pay, Tarjeta Física, QR, Correo o SMS y guarda el movimiento con su categoría."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Comercio o Texto Completo (Push / Correo / SMS / QR)", default: "Compra Apple Pay")
    var comercio: String

    @Parameter(title: "Monto Pagado (Dejar en 0 si pasas texto completo)", default: 0)
    var monto: Double

    @Parameter(title: "Nombre de la Tarjeta o Banco", default: "Tarjeta Wallet")
    var tarjeta: String

    @Parameter(title: "Método (Apple Watch, Celular, Tarjeta Física, QR)", default: "Apple Watch / Pay")
    var dispositivo: String

    static var parameterSummary: some ParameterSummary {
        Summary("Anotar pago de \(\.$monto) en \(\.$comercio) con \(\.$tarjeta) (\(\.$dispositivo))")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var comercioFinal = comercio
        var montoFinal = monto
        var tarjetaFinal = tarjeta
        var metodoFinal = dispositivo

        // Si viene de un Correo Bancario, SMS, Notificación Push o Comprobante QR
        if montoFinal <= 0, let extraido = RegistroPagosWalletEngine.extraerDatosDeTextoBancario(comercio) {
            comercioFinal = extraido.comercio
            montoFinal = extraido.monto
            if tarjetaFinal == "Tarjeta Wallet" || tarjetaFinal.isEmpty {
                tarjetaFinal = extraido.tarjeta
            }
            if metodoFinal == "Apple Watch / Pay" {
                metodoFinal = extraido.metodo
            }
        }

        guard montoFinal > 0 else {
            return .result(dialog: "No se detectó un monto válido mayor a $0.")
        }

        let item = RegistroPagosWalletEngine.guardarPagoReal(
            comercio: comercioFinal,
            monto: montoFinal,
            tarjeta: tarjetaFinal,
            dispositivo: metodoFinal
        )

        return .result(
            dialog: "✅ Guardado en \(item.categoria): \(item.comercio) por \(item.monto.copFormatted) con \(item.tarjeta)."
        )
    }
}

// MARK: - 2. AppIntent Especial para Tarjeta Física, QR, Correo Bancario y Notificación Push
@available(iOS 16.0, *)
struct RegistrarPagoTextoBancarioIntent: AppIntent {
    static var title: LocalizedStringResource = "Auto-Detectar Pago de Correo, Push, SMS o QR"
    static var description = IntentDescription(
        "Pega o pasa automáticamente el texto de un correo del banco, notificación push, SMS o comprobante QR. Extrae solo el valor, el comercio, la tarjeta y la categoría."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Texto de la Notificación Push, Correo, SMS o Pantalla")
    var textoNotificacion: String

    static var parameterSummary: some ParameterSummary {
        Summary("Auto-detectar compra y categoría desde \(\.$textoNotificacion)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let extraido = RegistroPagosWalletEngine.extraerDatosDeTextoBancario(textoNotificacion) else {
            return .result(dialog: "No se encontró un monto en pesos ($) dentro del texto recibido.")
        }

        let item = RegistroPagosWalletEngine.guardarPagoReal(
            comercio: extraido.comercio,
            monto: extraido.monto,
            tarjeta: extraido.tarjeta,
            dispositivo: extraido.metodo
        )

        return .result(
            dialog: "✅ \(item.categoria): \(item.comercio) (\(item.monto.copFormatted)) con \(item.tarjeta) [\(item.metodo)]."
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
            shortTitle: "Registrar Pago Watch / Tarjeta",
            systemImageName: "applewatch.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: RegistrarPagoTextoBancarioIntent(),
            phrases: [
                "Detectar pago bancario en \(.applicationName)",
                "Leer comprobante QR en \(.applicationName)"
            ],
            shortTitle: "Auto-Detectar Push / QR / Correo",
            systemImageName: "qrcode.viewfinder"
        )
    }
}

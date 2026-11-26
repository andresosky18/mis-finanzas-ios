import Foundation
import AppIntents
import UserNotifications

// MARK: - Motor Compartido de Registro Real de Pagos (Apple Watch, Tarjeta Física, QR, Correo, SMS, Push)
enum RegistroPagosWalletEngine {
    static let storageKey = "finanzas_personal_cache_v5_xoje"
    static let notificationName = Notification.Name("MisFinanzasDidReceiveWalletPayment")
    static let liveWebhookURL = "http://pagos.xo.je/api_finanzas.php"

    struct PagoDetectado: Equatable {
        let comercio: String
        let monto: Double
        let tarjeta: String
        let metodo: String
    }

    // Solicitar permiso de notificaciones locales en iPhone y Apple Watch para avisar la categoría al instante
    static func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Enviar Notificación Push Local inmediata al iPhone (Pantalla Bloqueada) y Apple Watch con la Categoría detectada
    static func dispararNotificacionCategoria(_ item: GastoTarjetaItem) {
        let content = UNMutableNotificationContent()
        content.title = "💳 Pago guardado en \(item.categoria)"
        content.subtitle = "\(item.comercio) • \(item.monto.copFormatted)"
        content.body = "Pagado con \(item.tarjeta) (\(item.metodo)). Sincronizado en Mis Finanzas."
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "misfinanzas-pay-\(item.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Extractor Multi-Pago (Soporta Capturas con Varias Notificaciones de Wallet / Nu / Bancolombia / Nequi / QR)
    static func extraerTodosLosPagosDeTexto(_ texto: String) -> [PagoDetectado] {
        let normalizado = texto
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizado.isEmpty else { return [] }

        var resultados: [PagoDetectado] = []

        // 1. Primero buscar bloques estilo Apple Wallet (Ej: "Nu \n Eds Coesco Union Roma \n COP 20,465")
        let lineas = normalizado
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let regexLineaMontoWallet = try? NSRegularExpression(
            pattern: #"^(?:COP|\$)\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{3,10})$"#,
            options: [.caseInsensitive]
        )

        var indicesUsadosEnWallet = Set<Int>()

        if let regexW = regexLineaMontoWallet {
            for (idx, linea) in lineas.enumerated() {
                guard let match = regexW.firstMatch(in: linea, range: NSRange(linea.startIndex..., in: linea)),
                      match.numberOfRanges >= 2,
                      let rMonto = Range(match.range(at: 1), in: linea) else {
                    continue
                }
                let monto = limpiarNumeroCOP(String(linea[rMonto]))
                guard monto >= 500 else { continue }

                // Buscar hacia arriba el comercio y el banco (ignorando horas o encabezados del sistema)
                var comercioCandidato: String? = nil
                var bancoCandidato: String = "Débito Nu"

                let startLookback = max(0, idx - 4)
                for prevIdx in stride(from: idx - 1, through: startLookback, by: -1) {
                    let prev = lineas[prevIdx]
                    if esLineaIgnorableDePantalla(prev) { continue }
                    if esNombreDeBancoCorto(prev) {
                        bancoCandidato = normalizarNombreTarjeta(prev)
                        indicesUsadosEnWallet.insert(prevIdx)
                        break
                    }
                    if comercioCandidato == nil {
                        comercioCandidato = limpiarNombreComercio(prev)
                        indicesUsadosEnWallet.insert(prevIdx)
                    }
                }

                if let com = comercioCandidato, !com.isEmpty {
                    indicesUsadosEnWallet.insert(idx)
                    let nuevo = PagoDetectado(
                        comercio: com,
                        monto: monto,
                        tarjeta: bancoCandidato,
                        metodo: "Apple Watch / Pay"
                    )
                    if !resultados.contains(where: { $0.comercio.caseInsensitiveCompare(nuevo.comercio) == .orderedSame && abs($0.monto - nuevo.monto) < 1 }) {
                        resultados.append(nuevo)
                    }
                }
            }
        }

        // 2. Buscar notificaciones Push de Nubank / Bancolombia / Nequi (incluso truncadas como "Compra aprobada por $3.9...")
        // Unimos las líneas que no fueron consumidas exclusivamente por Wallet o analizamos por bloques de "Compra aprobada" / "Compra en" / "Pagaste"
        let bloquesNotificacion = dividirEnBloquesDeNotificacion(lineas: lineas)
        for bloque in bloquesNotificacion {
            if let det = extraerPagoIndividualDeBloque(bloque) {
                if !resultados.contains(where: { $0.comercio.caseInsensitiveCompare(det.comercio) == .orderedSame && abs($0.monto - det.monto) < 1 }) {
                    resultados.append(det)
                }
            }
        }

        // 3. Si aún no se encontró con las reglas de múltiples bloques, intentar sobre el texto completo limpio
        if resultados.isEmpty, let unico = extraerPagoIndividualDeBloque(normalizado) {
            resultados.append(unico)
        }

        return resultados
    }

    // Compatibilidad con llamadas que esperan el primer pago detectado
    static func extraerDatosDeTextoBancario(_ texto: String) -> (comercio: String, monto: Double, tarjeta: String, metodo: String)? {
        guard let primero = extraerTodosLosPagosDeTexto(texto).first else { return nil }
        return (comercio: primero.comercio, monto: primero.monto, tarjeta: primero.tarjeta, metodo: primero.metodo)
    }

    // MARK: - Helpers de Parseo Inteligente para Notificaciones de iOS
    private static func dividirEnBloquesDeNotificacion(lineas: [String]) -> [String] {
        var bloques: [String] = []
        var actual: [String] = []

        for l in lineas {
            if esLineaIgnorableDePantalla(l) && !l.lowercased().contains("compra") && !l.lowercased().contains("pagaste") {
                continue
            }
            let low = l.lowercased()
            let iniciaNuevaNotif = low.hasPrefix("compra aprobada") ||
                                   low.hasPrefix("bancolombia") ||
                                   low.hasPrefix("recibiste ") ||
                                   low.hasPrefix("pagaste ") ||
                                   low.hasPrefix("enviaste ") ||
                                   low.hasPrefix("transferencia ")
            if iniciaNuevaNotif && !actual.isEmpty {
                bloques.append(actual.joined(separator: " "))
                actual = [l]
            } else {
                actual.append(l)
            }
        }
        if !actual.isEmpty {
            bloques.append(actual.joined(separator: " "))
        }
        return bloques
    }

    private static func extraerPagoIndividualDeBloque(_ bloqueRaw: String) -> PagoDetectado? {
        var limpio = bloqueRaw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return nil }

        let lowerCheck = limpio.lowercased()
        // Ignorar únicamente este bloque si es una transferencia recibida ("Recibiste 40.000,00" / "Te llegó dinero")
        if (lowerCheck.contains("recibiste ") || lowerCheck.contains("te llegó dinero") || lowerCheck.contains("te llego dinero")) &&
           !lowerCheck.contains("compra aprobada") && !lowerCheck.contains("compra en ") {
            return nil
        }

        // Eliminar "terminada en 3712" o "finalizada en 1234" para que los 4 dígitos de la tarjeta nunca se confundan con el monto
        if let regexTerm = try? NSRegularExpression(pattern: #"(?:terminad[ao]|finalizad[ao])\s+en\s+\*?[0-9]{3,4}"#, options: [.caseInsensitive]) {
            limpio = regexTerm.stringByReplacingMatches(in: limpio, options: [], range: NSRange(limpio.startIndex..., in: limpio), withTemplate: "")
        }

        var montoDetectado: Double = 0

        // Caso especial iOS Notification Center truncado de Nubank: "Compra aprobada por $3.9..." -> $3,900 o "$5.0..." -> $5,000
        let patronTruncadoNu = #"(?:compra\s+aprobada\s+por|compra\s+por|pagaste|valor\s+de)\s*\$\s*([0-9]{1,3})\.([0-9]{1,2})\s*(?:\.{2,3}|…)"#
        if let regexTrunc = try? NSRegularExpression(pattern: patronTruncadoNu, options: [.caseInsensitive]),
           let matchT = regexTrunc.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
           matchT.numberOfRanges >= 3,
           let rMiles = Range(matchT.range(at: 1), in: limpio),
           let rCentenas = Range(matchT.range(at: 2), in: limpio) {
            let miles = Int(limpio[rMiles]) ?? 0
            let centStr = String(limpio[rCentenas]).padding(toLength: 3, withPad: "0", startingAt: 0)
            let centenas = Int(centStr) ?? 0
            let calculado = Double(miles * 1000 + centenas)
            if calculado >= 500 {
                montoDetectado = calculado
            }
        }

        // Patrones normales de monto ($20,465 | COP 20,465 | $3.900,00 | 17100)
        if montoDetectado <= 0 {
            let patronesMonto = [
                #"(?:\$|COP|valor\s+de|compra\s+aprobada\s+por|compra\s+por|transferencia\s+por|pagaste|enviaste|pago\s+exitoso\s+por)\s*\$?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{3,10})"#,
                #"\$\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]{3,10})"#,
                #"\bCOP\s*([0-9]{1,3}(?:[.,][0-9]{3})+|[0-9]{3,10})\b"#,
                #"\b([0-9]{1,3}(?:[.,][0-9]{3})+)\b"#,
                #"\b([0-9]{4,8})\b"#
            ]

            for pat in patronesMonto {
                if let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) {
                    let matches = regex.matches(in: limpio, range: NSRange(limpio.startIndex..., in: limpio))
                    for match in matches where match.numberOfRanges >= 2 {
                        if let r = Range(match.range(at: 1), in: limpio) {
                            let candidato = limpiarNumeroCOP(String(limpio[r]))
                            // Evitar confundir el año 2025/2026/2027 con un monto si no tiene signo $
                            if candidato >= 500 && !(candidato >= 2024 && candidato <= 2030 && !limpio.contains("$") && !limpio.lowercased().contains("cop")) {
                                montoDetectado = candidato
                                break
                            }
                        }
                    }
                    if montoDetectado > 0 { break }
                }
            }
        }

        guard montoDetectado > 0 else { return nil }

        // Detectar método
        let lower = limpio.lowercased()
        var metodoDetectado = "Apple Watch / Pay"
        if lower.contains("qr") || lower.contains("código qr") || lower.contains("codigo qr") || lower.contains("bre-b") {
            metodoDetectado = "Pago con QR"
        } else if lower.contains("tarjeta débito") || lower.contains("tarjeta debito") || lower.contains("compra aprobada") {
            metodoDetectado = "Tarjeta / Notificación Push"
        } else if lower.contains("transferencia") || lower.contains("enviaste") || lower.contains("pse") {
            metodoDetectado = "Transferencia / QR"
        }

        // Detectar Banco / Tarjeta
        var tarjetaDetectada = "Débito Nu"
        let esCreditoTexto = lower.contains("crédito") || lower.contains("credito") || lower.contains("t.cred") || lower.contains("tc ")

        if lower.contains("bancolombia") {
            tarjetaDetectada = metodoDetectado.contains("QR") ? "QR Bancolombia" : (esCreditoTexto ? "Crédito Bancolombia" : "Débito Bancolombia")
        } else if lower.contains("nu") || lower.contains("nubank") || lower.contains("compra aprobada por") {
            tarjetaDetectada = esCreditoTexto ? "Crédito Nu" : "Débito Nu"
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
        } else if esCreditoTexto {
            tarjetaDetectada = "Tarjeta Crédito"
        }

        // Extraer el nombre del Comercio
        var comercioDetectado = ""
        let patronesComercio = [
            #"(?:compra\s+en|pagaste\s+en|en\s+el\s+comercio|establecimiento|comercio:?|a\s+nombre\s+de|transferencia\s+a|enviaste\s+a|pago\s+a)\s+([A-Za-z0-9ÁÉÍÓÚáéíóúÑñ\s\.\-\*\/&]{2,42}?)(?:\s+con\s+tu|\s+con\s+su|\s+por\s+|\s+el\s+\d|\s+exitos|\s+desde|\s+\$|\.|,|$)"#,
            #"\ben\s+([A-Z0-9ÁÉÍÓÚÑ][A-Za-z0-9ÁÉÍÓÚáéíóúÑñ\s\.\-\*\/&]{2,38}?)(?:\s+con\s+tu|\s+con\s+su|\s+por\s+|\s+\$|\.|,|$)"#
        ]
        for patC in patronesComercio {
            if let regexC = try? NSRegularExpression(pattern: patC, options: [.caseInsensitive]),
               let m = regexC.firstMatch(in: limpio, range: NSRange(limpio.startIndex..., in: limpio)),
               m.numberOfRanges >= 2,
               let r = Range(m.range(at: 1), in: limpio) {
                let candidato = limpiarNombreComercio(String(limpio[r]))
                if candidato.count >= 2 && !esPalabraGenericaNoComercio(candidato) {
                    comercioDetectado = candidato
                    break
                }
            }
        }

        // Si viene directo de Transacción de Wallet (ej: "Oxxo Elemento COP 17,100" sin decir "Compra en")
        if comercioDetectado.isEmpty {
            var sinMonto = limpio
            if let regexQuitarMonto = try? NSRegularExpression(pattern: #"(?:COP|\$)?\s*[0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|\b[0-9]{4,10}\b"#, options: [.caseInsensitive]) {
                sinMonto = regexQuitarMonto.stringByReplacingMatches(in: sinMonto, options: [], range: NSRange(sinMonto.startIndex..., in: sinMonto), withTemplate: " ")
            }
            let limpioSobras = limpiarNombreComercio(sinMonto)
            if limpioSobras.count >= 2 && !esPalabraGenericaNoComercio(limpioSobras) {
                comercioDetectado = limpioSobras
            } else {
                comercioDetectado = "Compra \(tarjetaDetectada)"
            }
        }

        return PagoDetectado(
            comercio: comercioDetectado,
            monto: montoDetectado,
            tarjeta: tarjetaDetectada,
            metodo: metodoDetectado
        )
    }

    private static func esLineaIgnorableDePantalla(_ s: String) -> Bool {
        let low = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if low.isEmpty || low.count <= 1 { return true }
        let ignorarExactos: Set<String> = [
            "wallet", "mostrar menos", "centro de notificaciones", "nubank", "personal",
            "claro", "movistar", "tigo", "5g", "lte", "x"
        ]
        if ignorarExactos.contains(low) { return true }
        // Horas tipo "1:16", "ayer, 11:42 pm", "vie 7:52 am", "jue 1:41 pm"
        if let regexHora = try? NSRegularExpression(pattern: #"^(?:ayer|hoy|lun|mar|mié|mie|jue|vie|sáb|sab|dom)?[,\s]*\d{1,2}:\d{2}\s*(?:am|pm|a\.\s*m\.|p\.\s*m\.)?$"#, options: [.caseInsensitive]),
           regexHora.firstMatch(in: low, range: NSRange(low.startIndex..., in: low)) != nil {
            return true
        }
        if low.contains("plátanos en tu pantalla") || low.contains("potasio inminente") {
            return true
        }
        return false
    }

    private static func esNombreDeBancoCorto(_ s: String) -> Bool {
        let low = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return ["nu", "nubank", "bancolombia", "nequi", "davivienda", "daviplata", "lulo", "bbva", "rappipay"].contains(low)
    }

    private static func normalizarNombreTarjeta(_ s: String) -> String {
        let low = s.lowercased()
        if low.contains("nu") { return "Débito Nu" }
        if low.contains("bancolombia") { return "Débito Bancolombia" }
        if low.contains("nequi") { return "Tarjeta Nequi" }
        if low.contains("davivienda") { return "Débito Davivienda" }
        return s
    }

    private static func limpiarNombreComercio(_ raw: String) -> String {
        var s = raw
            .replacingOccurrences(of: ", Bogotá, Bogotá", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ", Bogota, Bogota", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ", Bogotá", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "con tu tarjeta débito", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "con tu tarjeta crédito", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "con tu tarjeta", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,-•:\n\t"))

        // Quitar timestamp al inicio o final si quedó pegado (ej: "vie 7:52 am ")
        if let regexTS = try? NSRegularExpression(pattern: #"\b(?:ayer|hoy|lun|mar|mié|mie|jue|vie|sáb|sab|dom)[,\s]+\d{1,2}:\d{2}\s*(?:am|pm)?\b"#, options: [.caseInsensitive]) {
            s = regexTS.stringByReplacingMatches(in: s, options: [], range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        return s.trimmingCharacters(in: CharacterSet(charactersIn: " .,-•:\n\t"))
    }

    private static func esPalabraGenericaNoComercio(_ s: String) -> Bool {
        let low = s.lowercased()
        return low == "tu" || low == "su" || low == "nu" || low == "wallet" || low == "compra" || low.hasPrefix("tu c")
    }

    static func limpiarNumeroCOP(_ raw: String) -> Double {
        var s = raw
            .replacingOccurrences(of: "COP", with: "", options: .caseInsensitive)
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
            ? "Débito Nu"
            : tarjeta.trimmingCharacters(in: .whitespacesAndNewlines)

        let cat = CategoriaTarjeta.detectar(desde: comercioLimpio, categoriaExplicita: categoriaManual)
        let lowerCard = tarjetaLimpia.lowercased()
        let esCredito = lowerCard.contains("crédito") ||
                        lowerCard.contains("credito") ||
                        lowerCard.contains("tc") ||
                        lowerCard.contains("rappicard")

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

        // 2. Disparar notificación local en el iPhone (funciona con pantalla bloqueada) y Apple Watch
        dispararNotificacionCategoria(nuevoMovimiento)

        // 3. Sincronizar directamente en segundo plano con pagos.xo.je/api_finanzas.php
        Task {
            await subirPagoAServidorRemoto(nuevoMovimiento)
        }

        // 4. Notificar a la UI si está abierta
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notificationName, object: nuevoMovimiento)
        }

        return nuevoMovimiento
    }

    static func subirPagoAServidorRemoto(_ mov: GastoTarjetaItem) async {
        guard let url = URL(string: liveWebhookURL) else { return }
        let savedPin = UserDefaults.standard.string(forKey: "finanzas_user_pin") ?? "1234"
        var cachedCookie = UserDefaults.standard.string(forKey: "pagos_xoje_test_cookie") ?? "df86a58167736717237940b9bc671454"

        func sendPost(cookie: String) async throws -> String {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.setValue(savedPin, forHTTPHeaderField: "X-Auth-Pin")
            if !cookie.isEmpty {
                req.setValue("__test=\(cookie)", forHTTPHeaderField: "Cookie")
            }
            let params: [String: String] = [
                "pin": savedPin,
                "accion": "registrar_gasto_tarjeta",
                "comercio": mov.comercio,
                "monto": String(Int(mov.monto)),
                "categoria": mov.categoria,
                "tarjeta": mov.tarjeta,
                "metodo": mov.metodo
            ]
            let body = params.map { k, v in
                let ke = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
                let ve = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                return "\(ke)=\(ve)"
            }.joined(separator: "&")
            req.httpBody = body.data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: req)
            return String(data: data, encoding: .utf8) ?? ""
        }

        do {
            let text = try await sendPost(cookie: cachedCookie)
            if text.contains("slowAES.decrypt") || text.contains("/aes.js"),
               let newCookie = InfinityFreeAESDecryptor.extractTestCookie(from: text) {
                cachedCookie = newCookie
                UserDefaults.standard.set(newCookie, forKey: "pagos_xoje_test_cookie")
                _ = try await sendPost(cookie: newCookie)
            }
        } catch {
            // Queda en caché local y se sube al abrir la app
        }
    }
}

// MARK: - 1. AppIntent para Transacciones de Apple Watch / Apple Pay (Funciona con el iPhone Bloqueado)
@available(iOS 16.0, *)
struct RegistrarPagoWalletIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Pago con Tarjeta o Apple Watch"
    static var description = IntentDescription(
        "Se ejecuta en segundo plano (incluso con el iPhone bloqueado) cuando pagas con Apple Watch, Apple Pay, Tarjeta Física, QR o Notificación y guarda el movimiento con su categoría."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Comercio o Texto Completo (Push / Wallet / SMS / QR)", default: "Compra Apple Pay")
    var comercio: String

    @Parameter(title: "Monto Pagado (Dejar en 0 si pasas texto completo)", default: 0)
    var monto: Double

    @Parameter(title: "Nombre de la Tarjeta o Banco", default: "Débito Nu")
    var tarjeta: String

    @Parameter(title: "Método (Apple Watch, Celular, Tarjeta Física, QR)", default: "Apple Watch / Pay")
    var dispositivo: String

    static var parameterSummary: some ParameterSummary {
        Summary("Anotar pago de \(\.$monto) en \(\.$comercio) con \(\.$tarjeta) (\(\.$dispositivo))")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let detectados = RegistroPagosWalletEngine.extraerTodosLosPagosDeTexto(comercio)

        if monto <= 0 && !detectados.isEmpty {
            var guardados: [GastoTarjetaItem] = []
            for det in detectados {
                let item = RegistroPagosWalletEngine.guardarPagoReal(
                    comercio: det.comercio,
                    monto: det.monto,
                    tarjeta: (tarjeta == "Débito Nu" || tarjeta == "Tarjeta Wallet" || tarjeta.isEmpty) ? det.tarjeta : tarjeta,
                    dispositivo: det.metodo
                )
                await RegistroPagosWalletEngine.subirPagoAServidorRemoto(item)
                guardados.append(item)
            }
            if let primero = guardados.first {
                return .result(
                    dialog: "✅ Se guardaron \(guardados.count) pago(s). Último: \(primero.comercio) por \(primero.monto.copFormatted) en \(primero.categoria)."
                )
            }
        }

        let montoFinal = monto > 0 ? monto : (detectados.first?.monto ?? 0)
        let comercioFinal = detectados.first?.comercio ?? comercio
        guard montoFinal > 0 else {
            return .result(dialog: "No se detectó un monto válido mayor a $0.")
        }

        let item = RegistroPagosWalletEngine.guardarPagoReal(
            comercio: comercioFinal,
            monto: montoFinal,
            tarjeta: tarjeta,
            dispositivo: dispositivo
        )
        await RegistroPagosWalletEngine.subirPagoAServidorRemoto(item)

        return .result(
            dialog: "✅ Guardado en \(item.categoria): \(item.comercio) por \(item.monto.copFormatted) con \(item.tarjeta)."
        )
    }
}

// MARK: - 2. AppIntent Especial para Capturas, Notificaciones Push, QR y SMS (Funciona con el iPhone Bloqueado)
@available(iOS 16.0, *)
struct RegistrarPagoTextoBancarioIntent: AppIntent {
    static var title: LocalizedStringResource = "Auto-Detectar Pago de Correo, Push, SMS o QR"
    static var description = IntentDescription(
        "Pasa el texto de una captura de pantalla, notificación de Wallet o Nu, SMS o comprobante QR. Funciona con el iPhone bloqueado sin abrir la app."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Texto de la Notificación Push, Captura, SMS o Pantalla")
    var textoNotificacion: String

    static var parameterSummary: some ParameterSummary {
        Summary("Auto-detectar compra y categoría desde \(\.$textoNotificacion)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let detectados = RegistroPagosWalletEngine.extraerTodosLosPagosDeTexto(textoNotificacion)
        guard !detectados.isEmpty else {
            return .result(dialog: "No se encontró un monto en pesos ($) dentro del texto recibido.")
        }

        var guardados: [GastoTarjetaItem] = []
        for det in detectados {
            let item = RegistroPagosWalletEngine.guardarPagoReal(
                comercio: det.comercio,
                monto: det.monto,
                tarjeta: det.tarjeta,
                dispositivo: det.metodo
            )
            await RegistroPagosWalletEngine.subirPagoAServidorRemoto(item)
            guardados.append(item)
        }

        let resumen = guardados.map { "\($0.comercio) (\($0.monto.copFormatted) → \($0.categoria))" }.joined(separator: ", ")
        return .result(
            dialog: "✅ Guardado: \(resumen)."
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

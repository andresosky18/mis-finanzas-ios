import Foundation
import SwiftUI
import UIKit
import LocalAuthentication
import CommonCrypto

// MARK: - Delegado URLSession que acepta certificados SSL de InfinityFree sin alertas
final class SSLTrustSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Desencriptador Nativo AES-128-CBC (CommonCrypto) para el reto aes.js de pagos.xo.je
enum InfinityFreeAESDecryptor {
    static func extractTestCookie(from html: String) -> String? {
        let pattern = #"toNumbers\("([0-9a-fA-F]{32})"\).*?toNumbers\("([0-9a-fA-F]{32})"\).*?toNumbers\("([0-9a-fA-F]{32})"\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              match.numberOfRanges >= 4,
              let rA = Range(match.range(at: 1), in: html),
              let rB = Range(match.range(at: 2), in: html),
              let rC = Range(match.range(at: 3), in: html) else {
            return nil
        }

        let keyBytes = hexToBytes(String(html[rA]))
        let ivBytes = hexToBytes(String(html[rB]))
        let cipherBytes = hexToBytes(String(html[rC]))

        guard keyBytes.count == kCCKeySizeAES128,
              ivBytes.count == kCCBlockSizeAES128,
              cipherBytes.count == kCCBlockSizeAES128 else {
            return nil
        }

        var outBytes = [UInt8](repeating: 0, count: cipherBytes.count + kCCBlockSizeAES128)
        var numBytesDecrypted: size_t = 0

        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(0), // Sin PKCS7 padding (idéntico a slowAES.decrypt)
            keyBytes,
            kCCKeySizeAES128,
            ivBytes,
            cipherBytes,
            cipherBytes.count,
            &outBytes,
            outBytes.count,
            &numBytesDecrypted
        )

        guard status == kCCSuccess else { return nil }
        return outBytes.prefix(cipherBytes.count).map { String(format: "%02x", $0) }.joined()
    }

    private static func hexToBytes(_ hex: String) -> [UInt8] {
        var bytes = [UInt8]()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let nextIdx = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let b = UInt8(hex[idx..<nextIdx], radix: 16) {
                bytes.append(b)
            }
            idx = nextIdx
        }
        return bytes
    }
}

// MARK: - Parser Nativo del HTML en Vivo de https://pagos.xo.je/mis_finanzas.php
enum LiveHTMLFinanzasParser {
    static func parse(html: String, fallback: FinanzasData) -> FinanzasData? {
        guard html.contains("Mis Finanzas") || html.contains("contenedor-deudas") else {
            return nil
        }

        var data = fallback

        // 1. Sueldo Base y Bono Q1 desde el modal-sueldo
        if let sueldoStr = firstCapture(#"name="nuevo_sueldo"[^>]*value="([0-9.]+)""#, in: html),
           let sueldo = Double(sueldoStr) {
            data.sueldoBase = sueldo
        }
        if let bonoStr = firstCapture(#"name="nuevo_bono"[^>]*value="([0-9.]+)""#, in: html),
           let bono = Double(bonoStr) {
            data.bonoQ1 = bono
        }

        // 2. Ahorro Base (Corvanca)
        if let corvancaStr = firstCapture(#"Ahorro Base \(Corvanca\).*?font-size:\s*32px[^>]*>\$([0-9,]+)"#, in: html) {
            data.ahorroCorvanca = parseCurrency(corvancaStr)
        }

        // 3. Deudas reales desde abrirEditarDeuda('Nombre', total, pendiente, cuota, 'icono')
        let deudaPattern = #"abrirEditarDeuda\('([^']+)',\s*([0-9.]+),\s*([0-9.]+),\s*([0-9.]+),\s*'([^']*)'\)"#
        if let regex = try? NSRegularExpression(pattern: deudaPattern, options: []) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            if !matches.isEmpty {
                var parsedDeudas: [DeudaItem] = []
                for m in matches {
                    guard m.numberOfRanges >= 6,
                          let rNom = Range(m.range(at: 1), in: html),
                          let rTot = Range(m.range(at: 2), in: html),
                          let rPen = Range(m.range(at: 3), in: html),
                          let rCuo = Range(m.range(at: 4), in: html),
                          let rIco = Range(m.range(at: 5), in: html) else { continue }
                    let nombre = decodeHTML(String(html[rNom]))
                    let total = Double(html[rTot]) ?? 0
                    let pendiente = Double(html[rPen]) ?? 0
                    let cuota = Double(html[rCuo]) ?? 0
                    let icono = decodeHTML(String(html[rIco]))
                    parsedDeudas.append(
                        DeudaItem(nombre: nombre, total: total, pendiente: pendiente, cuota: cuota, icono: icono)
                    )
                }
                if !parsedDeudas.isEmpty {
                    data.deudasLista = parsedDeudas
                }
            }
        }

        // 4. Gastos Quincenales reales y su estado checked
        let gastoPattern = #"<li class="data-row([^"]*)">\s*<div class="row-left">\s*<form[^>]*>\s*<input type="hidden" name="accion" value="toggle_gasto">\s*<input type="hidden" name="gasto" value="([^"]+)">.*?(?:<span class="badge">([^<]*)</span>)?\s*</div>\s*</div>\s*<div class="row-right">\s*<span[^>]*>-\$([0-9,]+)</span>"#
        if let regex = try? NSRegularExpression(pattern: gastoPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            if !matches.isEmpty {
                var parsedGastos: [GastoQuincenalItem] = []
                var marcados: [String] = []
                for m in matches {
                    guard m.numberOfRanges >= 5,
                          let rClass = Range(m.range(at: 1), in: html),
                          let rNom = Range(m.range(at: 2), in: html),
                          let rVal = Range(m.range(at: 4), in: html) else { continue }
                    let rowClass = String(html[rClass])
                    let isChecked = rowClass.contains("checked")
                    let nombre = decodeHTML(String(html[rNom]))
                    var label = ""
                    if m.range(at: 3).location != NSNotFound, let rLab = Range(m.range(at: 3), in: html) {
                        label = decodeHTML(String(html[rLab]))
                            .replacingOccurrences(of: "Día s", with: "Días")
                            .replacingOccurrences(of: "Día  ", with: "Día ")
                    }
                    let valor = parseCurrency(String(html[rVal]))
                    if isChecked {
                        marcados.append(nombre)
                    }
                    let deudaVinc = FinanzasData.resolverDeuda(
                        nombreGasto: nombre,
                        deudaExplicita: nil,
                        deudas: data.deudasLista
                    )
                    parsedGastos.append(
                        GastoQuincenalItem(
                            nombre: nombre,
                            valor: valor,
                            label: label,
                            deudaDetectada: deudaVinc,
                            pagado: isChecked
                        )
                    )
                }
                if !parsedGastos.isEmpty {
                    data.gastosLista = parsedGastos
                    data.gastosMarcados = marcados
                }
            }
        }

        // 5. Metas (Wishlist & Metas)
        if let metasBlock = firstCapture(#"Wishlist & Metas(.*?)</main>"#, in: html) {
            let metaPattern = #"<i data-lucide="([^"]+)"[^>]*></i>\s*([^<]+?)\s*<form[^>]*><input type="hidden" name="accion" value="eliminar_meta"><input type="hidden" name="meta_eliminar" value="([^"]+)".*?<div class="progress-meta"><span>\$([0-9,]+)</span><span>\$([0-9,]+)</span></div>"#
            if let regex = try? NSRegularExpression(pattern: metaPattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: metasBlock, range: NSRange(metasBlock.startIndex..., in: metasBlock))
                var parsedMetas: [MetaItem] = []
                for m in matches {
                    guard m.numberOfRanges >= 6,
                          let rIco = Range(m.range(at: 1), in: metasBlock),
                          let rNom = Range(m.range(at: 3), in: metasBlock),
                          let rAct = Range(m.range(at: 4), in: metasBlock),
                          let rTot = Range(m.range(at: 5), in: metasBlock) else { continue }
                    let icono = decodeHTML(String(metasBlock[rIco]))
                    let nombre = decodeHTML(String(metasBlock[rNom]))
                    let actual = parseCurrency(String(metasBlock[rAct]))
                    let total = parseCurrency(String(metasBlock[rTot]))
                    parsedMetas.append(MetaItem(nombre: nombre, total: total, actual: actual, icono: icono))
                }
                data.metasLista = parsedMetas
            }
        }

        // 6. Actividad Reciente (Historial)
        let histPattern = #"<span>([^<]+)</span>\s*<span[^>]*><i data-lucide="clock"[^>]*></i>([^<]+)</span>\s*</div>\s*<div class="row-right">\s*<span[^>]*>\+\$([0-9,]+)</span>\s*<form[^>]*><input type="hidden" name="accion" value="reversar_historial"><input type="hidden" name="index" value="(\d+)""#
        if let regex = try? NSRegularExpression(pattern: histPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            if !matches.isEmpty {
                var parsedHist: [HistorialItem] = []
                for m in matches {
                    guard m.numberOfRanges >= 5,
                          let rCon = Range(m.range(at: 1), in: html),
                          let rFec = Range(m.range(at: 2), in: html),
                          let rMon = Range(m.range(at: 3), in: html) else { continue }
                    let concepto = decodeHTML(String(html[rCon]))
                    let fecha = decodeHTML(String(html[rFec]))
                    let monto = parseCurrency(String(html[rMon]))
                    let tipo = (concepto.localizedCaseInsensitiveContains("corvanca") || concepto.localizedCaseInsensitiveContains("meta")) ? "ahorro" : "pago"
                    parsedHist.append(
                        HistorialItem(fecha: fecha, concepto: concepto, monto: monto, tipo: tipo, deudaKey: nil, gastoOrigen: nil)
                    )
                }
                let localTarjetaMoves = fallback.historial.filter { $0.tipo == "tarjeta" }
                data.historial = localTarjetaMoves + parsedHist
            }
        }

        data.recalculateAll()
        return data
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func parseCurrency(_ raw: String) -> Double {
        let digits = raw.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(digits) ?? 0
    }

    private static func decodeHTML(_ str: String) -> String {
        str.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - ViewModel Principal Nativo SwiftUI Conectado Directamente a pagos.xo.je
@MainActor
final class FinanzasViewModel: ObservableObject {
    static let defaultLiveURL = "http://pagos.xo.je/mis_finanzas.php?i=1"

    @AppStorage("finanzas_api_url_v4") var apiURL: String = "http://pagos.xo.je/mis_finanzas.php?i=1"
    @AppStorage("finanzas_user_pin") var savedPin: String = "1234"
    @AppStorage("finanzas_is_unlocked") var isUnlocked: Bool = false
    @AppStorage("pagos_xoje_test_cookie") private var cachedTestCookie: String = "a4ab21be42c5ca6d5fd36f5acf1e2be0"

    @Published var finanzas: FinanzasData
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var syncStatusText: String = "En vivo • pagos.xo.je"
    @Published var navigateToTab: Int? = nil
    @Published var lastApplePayToast: String? = nil

    private let cacheKey = "finanzas_personal_cache_v4_xoje"
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config, delegate: SSLTrustSessionDelegate(), delegateQueue: nil)
    }()

    init() {
        if let data = UserDefaults.standard.data(forKey: "finanzas_personal_cache_v4_xoje"),
           var cached = try? JSONDecoder().decode(FinanzasData.self, from: data) {
            cached.recalculateAll()
            self.finanzas = cached
        } else {
            let initial = FinanzasData.defaultAndresData()
            self.finanzas = initial
            if let encoded = try? JSONEncoder().encode(initial) {
                UserDefaults.standard.set(encoded, forKey: "finanzas_personal_cache_v4_xoje")
            }
        }

        // Asegurar que siempre apunte al servidor real pagos.xo.je
        if apiURL.isEmpty || apiURL.contains("tu-dominio") || apiURL.contains("tudominio") {
            apiURL = Self.defaultLiveURL
        }

        // Escuchar pagos registrados en segundo plano por AppIntents (Apple Watch / Apple Pay / SMS Bancario)
        NotificationCenter.default.addObserver(
            forName: RegistroPagosWalletEngine.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            Task { @MainActor in
                self.reloadFromLocalCache()
                if let mov = note.object as? GastoTarjetaItem {
                    self.lastApplePayToast = "✅ \(mov.comercio): \(mov.monto.copFormatted) → \(mov.categoria) (\(mov.tarjeta))"
                    // Sincronizar también con pagos.xo.je en segundo plano
                    await self.syncCardExpenseToRemote(mov)
                }
            }
        }

        // Sincronizar automáticamente en segundo plano al iniciar
        Task {
            await fetchAllData()
        }
    }

    func reloadFromLocalCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           var cached = try? JSONDecoder().decode(FinanzasData.self, from: data) {
            cached.recalculateAll()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                self.finanzas = cached
            }
        }
    }

    func syncCardExpenseToRemote(_ mov: GastoTarjetaItem) async {
        guard let targetURL = normalizedLiveURL() else { return }
        _ = try? await performLiveRequest(
            url: targetURL,
            formParams: [
                "accion": "registrar_gasto_tarjeta",
                "comercio": mov.comercio,
                "monto": String(Int(mov.monto)),
                "categoria": mov.categoria,
                "tarjeta": mov.tarjeta,
                "metodo": mov.metodo
            ]
        )
    }

    // MARK: - Desbloqueo con Face ID Nativo o PIN
    func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Desbloquea tu billetera personal de Mis Finanzas"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    if success {
                        self.errorMessage = nil
                        self.triggerHaptic(.success)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                            self.isUnlocked = true
                        }
                        await self.fetchAllData()
                    }
                }
            }
        }
    }

    func unlockWithPin(_ inputPin: String) async -> Bool {
        let clean = inputPin.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPin = savedPin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1234" : savedPin.trimmingCharacters(in: .whitespacesAndNewlines)

        guard clean == targetPin else {
            errorMessage = "PIN incorrecto"
            triggerHaptic(.error)
            return false
        }

        errorMessage = nil
        triggerHaptic(.success)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            isUnlocked = true
        }
        Task { await fetchAllData() }
        return true
    }

    // MARK: - Sincronización en Vivo con https://pagos.xo.je/mis_finanzas.php
    func fetchAllData() async {
        reloadFromLocalCache()
        guard let targetURL = normalizedLiveURL() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let htmlOrJson = try await performLiveRequest(url: targetURL, formParams: nil)
            applyLiveResponse(htmlOrJson)
            syncStatusText = "Sincronizado • pagos.xo.je"
        } catch {
            syncStatusText = "Datos reales en caché • pagos.xo.je"
        }

        isLoading = false
    }

    // MARK: - Enviar Acción en Vivo a pagos.xo.je + Actualización Instantánea
    func sendAction(_ payload: [String: Any]) async {
        triggerHaptic(.medium)

        // Detectar si es un toggle_gasto que pasa de NO pagado a PAGADO para descontar deuda en el servidor si aún tiene el PHP anterior
        let accion = (payload["accion"] as? String) ?? ""
        var extraDebtAbono: (deuda: String, monto: Double)? = nil

        if accion == "toggle_gasto",
           let nombreGasto = payload["gasto"] as? String,
           let gastoItem = finanzas.gastosLista.first(where: { $0.nombre == nombreGasto }),
           !finanzas.gastosMarcados.contains(nombreGasto),
           let deudaAsociada = FinanzasData.resolverDeuda(
               nombreGasto: gastoItem.nombre,
               deudaExplicita: gastoItem.deudaDetectada,
               deudas: finanzas.deudasLista
           ),
           gastoItem.valor > 0 {
            extraDebtAbono = (deuda: deudaAsociada, monto: gastoItem.valor)
        }

        // 1. Actualizar inmediatamente en pantalla (0ms latencia)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            applyLocalAction(payload)
        }
        saveLocalFinanzas()
        triggerHaptic(.success)

        // 2. Enviar POST directo a pagos.xo.je/mis_finanzas.php
        guard let targetURL = normalizedLiveURL() else { return }
        var formParams: [String: String] = [:]
        for (k, v) in payload {
            formParams[k] = "\(v)"
        }

        do {
            let responseText = try await performLiveRequest(url: targetURL, formParams: formParams)
            // Si el servidor aún tiene la versión de mis_finanzas.php que no descuenta sola al hacer toggle_gasto, enviamos abonar_deuda automáticamente
            if let abono = extraDebtAbono,
               let parsed = LiveHTMLFinanzasParser.parse(html: responseText, fallback: finanzas),
               let remoteDeuda = parsed.deudasLista.first(where: { $0.nombre == abono.deuda }),
               let localDeuda = finanzas.deudasLista.first(where: { $0.nombre == abono.deuda }),
               abs(remoteDeuda.pendiente - localDeuda.pendiente) > 1 {
                let updatedText = try await performLiveRequest(
                    url: targetURL,
                    formParams: [
                        "accion": "abonar_deuda",
                        "deuda": abono.deuda,
                        "monto": String(Int(abono.monto))
                    ]
                )
                applyLiveResponse(updatedText)
            } else {
                applyLiveResponse(responseText)
            }
            syncStatusText = "Sincronizado • pagos.xo.je"
        } catch {
            syncStatusText = "Guardado localmente"
        }
    }

    // MARK: - Cliente HTTP con Resolución Automática de Cookie __test AES-128 de pagos.xo.je
    private func performLiveRequest(url: URL, formParams: [String: String]?, isRetry: Bool = false) async throws -> String {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = true
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        if !cachedTestCookie.isEmpty {
            request.setValue("__test=\(cachedTestCookie)", forHTTPHeaderField: "Cookie")
        }

        if let formParams = formParams {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let bodyString = formParams.map { key, val in
                let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let v = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? val
                return "\(k)=\(v)"
            }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
        } else {
            request.httpMethod = "GET"
        }

        let (data, _) = try await urlSession.data(for: request)
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        // Si InfinityFree devuelve el reto aes.js, desencriptarlo en Swift nativo y reintentar
        if (text.contains("slowAES.decrypt") || text.contains("/aes.js")) && !isRetry {
            if let solvedHex = InfinityFreeAESDecryptor.extractTestCookie(from: text) {
                cachedTestCookie = solvedHex
                return try await performLiveRequest(url: url, formParams: formParams, isRetry: true)
            }
        }

        return text
    }

    private func normalizedLiveURL() -> URL? {
        var raw = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            raw = Self.defaultLiveURL
        }
        // pagos.xo.je responde por HTTP sin errores de certificado SSL
        if raw.hasPrefix("https://pagos.xo.je") {
            raw = raw.replacingOccurrences(of: "https://pagos.xo.je", with: "http://pagos.xo.je")
        }
        return URL(string: raw)
    }

    private func applyLiveResponse(_ text: String) {
        // 1. Intentar decodificar si es JSON (api_finanzas.php)
        if let jsonData = text.data(using: .utf8),
           let apiResp = try? JSONDecoder().decode(ApiResponse.self, from: jsonData),
           apiResp.ok,
           var remoteFinanzas = apiResp.finanzas {
            remoteFinanzas.recalculateAll()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                self.finanzas = remoteFinanzas
            }
            saveLocalFinanzas()
            return
        }

        // 2. Parsear el HTML en vivo de pagos.xo.je/mis_finanzas.php
        if let parsed = LiveHTMLFinanzasParser.parse(html: text, fallback: finanzas) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                self.finanzas = parsed
            }
            saveLocalFinanzas()
        }
    }

    // MARK: - Motor Financiero Local (Respuesta en 0ms mientras sincroniza)
    private func applyLocalAction(_ payload: [String: Any]) {
        guard let accion = payload["accion"] as? String else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy - HH:mm"
        formatter.locale = Locale(identifier: "es_CO")
        let fechaActual = formatter.string(from: Date())

        switch accion {
        case "editar_sueldo":
            if let nuevoSueldo = payload["nuevo_sueldo"] as? Double {
                finanzas.sueldoBase = nuevoSueldo
            }
            if let nuevoBono = payload["nuevo_bono"] as? Double {
                finanzas.bonoQ1 = nuevoBono
            }

        case "abonar_ahorro":
            let abono = (payload["monto"] as? Double) ?? 0
            guard abono > 0 else { break }
            finanzas.ahorroCorvanca += abono
            finanzas.historial.insert(
                HistorialItem(fecha: fechaActual, concepto: "Aporte Corvanca", monto: abono, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                at: 0
            )

        case "abonar_deuda":
            guard let nombreDeuda = payload["deuda"] as? String else { break }
            let abono = (payload["monto"] as? Double) ?? 0
            guard abono > 0 else { break }
            if let idx = finanzas.deudasLista.firstIndex(where: { $0.nombre == nombreDeuda }) {
                finanzas.deudasLista[idx].pendiente = max(0, finanzas.deudasLista[idx].pendiente - abono)
                finanzas.historial.insert(
                    HistorialItem(fecha: fechaActual, concepto: "Abono a: \(nombreDeuda)", monto: abono, tipo: "pago", deudaKey: nombreDeuda, gastoOrigen: nil),
                    at: 0
                )
            }

        case "reversar_historial":
            guard let index = payload["index"] as? Int,
                  finanzas.historial.indices.contains(index) else { break }
            let item = finanzas.historial[index]
            let monto = item.monto

            if item.tipo == "pago" {
                let nombreDeuda = item.deudaKey ??
                    item.concepto
                        .replacingOccurrences(of: "Abono a: ", with: "")
                        .replacingOccurrences(of: "Pago Quincenal: ", with: "")
                if let idxD = finanzas.deudasLista.firstIndex(where: { $0.nombre.caseInsensitiveCompare(nombreDeuda) == .orderedSame }) {
                    finanzas.deudasLista[idxD].pendiente = min(
                        finanzas.deudasLista[idxD].total,
                        finanzas.deudasLista[idxD].pendiente + monto
                    )
                }
            } else if item.tipo == "ahorro" {
                if item.concepto == "Aporte Corvanca" {
                    finanzas.ahorroCorvanca = max(0, finanzas.ahorroCorvanca - monto)
                } else {
                    let nombreMeta = item.concepto.replacingOccurrences(of: "Aporte Meta: ", with: "")
                    if let idxM = finanzas.metasLista.firstIndex(where: { $0.nombre == nombreMeta }) {
                        finanzas.metasLista[idxM].actual = max(0, finanzas.metasLista[idxM].actual - monto)
                    }
                }
            }
            finanzas.historial.remove(at: index)

        case "editar_deuda":
            guard let original = payload["nombre_original"] as? String,
                  let idx = finanzas.deudasLista.firstIndex(where: { $0.nombre == original }) else { break }
            let nuevoNombre = (payload["nombre_deuda_nuevo"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? original
            let total = (payload["total_deuda"] as? Double) ?? finanzas.deudasLista[idx].total
            let pendiente = (payload["pendiente_deuda"] as? Double) ?? finanzas.deudasLista[idx].pendiente
            let cuota = (payload["cuota_deuda"] as? Double) ?? finanzas.deudasLista[idx].cuota
            let icono = (payload["icono_deuda"] as? String) ?? finanzas.deudasLista[idx].icono

            finanzas.deudasLista[idx] = DeudaItem(
                nombre: nuevoNombre.isEmpty ? original : nuevoNombre,
                total: total,
                pendiente: pendiente,
                cuota: cuota,
                icono: icono
            )

        case "agregar_deuda":
            guard let nombre = (payload["nombre_deuda"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !nombre.isEmpty else { break }
            let total = (payload["total_deuda"] as? Double) ?? 0
            let cuota = (payload["cuota_deuda"] as? Double) ?? 0
            let icono = (payload["icono_deuda"] as? String) ?? "credit-card"
            guard total > 0 else { break }
            finanzas.deudasLista.append(
                DeudaItem(nombre: nombre, total: total, pendiente: total, cuota: cuota, icono: icono)
            )

        case "eliminar_deuda":
            guard let nombre = payload["deuda_eliminar"] as? String else { break }
            finanzas.deudasLista.removeAll { $0.nombre == nombre }

        case "toggle_gasto":
            guard let nombreGasto = payload["gasto"] as? String,
                  let idxG = finanzas.gastosLista.firstIndex(where: { $0.nombre == nombreGasto }) else { break }
            let gastoItem = finanzas.gastosLista[idxG]
            let valorGasto = gastoItem.valor
            let deudaAsociada = FinanzasData.resolverDeuda(
                nombreGasto: gastoItem.nombre,
                deudaExplicita: gastoItem.deudaDetectada,
                deudas: finanzas.deudasLista
            )

            if finanzas.gastosMarcados.contains(nombreGasto) {
                finanzas.gastosMarcados.removeAll { $0 == nombreGasto }
            } else {
                finanzas.gastosMarcados.append(nombreGasto)
                if let nombreD = deudaAsociada,
                   let idxD = finanzas.deudasLista.firstIndex(where: { $0.nombre == nombreD }),
                   valorGasto > 0 {
                    finanzas.deudasLista[idxD].pendiente = max(0, finanzas.deudasLista[idxD].pendiente - valorGasto)
                    finanzas.historial.insert(
                        HistorialItem(
                            fecha: fechaActual,
                            concepto: "Abono a: \(nombreD)",
                            monto: valorGasto,
                            tipo: "pago",
                            deudaKey: nombreD,
                            gastoOrigen: nombreGasto
                        ),
                        at: 0
                    )
                }
            }

        case "reset_quincena":
            finanzas.gastosMarcados.removeAll()

        case "agregar_gasto":
            guard let nombre = (payload["nombre_gasto"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !nombre.isEmpty else { break }
            let valor = (payload["valor_gasto"] as? Double) ?? 0
            let label = (payload["label_gasto"] as? String) ?? ""
            let deudaVinc = (payload["deuda_vinculada"] as? String)
            guard valor > 0 else { break }
            finanzas.gastosLista.append(
                GastoQuincenalItem(
                    nombre: nombre,
                    valor: valor,
                    label: label,
                    deudaDetectada: (deudaVinc?.isEmpty == false) ? deudaVinc : nil,
                    pagado: false
                )
            )

        case "eliminar_gasto":
            guard let nombre = payload["gasto_eliminar"] as? String else { break }
            finanzas.gastosLista.removeAll { $0.nombre == nombre }
            finanzas.gastosMarcados.removeAll { $0 == nombre }

        case "abonar_meta":
            guard let nombreMeta = payload["meta"] as? String,
                  let idxM = finanzas.metasLista.firstIndex(where: { $0.nombre == nombreMeta }) else { break }
            let abono = (payload["monto"] as? Double) ?? 0
            guard abono > 0 else { break }
            finanzas.metasLista[idxM].actual += abono
            finanzas.historial.insert(
                HistorialItem(fecha: fechaActual, concepto: "Aporte Meta: \(nombreMeta)", monto: abono, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                at: 0
            )

        case "agregar_meta":
            guard let nombre = (payload["nombre_meta"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !nombre.isEmpty else { break }
            let total = (payload["total_meta"] as? Double) ?? 0
            let icono = (payload["icono_meta"] as? String) ?? "target"
            guard total > 0 else { break }
            finanzas.metasLista.append(
                MetaItem(nombre: nombre, total: total, actual: 0, icono: icono)
            )

        case "eliminar_meta":
            guard let nombre = payload["meta_eliminar"] as? String else { break }
            finanzas.metasLista.removeAll { $0.nombre == nombre }

        case "registrar_gasto_tarjeta":
            let comercio = (payload["comercio"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Compra con Tarjeta"
            let monto = (payload["monto"] as? Double) ?? 0
            guard monto > 0 else { break }
            let tarjeta = (payload["tarjeta"] as? String) ?? "Débito"
            let metodo = (payload["metodo"] as? String) ?? "Apple Pay"
            let esCredito = (payload["es_credito"] as? Bool) ?? tarjeta.localizedCaseInsensitiveContains("crédito") || tarjeta.localizedCaseInsensitiveContains("credito") || tarjeta.localizedCaseInsensitiveContains("nu")
            let catDetectada = CategoriaTarjeta.detectar(
                desde: comercio,
                categoriaExplicita: payload["categoria"] as? String
            )

            let nuevoItem = GastoTarjetaItem(
                id: UUID().uuidString,
                fecha: fechaActual,
                comercio: comercio.isEmpty ? "Compra \(catDetectada.rawValue)" : comercio,
                monto: monto,
                categoria: catDetectada.rawValue,
                tarjeta: tarjeta,
                metodo: metodo,
                esCredito: esCredito
            )
            finanzas.gastosTarjeta.insert(nuevoItem, at: 0)

            // También lo anotamos en el Historial General de Movimientos
            finanzas.historial.insert(
                HistorialItem(
                    fecha: fechaActual,
                    concepto: "[\(catDetectada.rawValue)] \(nuevoItem.comercio) • \(tarjeta)",
                    monto: monto,
                    tipo: "tarjeta",
                    deudaKey: nil,
                    gastoOrigen: metodo
                ),
                at: 0
            )

            // Si el usuario eligió vincular la compra con tarjeta de crédito a una deuda o gasto quincenal
            if let gastoQuincena = payload["sumar_a_gasto_quincena"] as? String,
               !gastoQuincena.isEmpty,
               let idxG = finanzas.gastosLista.firstIndex(where: { $0.nombre.caseInsensitiveCompare(gastoQuincena) == .orderedSame }) {
                finanzas.gastosLista[idxG].valor += monto
            }

        case "eliminar_gasto_tarjeta":
            if let idBorrar = payload["id"] as? String {
                finanzas.gastosTarjeta.removeAll { $0.id == idBorrar }
            }

        default:
            break
        }

        if finanzas.historial.count > 30 {
            finanzas.historial = Array(finanzas.historial.prefix(30))
        }
        finanzas.recalculateAll()
    }

    private func saveLocalFinanzas() {
        if let encoded = try? JSONEncoder().encode(finanzas) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    // MARK: - Automatización Apple Pay / Apple Watch (Estilo Lukas via Atajos URL Scheme)
    // Ejemplo de URL que dispara el iPhone o Apple Watch al pagar en datáfono:
    // misfinanzas://pay?monto=38500&comercio=McDonalds&tarjeta=Debito&metodo=Apple%20Watch
    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "misfinanzas" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        func param(_ names: [String]) -> String? {
            for n in names {
                if let val = queryItems.first(where: { $0.name.caseInsensitiveCompare(n) == .orderedSame })?.value,
                   !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return val.removingPercentEncoding ?? val
                }
            }
            return nil
        }

        // Si el Atajo envía un SMS o notificación completa (ej: misfinanzas://pay?texto=Bancolombia%20compraste%20$25.000%20en%20D1)
        if let rawTexto = param(["texto", "sms", "mensaje", "notificacion"]),
           let extraido = RegistroPagosWalletEngine.extraerDatosDeTextoBancario(rawTexto) {
            isUnlocked = true
            navigateToTab = 2
            let cat = CategoriaTarjeta.detectar(desde: extraido.comercio)
            Task {
                await sendAction([
                    "accion": "registrar_gasto_tarjeta",
                    "comercio": extraido.comercio,
                    "monto": extraido.monto,
                    "categoria": cat.rawValue,
                    "tarjeta": extraido.tarjeta,
                    "metodo": "SMS / Notificación Bancaria",
                    "es_credito": extraido.tarjeta.localizedCaseInsensitiveContains("crédito") || extraido.tarjeta.localizedCaseInsensitiveContains("credito")
                ])
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    lastApplePayToast = "✅ \(extraido.comercio) (\(extraido.monto.copFormatted)) → \(cat.rawValue) [\(extraido.tarjeta)]"
                }
            }
            return
        }

        let rawMonto = param(["monto", "amount", "valor"]) ?? "0"
        let monto = RegistroPagosWalletEngine.limpiarNumeroCOP(rawMonto)
        guard monto > 0 else { return }

        let comercio = param(["comercio", "merchant", "nombre", "lugar"]) ?? "Compra Apple Pay"
        let tarjeta = param(["tarjeta", "card", "medio", "pase"]) ?? "Tarjeta Wallet"
        let metodo = param(["metodo", "dispositivo", "origen"]) ?? "Apple Watch / Pay"
        let categoriaParam = param(["categoria", "category"])

        let cat = CategoriaTarjeta.detectar(desde: comercio, categoriaExplicita: categoriaParam)
        let esCredito = tarjeta.localizedCaseInsensitiveContains("crédito") ||
                        tarjeta.localizedCaseInsensitiveContains("credito") ||
                        tarjeta.localizedCaseInsensitiveContains("nu")

        isUnlocked = true
        navigateToTab = 2 // Abrir pestaña Tarjetas / Movimientos automáticamente

        Task {
            await sendAction([
                "accion": "registrar_gasto_tarjeta",
                "comercio": comercio,
                "monto": monto,
                "categoria": cat.rawValue,
                "tarjeta": tarjeta,
                "metodo": metodo,
                "es_credito": esCredito
            ])

            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                lastApplePayToast = "Apple Pay: \(comercio) (\(monto.copFormatted)) en \(cat.rawValue)"
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation {
                lastApplePayToast = nil
            }
        }
    }

    // MARK: - Vibración Háptica Nativa de iOS
    enum HapticType { case light, medium, success, error }
    func triggerHaptic(_ type: HapticType) {
        switch type {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

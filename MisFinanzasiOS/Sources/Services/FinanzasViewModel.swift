import Foundation
import SwiftUI
import UIKit
import LocalAuthentication
import WebKit

// MARK: - Delegado URLSession que acepta certificados SSL de InfinityFree sin error
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

// MARK: - Puente invisible para resolver cookie anti-bot (__test) de InfinityFree
final class InfinityFreeCookieResolver: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Void, Never>?

    @MainActor
    func resolveCookieIfNeeded(for url: URL) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            let config = WKWebViewConfiguration()
            let wv = WKWebView(frame: .zero, configuration: config)
            wv.navigationDelegate = self
            self.webView = wv
            wv.load(URLRequest(url: url))

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                self.finish()
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            Task { @MainActor in
                self.finish()
            }
        }
    }

    func webView(
        _ webView: WKWebView,
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

    @MainActor
    private func finish() {
        guard let cont = continuation else { return }
        continuation = nil
        webView = nil
        cont.resume()
    }
}

// MARK: - ViewModel Principal Nativo SwiftUI (Motor Local Instantáneo + Cloud Sync Silencioso)
@MainActor
final class FinanzasViewModel: ObservableObject {
    @AppStorage("finanzas_api_url") var apiURL: String = ""
    @AppStorage("finanzas_user_pin") var savedPin: String = "1234"
    @AppStorage("finanzas_is_unlocked") var isUnlocked: Bool = false

    @Published var finanzas: FinanzasData
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var syncStatusText: String = "Sincronizado en iPhone"

    private let cacheKey = "finanzas_personal_cache_v3"
    private let cookieResolver = InfinityFreeCookieResolver()
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config, delegate: SSLTrustSessionDelegate(), delegateQueue: nil)
    }()

    init() {
        if let data = UserDefaults.standard.data(forKey: "finanzas_personal_cache_v3"),
           var cached = try? JSONDecoder().decode(FinanzasData.self, from: data) {
            cached.recalculateAll()
            self.finanzas = cached
        } else if let dataV2 = UserDefaults.standard.data(forKey: "finanzas_personal_cache_v2"),
                  let cachedResp = try? JSONDecoder().decode(ApiResponse.self, from: dataV2),
                  var f = cachedResp.finanzas {
            f.recalculateAll()
            self.finanzas = f
        } else {
            let initial = FinanzasData.defaultAndresData()
            self.finanzas = initial
            if let encoded = try? JSONEncoder().encode(initial) {
                UserDefaults.standard.set(encoded, forKey: "finanzas_personal_cache_v3")
            }
        }

        // Limpiar URL de ejemplo vieja si había quedado guardada en el dispositivo
        if apiURL.contains("tu-dominio.infinityfreeapp.com") || apiURL.contains("tudominio.infinityfreeapp.com") {
            apiURL = ""
        }
    }

    var hasConfiguredRemoteServer: Bool {
        let trimmed = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty &&
            !trimmed.contains("tu-dominio") &&
            !trimmed.contains("tudominio") &&
            (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
    }

    // MARK: - Desbloqueo con Face ID Nativo o PIN Instantáneo
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
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            self.isUnlocked = true
                        }
                        if self.hasConfiguredRemoteServer {
                            await self.fetchAllData()
                        }
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
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            isUnlocked = true
        }

        if hasConfiguredRemoteServer {
            Task { await fetchAllData() }
        }
        return true
    }

    // MARK: - Sincronización Silenciosa Opcional con Servidor
    func fetchAllData() async {
        guard hasConfiguredRemoteServer, let url = buildURLWithPin() else {
            // Ya tenemos todos los datos locales listos sin error
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await performRequest(url: url, method: "GET", body: nil)
            applyResponse(response)
            syncStatusText = "Sincronizado con la Nube"
        } catch {
            // Mantener los datos locales funcionando sin romper la experiencia
            syncStatusText = "Modo Local Activo"
        }

        isLoading = false
    }

    // MARK: - Ejecución Instantánea en el iPhone + Sincronización en Segundo Plano
    func sendAction(_ payload: [String: Any]) async {
        triggerHaptic(.medium)

        // 1. Aplicar inmediatamente en el motor nativo del iPhone (0ms latencia)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            applyLocalAction(payload)
        }
        saveLocalFinanzas()
        triggerHaptic(.success)

        // 2. Si el usuario configuró URL remota, sincronizar en segundo plano sin bloquear
        guard hasConfiguredRemoteServer, let url = buildURLWithPin() else { return }
        var bodyDict = payload
        bodyDict["pin"] = savedPin

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
            let response = try await performRequest(url: url, method: "POST", body: bodyData)
            applyResponse(response)
            syncStatusText = "Sincronizado con la Nube"
        } catch {
            syncStatusText = "Guardado en iPhone"
        }
    }

    // MARK: - Motor Financiero Nativo (100% Paridad con mis_finanzas.php)
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
                HistorialItem(
                    fecha: fechaActual,
                    concepto: "Aporte Corvanca",
                    monto: abono,
                    tipo: "ahorro",
                    deudaKey: nil,
                    gastoOrigen: nil
                ),
                at: 0
            )

        case "abonar_deuda":
            guard let nombreDeuda = payload["deuda"] as? String else { break }
            let abono = (payload["monto"] as? Double) ?? 0
            guard abono > 0 else { break }
            if let idx = finanzas.deudasLista.firstIndex(where: { $0.nombre == nombreDeuda }) {
                finanzas.deudasLista[idx].pendiente = max(0, finanzas.deudasLista[idx].pendiente - abono)
                finanzas.historial.insert(
                    HistorialItem(
                        fecha: fechaActual,
                        concepto: "Abono a: \(nombreDeuda)",
                        monto: abono,
                        tipo: "pago",
                        deudaKey: nombreDeuda,
                        gastoOrigen: nil
                    ),
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
                if let idxD = finanzas.deudasLista.firstIndex(where: { $0.nombre == nombreDeuda }) {
                    finanzas.deudasLista[idxD].pendiente = min(
                        finanzas.deudasLista[idxD].total,
                        finanzas.deudasLista[idxD].pendiente + monto
                    )
                }
                if let origen = item.gastoOrigen {
                    finanzas.gastosMarcados.removeAll { $0 == origen }
                }
            } else if item.tipo == "ahorro" {
                if item.concepto == "Aporte Corvanca" {
                    finanzas.ahorroCorvanca = max(0, finanzas.ahorroCorvanca - monto)
                    if let origen = item.gastoOrigen {
                        finanzas.gastosMarcados.removeAll { $0 == origen }
                    }
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
                // Desmarcar -> Revertir descuento automático
                finanzas.gastosMarcados.removeAll { $0 == nombreGasto }
                if let nombreD = deudaAsociada,
                   let idxD = finanzas.deudasLista.firstIndex(where: { $0.nombre == nombreD }),
                   valorGasto > 0 {
                    let maxTotal = finanzas.deudasLista[idxD].total
                    finanzas.deudasLista[idxD].pendiente = min(maxTotal, finanzas.deudasLista[idxD].pendiente + valorGasto)
                    if let idxH = finanzas.historial.firstIndex(where: { $0.gastoOrigen == nombreGasto }) {
                        finanzas.historial.remove(at: idxH)
                    }
                }
            } else {
                // Marcar -> Descontar automáticamente de la deuda vinculada
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
                HistorialItem(
                    fecha: fechaActual,
                    concepto: "Aporte Meta: \(nombreMeta)",
                    monto: abono,
                    tipo: "ahorro",
                    deudaKey: nil,
                    gastoOrigen: nil
                ),
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

        default:
            break
        }

        if finanzas.historial.count > 30 {
            finanzas.historial = Array(finanzas.historial.prefix(30))
        }
        finanzas.recalculateAll()
    }

    // MARK: - Petición URLSession con soporte SSL y reto JS de InfinityFree
    private func performRequest(url: URL, method: String, body: Data?, isRetry: Bool = false) async throws -> ApiResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(savedPin, forHTTPHeaderField: "X-Auth-Pin")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, httpResp) = try await urlSession.data(for: request)

        if let status = (httpResp as? HTTPURLResponse)?.statusCode, status == 401 {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "PIN incorrecto en el servidor."])
        }

        if let rawText = String(data: data, encoding: .utf8),
           (rawText.contains("aes.js") || rawText.contains("__test=")) && !isRetry {
            await cookieResolver.resolveCookieIfNeeded(for: url)
            return try await performRequest(url: url, method: method, body: body, isRetry: true)
        }

        return try JSONDecoder().decode(ApiResponse.self, from: data)
    }

    private func buildURLWithPin() -> URL? {
        let trimmed = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "pin", value: savedPin))
        components.queryItems = items
        return components.url
    }

    private func applyResponse(_ response: ApiResponse) {
        if response.ok, var remoteFinanzas = response.finanzas {
            remoteFinanzas.recalculateAll()
            self.finanzas = remoteFinanzas
            saveLocalFinanzas()
        }
    }

    private func saveLocalFinanzas() {
        if let encoded = try? JSONEncoder().encode(finanzas) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
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

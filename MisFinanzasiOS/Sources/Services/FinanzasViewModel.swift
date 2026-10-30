import Foundation
import SwiftUI
import UIKit
import LocalAuthentication
import WebKit

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
                try? await Task.sleep(nanoseconds: 4_000_000_000)
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

    @MainActor
    private func finish() {
        guard let cont = continuation else { return }
        continuation = nil
        webView = nil
        cont.resume()
    }
}

// MARK: - ViewModel Principal Nativo SwiftUI (Exclusivo Mis Finanzas)
@MainActor
final class FinanzasViewModel: ObservableObject {
    @AppStorage("finanzas_api_url") var apiURL: String = "https://tu-dominio.infinityfreeapp.com/api_finanzas.php"
    @AppStorage("finanzas_user_pin") var savedPin: String = "1234"
    @AppStorage("finanzas_is_unlocked") var isUnlocked: Bool = false

    @Published var finanzas: FinanzasData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let cacheKey = "finanzas_personal_cache_v2"
    private let cookieResolver = InfinityFreeCookieResolver()

    init() {
        loadFromLocalCache()
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
                        self.triggerHaptic(.success)
                        self.isUnlocked = true
                        await self.fetchAllData()
                    }
                }
            }
        }
    }

    func unlockWithPin(_ inputPin: String) async -> Bool {
        savedPin = inputPin.trimmingCharacters(in: .whitespacesAndNewlines)
        await fetchAllData()
        if errorMessage == nil {
            triggerHaptic(.success)
            isUnlocked = true
            return true
        }
        triggerHaptic(.error)
        return false
    }

    // MARK: - Sincronización con api_finanzas.php en InfinityFree
    func fetchAllData() async {
        guard let url = buildURLWithPin() else {
            errorMessage = "Configura una URL válida de api_finanzas.php"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await performRequest(url: url, method: "GET", body: nil)
            applyResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendAction(_ payload: [String: Any]) async {
        guard let url = buildURLWithPin() else { return }
        var bodyDict = payload
        bodyDict["pin"] = savedPin

        isLoading = true
        errorMessage = nil
        triggerHaptic(.medium)

        do {
            let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
            let response = try await performRequest(url: url, method: "POST", body: bodyData)
            applyResponse(response)
            triggerHaptic(.success)
        } catch {
            errorMessage = error.localizedDescription
            triggerHaptic(.error)
        }

        isLoading = false
    }

    // MARK: - Petición URLSession con soporte automático para el reto JS de InfinityFree
    private func performRequest(url: URL, method: String, body: Data?, isRetry: Bool = false) async throws -> ApiResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(savedPin, forHTTPHeaderField: "X-Auth-Pin")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let (data, httpResp) = try await URLSession.shared.data(for: request)

        if let status = (httpResp as? HTTPURLResponse)?.statusCode, status == 401 {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "PIN incorrecto o sesión expirada."])
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
        guard var components = URLComponents(string: trimmed) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "pin", value: savedPin))
        components.queryItems = items
        return components.url
    }

    private func applyResponse(_ response: ApiResponse) {
        if response.ok {
            if let f = response.finanzas { self.finanzas = f }
            saveToLocalCache(response)
        } else if let err = response.error {
            self.errorMessage = err
        }
    }

    // MARK: - Caché Offline en el iPhone
    private func saveToLocalCache(_ response: ApiResponse) {
        if let encoded = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private func loadFromLocalCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(ApiResponse.self, from: data) else { return }
        self.finanzas = cached.finanzas
    }

    // MARK: - Vibración Háptica Nativa de iOS
    enum HapticType { case medium, success, error }
    func triggerHaptic(_ type: HapticType) {
        switch type {
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

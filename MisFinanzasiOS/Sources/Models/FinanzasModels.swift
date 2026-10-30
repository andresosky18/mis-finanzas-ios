import Foundation
import SwiftUI

// MARK: - Respuesta Principal de api_finanzas.php (Exclusivo Mis Finanzas)
struct ApiResponse: Codable {
    let ok: Bool
    let requirePin: Bool?
    let error: String?
    let finanzas: FinanzasData?

    enum CodingKeys: String, CodingKey {
        case ok
        case requirePin = "require_pin"
        case error
        case finanzas
    }
}

// MARK: - Modelo de Billetera Personal (mis_finanzas.php)
struct FinanzasData: Codable {
    var sueldoBase: Double
    var auxTransporte: Double
    var bonoQ1: Double
    var ahorroCorvanca: Double
    var totalIngresosMensual: Double
    var totalDeudaPendiente: Double
    var netoQ1: Double
    var netoQ2: Double
    var flujoQ1: Double
    var flujoQ2: Double
    var totalGastosQuincena: Double
    var deduccionesNomina: [String: Double]
    var gastosLista: [GastoQuincenalItem]
    var gastosMarcados: [String]
    var deudasLista: [DeudaItem]
    var metasLista: [MetaItem]
    var historial: [HistorialItem]

    enum CodingKeys: String, CodingKey {
        case sueldoBase = "sueldo_base"
        case auxTransporte = "aux_transporte"
        case bonoQ1 = "bono_q1"
        case ahorroCorvanca = "ahorro_corvanca"
        case totalIngresosMensual = "total_ingresos_mensual"
        case totalDeudaPendiente = "total_deuda_pendiente"
        case netoQ1 = "neto_q1"
        case netoQ2 = "neto_q2"
        case flujoQ1 = "flujo_q1"
        case flujoQ2 = "flujo_q2"
        case totalGastosQuincena = "total_gastos_quincena"
        case deduccionesNomina = "deducciones_nomina"
        case gastosLista = "gastos_lista"
        case gastosMarcados = "gastos_marcados"
        case deudasLista = "deudas_lista"
        case metasLista = "metas_lista"
        case historial
    }
}

struct GastoQuincenalItem: Codable, Identifiable {
    var id: String { nombre }
    var nombre: String
    var valor: Double
    var label: String
    var deudaDetectada: String?
    var pagado: Bool

    enum CodingKeys: String, CodingKey {
        case nombre
        case valor
        case label
        case deudaDetectada = "deuda_detectada"
        case pagado
    }
}

struct DeudaItem: Codable, Identifiable {
    var id: String { nombre }
    var nombre: String
    var total: Double
    var pendiente: Double
    var cuota: Double
    var icono: String

    var pagado: Double {
        max(0, total - pendiente)
    }

    var porcentaje: Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, pagado / total))
    }

    var mesesRestantes: Int {
        guard cuota > 0 && pendiente > 0 else { return 0 }
        return Int(ceil(pendiente / cuota))
    }
}

struct MetaItem: Codable, Identifiable {
    var id: String { nombre }
    var nombre: String
    var total: Double
    var actual: Double
    var icono: String

    var porcentaje: Double {
        guard total > 0 else { return 0 }
        return min(1.0, max(0.0, actual / total))
    }

    var completada: Bool {
        total > 0 && actual >= total
    }
}

struct HistorialItem: Codable, Identifiable {
    var id: String { "\(fecha)-\(concepto)-\(monto)" }
    var fecha: String
    var concepto: String
    var monto: Double
    var tipo: String
    var deudaKey: String?
    var gastoOrigen: String?

    enum CodingKeys: String, CodingKey {
        case fecha
        case concepto
        case monto
        case tipo
        case deudaKey = "deuda_key"
        case gastoOrigen = "gasto_origen"
    }
}

// MARK: - Extensiones de Formato COP y Símbolos SF Nativos de Apple
extension Double {
    var copFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
}

enum SFIconMapper {
    static func symbol(for lucideOrEmoji: String) -> String {
        let clean = lucideOrEmoji.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch clean {
        case "smartphone", "📱": return "iphone"
        case "bike", "🏍️": return "bicycle"
        case "car", "🛑": return "car.fill"
        case "graduation-cap", "🎓": return "graduationcap.fill"
        case "plane", "✈️": return "airplane"
        case "watch", "⌚": return "applewatch"
        case "shield", "🪖": return "shield.fill"
        case "target", "🎯": return "target"
        case "banknote", "💸": return "banknote.fill"
        case "shopping-bag": return "bag.fill"
        case "camera": return "camera.fill"
        case "utensils": return "fork.knife"
        case "gamepad-2": return "gamecontroller.fill"
        case "hard-drive": return "externaldrive.fill"
        case "credit-card": return "creditcard.fill"
        default: return "creditcard.fill"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (99, 102, 241)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

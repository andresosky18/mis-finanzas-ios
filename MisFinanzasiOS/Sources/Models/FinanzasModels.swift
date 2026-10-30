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

    // MARK: - Recálculo Instantáneo en el iPhone (Idéntico a mis_finanzas.php)
    mutating func recalculateAll() {
        let sueldoQuincenal = sueldoBase / 2.0
        let otrosIngresosMensual: Double = 1_000_000

        let ingresoBrutoQ2 = sueldoQuincenal + auxTransporte
        let ingresoBrutoQ1 = ingresoBrutoQ2 + bonoQ1

        let totalDeducciones = deduccionesNomina.values.reduce(0, +)
        netoQ2 = ingresoBrutoQ2 - totalDeducciones
        netoQ1 = ingresoBrutoQ1 - totalDeducciones

        // Actualizar vinculación inteligente de gastos con deudas y estado pagado
        for idx in gastosLista.indices {
            let nombreG = gastosLista[idx].nombre
            gastosLista[idx].pagado = gastosMarcados.contains(nombreG)
            gastosLista[idx].deudaDetectada = Self.resolverDeuda(
                nombreGasto: nombreG,
                deudaExplicita: gastosLista[idx].deudaDetectada,
                deudas: deudasLista
            )
        }

        totalGastosQuincena = gastosLista.reduce(0) { $0 + $1.valor }
        flujoQ1 = netoQ1 - totalGastosQuincena
        flujoQ2 = netoQ2 - totalGastosQuincena

        totalIngresosMensual = sueldoBase + (auxTransporte * 2.0) + bonoQ1 + otrosIngresosMensual
        totalDeudaPendiente = deudasLista.reduce(0) { $0 + $1.pendiente }
    }

    static func resolverDeuda(nombreGasto: String, deudaExplicita: String?, deudas: [DeudaItem]) -> String? {
        if let exp = deudaExplicita, !exp.isEmpty, deudas.contains(where: { $0.nombre.caseInsensitiveCompare(exp) == .orderedSame }) {
            return deudas.first(where: { $0.nombre.caseInsensitiveCompare(exp) == .orderedSame })?.nombre
        }
        if nombreGasto.localizedCaseInsensitiveContains("internet") {
            return nil
        }
        let cleanGasto = nombreGasto.trimmingCharacters(in: .whitespacesAndNewlines)
        for d in deudas {
            let cleanD = d.nombre.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanGasto.caseInsensitiveCompare(cleanD) == .orderedSame ||
                cleanGasto.caseInsensitiveCompare("Cuota \(cleanD)") == .orderedSame ||
                cleanGasto.localizedCaseInsensitiveContains(cleanD) {
                return d.nombre
            }
        }
        return nil
    }

    // MARK: - Métricas de Distribución para el Gráfico Donut Liquid Glass
    var totalAhorroQuincenal: Double {
        gastosLista
            .filter { $0.nombre.localizedCaseInsensitiveContains("ahorro") }
            .reduce(0) { $0 + $1.valor }
    }

    var totalDeudasQuincenal: Double {
        gastosLista
            .filter {
                !$0.nombre.localizedCaseInsensitiveContains("ahorro") &&
                ($0.nombre.localizedCaseInsensitiveContains("deuda") || ($0.deudaDetectada != nil && !($0.deudaDetectada ?? "").isEmpty))
            }
            .reduce(0) { $0 + $1.valor }
    }

    var totalFijosQuincenal: Double {
        max(0, totalGastosQuincena - totalAhorroQuincenal - totalDeudasQuincenal)
    }

    // MARK: - Datos Reales de Andrés Pre-cargados (Cero configuración inicial)
    static func defaultAndresData() -> FinanzasData {
        var initial = FinanzasData(
            sueldoBase: 2_500_000,
            auxTransporte: 124_548,
            bonoQ1: 160_000,
            ahorroCorvanca: 900_000,
            totalIngresosMensual: 3_909_096,
            totalDeudaPendiente: 17_791_330,
            netoQ1: 1_324_548,
            netoQ2: 1_164_548,
            flujoQ1: 170_519,
            flujoQ2: 10_519,
            totalGastosQuincena: 1_154_029,
            deduccionesNomina: [
                "Fondo de salud": 50_000,
                "Fondo de pensión": 50_000,
                "Parqueadero": 41_333,
                "Ahorro Corvanca": 75_000
            ],
            gastosLista: [
                GastoQuincenalItem(nombre: "Arriendo", valor: 157_500, label: "Día 3", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "Moto", valor: 226_500, label: "Día 5", deudaDetectada: "Moto", pagado: false),
                GastoQuincenalItem(nombre: "Ahorros", valor: 150_000, label: "Día 10", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "Fondo Deudas", valor: 156_590, label: "Día 10", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "SOAT/Tecno", valor: 82_375, label: "Día 10", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "Internet y Celular", valor: 59_950, label: "Días 10 y 13", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "Net/Spo/iCloud", valor: 32_500, label: "Días 10 y 25", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "Comida", valor: 100_000, label: "Día 11", deudaDetectada: nil, pagado: false),
                GastoQuincenalItem(nombre: "Cuota Celular", valor: 133_000, label: "Día 11", deudaDetectada: "Celular", pagado: false),
                GastoQuincenalItem(nombre: "Universidad", valor: 56_114, label: "Día 25", deudaDetectada: "Universidad", pagado: false),
                GastoQuincenalItem(nombre: "Gasolina", valor: 56_000, label: "Variable", deudaDetectada: nil, pagado: false)
            ],
            gastosMarcados: [],
            deudasLista: [
                DeudaItem(nombre: "Tránsito", total: 7_000_000, pendiente: 4_000_000, cuota: 1_000_000, icono: "car"),
                DeudaItem(nombre: "Celular", total: 5_000_000, pendiente: 4_223_405, cuota: 133_000, icono: "smartphone"),
                DeudaItem(nombre: "Moto", total: 11_500_000, pendiente: 8_512_043, cuota: 453_000, icono: "bike"),
                DeudaItem(nombre: "Universidad", total: 1_280_338, pendiente: 1_055_882, cuota: 112_228, icono: "graduation-cap")
            ],
            metasLista: [
                MetaItem(nombre: "Viaje a San Andrés", total: 1_500_000, actual: 0, icono: "plane"),
                MetaItem(nombre: "Casco Nuevo Moto", total: 400_000, actual: 0, icono: "shield")
            ],
            historial: []
        )
        initial.recalculateAll()
        return initial
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

    static func accentColor(for deudaNombre: String) -> Color {
        let lower = deudaNombre.lowercased()
        if lower.contains("tránsito") || lower.contains("transito") {
            return Color(hex: "#F59E0B")
        } else if lower.contains("celular") {
            return Color(hex: "#06B6D4")
        } else if lower.contains("moto") {
            return Color(hex: "#6366F1")
        } else if lower.contains("universidad") {
            return Color(hex: "#10B981")
        }
        return Color(hex: "#8B5CF6")
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

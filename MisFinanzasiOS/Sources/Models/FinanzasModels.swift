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

// MARK: - Categorías Inteligentes de Gastos con Tarjeta / Apple Pay (Inspirado en Lukas)
enum CategoriaTarjeta: String, Codable, CaseIterable, Identifiable {
    case comida = "Comida"
    case transporte = "Transporte"
    case mercado = "Mercado"
    case compras = "Compras"
    case suscripciones = "Suscripciones"
    case ocio = "Ocio"
    case salud = "Salud"
    case otros = "Otros"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .comida: return "fork.knife"
        case .transporte: return "fuelpump.fill"
        case .mercado: return "cart.fill"
        case .compras: return "bag.fill"
        case .suscripciones: return "play.tv.fill"
        case .ocio: return "gamecontroller.fill"
        case .salud: return "cross.case.fill"
        case .otros: return "sparkles"
        }
    }

    var colorHex: String {
        switch self {
        case .comida: return "#F97316"       // Naranja vibrante
        case .transporte: return "#06B6D4"   // Cyan
        case .mercado: return "#10B981"      // Esmeralda
        case .compras: return "#6366F1"      // Índigo
        case .suscripciones: return "#8B5CF6" // Violeta
        case .ocio: return "#EC4899"         // Rosa
        case .salud: return "#EF4444"        // Rojo
        case .otros: return "#64748B"        // Gris pizarra
        }
    }

    var color: Color {
        Color(hex: colorHex)
    }

    static func detectar(desde comercio: String, categoriaExplicita: String? = nil) -> CategoriaTarjeta {
        if let exp = categoriaExplicita?.trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty {
            for cat in Self.allCases {
                if cat.rawValue.localizedCaseInsensitiveCompare(exp) == .orderedSame {
                    return cat
                }
            }
        }
        let lower = comercio.lowercased()
        if lower.contains("mcdonald") || lower.contains("rappi") || lower.contains("crepes") ||
           lower.contains("corral") || lower.contains("kfc") || lower.contains("starbucks") ||
           lower.contains("juan valdez") || lower.contains("restaurante") || lower.contains("almuerzo") ||
           lower.contains("pizza") || lower.contains("burger") || lower.contains("cafe") ||
           lower.contains("café") || lower.contains("panaderia") || lower.contains("comida") {
            return .comida
        }
        if lower.contains("terpel") || lower.contains("primax") || lower.contains("biomax") ||
           lower.contains("texaco") || lower.contains("gasolina") || lower.contains("uber") ||
           lower.contains("didi") || lower.contains("cabify") || lower.contains("peaje") ||
           lower.contains("parqueadero") || lower.contains("transporte") || lower.contains("moto") {
            return .transporte
        }
        if lower.contains("d1") || lower.contains("ara") || lower.contains("exito") ||
           lower.contains("éxito") || lower.contains("carulla") || lower.contains("olimpica") ||
           lower.contains("olímpica") || lower.contains("alkosto") || lower.contains("makro") ||
           lower.contains("dollarcity") || lower.contains("mercado") || lower.contains("supermercado") {
            return .mercado
        }
        if lower.contains("netflix") || lower.contains("spotify") || lower.contains("icloud") ||
           lower.contains("apple.com/bill") || lower.contains("claro") || lower.contains("movistar") ||
           lower.contains("tigo") || lower.contains("youtube") || lower.contains("disney") ||
           lower.contains("prime") || lower.contains("hbo") || lower.contains("chatgpt") {
            return .suscripciones
        }
        if lower.contains("cine") || lower.contains("cinecolombia") || lower.contains("bar") ||
           lower.contains("steam") || lower.contains("playstation") || lower.contains("xbox") ||
           lower.contains("concierto") || lower.contains("salida") {
            return .ocio
        }
        if lower.contains("drogueria") || lower.contains("droguería") || lower.contains("farmatodo") ||
           lower.contains("cruz verde") || lower.contains("pasteur") || lower.contains("rebaja") ||
           lower.contains("salud") || lower.contains("medico") || lower.contains("médico") {
            return .salud
        }
        if lower.contains("amazon") || lower.contains("mercadolibre") || lower.contains("mercado libre") ||
           lower.contains("falabella") || lower.contains("zara") || lower.contains("hm") ||
           lower.contains("nike") || lower.contains("adidas") || lower.contains("ropa") ||
           lower.contains("tienda") {
            return .compras
        }
        return .otros
    }
}

// MARK: - Movimiento Individual de Tarjeta / Apple Pay / Apple Watch
struct GastoTarjetaItem: Codable, Identifiable {
    var id: String
    var fecha: String
    var comercio: String
    var monto: Double
    var categoria: String
    var tarjeta: String      // Ej: "Débito Bancolombia", "Crédito Nu", "Nequi / Débito"
    var metodo: String       // Ej: "Apple Watch", "Apple Pay", "Tarjeta Física"
    var esCredito: Bool

    var categoriaEnum: CategoriaTarjeta {
        CategoriaTarjeta.detectar(desde: comercio, categoriaExplicita: categoria)
    }
}

// MARK: - Modelo de Billetera Personal (mis_finanzas.php en pagos.xo.je)
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
    var gastosTarjeta: [GastoTarjetaItem]

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
        case gastosTarjeta = "gastos_tarjeta"
    }

    init(
        sueldoBase: Double,
        auxTransporte: Double,
        bonoQ1: Double,
        ahorroCorvanca: Double,
        totalIngresosMensual: Double,
        totalDeudaPendiente: Double,
        netoQ1: Double,
        netoQ2: Double,
        flujoQ1: Double,
        flujoQ2: Double,
        totalGastosQuincena: Double,
        deduccionesNomina: [String: Double],
        gastosLista: [GastoQuincenalItem],
        gastosMarcados: [String],
        deudasLista: [DeudaItem],
        metasLista: [MetaItem],
        historial: [HistorialItem],
        gastosTarjeta: [GastoTarjetaItem] = []
    ) {
        self.sueldoBase = sueldoBase
        self.auxTransporte = auxTransporte
        self.bonoQ1 = bonoQ1
        self.ahorroCorvanca = ahorroCorvanca
        self.totalIngresosMensual = totalIngresosMensual
        self.totalDeudaPendiente = totalDeudaPendiente
        self.netoQ1 = netoQ1
        self.netoQ2 = netoQ2
        self.flujoQ1 = flujoQ1
        self.flujoQ2 = flujoQ2
        self.totalGastosQuincena = totalGastosQuincena
        self.deduccionesNomina = deduccionesNomina
        self.gastosLista = gastosLista
        self.gastosMarcados = gastosMarcados
        self.deudasLista = deudasLista
        self.metasLista = metasLista
        self.historial = historial
        self.gastosTarjeta = gastosTarjeta
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sueldoBase = try c.decodeIfPresent(Double.self, forKey: .sueldoBase) ?? 2_500_000
        auxTransporte = try c.decodeIfPresent(Double.self, forKey: .auxTransporte) ?? 124_548
        bonoQ1 = try c.decodeIfPresent(Double.self, forKey: .bonoQ1) ?? 160_000
        ahorroCorvanca = try c.decodeIfPresent(Double.self, forKey: .ahorroCorvanca) ?? 1_575_000
        totalIngresosMensual = try c.decodeIfPresent(Double.self, forKey: .totalIngresosMensual) ?? 3_909_096
        totalDeudaPendiente = try c.decodeIfPresent(Double.self, forKey: .totalDeudaPendiente) ?? 8_627_734
        netoQ1 = try c.decodeIfPresent(Double.self, forKey: .netoQ1) ?? 1_318_215
        netoQ2 = try c.decodeIfPresent(Double.self, forKey: .netoQ2) ?? 1_158_215
        flujoQ1 = try c.decodeIfPresent(Double.self, forKey: .flujoQ1) ?? 75_286
        flujoQ2 = try c.decodeIfPresent(Double.self, forKey: .flujoQ2) ?? -84_714
        totalGastosQuincena = try c.decodeIfPresent(Double.self, forKey: .totalGastosQuincena) ?? 1_242_929
        deduccionesNomina = try c.decodeIfPresent([String: Double].self, forKey: .deduccionesNomina) ?? [:]
        gastosLista = try c.decodeIfPresent([GastoQuincenalItem].self, forKey: .gastosLista) ?? []
        gastosMarcados = try c.decodeIfPresent([String].self, forKey: .gastosMarcados) ?? []
        deudasLista = try c.decodeIfPresent([DeudaItem].self, forKey: .deudasLista) ?? []
        metasLista = try c.decodeIfPresent([MetaItem].self, forKey: .metasLista) ?? []
        historial = try c.decodeIfPresent([HistorialItem].self, forKey: .historial) ?? []
        gastosTarjeta = try c.decodeIfPresent([GastoTarjetaItem].self, forKey: .gastosTarjeta) ?? FinanzasData.defaultGastosTarjeta()
    }

    // MARK: - Recálculo Exacto (Idéntico a pagos.xo.je/mis_finanzas.php)
    mutating func recalculateAll() {
        let sueldoQuincenal = sueldoBase / 2.0
        let otrosIngresosMensual: Double = 1_000_000

        let ingresoBrutoQ2 = sueldoQuincenal + auxTransporte
        let ingresoBrutoQ1 = ingresoBrutoQ2 + bonoQ1

        let totalDeducciones = deduccionesNomina.values.reduce(0, +)
        netoQ2 = ingresoBrutoQ2 - totalDeducciones
        netoQ1 = ingresoBrutoQ1 - totalDeducciones

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
        if let exp = deudaExplicita, !exp.isEmpty,
           let match = deudas.first(where: { $0.nombre.caseInsensitiveCompare(exp) == .orderedSame }) {
            return match.nombre
        }
        // Evitar que "Internet y Celular (Hogar/Plan)" o "Parqueadero U" descuenten deudas equivocadas
        if nombreGasto.localizedCaseInsensitiveContains("internet") ||
           nombreGasto.localizedCaseInsensitiveContains("parqueadero") {
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

    var totalGastadoTarjetas: Double {
        gastosTarjeta.reduce(0) { $0 + $1.monto }
    }

    var totalGastadoDebito: Double {
        gastosTarjeta.filter { !$0.esCredito }.reduce(0) { $0 + $1.monto }
    }

    var totalGastadoCredito: Double {
        gastosTarjeta.filter { $0.esCredito }.reduce(0) { $0 + $1.monto }
    }

    static func defaultGastosTarjeta() -> [GastoTarjetaItem] {
        [
            GastoTarjetaItem(
                id: "card-1",
                fecha: "Hoy · Apple Watch",
                comercio: "Estación Terpel (Gasolina)",
                monto: 28_000,
                categoria: CategoriaTarjeta.transporte.rawValue,
                tarjeta: "Débito",
                metodo: "Apple Watch",
                esCredito: false
            ),
            GastoTarjetaItem(
                id: "card-2",
                fecha: "Ayer · Apple Pay",
                comercio: "Tiendas D1 Mercado",
                monto: 64_500,
                categoria: CategoriaTarjeta.mercado.rawValue,
                tarjeta: "Débito",
                metodo: "Apple Pay",
                esCredito: false
            ),
            GastoTarjetaItem(
                id: "card-3",
                fecha: "28 Oct · Apple Pay",
                comercio: "Netflix / Spotify / iCloud",
                monto: 32_500,
                categoria: CategoriaTarjeta.suscripciones.rawValue,
                tarjeta: "Crédito Nu",
                metodo: "Apple Pay",
                esCredito: true
            ),
            GastoTarjetaItem(
                id: "card-4",
                fecha: "27 Oct · Apple Watch",
                comercio: "El Corral / Almuerzo",
                monto: 38_900,
                categoria: CategoriaTarjeta.comida.rawValue,
                tarjeta: "Débito",
                metodo: "Apple Watch",
                esCredito: false
            )
        ]
    }

    // MARK: - Snapshot Real en Vivo de https://pagos.xo.je/mis_finanzas.php
    static func defaultAndresData() -> FinanzasData {
        var initial = FinanzasData(
            sueldoBase: 2_500_000,
            auxTransporte: 124_548,
            bonoQ1: 160_000,
            ahorroCorvanca: 1_575_000,
            totalIngresosMensual: 3_909_096,
            totalDeudaPendiente: 8_627_734,
            netoQ1: 1_318_215,
            netoQ2: 1_158_215,
            flujoQ1: 75_286,
            flujoQ2: -84_714,
            totalGastosQuincena: 1_242_929,
            deduccionesNomina: [
                "Fondo de salud": 50_000,
                "Fondo de pensión": 50_000,
                "Parqueadero": 41_333,
                "Ahorro Corvanca": 75_000
            ],
            gastosLista: [
                GastoQuincenalItem(nombre: "Comida", valor: 100_000, label: "Día 11", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Arriendo", valor: 157_500, label: "Día 3", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Moto", valor: 226_500, label: "Día 5", deudaDetectada: "Moto", pagado: true),
                GastoQuincenalItem(nombre: "Gasolina", valor: 56_000, label: "Variable", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Internet y Celular (Hogar/Plan)", valor: 59_950, label: "Días 10 y 13", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Cuota Celular", valor: 133_000, label: "Día 11", deudaDetectada: "celular", pagado: true),
                GastoQuincenalItem(nombre: "Net/Spo/iCloud", valor: 32_500, label: "Días 10 y 25", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Ahorros", valor: 150_000, label: "Día 10", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Fondo Deudas", valor: 156_590, label: "Día 10", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "SOAT/Tecno", valor: 82_375, label: "Día 10", deudaDetectada: nil, pagado: true),
                GastoQuincenalItem(nombre: "Universidad", valor: 56_114, label: "Día 25", deudaDetectada: "Universidad", pagado: true),
                GastoQuincenalItem(nombre: "Parqueadero U", valor: 32_400, label: "Día 10", deudaDetectada: nil, pagado: true)
            ],
            gastosMarcados: [
                "Comida",
                "Arriendo",
                "Moto",
                "Gasolina",
                "Internet y Celular (Hogar/Plan)",
                "Cuota Celular",
                "Net/Spo/iCloud",
                "Ahorros",
                "Fondo Deudas",
                "SOAT/Tecno",
                "Universidad",
                "Parqueadero U"
            ],
            deudasLista: [
                DeudaItem(nombre: "Moto", total: 11_500_000, pendiente: 2_446_961, cuota: 453_000, icono: "bike"),
                DeudaItem(nombre: "Universidad", total: 1_280_338, pendiente: 619_138, cuota: 112_228, icono: "graduation-cap"),
                DeudaItem(nombre: "celular", total: 4_223_405, pendiente: 3_761_635, cuota: 133_000, icono: "phone"),
                DeudaItem(nombre: "TV", total: 1_800_000, pendiente: 1_800_000, cuota: 225_000, icono: "tv")
            ],
            metasLista: [],
            historial: [
                HistorialItem(fecha: "28 Oct 2026 - 11:42", concepto: "Abono a: Moto", monto: 226_000, tipo: "pago", deudaKey: "Moto", gastoOrigen: nil),
                HistorialItem(fecha: "26 Oct 2026 - 17:35", concepto: "Abono a: celular", monto: 133_000, tipo: "pago", deudaKey: "celular", gastoOrigen: nil),
                HistorialItem(fecha: "24 Oct 2026 - 01:57", concepto: "Aporte Corvanca", monto: 75_000, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                HistorialItem(fecha: "22 Oct 2026 - 19:52", concepto: "Abono a: Tránsito", monto: 2_000_000, tipo: "pago", deudaKey: "Tránsito", gastoOrigen: nil),
                HistorialItem(fecha: "13 Oct 2026 - 16:18", concepto: "Aporte Corvanca", monto: 75_000, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                HistorialItem(fecha: "13 Oct 2026 - 16:18", concepto: "Aporte Corvanca", monto: 75_000, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                HistorialItem(fecha: "12 Oct 2026 - 17:42", concepto: "Abono a: Moto", monto: 226_000, tipo: "pago", deudaKey: "Moto", gastoOrigen: nil),
                HistorialItem(fecha: "08 Oct 2026 - 13:26", concepto: "Abono a: Moto", monto: 272_366, tipo: "pago", deudaKey: "Moto", gastoOrigen: nil),
                HistorialItem(fecha: "03 Oct 2026 - 20:22", concepto: "Abono a: Universidad", monto: 100_000, tipo: "pago", deudaKey: "Universidad", gastoOrigen: nil),
                HistorialItem(fecha: "28 Sep 2026 - 23:51", concepto: "Abono a: celular", monto: 195_770, tipo: "pago", deudaKey: "celular", gastoOrigen: nil),
                HistorialItem(fecha: "28 Sep 2026 - 23:45", concepto: "Aporte Corvanca", monto: 75_000, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                HistorialItem(fecha: "17 Sep 2026 - 23:10", concepto: "Abono a: YO TARGETA NU", monto: 279_000, tipo: "pago", deudaKey: nil, gastoOrigen: nil),
                HistorialItem(fecha: "11 Sep 2026 - 00:34", concepto: "Aporte Corvanca", monto: 75_000, tipo: "ahorro", deudaKey: nil, gastoOrigen: nil),
                HistorialItem(fecha: "11 Sep 2026 - 00:31", concepto: "Abono a: Moto", monto: 455_000, tipo: "pago", deudaKey: "Moto", gastoOrigen: nil),
                HistorialItem(fecha: "02 Sep 2026 - 22:59", concepto: "Abono a: Universidad", monto: 112_228, tipo: "pago", deudaKey: "Universidad", gastoOrigen: nil)
            ],
            gastosTarjeta: Self.defaultGastosTarjeta()
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

    var etaTexto: String {
        guard mesesRestantes > 0 else { return "Liquidada 🎉" }
        let cal = Calendar.current
        if let future = cal.date(byAdding: .month, value: mesesRestantes, to: Date()) {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "es_CO")
            fmt.dateFormat = "MMM yyyy"
            return fmt.string(from: future).capitalized
        }
        return "~\(mesesRestantes) meses"
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
        case "smartphone", "phone", "📱": return "iphone"
        case "bike", "🏍️": return "bicycle"
        case "tv", "📺": return "tv.fill"
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
        case "home", "house": return "house.fill"
        default: return "creditcard.fill"
        }
    }

    static func accentColor(for deudaNombre: String) -> Color {
        let lower = deudaNombre.lowercased()
        if lower.contains("moto") {
            return Color(hex: "#6366F1")
        } else if lower.contains("universidad") {
            return Color(hex: "#10B981")
        } else if lower.contains("celular") {
            return Color(hex: "#06B6D4")
        } else if lower.contains("tv") {
            return Color(hex: "#F59E0B")
        } else if lower.contains("tránsito") || lower.contains("transito") {
            return Color(hex: "#EF4444")
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

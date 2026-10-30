import SwiftUI

struct CreditosNuView: View {
    @EnvironmentObject var vm: FinanzasViewModel
    @State private var showAbonarFactura = false
    @State private var montoFactura = ""
    @State private var categoriaFactura = "dron"
    @State private var avanzarCuotas = true

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let nu = vm.creditosNu {
                    // BALANCE TOTAL CRÉDITOS NU
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("BALANCE TOTAL PENDIENTE")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("CORTE: \(nu.fechaCorte)")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#6366F1").opacity(0.16))
                                .foregroundColor(Color(hex: "#818CF8"))
                                .clipShape(Capsule())
                        }

                        Text(nu.saldoPendiente.copFormatted)
                            .font(.system(size: 34, weight: .heavy))

                        // LÍNEAS DE CRÉDITO (DRON, RELOJ, ETC.)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(nu.lineasCredito) { linea in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: SFIconMapper.symbol(for: linea.icono))
                                            .foregroundColor(Color(hex: linea.color))
                                        Text(linea.nombre)
                                            .font(.system(size: 12, weight: .bold))
                                            .lineLimit(1)
                                    }
                                    Text((linea.stats?.saldo ?? 0).copFormatted)
                                        .font(.system(size: 17, weight: .heavy))
                                        .foregroundColor(Color(hex: linea.color))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .cornerRadius(14)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)

                    // PROGRESO DE CUOTAS DIFERIDAS
                    if !nu.cuotasDinamicas.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PROGRESO DE CUOTAS DIFERIDAS")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(nu.cuotasDinamicas) { c in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: SFIconMapper.symbol(for: c.icono))
                                                .foregroundColor(Color(hex: "#3B82F6"))
                                            Text(c.nombre.capitalized)
                                                .font(.system(size: 13, weight: .bold))
                                            Spacer()
                                            Text("\(c.act)/\(c.tot)")
                                                .font(.system(size: 13, weight: .heavy))
                                                .foregroundColor(Color(hex: "#3B82F6"))
                                        }
                                        ProgressView(value: c.porcentaje)
                                            .tint(Color(hex: "#3B82F6"))
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }

                    // FACTURACIÓN DEL PERÍODO (CON DESCUENTO AUTOMÁTICO DE DEUDA)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("FACTURACIÓN DEL PERÍODO")
                                .font(.system(size: 12, weight: .heavy))
                            Spacer()
                            Button {
                                montoFactura = String(Int(nu.cuotaMes))
                                categoriaFactura = nu.lineasCredito.first?.id ?? "dron"
                                showAbonarFactura = true
                            } label: {
                                Label("Abonar Factura", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#4F46E5"))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }

                        ForEach(Array(nu.facturacionItems.enumerated()), id: \.offset) { idx, item in
                            HStack {
                                Image(systemName: item.pagado ? "checkmark.circle.fill" : "doc.text.fill")
                                    .foregroundColor(item.pagado ? Color(hex: "#10B981") : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.nombre)
                                        .font(.system(size: 14, weight: .semibold))
                                        .strikethrough(item.pagado)
                                    if let cat = item.categoria {
                                        Text(cat.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if item.monto > 0 {
                                    Text(item.monto.copFormatted)
                                        .font(.system(size: 13, weight: .bold))
                                }

                                if !item.pagado && item.monto > 0 {
                                    Button("Pagar") {
                                        Task {
                                            await vm.sendAction([
                                                "accion": "pagar_item_nu",
                                                "item_index": idx
                                            ])
                                        }
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#10B981"))
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }

                        HStack {
                            Text("Total Cierre Mensual:")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#818CF8"))
                            Spacer()
                            Text(nu.cuotaMes <= 0 ? "¡AL DÍA! ($0)" : nu.cuotaMes.copFormatted)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundColor(nu.cuotaMes <= 0 ? Color(hex: "#10B981") : Color(hex: "#818CF8"))
                        }
                        .padding(14)
                        .background(Color(hex: "#4F46E5").opacity(0.14))
                        .cornerRadius(12)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)

                    // HISTORIAL DE MOVIMIENTOS NU + ENLACE A RECIBO.PHP
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOVIMIENTOS RECIENTES & RECIBOS")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.secondary)

                        ForEach(nu.movimientos) { mov in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mov.concepto)
                                        .font(.system(size: 13, weight: .bold))
                                    HStack(spacing: 8) {
                                        Text(mov.fecha)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        if mov.tipo.lowercased() == "pago", let url = vm.reciboURL(id: mov.id) {
                                            Link("🧾 Recibo #\(mov.id)", destination: url)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Color(hex: "#10B981"))
                                        }
                                    }
                                }
                                Spacer()
                                let esPago = mov.tipo.lowercased() == "pago"
                                Text("\(esPago ? "+" : "-")\(mov.monto.copFormatted)")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(esPago ? Color(hex: "#10B981") : .primary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Panel Créditos Nu")
        .refreshable {
            await vm.fetchAllData()
        }
        .sheet(isPresented: $showAbonarFactura) {
            NavigationStack {
                Form {
                    Section("Abonar / Pagar Factura del Mes") {
                        TextField("Monto a abonar ($)", text: $montoFactura)
                            .keyboardType(.numberPad)

                        if let lineas = vm.creditosNu?.lineasCredito {
                            Picker("Línea a descontar", selection: $categoriaFactura) {
                                ForEach(lineas) { l in
                                    Text(l.nombre).tag(l.id)
                                }
                            }
                        }

                        Toggle("Avanzar +1 en cuotas diferidas", isOn: $avanzarCuotas)
                    }

                    Section {
                        Button("Confirmar Pago y Bajar Deuda") {
                            guard let val = Double(montoFactura), val > 0 else { return }
                            Task {
                                await vm.sendAction([
                                    "accion": "abonar_factura_nu",
                                    "monto": val,
                                    "categoria": categoriaFactura,
                                    "avanzar_cuotas": avanzarCuotas ? 1 : 0
                                ])
                                showAbonarFactura = false
                            }
                        }
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#10B981"))
                    }
                }
                .navigationTitle("Abonar Factura")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { showAbonarFactura = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

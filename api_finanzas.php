<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, X-Auth-Pin");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

session_start();
include 'conexion.php';

$archivo_config = 'config.json';
$config = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];
$pin_sistema = (string)($config['pin_acceso'] ?? '1234');

// Leer body JSON si se envió como application/json desde Swift URLSession
$raw_input = file_get_contents('php://input');
$json_input = json_decode($raw_input, true);
$req = is_array($json_input) ? array_merge($_REQUEST, $json_input) : $_REQUEST;

// Verificar PIN (por sesión, header o parámetro)
$pin_enviado = trim($req['pin'] ?? ($_SERVER['HTTP_X_AUTH_PIN'] ?? ''));
if (isset($req['accion']) && $req['accion'] === 'verificar_pin') {
    if ($pin_enviado === $pin_sistema) {
        $_SESSION['auth_pin_ok'] = true;
        echo json_encode(['ok' => true, 'mensaje' => 'PIN válido']);
    } else {
        http_response_code(401);
        echo json_encode(['ok' => false, 'error' => 'PIN incorrecto']);
    }
    exit();
}

if (empty($_SESSION['auth_pin_ok']) && $pin_enviado !== $pin_sistema) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'require_pin' => true, 'error' => 'PIN requerido']);
    exit();
}
$_SESSION['auth_pin_ok'] = true;

// Cargar datos de mi_billetera (ID 3)
$conn->query("CREATE TABLE IF NOT EXISTS mi_billetera (id INT PRIMARY KEY, datos TEXT)");
$result = $conn->query("SELECT datos FROM mi_billetera WHERE id = 3");

$default_data = [
    'sueldo_base' => 2500000,
    'aux_transporte' => 124548,
    'bono_q1' => 160000,
    'ahorro_corvanca' => 900000,
    'deudas' => [
        'Tránsito' => ['total' => 7000000, 'pendiente' => 4000000, 'cuota' => 1000000, 'icono' => 'car'],
        'Celular' => ['total' => 5000000, 'pendiente' => 4223405, 'cuota' => 133000, 'icono' => 'smartphone'],
        'Moto' => ['total' => 11500000, 'pendiente' => 8512043, 'cuota' => 453000, 'icono' => 'bike'],
        'Universidad' => ['total' => 1280338, 'pendiente' => 1055882, 'cuota' => 112228, 'icono' => 'graduation-cap']
    ],
    'gastos_quincenales' => [
        'Comida' => ['valor' => 100000, 'dias' => [11], 'label' => 'Día 11'],
        'Arriendo' => ['valor' => 157500, 'dias' => [3], 'label' => 'Día 3'],
        'Moto' => ['valor' => 226500, 'dias' => [5], 'label' => 'Día 5', 'deuda_vinculada' => 'Moto'],
        'Gasolina' => ['valor' => 56000, 'dias' => [], 'label' => 'Variable'],
        'Internet y Celular' => ['valor' => 59950, 'dias' => [10, 13], 'label' => 'Días 10 y 13'],
        'Cuota Celular' => ['valor' => 133000, 'dias' => [11], 'label' => 'Día 11', 'deuda_vinculada' => 'Celular'],
        'Net/Spo/iCloud' => ['valor' => 32500, 'dias' => [10, 25], 'label' => 'Días 10 y 25'],
        'Ahorros' => ['valor' => 150000, 'dias' => [10], 'label' => 'Día 10'],
        'Fondo Deudas' => ['valor' => 156590, 'dias' => [10], 'label' => 'Día 10'],
        'SOAT/Tecno' => ['valor' => 82375, 'dias' => [10], 'label' => 'Día 10'],
        'Universidad' => ['valor' => 56114, 'dias' => [25], 'label' => 'Día 25', 'deuda_vinculada' => 'Universidad']
    ],
    'metas' => [
        'Viaje a San Andrés' => ['total' => 1500000, 'actual' => 0, 'icono' => 'plane'],
        'Casco Nuevo Moto' => ['total' => 400000, 'actual' => 0, 'icono' => 'shield']
    ],
    'gastos_marcados' => [],
    'historial' => []
];

if ($result && $result->num_rows == 0) {
    $json_default = json_encode($default_data, JSON_UNESCAPED_UNICODE);
    $stmt_i = $conn->prepare("INSERT INTO mi_billetera (id, datos) VALUES (3, ?)");
    $stmt_i->bind_param("s", $json_default);
    $stmt_i->execute();
    $stmt_i->close();
    $data = $default_data;
} else {
    $row = $result->fetch_assoc();
    $raw_json = $row['datos'];
    $correcciones = [
        'Tru00e1nsito' => 'Tránsito', 'DU00EDA' => 'Día', 'Du00eda' => 'Día', '\\u' => '',
        '🛑' => 'car', '📱' => 'smartphone', '🏍️' => 'bike', '🎓' => 'graduation-cap',
        '✈️' => 'plane', '🪖' => 'shield', '🎯' => 'target', '💸' => 'credit-card',
        'u2708ufe0f' => 'plane', 'ud83eude96' => 'shield', 'ud83duded1' => 'car',
        'ud83dudcf1' => 'smartphone', 'ud83cudfcdufe0f' => 'bike', 'ud83cudf93' => 'graduation-cap'
    ];
    $raw_json = str_replace(array_keys($correcciones), array_values($correcciones), $raw_json);
    $data = json_decode($raw_json, true);
    if (!is_array($data)) $data = $default_data;
    if (!isset($data['metas'])) $data['metas'] = $default_data['metas'];
    if (!isset($data['gastos_quincenales'])) $data['gastos_quincenales'] = $default_data['gastos_quincenales'];
    if (!isset($data['historial'])) $data['historial'] = [];
    if (!isset($data['gastos_marcados'])) $data['gastos_marcados'] = [];
}

function resolverDeudaDeGastoApi($nombre_gasto, $gasto_info, $deudas) {
    if (!empty($gasto_info['deuda_vinculada']) && isset($deudas[$gasto_info['deuda_vinculada']])) {
        return $gasto_info['deuda_vinculada'];
    }
    if (stripos($nombre_gasto, 'internet') !== false) return null;
    foreach ($deudas as $nombre_deuda => $info_d) {
        if (
            strcasecmp(trim($nombre_gasto), trim($nombre_deuda)) === 0 ||
            strcasecmp(trim($nombre_gasto), "Cuota " . trim($nombre_deuda)) === 0 ||
            stripos($nombre_gasto, $nombre_deuda) !== false
        ) {
            return $nombre_deuda;
        }
    }
    return null;
}

// PROCESAR ACCIONES POST EN LA API
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($req['accion'])) {
    $accion = $req['accion'];
    $fecha_actual = date('Y-m-d H:i');
    $guardar_billetera = true;

    if ($accion === 'toggle_gasto') {
        $gasto = $req['gasto'] ?? '';
        $gasto_info = $data['gastos_quincenales'][$gasto] ?? null;
        $valor_gasto = $gasto_info ? floatval($gasto_info['valor']) : 0;
        $deuda_asociada = $gasto_info ? resolverDeudaDeGastoApi($gasto, $gasto_info, $data['deudas']) : null;

        if (in_array($gasto, $data['gastos_marcados'])) {
            $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$gasto]));
            if ($deuda_asociada && isset($data['deudas'][$deuda_asociada]) && $valor_gasto > 0) {
                $max_total = floatval($data['deudas'][$deuda_asociada]['total']);
                $data['deudas'][$deuda_asociada]['pendiente'] = min($max_total, $data['deudas'][$deuda_asociada]['pendiente'] + $valor_gasto);
                foreach ($data['historial'] as $idx_h => $h_item) {
                    if (!empty($h_item['gasto_origen']) && $h_item['gasto_origen'] === $gasto) {
                        unset($data['historial'][$idx_h]);
                        $data['historial'] = array_values($data['historial']);
                        break;
                    }
                }
            }
        } else {
            $data['gastos_marcados'][] = $gasto;
            if ($deuda_asociada && isset($data['deudas'][$deuda_asociada]) && $valor_gasto > 0) {
                $data['deudas'][$deuda_asociada]['pendiente'] = max(0, $data['deudas'][$deuda_asociada]['pendiente'] - $valor_gasto);
                array_unshift($data['historial'], [
                    'fecha' => $fecha_actual,
                    'concepto' => "Abono a: $deuda_asociada",
                    'monto' => $valor_gasto,
                    'tipo' => 'pago',
                    'deuda_key' => $deuda_asociada,
                    'gasto_origen' => $gasto
                ]);
            }
        }
    } elseif ($accion === 'reset_quincena') {
        $data['gastos_marcados'] = [];
    } elseif ($accion === 'abonar_deuda') {
        $nombre_deuda = $req['deuda'] ?? '';
        $abono = floatval($req['monto'] ?? 0);
        if (isset($data['deudas'][$nombre_deuda]) && $abono > 0) {
            $data['deudas'][$nombre_deuda]['pendiente'] = max(0, $data['deudas'][$nombre_deuda]['pendiente'] - $abono);
            array_unshift($data['historial'], ['fecha' => $fecha_actual, 'concepto' => "Abono a: $nombre_deuda", 'monto' => $abono, 'tipo' => 'pago']);
        }
    } elseif ($accion === 'agregar_deuda') {
        $nombre = trim($req['nombre_deuda'] ?? '');
        $total = floatval($req['total_deuda'] ?? 0);
        $cuota = floatval($req['cuota_deuda'] ?? 0);
        $icono = trim($req['icono_deuda'] ?? 'credit-card');
        if ($nombre !== '' && $total > 0) {
            $data['deudas'][$nombre] = ['total' => $total, 'pendiente' => $total, 'cuota' => $cuota, 'icono' => $icono];
        }
    } elseif ($accion === 'editar_deuda') {
        $orig = trim($req['nombre_original'] ?? '');
        $nuevo = trim($req['nombre_deuda_nuevo'] ?? $orig);
        $total = floatval($req['total_deuda'] ?? 0);
        $pendiente = floatval($req['pendiente_deuda'] ?? 0);
        $cuota = floatval($req['cuota_deuda'] ?? 0);
        $icono = trim($req['icono_deuda'] ?? 'credit-card');
        if (isset($data['deudas'][$orig])) {
            $nuevas = [];
            foreach ($data['deudas'] as $k => $v) {
                if ($k === $orig) {
                    $nuevas[$nuevo] = ['total' => $total, 'pendiente' => $pendiente, 'cuota' => $cuota, 'icono' => $icono];
                } else {
                    $nuevas[$k] = $v;
                }
            }
            $data['deudas'] = $nuevas;
        }
    } elseif ($accion === 'eliminar_deuda') {
        $del = $req['deuda_eliminar'] ?? '';
        unset($data['deudas'][$del]);
    } elseif ($accion === 'abonar_ahorro') {
        $abono = floatval($req['monto'] ?? 0);
        if ($abono > 0) {
            $data['ahorro_corvanca'] += $abono;
            array_unshift($data['historial'], ['fecha' => $fecha_actual, 'concepto' => "Aporte Corvanca", 'monto' => $abono, 'tipo' => 'ahorro']);
        }
    } elseif ($accion === 'abonar_meta') {
        $meta = $req['meta'] ?? '';
        $abono = floatval($req['monto'] ?? 0);
        if (isset($data['metas'][$meta]) && $abono > 0) {
            $data['metas'][$meta]['actual'] += $abono;
            array_unshift($data['historial'], ['fecha' => $fecha_actual, 'concepto' => "Aporte Meta: $meta", 'monto' => $abono, 'tipo' => 'ahorro']);
        }
    } elseif ($accion === 'agregar_meta') {
        $nombre = trim($req['nombre_meta'] ?? '');
        $total = floatval($req['total_meta'] ?? 0);
        $icono = trim($req['icono_meta'] ?? 'target') ?: 'target';
        if ($nombre !== '' && $total > 0) {
            $data['metas'][$nombre] = ['total' => $total, 'actual' => 0, 'icono' => $icono];
        }
    } elseif ($accion === 'eliminar_meta') {
        $del = $req['meta_eliminar'] ?? '';
        unset($data['metas'][$del]);
    } elseif ($accion === 'agregar_gasto') {
        $nombre = trim($req['nombre_gasto'] ?? '');
        $valor = floatval($req['valor_gasto'] ?? 0);
        $label = trim($req['label_gasto'] ?? '');
        $deuda_vinc = trim($req['deuda_vinculada'] ?? '');
        if ($nombre !== '' && $valor > 0) {
            $ng = ['valor' => $valor, 'dias' => [], 'label' => $label];
            if ($deuda_vinc !== '') $ng['deuda_vinculada'] = $deuda_vinc;
            $data['gastos_quincenales'][$nombre] = $ng;
        }
    } elseif ($accion === 'eliminar_gasto') {
        $del = $req['gasto_eliminar'] ?? '';
        unset($data['gastos_quincenales'][$del]);
        $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$del]));
    } elseif ($accion === 'reversar_historial') {
        $index = intval($req['index'] ?? -1);
        if (isset($data['historial'][$index])) {
            $item = $data['historial'][$index];
            $monto = floatval($item['monto']);
            if ($item['tipo'] == 'pago') {
                $nombre_deuda = $item['deuda_key'] ?? str_replace("Abono a: ", "", $item['concepto']);
                if (isset($data['deudas'][$nombre_deuda])) {
                    $data['deudas'][$nombre_deuda]['pendiente'] += $monto;
                }
                if (!empty($item['gasto_origen'])) {
                    $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$item['gasto_origen']]));
                }
            } elseif ($item['tipo'] == 'ahorro') {
                if ($item['concepto'] == "Aporte Corvanca") {
                    $data['ahorro_corvanca'] -= $monto;
                } else {
                    $nombre_meta = str_replace("Aporte Meta: ", "", $item['concepto']);
                    if (isset($data['metas'][$nombre_meta])) {
                        $data['metas'][$nombre_meta]['actual'] -= $monto;
                    }
                }
            }
            unset($data['historial'][$index]);
            $data['historial'] = array_values($data['historial']);
        }
    } elseif ($accion === 'editar_sueldo') {
        $data['sueldo_base'] = floatval($req['nuevo_sueldo'] ?? $data['sueldo_base']);
        $data['bono_q1'] = floatval($req['nuevo_bono'] ?? $data['bono_q1']);
    } elseif ($accion === 'abonar_factura_nu') {
        $guardar_billetera = false;
        $monto_nu = floatval($req['monto'] ?? ($config['cuota_mes'] ?? 0));
        $cat_nu = trim($req['categoria'] ?? ($config['lineas_credito'][0]['id'] ?? 'dron'));
        $concepto_nu = trim($req['concepto'] ?? ("Abono Factura " . ($config['fecha_corte'] ?? 'Mes')));
        if ($monto_nu > 0) {
            $tipo_m = 'pago';
            $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
            $stmt->bind_param("sdss", $tipo_m, $monto_nu, $concepto_nu, $cat_nu);
            $stmt->execute();
            $stmt->close();

            $config['cuota_mes'] = max(0, (float)($config['cuota_mes'] ?? 0) - $monto_nu);
            if ($config['cuota_mes'] == 0 && isset($config['facturacion_items'])) {
                foreach ($config['facturacion_items'] as $k => $v) {
                    $config['facturacion_items'][$k]['pagado'] = true;
                }
            }
            if (!empty($req['avanzar_cuotas']) && isset($config['cuotas_dinamicas'])) {
                foreach ($config['cuotas_dinamicas'] as $k => $cd) {
                    if ($cd['act'] < $cd['tot']) {
                        $config['cuotas_dinamicas'][$k]['act']++;
                    }
                }
            }
            file_put_contents($archivo_config, json_encode($config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
        }
    } elseif ($accion === 'pagar_item_nu') {
        $guardar_billetera = false;
        $idx = intval($req['item_index'] ?? -1);
        if (isset($config['facturacion_items'][$idx]) && empty($config['facturacion_items'][$idx]['pagado'])) {
            $it = $config['facturacion_items'][$idx];
            $mto = floatval($it['monto'] ?? 0);
            $cat = $it['categoria'] ?? ($config['lineas_credito'][0]['id'] ?? 'dron');
            $config['facturacion_items'][$idx]['pagado'] = true;
            if ($mto > 0) {
                $concepto = "Pago Factura: " . $it['nombre'];
                $tipo_m = 'pago';
                $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
                $stmt->bind_param("sdss", $tipo_m, $mto, $concepto, $cat);
                $stmt->execute();
                $stmt->close();
                $config['cuota_mes'] = max(0, (float)($config['cuota_mes'] ?? 0) - $mto);
            }
            file_put_contents($archivo_config, json_encode($config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
        }
    }

    if ($guardar_billetera) {
        $data['historial'] = array_slice($data['historial'], 0, 30);
        $json_update = json_encode($data, JSON_UNESCAPED_UNICODE);
        $stmt_u = $conn->prepare("UPDATE mi_billetera SET datos = ? WHERE id = 3");
        $stmt_u->bind_param("s", $json_update);
        $stmt_u->execute();
        $stmt_u->close();
    }
}

// CALCULAR RESUMEN PARA LA APP MÓVIL NATIVA SWIFTUI
$sueldo_quincenal = $data['sueldo_base'] / 2;
$aux_transporte = $data['aux_transporte'];
$bono_q1 = $data['bono_q1'];
$otros_ingresos_mensual = 1000000;
$deducciones_nomina = ['Fondo de salud' => 50000, 'Fondo de pensión' => 50000, 'Parqueadero' => 41333, 'Ahorro Corvanca' => 75000];
$total_deducciones = array_sum($deducciones_nomina);

$neto_q2 = ($sueldo_quincenal + $aux_transporte) - $total_deducciones;
$neto_q1 = ($sueldo_quincenal + $aux_transporte + $bono_q1) - $total_deducciones;

$chart_ahorro = 0; $chart_deudas = 0; $chart_gastos_fijos = 0;
$gastos_enriquecidos = [];
$gastos_lista = [];
foreach ($data['gastos_quincenales'] as $nombre => $g) {
    $deuda_vinc = resolverDeudaDeGastoApi($nombre, $g, $data['deudas']);
    if (stripos($nombre, 'ahorro') !== false) $chart_ahorro += $g['valor'];
    elseif (stripos($nombre, 'deuda') !== false || $deuda_vinc !== null) $chart_deudas += $g['valor'];
    else $chart_gastos_fijos += $g['valor'];

    $g['deuda_detectada'] = $deuda_vinc;
    $g['pagado'] = in_array($nombre, $data['gastos_marcados']);
    $gastos_enriquecidos[$nombre] = $g;
    $gastos_lista[] = [
        'nombre' => (string)$nombre,
        'valor' => (float)$g['valor'],
        'label' => (string)($g['label'] ?? ''),
        'deuda_detectada' => $deuda_vinc,
        'pagado' => (bool)$g['pagado']
    ];
}
$total_gastos = $chart_ahorro + $chart_deudas + $chart_gastos_fijos;
$flujo_q1 = $neto_q1 - $total_gastos;
$flujo_q2 = $neto_q2 - $total_gastos;
$total_ingresos_mensual = $data['sueldo_base'] + ($aux_transporte * 2) + $bono_q1 + $otros_ingresos_mensual;

$total_deuda_pendiente = 0;
$deudas_lista = [];
foreach ($data['deudas'] as $nombre_d => $d) {
    $total_deuda_pendiente += $d['pendiente'];
    $deudas_lista[] = [
        'nombre' => (string)$nombre_d,
        'total' => (float)$d['total'],
        'pendiente' => (float)$d['pendiente'],
        'cuota' => (float)$d['cuota'],
        'icono' => (string)($d['icono'] ?? 'credit-card')
    ];
}

$metas_lista = [];
foreach ($data['metas'] as $nombre_m => $m) {
    $metas_lista[] = [
        'nombre' => (string)$nombre_m,
        'total' => (float)$m['total'],
        'actual' => (float)$m['actual'],
        'icono' => (string)($m['icono'] ?? 'target')
    ];
}

// Datos de Créditos Nu (index.php)
function obtenerTotalesApi($conn, $categoria = null) {
    $filtro = $categoria ? "AND LOWER(TRIM(categoria)) = LOWER(TRIM('" . $conn->real_escape_string($categoria) . "'))" : "";
    $deudas = $conn->query("SELECT SUM(monto) AS total FROM movimientos WHERE LOWER(TRIM(tipo)) IN ('deuda', 'interes', 'ajuste') $filtro")->fetch_assoc()['total'] ?? 0;
    $pagos = $conn->query("SELECT SUM(monto) AS total FROM movimientos WHERE LOWER(TRIM(tipo)) = 'pago' $filtro")->fetch_assoc()['total'] ?? 0;
    return ['deudas' => (float)$deudas, 'pagos' => (float)$pagos, 'saldo' => (float)$deudas - (float)$pagos];
}

$nu_global = obtenerTotalesApi($conn);
$nu_lineas = [];
foreach (($config['lineas_credito'] ?? []) as $lc) {
    $lc['stats'] = obtenerTotalesApi($conn, $lc['id']);
    $nu_lineas[] = $lc;
}
$nu_movs = [];
$q_mov = $conn->query("SELECT id, tipo, monto, concepto, categoria, fecha FROM movimientos WHERE LOWER(TRIM(tipo)) != 'ajuste' ORDER BY fecha DESC LIMIT 20");
if ($q_mov) {
    while ($m = $q_mov->fetch_assoc()) {
        $nu_movs[] = [
            'id' => (int)$m['id'],
            'tipo' => (string)$m['tipo'],
            'monto' => (float)$m['monto'],
            'concepto' => (string)$m['concepto'],
            'categoria' => (string)$m['categoria'],
            'fecha' => (string)$m['fecha']
        ];
    }
}

echo json_encode([
    'ok' => true,
    'finanzas' => [
        'sueldo_base' => (float)$data['sueldo_base'],
        'aux_transporte' => (float)$data['aux_transporte'],
        'bono_q1' => (float)$data['bono_q1'],
        'ahorro_corvanca' => (float)$data['ahorro_corvanca'],
        'total_ingresos_mensual' => (float)$total_ingresos_mensual,
        'total_deuda_pendiente' => (float)$total_deuda_pendiente,
        'neto_q1' => (float)$neto_q1,
        'neto_q2' => (float)$neto_q2,
        'flujo_q1' => (float)$flujo_q1,
        'flujo_q2' => (float)$flujo_q2,
        'total_gastos_quincena' => (float)$total_gastos,
        'deducciones_nomina' => (object)$deducciones_nomina,
        'gastos_quincenales' => (object)$gastos_enriquecidos,
        'gastos_lista' => $gastos_lista,
        'gastos_marcados' => array_values($data['gastos_marcados']),
        'deudas' => (object)$data['deudas'],
        'deudas_lista' => $deudas_lista,
        'metas' => (object)$data['metas'],
        'metas_lista' => $metas_lista,
        'historial' => array_values($data['historial'])
    ],
    'creditos_nu' => [
        'saldo_pendiente' => (float)$nu_global['saldo'],
        'fecha_corte' => (string)($config['fecha_corte'] ?? ''),
        'cuota_mes' => (float)($config['cuota_mes'] ?? 0),
        'lineas_credito' => $nu_lineas,
        'cuotas_dinamicas' => array_values($config['cuotas_dinamicas'] ?? []),
        'facturacion_items' => array_values($config['facturacion_items'] ?? []),
        'movimientos' => $nu_movs
    ]
], JSON_UNESCAPED_UNICODE);

<?php
session_start();
include 'conexion.php';

// Leer la configuración generada desde el panel admin
$archivo_config = 'config.json';
$config = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [
    'fecha_corte' => '18 DE OCTUBRE',
    'cuota_mes' => 372875,
    'cuota_adelanto' => 0,
    'items_mes' => "Dron nu\nReloj\nInteres\nPizza\nMcdonalds mc cafe",
    'items_adelanto' => "• Cuota programada correspondiente al adelanto de efectivo"
];

$pin_sistema = $config['pin_acceso'] ?? '1234';
$es_admin = !empty($_SESSION['auth_pin_ok']);

// MIGRACIÓN: Cuotas dinámicas
if (!isset($config['cuotas_dinamicas'])) {
    $config['cuotas_dinamicas'] = [
        ['nombre' => 'Dron', 'icono' => 'plane', 'act' => 7, 'tot' => 18],
        ['nombre' => 'reloj', 'icono' => 'watch', 'act' => 3, 'tot' => 18]
    ];
}

// MIGRACIÓN: Líneas de crédito dinámicas
if (!isset($config['lineas_credito']) || empty($config['lineas_credito'])) {
    $config['lineas_credito'] = [
        ['id' => 'dron', 'nombre' => 'Dron + Memoria', 'icono' => 'plane', 'color' => '#3B82F6', 'bg' => 'var(--bg-light-blue)'],
        ['id' => 'reloj', 'nombre' => 'Reloj', 'icono' => 'watch', 'color' => '#F2C10D', 'bg' => 'var(--bg-light-purple)']
    ];
}

// ACCIÓN RÁPIDA DESDE INDEX.PHP: PAGAR ÍTEM O FACTURA DEL MES (protegido con PIN si no tiene sesión admin)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['accion_factura_index'])) {
    $pin_ingresado = trim($_POST['pin_confirm'] ?? '');
    if ($es_admin || $pin_ingresado === (string)$pin_sistema) {
        $_SESSION['auth_pin_ok'] = true;
        $es_admin = true;
        $tipo_accion = $_POST['accion_factura_index'];

        if ($tipo_accion === 'pagar_item' && isset($_POST['item_idx'])) {
            $idx = (int)$_POST['item_idx'];
            if (isset($config['facturacion_items'][$idx]) && empty($config['facturacion_items'][$idx]['pagado'])) {
                $it = $config['facturacion_items'][$idx];
                $monto_it = (float)($it['monto'] ?? 0);
                $cat_it = $it['categoria'] ?? ($config['lineas_credito'][0]['id'] ?? 'dron');
                $config['facturacion_items'][$idx]['pagado'] = true;

                if ($monto_it > 0) {
                    $concepto = "Pago Factura: " . $it['nombre'];
                    $tipo_m = 'pago';
                    $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
                    $stmt->bind_param("sdss", $tipo_m, $monto_it, $concepto, $cat_it);
                    $stmt->execute();
                    $stmt->close();
                    $config['cuota_mes'] = max(0, (float)$config['cuota_mes'] - $monto_it);
                }
                file_put_contents($archivo_config, json_encode($config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
            }
        } elseif ($tipo_accion === 'pagar_mes_completo') {
            $cuota_actual = (float)($config['cuota_mes'] ?? 0);
            $monto_abono = isset($_POST['monto_abono_factura']) && (float)$_POST['monto_abono_factura'] > 0
                ? (float)$_POST['monto_abono_factura']
                : $cuota_actual;
            $cat_destino = $_POST['categoria_abono_factura'] ?? ($config['lineas_credito'][0]['id'] ?? 'dron');

            if ($monto_abono > 0) {
                $concepto = "Abono Factura (" . ($config['fecha_corte'] ?? 'Mes') . ")";
                $tipo_m = 'pago';
                $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
                $stmt->bind_param("sdss", $tipo_m, $monto_abono, $concepto, $cat_destino);
                $stmt->execute();
                $stmt->close();

                $config['cuota_mes'] = max(0, $cuota_actual - $monto_abono);
                if ($config['cuota_mes'] == 0 && isset($config['facturacion_items'])) {
                    foreach ($config['facturacion_items'] as $k => $v) {
                        $config['facturacion_items'][$k]['pagado'] = true;
                    }
                }
                if (!empty($_POST['avanzar_cuota_check']) && isset($config['cuotas_dinamicas'])) {
                    foreach ($config['cuotas_dinamicas'] as $k => $cd) {
                        if ($cd['act'] < $cd['tot'] && (stripos($cd['nombre'], $cat_destino) !== false || $config['cuota_mes'] == 0)) {
                            $config['cuotas_dinamicas'][$k]['act']++;
                        }
                    }
                }
                file_put_contents($archivo_config, json_encode($config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
            }
        }
    }
    header("Location: index.php#seccion-facturas");
    exit();
}

function obtenerTotales($conn, $categoria = null) {
    $filtro = $categoria ? "AND LOWER(TRIM(categoria)) = LOWER(TRIM('" . $conn->real_escape_string($categoria) . "'))" : "";
    $deudas = $conn->query("SELECT SUM(monto) AS total FROM movimientos WHERE LOWER(TRIM(tipo)) IN ('deuda', 'interes', 'ajuste') $filtro")->fetch_assoc()['total'] ?? 0;
    $pagos = $conn->query("SELECT SUM(monto) AS total FROM movimientos WHERE LOWER(TRIM(tipo)) = 'pago' $filtro")->fetch_assoc()['total'] ?? 0;
    return ['deudas' => (float)$deudas, 'pagos' => (float)$pagos, 'saldo' => (float)$deudas - (float)$pagos];
}

$global = obtenerTotales($conn);
$saldo_pendiente = $global['saldo'];

// Calcular totales dinámicos para cada línea de crédito configurada
$totales_lineas = [];
$mapa_lineas = [];
foreach ($config['lineas_credito'] as $linea) {
    $id_l = $linea['id'];
    $stats_l = obtenerTotales($conn, $id_l);
    $linea['stats'] = $stats_l;
    $totales_lineas[] = $linea;
    $mapa_lineas[$id_l] = $linea;
}

$adelanto = obtenerTotales($conn, 'adelanto');

$historial = $conn->query("SELECT * FROM movimientos WHERE LOWER(TRIM(tipo)) != 'ajuste' ORDER BY fecha DESC");

$cuota_estimada = $config['cuota_mes'] > 0 ? $config['cuota_mes'] : 350000;
$meses_restantes = ($cuota_estimada > 0 && $saldo_pendiente > 0) ? ceil($saldo_pendiente / $cuota_estimada) : 0;
$meses_espanol = ['Jan'=>'Ene', 'Feb'=>'Feb', 'Mar'=>'Mar', 'Apr'=>'Abr', 'May'=>'May', 'Jun'=>'Jun', 'Jul'=>'Jul', 'Aug'=>'Ago', 'Sep'=>'Sep', 'Oct'=>'Oct', 'Nov'=>'Nov', 'Dec'=>'Dic'];
$mes_ing = date('M', strtotime("+$meses_restantes months"));
$ano_ing = date('Y', strtotime("+$meses_restantes months"));
$fecha_libre = $meses_espanol[$mes_ing] . ' ' . $ano_ing;

// Validar cuentas completadas dinámicamente
$cuentas_completadas = 0;
foreach ($totales_lineas as $linea) {
    if ($linea['stats']['deudas'] > 0 && $linea['stats']['saldo'] <= 0) $cuentas_completadas++;
}

// ALGORITMO STREAK Y CHART.JS
$pagos_chart = array_fill(1, 12, 0); 
$pagos_q = $conn->query("SELECT fecha, monto FROM movimientos WHERE LOWER(TRIM(tipo)) = 'pago' ORDER BY fecha DESC");
$meses_pagados = [];
if($pagos_q) {
    while($p = $pagos_q->fetch_assoc()) {
        $mes_num = (int)date('m', strtotime($p['fecha']));
        $pagos_chart[$mes_num] += (float)$p['monto'];
        $meses_pagados[date('Y-m', strtotime($p['fecha']))] = true; 
    }
}
$streak = 0;
$mes_evaluar = strtotime(date('Y-m-01')); 
if (!isset($meses_pagados[date('Y-m', $mes_evaluar)])) $mes_evaluar = strtotime("-1 month", $mes_evaluar);
while(isset($meses_pagados[date('Y-m', $mes_evaluar)])) {
    $streak++;
    $mes_evaluar = strtotime("-1 month", $mes_evaluar);
}

// Construir las 3 burbujas principales de forma inteligente según las líneas reales
$burbuja_izq = $totales_lineas[0] ?? ['id' => 'dron', 'nombre' => 'Dron', 'icono' => 'plane', 'stats' => ['saldo' => 0]];
$burbuja_der = $totales_lineas[1] ?? ['id' => 'reloj', 'nombre' => 'Reloj', 'icono' => 'watch', 'stats' => ['saldo' => 0]];
if (count($totales_lineas) >= 3) {
    $burbuja_centro = $totales_lineas[2];
    $es_centro_factura = false;
} else {
    // Si hay 2 líneas (ej. Dron y Reloj), la burbuja central muestra la Cuota del Mes actual para máxima claridad
    $burbuja_centro = [
        'id' => 'factura',
        'nombre' => 'Cuota Mes',
        'icono' => 'receipt',
        'stats' => ['saldo' => (float)($config['cuota_mes'] ?? 0)]
    ];
    $es_centro_factura = true;
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="Cuentas Pro">
    <title>Panel de Cuentas Pro</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <script src="https://cdn.jsdelivr.net/npm/canvas-confetti@1.6.0/dist/confetti.browser.min.js"></script>
    
    <style>
        :root {
            --bg-body: #F8FAFC;
            --card-bg: #FFFFFF;
            --text-main: #1F2937;
            --text-muted: #6B7280;
            --border-light: #E2E8F0;
            --blue-gradient: linear-gradient(135deg, #7C98FF 0%, #4F46E5 100%);
            --btn-black: #111827;
            --btn-black-text: #FFFFFF;
            --bg-light-blue: #EFF6FF;
            --bg-light-green: #ECFDF5;
            --bg-light-purple: #F5F3FF;
            --card-shadow: 0 4px 15px rgba(0,0,0,0.02);
            --modal-overlay: rgba(0,0,0,0.5);
            --icon-stroke: #6B7280;
        }

        body.dark-mode {
            --bg-body: #000000;
            --card-bg: #0A0A0A;
            --text-main: #F9FAFB;
            --text-muted: #9CA3AF;
            --border-light: #1F2937;
            --btn-black: #F9FAFB;
            --btn-black-text: #000000;
            --bg-light-blue: #172554;
            --bg-light-green: #064E3B;
            --bg-light-purple: #2E1065;
            --card-shadow: 0 4px 25px rgba(255,255,255,0.02);
            --modal-overlay: rgba(255,255,255,0.1);
            --icon-stroke: #9CA3AF;
        }
        
        body.dark-mode .bubble-side { background: #111111; box-shadow: 0 4px 20px rgba(255,255,255,0.05); border: 1px solid #1F2937;}
        body.dark-mode .bubble-center { border-color: #000000; }
        body.dark-mode .fact-total { background: #172554; border:none;}
        body.dark-mode .fact-icon, body.dark-mode .tx-icon-cat { background: #111111; border-color: #1F2937;}
        body.dark-mode .tx-row, body.dark-mode .fact-item { border-bottom-color: #1F2937; }
        body.dark-mode .l-metric { border-color: #1F2937; background: #050505; }
        body.dark-mode .c-bar-bg, body.dark-mode .l-prog-bg { background: #1F2937; }
        body.dark-mode .nav-icon.active { background: #111111; border: 1px solid #1F2937; color: #818CF8;}

        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; scroll-behavior: smooth; }
        body { background-color: var(--bg-body); color: var(--text-main); display: flex; min-height: 100vh; overflow-x: hidden; transition: background-color 0.3s, color 0.3s;}

        .lucide { width: 100%; height: 100%; stroke-width: 2; }
        .icon-sm { width: 16px; height: 16px; display: inline-block; }

        /* SIDEBAR */
        .sidebar { width: 80px; background-color: transparent; display: flex; flex-direction: column; align-items: center; padding: 30px 0; position: fixed; height: 100vh; left:0; top:0; z-index: 100;}
        .logo-mark { width: 44px; height: 44px; background: #4F46E5; border-radius: 14px; margin-bottom: 40px; display:flex; align-items:center; justify-content:center; color: white; padding: 10px; box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);}
        .nav-icon { width: 48px; height: 48px; display: flex; align-items: center; justify-content: center; border-radius: 50%; margin-bottom: 12px; color: #64748B; cursor: pointer; transition: all 0.2s ease; text-decoration: none; padding: 12px;}
        .nav-icon:hover { color: #1E293B; background: rgba(0,0,0,0.03); }
        .nav-icon.active { background: #FFFFFF; color: #4F46E5; box-shadow: 0 4px 15px rgba(0,0,0,0.06); }
        
        .main-wrapper { flex: 1; padding: 30px 40px; margin-left: 80px; display: flex; flex-direction: column; }
        .top-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 30px; flex-wrap: wrap; gap:15px;}
        .grid-layout { display: grid; grid-template-columns: 2.2fr 1fr; gap: 30px; }
        @media (max-width: 1100px) { .grid-layout { grid-template-columns: 1fr; } }
        @media (max-width: 768px) {
            .sidebar { width: 100%; height: 64px; flex-direction: row; justify-content: space-around; padding: 0 12px; bottom: 0; top: auto; background: var(--card-bg); border-top: 1px solid var(--border-light); }
            .logo-mark { display: none; }
            .nav-icon { margin-bottom: 0; width: 42px; height: 42px; }
            .main-wrapper { margin-left: 0; padding: 20px 16px 90px 16px; }
            .bubbles-container { width: 100% !important; max-width: 340px; transform: scale(0.88); }
            .balance-header-title h1 { font-size: 36px !important; flex-wrap: wrap; }
        }
        .col-left, .col-right { display: flex; flex-direction: column; gap: 30px; }

        .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; margin-top: 10px;}
        .section-title { font-size: 14px; font-weight: 700; color: var(--text-main); text-transform: uppercase; letter-spacing: 0.5px; }
        .section-badge { background: var(--card-bg); border: 1px solid var(--border-light); padding: 4px 12px; border-radius: 16px; font-size: 11px; font-weight: 600; color: var(--text-main); box-shadow: var(--card-shadow);}

        /* BALANCE GIGANTE */
        .balance-header-title p { font-size: 13px; color: var(--text-muted); font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px; display:flex; align-items:center; gap:8px; flex-wrap:wrap;}
        .balance-header-title h1 { font-size: 52px; font-weight: 800; color: var(--text-main); letter-spacing: -1.5px; margin-top: 0; line-height: 1; display:flex; align-items:center; gap:15px;}
        .btn-simular { background: var(--bg-light-blue); color: #4F46E5; border: 1px solid rgba(79, 70, 229, 0.2); padding: 8px 16px; border-radius: 20px; font-size: 12px; font-weight: 700; cursor: pointer; transition: all 0.2s; display:inline-flex; align-items:center; gap:6px;}
        .btn-simular:hover { background: #4F46E5; color: white; }
        
        .theme-toggle { background: var(--card-bg); border: 1px solid var(--border-light); color: var(--text-main); border-radius: 50%; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; transition: 0.3s; padding: 10px;}
        .theme-toggle:hover { background: var(--border-light); }

        /* BUBBLES ANIMADAS */
        .hero-section { display: flex; flex-direction: column; align-items: center; justify-content: center; margin-bottom: 10px; }
        .bubbles-wrapper { padding: 30px 0 20px 0; display: flex; justify-content: center; width: 100%; }
        .bubbles-container { position: relative; width: 440px; height: 180px; display: flex; justify-content: center; align-items: center; }
        
        .bubble { border-radius: 50%; display: flex; flex-direction: column; justify-content: center; align-items: center; position: absolute; cursor: pointer; transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); text-align: center; padding: 10px;}
        .bubble:hover { z-index: 50 !important; transform: scale(1.15) !important; box-shadow: 0 25px 50px rgba(0,0,0,0.15) !important; }
        
        .bubble-center { width: 190px; height: 190px; background: var(--blue-gradient); color: white; z-index: 10; box-shadow: 0 15px 35px rgba(79, 70, 229, 0.4); border: 4px solid var(--bg-body); }
        .bubble-side { width: 155px; height: 155px; background: var(--card-bg); box-shadow: 0 4px 20px rgba(0,0,0,0.05); z-index: 1; border: 1px solid var(--border-light); }
        .bubble-left { left: 0; }
        .bubble-right { right: 0; }
        
        .b-val { font-size: 16px; font-weight: 800; letter-spacing: -0.5px; color: var(--text-main); }
        .bubble-center .b-val { font-size: 20px; color: white; }
        .b-label { font-size: 12px; font-weight: 600; margin-top: 4px; display:flex; align-items:center; gap:6px;}
        .bubble-side .b-label { color: var(--text-muted); }

        .hero-actions { display: flex; gap: 12px; margin-top: 15px; flex-wrap: wrap; justify-content: center;}
        .btn-action { border-radius: 12px; padding: 12px 20px; font-size: 13px; font-weight: 700; text-decoration: none; display: flex; align-items: center; gap: 8px; transition: transform 0.2s, box-shadow 0.2s; border:none; cursor:pointer;}
        .btn-action:hover { transform: translateY(-3px); box-shadow: 0 6px 15px rgba(0,0,0,0.15); }
        .btn-avisar { background: #10B981; color: white; box-shadow: 0 4px 10px rgba(16, 185, 129, 0.2); }
        .btn-pagar { background: var(--btn-black); color: var(--btn-black-text); box-shadow: 0 4px 10px rgba(0,0,0, 0.2); }
        .btn-reporte { background: var(--card-bg); color: var(--text-main); border: 1px solid var(--border-light); }

        .c-card { background: var(--card-bg); border: 1px solid var(--border-light); border-radius: 20px; padding: 24px; box-shadow: var(--card-shadow); }

        /* PROGRESO CUOTAS */
        .cuotas-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 16px; }
        .cuota-card { background: var(--card-bg); border-radius: 16px; padding: 18px; border: 1px solid var(--border-light); display: flex; flex-direction: column; gap: 10px;}
        .c-header { display: flex; justify-content: space-between; align-items: center; }
        .c-title { font-size: 13px; font-weight: 700; color: var(--text-main); display: flex; align-items: center; gap: 8px; }
        .c-frac { font-size: 14px; font-weight: 700; }
        .c-bar-bg { height: 4px; background: var(--border-light); border-radius: 2px; width: 100%; overflow: hidden; }
        .c-bar-fill { height: 100%; border-radius: 2px; }
        .c-status { font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; }

        /* LÍNEAS DE CRÉDITO */
        .lines-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
        .l-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; }
        .l-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; padding: 10px; }
        .l-title-box h4 { font-size: 15px; font-weight: 700; color: var(--text-main); }
        .l-title-box p { font-size: 11px; color: var(--text-muted); font-weight: 500; margin-top: 2px; text-transform: uppercase;}
        .l-badge { background: rgba(245, 158, 11, 0.1); color: #D97706; padding: 4px 12px; border-radius: 16px; font-size: 10px; font-weight: 700; }
        .l-metrics { display: flex; justify-content: space-between; margin-bottom: 24px; gap:8px;}
        .l-metric { display: flex; flex-direction: column; align-items: center; gap: 6px; border: 1px solid var(--border-light); padding:10px 0; border-radius:12px; flex:1;}
        .lm-label { font-size: 9px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.5px; }
        .lm-val { font-size: 14px; font-weight: 800; color: var(--text-main); }
        .l-prog-wrap { display: flex; align-items: center; gap: 12px; }
        .l-prog-bg { flex: 1; height: 5px; background: var(--border-light); border-radius: 2.5px; overflow: hidden; }
        .l-prog-fill { height: 100%; border-radius: 2.5px; }
        .l-prog-txt { font-size: 11px; font-weight: 700; color: var(--text-muted); }

        /* FACTURACIÓN DEL MES */
        .fact-card { background: var(--card-bg); border: 1px solid var(--border-light); border-radius: 16px; padding: 24px; box-shadow: var(--card-shadow); }
        .fact-list { margin-bottom: 20px; }
        .fact-item { display: flex; align-items: center; justify-content: space-between; gap: 14px; padding: 14px 0; border-bottom: 1px solid var(--border-light); }
        .fact-item-left { display: flex; align-items: center; gap: 14px; }
        .fact-icon { width: 34px; height: 34px; background: var(--bg-body); border-radius: 8px; display: flex; align-items: center; justify-content: center; color: var(--text-muted); padding: 8px; border: 1px solid var(--border-light);}
        .fact-text { font-size: 13px; font-weight: 600; color: var(--text-main); }
        .fact-cat-pill { font-size: 10px; font-weight: 700; padding: 2px 8px; border-radius: 10px; background: var(--bg-body); border: 1px solid var(--border-light); color: var(--text-muted); text-transform: uppercase; }
        
        .fact-total { background: var(--bg-light-blue); padding: 18px 24px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; }
        .ft-label { font-size: 13px; font-weight: 600; color: #4F46E5; }
        .ft-val { font-size: 22px; font-weight: 800; color: #4F46E5; }

        /* LIBERTAD FINANCIERA */
        .health-card { background: var(--blue-gradient); color: white; border-radius: 20px; padding: 24px; position: relative; overflow: hidden; display:flex; flex-direction:column; justify-content:center;}
        .health-card h3 { font-size: 13px; font-weight: 500; opacity: 0.9; margin-bottom: 8px;}
        .health-card .percentage { font-size: 32px; font-weight: 700; letter-spacing: -1px; line-height:1.1;}
        .health-card .sub { font-size: 12px; opacity: 0.8; margin-top:8px;}
        .health-card .icon-sync { position: absolute; top: 24px; right: 24px; width: 36px; height: 36px; background: rgba(255,255,255,0.15); border-radius: 50%; display: flex; align-items: center; justify-content: center; padding:8px;}

        /* TRANSACTIONS Y CHART.JS */
        .tx-header { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 20px; }
        .tx-header h3 { font-size: 15px; font-weight: 700; color: var(--text-main); }
        .filter-tabs { display: flex; gap: 8px; margin-bottom: 16px; overflow-x: auto; padding-bottom: 4px; }
        .filter-btn { background: var(--bg-body); border: none; color: var(--text-muted); padding: 8px 16px; border-radius: 20px; font-size: 11px; font-weight: 600; cursor: pointer; transition: 0.2s; white-space: nowrap; }
        .filter-btn:hover { background: var(--border-light); color: var(--text-main); }
        .filter-btn.active { background: var(--btn-black); color: var(--btn-black-text); }
        
        .chart-container { width: 100%; height: 200px; margin-bottom: 20px; padding-bottom:20px; border-bottom: 1px dashed var(--border-light);}

        .tx-list { max-height: 360px; overflow-y: auto; padding-right:5px;}
        .tx-row { display: flex; align-items: center; justify-content: space-between; padding: 14px 0; border-bottom: 1px solid var(--border-light); gap: 8px;}
        .tx-icon-cat { margin-right:12px; background:var(--bg-body); width:36px; height:36px; border-radius:8px; display:flex; align-items:center; justify-content:center; border:1px solid var(--border-light); padding: 8px; color: var(--text-muted); flex-shrink:0;}
        .tx-info { display:flex; align-items:center; overflow:hidden;}
        .tx-name { font-size: 12px; font-weight: 600; color: var(--text-main); text-transform: uppercase;}
        .tx-date { font-size: 10px; color: var(--text-muted); margin-top:4px; display:flex; align-items:center; gap:6px;}
        .tx-amount { font-size: 13px; font-weight: 700; text-align: right; white-space: nowrap;}
        .recibo-link { font-size: 10px; font-weight: 700; color: #10B981; background: rgba(16, 185, 129, 0.1); border: 1px solid rgba(16, 185, 129, 0.3); padding: 2px 7px; border-radius: 8px; text-decoration: none; transition: 0.2s; }
        .recibo-link:hover { background: #10B981; color: white; }

        /* ADELANTO */
        .adelanto-card { background: var(--card-bg); border-radius: 16px; padding: 24px; margin-top: 24px; border: 1px solid var(--border-light); }
        .ad-header { font-size: 14px; font-weight: 700; color: var(--text-main); text-transform: uppercase; margin-bottom: 16px; }
        .ad-list { margin-bottom: 24px; }
        .ad-item { display: flex; align-items: center; gap: 14px; padding: 16px 0; border-bottom: 1px solid var(--border-light); }
        .ad-icon { width: 32px; height: 32px; background: var(--bg-body); border-radius: 8px; display: flex; align-items: center; justify-content: center; color: var(--text-muted); border: 1px solid var(--border-light); }
        .ad-text { font-size: 13px; font-weight: 500; color: var(--text-main); }
        .ad-total { background: var(--bg-light-purple); padding: 18px 24px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; }
        .ad-total span { font-size: 13px; font-weight: 700; color: #8B5CF6; }
        .ad-total strong { font-size: 22px; font-weight: 800; color: #8B5CF6; }

        /* MODALES */
        .modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: var(--modal-overlay); z-index: 1000; justify-content: center; align-items: center; backdrop-filter: blur(4px); opacity: 0; transition: opacity 0.3s ease;}
        .modal-overlay.active { display: flex; opacity: 1; }
        .modal-content { background: var(--card-bg); padding: 30px; border-radius: 24px; width: 420px; max-width: 92%; box-shadow: 0 20px 50px rgba(0,0,0,0.2); transform: translateY(20px); transition: transform 0.3s ease; border: 1px solid var(--border-light);}
        .modal-overlay.active .modal-content { transform: translateY(0); }
        .modal-close { float: right; cursor: pointer; border:none; background:transparent; color: var(--text-muted); padding: 5px; width:28px; height:28px;}
        .modal-close:hover { color: var(--text-main); }
        
        .calc-input { width:100%; border:1px solid var(--border-light); background:var(--bg-body); padding:14px; border-radius:12px; font-size:15px; font-weight:600; color:var(--text-main); margin-bottom:12px; outline:none; transition:0.2s;}
        .calc-input:focus { border-color: #4F46E5; box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1); background:var(--card-bg);}
        .calc-result { background:var(--bg-light-blue); padding:14px; border-radius:12px; font-size:12px; color:#4F46E5; text-align:center; min-height:60px; display:flex; flex-direction:column; justify-content:center;}
        .calc-highlight { font-weight:800; display:block; margin-top:4px; font-size:14px;}
    </style>
</head>
<body>

    <?php if ($cuentas_completadas > 0): ?>
    <script>
        window.onload = function() {
            if (typeof confetti === 'function') {
                var duration = 3 * 1000; var end = Date.now() + duration;
                (function frame() {
                    confetti({ particleCount: 5, angle: 60, spread: 55, origin: { x: 0 }, colors: ['#4F46E5', '#10B981', '#3B82F6'] });
                    confetti({ particleCount: 5, angle: 120, spread: 55, origin: { x: 1 }, colors: ['#4F46E5', '#10B981', '#3B82F6'] });
                    if (Date.now() < end) requestAnimationFrame(frame);
                }());
            }
        };
    </script>
    <?php endif; ?>

    <!-- SIDEBAR -->
    <div class="sidebar" id="mainSidebar">
        <a href="#inicio" class="logo-mark" style="text-decoration:none;">
            <i data-lucide="zap"></i>
        </a>
        <a href="#inicio" class="nav-icon active" title="Inicio"><i data-lucide="layout-dashboard"></i></a>
        <a href="#seccion-creditos" class="nav-icon" title="Líneas de Crédito"><i data-lucide="wallet"></i></a>
        <a href="#seccion-facturas" class="nav-icon" title="Facturación del Período"><i data-lucide="credit-card"></i></a>
        <a href="#seccion-movimientos" class="nav-icon" title="Movimientos"><i data-lucide="pie-chart"></i></a>
        <a href="mis_finanzas.php" class="nav-icon" title="Mis Finanzas Personales"><i data-lucide="landmark"></i></a>
        <a href="admin.php" class="nav-icon" title="Administrar Panel"><i data-lucide="settings"></i></a>
    </div>

    <!-- MAIN CONTENT -->
    <div class="main-wrapper" id="inicio">
        
        <div class="top-header">
            <div class="balance-header-title">
                <p>Balance total pendiente <span style="background:#E2E8F0; padding:2px 8px; border-radius:10px; color:#4B5563; font-size:10px; font-weight:700; margin-left:8px;">CORTE: <?php echo htmlspecialchars($config['fecha_corte']); ?></span></p>
                <h1 id="saldo-base" data-saldo="<?php echo $saldo_pendiente; ?>">
                    $<?php echo number_format($saldo_pendiente, 0); ?>
                    <button class="btn-simular" onclick="openModal()"><i data-lucide="calculator" class="icon-sm"></i> Simular</button>
                </h1>
            </div>
            
            <div style="display:flex; gap:12px; align-items:center;">
                <?php if($streak > 0): ?>
                    <div style="background:#FEF3C7; color:#D97706; padding:8px 16px; border-radius:20px; font-size:13px; font-weight:700; display:flex; align-items:center; gap:6px;">
                        <i data-lucide="flame" class="icon-sm"></i> Racha: <?php echo $streak; ?> meses
                    </div>
                <?php endif; ?>
                <button class="theme-toggle" onclick="toggleTheme()" title="Cambiar Tema" id="theme-btn">
                    <i data-lucide="moon"></i>
                </button>
            </div>
        </div>

        <div class="grid-layout">
            
            <!-- COLUMNA IZQUIERDA -->
            <div class="col-left">
                
                <!-- BUBBLES DINÁMICAS (CORREGIDAS CON TUS LÍNEAS REALES) -->
                <div class="hero-section">
                    <div class="bubbles-wrapper">
                        <div class="bubbles-container">
                            <div class="bubble bubble-side bubble-left" onclick="irALinea('<?php echo htmlspecialchars($burbuja_izq['id']); ?>')">
                                <div class="b-val">$<?php echo number_format($burbuja_izq['stats']['saldo'], 0); ?></div>
                                <div class="b-label"><i data-lucide="<?php echo htmlspecialchars($burbuja_izq['icono']); ?>" class="icon-sm"></i> <?php echo htmlspecialchars($burbuja_izq['nombre']); ?></div>
                            </div>
                            <div class="bubble bubble-center" onclick="<?php echo $es_centro_factura ? "document.getElementById('seccion-facturas').scrollIntoView({behavior:'smooth'})" : "irALinea('".htmlspecialchars($burbuja_centro['id'])."')"; ?>">
                                <div class="b-val">$<?php echo number_format($burbuja_centro['stats']['saldo'], 0); ?></div>
                                <div class="b-label" style="color:white;"><i data-lucide="<?php echo htmlspecialchars($burbuja_centro['icono']); ?>" class="icon-sm"></i> <?php echo htmlspecialchars($burbuja_centro['nombre']); ?></div>
                            </div>
                            <div class="bubble bubble-side bubble-right" onclick="irALinea('<?php echo htmlspecialchars($burbuja_der['id']); ?>')">
                                <div class="b-val">$<?php echo number_format($burbuja_der['stats']['saldo'], 0); ?></div>
                                <div class="b-label"><i data-lucide="<?php echo htmlspecialchars($burbuja_der['icono']); ?>" class="icon-sm"></i> <?php echo htmlspecialchars($burbuja_der['nombre']); ?></div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="hero-actions">
                        <a href="https://wa.me/573000000000?text=¡Bro!%20Ya%20te%20transferí%20la%20cuota." target="_blank" class="btn-action btn-avisar">
                            <i data-lucide="message-circle" class="icon-sm"></i> Avisar
                        </a>
                        <a href="QR-Nu.pdf" target="_blank" class="btn-action btn-pagar">
                            <i data-lucide="smartphone-nfc" class="icon-sm"></i> Pagar con Nu
                        </a>
                        <button onclick="openPagoFacturaModal()" class="btn-action" style="background:#4F46E5; color:white;">
                            <i data-lucide="check-circle-2" class="icon-sm"></i> Abonar Factura
                        </button>
                        <button onclick="window.print()" class="btn-action btn-reporte">
                            <i data-lucide="download" class="icon-sm"></i> Reporte
                        </button>
                    </div>
                </div>

                <!-- PROGRESO CUOTAS -->
                <div>
                    <div class="section-header">
                        <h3 class="section-title">Progreso de Cuotas Diferidas</h3>
                        <span class="section-badge">Detalle</span>
                    </div>
                    <div class="cuotas-grid">
                        <?php 
                        if (isset($config['cuotas_dinamicas']) && is_array($config['cuotas_dinamicas'])) {
                            foreach ($config['cuotas_dinamicas'] as $c) {
                                $act = $c['act']; $tot = $c['tot'];
                                $pct = ($tot > 0) ? ($act / $tot) * 100 : 0;
                                $isDone = ($act == $tot && $tot > 0);
                                
                                $color = '#3B82F6'; 
                                if (strpos(strtolower($c['nombre']), 'cámara') !== false) $color = '#10B981';
                                if (strpos(strtolower($c['nombre']), 'reloj') !== false) $color = '#F59E0B';
                                if ($isDone) $color = '#10B981'; 
                                
                                $status = $isDone ? 'LIQUIDADO' : 'EN CURSO';
                                $statusColor = $isDone ? 'var(--text-main)' : 'var(--text-muted)';
                                
                                echo '
                                <div class="cuota-card">
                                    <div class="c-header">
                                        <div class="c-title"><i data-lucide="'.htmlspecialchars($c['icono']).'" class="icon-sm" style="color:'.$color.';"></i> '.htmlspecialchars($c['nombre']).'</div>
                                        <div class="c-frac" style="color:'.$color.';">'.$act.'/'.$tot.'</div>
                                    </div>
                                    <div class="c-bar-bg"><div class="c-bar-fill" style="width:'.$pct.'%; background:'.$color.';"></div></div>
                                    <div class="c-status" style="color:'.$statusColor.';">'.$status.'</div>
                                </div>';
                            }
                        }
                        ?>
                    </div>
                </div>

                <!-- LÍNEAS DE CRÉDITO -->
                <div id="seccion-creditos" style="scroll-margin-top: 40px;">
                    <div class="section-header">
                        <h3 class="section-title">Distribución por Líneas de Crédito</h3>
                    </div>
                    <div class="lines-grid">
                        <?php 
                        foreach ($totales_lineas as $linea) {
                            $stats = $linea['stats'];
                            $pct = ($stats['deudas'] > 0) ? min(100, ($stats['pagos'] / $stats['deudas']) * 100) : 0;
                            $color = $linea['color'];
                            $bg_color = isset($linea['bg']) ? $linea['bg'] : 'var(--bg-light-blue)';
                            $badge_txt = ($stats['deudas'] > 0 && $stats['saldo'] <= 0) ? 'PAZ Y SALVO' : 'ACTIVO';
                            $badge_style = ($stats['deudas'] > 0 && $stats['saldo'] <= 0)
                                ? 'background: rgba(16, 185, 129, 0.12); color: #10B981;'
                                : 'background: rgba(245, 158, 11, 0.1); color: #D97706;';
                            
                            echo '
                            <div class="c-card line-card">
                                <div class="l-header">
                                    <div style="display:flex; gap:12px; align-items:center;">
                                        <div class="l-icon" style="background:'.$bg_color.'; color:'.$color.';"><i data-lucide="'.htmlspecialchars($linea['icono']).'"></i></div>
                                        <div class="l-title-box">
                                            <h4>'.htmlspecialchars($linea['nombre']).'</h4>
                                            <p>Estado de cuenta</p>
                                        </div>
                                    </div>
                                    <div class="l-badge" style="'.$badge_style.'">'.$badge_txt.'</div>
                                </div>
                                <div class="l-metrics">
                                    <div class="l-metric"><div class="lm-label">ASIGNADO</div><div class="lm-val">$'.number_format($stats['deudas'], 0).'</div></div>
                                    <div class="l-metric"><div class="lm-label">ABONOS</div><div class="lm-val" style="color:#10B981;">$'.number_format($stats['pagos'], 0).'</div></div>
                                    <div class="l-metric"><div class="lm-label" style="color:'.$color.';">PENDIENTE</div><div class="lm-val" style="color:'.$color.';">$'.number_format($stats['saldo'], 0).'</div></div>
                                </div>
                                <div class="l-prog-wrap">
                                    <div class="l-prog-bg"><div class="l-prog-fill" style="width: '.$pct.'%; background:'.$color.';"></div></div>
                                    <div class="l-prog-txt">'.number_format($pct, 0).'%</div>
                                </div>
                            </div>';
                        }
                        ?>
                    </div>
                </div>

                <!-- FACTURACIÓN DEL PERÍODO (CON DESCUENTO AUTOMÁTICO DE DEUDA) -->
                <div class="fact-card" id="seccion-facturas" style="scroll-margin-top: 40px;">
                    <div class="section-header" style="margin-top:0;">
                        <h3 class="section-title" style="font-size:14px; color:var(--text-main);">
                            FACTURACIÓN DEL PERÍODO
                        </h3>
                        <div style="display:flex; gap:8px; align-items:center;">
                            <span class="section-badge">Diferidos</span>
                            <a href="admin.php?tab=tab-cfg" class="section-badge" style="text-decoration:none; color:#4F46E5; border-color:rgba(79,70,229,0.3);">Editar / Configurar</a>
                        </div>
                    </div>
                    
                    <div class="fact-list">
                        <?php 
                        $items_f = $config['facturacion_items'] ?? [];
                        if (!empty($items_f)) {
                            foreach ($items_f as $idx_it => $it) {
                                $nom_it = $it['nombre'] ?? '';
                                $mto_it = (float)($it['monto'] ?? 0);
                                $cat_it = $it['categoria'] ?? '';
                                $pag_it = !empty($it['pagado']);
                                $nombre_cat = isset($mapa_lineas[$cat_it]) ? $mapa_lineas[$cat_it]['nombre'] : $cat_it;
                                $icono_cat = isset($mapa_lineas[$cat_it]) ? $mapa_lineas[$cat_it]['icono'] : 'file-text';
                                
                                echo '<div class="fact-item" style="'.($pag_it ? 'opacity:0.55;' : '').'">
                                    <div class="fact-item-left">
                                        <div class="fact-icon"><i data-lucide="'.htmlspecialchars($icono_cat).'" class="icon-sm"></i></div>
                                        <div>
                                            <div class="fact-text" style="'.($pag_it ? 'text-decoration:line-through;' : '').'">'.htmlspecialchars($nom_it).'</div>
                                            '.($nombre_cat ? '<span class="fact-cat-pill">'.htmlspecialchars($nombre_cat).'</span>' : '').'
                                        </div>
                                    </div>
                                    <div style="display:flex; align-items:center; gap:10px;">
                                        '.($mto_it > 0 ? '<span style="font-size:13px; font-weight:800; color:var(--text-main);">$'.number_format($mto_it, 0).'</span>' : '').'
                                        '.($pag_it 
                                            ? '<span style="font-size:11px; font-weight:700; color:#10B981;">✔ Pagado</span>' 
                                            : ($mto_it > 0 ? '<button type="button" onclick="confirmarPagoItem('.$idx_it.', \''.htmlspecialchars(addslashes($nom_it)).'\', '.$mto_it.')" style="background:rgba(16,185,129,0.12); color:#10B981; border:1px solid rgba(16,185,129,0.3); padding:4px 10px; border-radius:8px; font-size:11px; font-weight:700; cursor:pointer;">Pagar</button>' : '')
                                        ).'
                                    </div>
                                </div>';
                            }
                        } else {
                            $lista_mes = explode("\n", trim($config['items_mes'] ?? ''));
                            foreach($lista_mes as $item) {
                                if(trim($item) != "") {
                                    echo '<div class="fact-item"><div class="fact-item-left"><div class="fact-icon"><i data-lucide="file-text" class="icon-sm"></i></div> <div class="fact-text">'.htmlspecialchars(trim($item)).'</div></div></div>';
                                }
                            }
                        }
                        ?>
                    </div>
                    
                    <div class="fact-total" style="<?php echo ($config['cuota_mes'] <= 0) ? 'background: var(--bg-light-green);' : ''; ?>">
                        <span class="ft-label" style="<?php echo ($config['cuota_mes'] <= 0) ? 'color: #10B981;' : ''; ?>">
                            Total Cierre Mensual <span style="color:#6B7280; font-weight:500;">(Pagar el <?php echo htmlspecialchars($config['fecha_corte']); ?>):</span>
                        </span>
                        <div style="display:flex; align-items:center; gap:14px;">
                            <span class="ft-val" style="<?php echo ($config['cuota_mes'] <= 0) ? 'color: #10B981;' : ''; ?>">
                                <?php echo ($config['cuota_mes'] <= 0) ? '¡AL DÍA! ($0)' : '$' . number_format($config['cuota_mes'], 0); ?>
                            </span>
                            <?php if ($config['cuota_mes'] > 0): ?>
                                <button type="button" onclick="openPagoFacturaModal()" style="background:#4F46E5; color:white; border:none; padding:10px 16px; border-radius:10px; font-size:12px; font-weight:700; cursor:pointer; display:inline-flex; align-items:center; gap:6px;">
                                    <i data-lucide="check" class="icon-sm"></i> Abonar / Pagar
                                </button>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>

            </div>

            <!-- COLUMNA DERECHA -->
            <div class="col-right">
                
                <!-- LIBERTAD FINANCIERA -->
                <div class="health-card">
                    <div class="icon-sync"><i data-lucide="rocket"></i></div>
                    <h3>Libertad Financiera</h3>
                    
                    <?php if ($saldo_pendiente > 0): ?>
                        <div class="percentage"><?php echo $fecha_libre; ?></div>
                        <div class="sub">Faltan ~<?php echo $meses_restantes; ?> pagos base</div>
                    <?php else: ?>
                        <div class="percentage">100%</div>
                        <div class="sub">¡Cuenta liquidada! 🎉</div>
                    <?php endif; ?>
                    
                    <svg width="100%" height="60" viewBox="0 0 200 60" style="margin-top:10px; overflow:visible;">
                        <path d="M 0 50 Q 50 20, 100 40 T 170 20 T 200 30" fill="none" stroke="rgba(255,255,255,0.6)" stroke-width="2"/>
                        <circle cx="120" cy="30" r="4" fill="white"/>
                        <circle cx="170" cy="20" r="4" fill="white"/>
                    </svg>
                </div>

                <!-- TRANSACTIONS + CHART -->
                <div class="c-card tx-card" id="seccion-movimientos" style="scroll-margin-top: 40px;">
                    <div class="tx-header">
                        <h3>Movimientos</h3>
                    </div>

                    <div class="filter-tabs">
                        <button class="filter-btn active" id="btn-filtro-todas" onclick="filtrarTabla('todas', this)">Todo</button>
                        <?php foreach ($config['lineas_credito'] as $l): ?>
                            <button class="filter-btn" id="btn-filtro-<?php echo htmlspecialchars($l['id']); ?>" onclick="filtrarTabla('<?php echo htmlspecialchars($l['id']); ?>', this)">
                                <i data-lucide="<?php echo htmlspecialchars($l['icono']); ?>" class="icon-sm" style="vertical-align:middle; margin-right:4px;"></i> <?php echo htmlspecialchars($l['nombre']); ?>
                            </button>
                        <?php endforeach; ?>
                    </div>

                    <!-- CHART.JS CONTENEDOR -->
                    <div class="chart-container">
                        <canvas id="pagosChart"></canvas>
                    </div>

                    <!-- LISTA DE MOVIMIENTOS CON ENLACE A RECIBO.PHP -->
                    <div class="tx-list">
                        <?php if ($historial && $historial->num_rows > 0): ?>
                            <?php while($row = $historial->fetch_assoc()): 
                                $cat = strtolower(trim($row['categoria']));
                                $tipo = strtolower(trim($row['tipo']));
                                $monto = (float)$row['monto'];
                                
                                $icono_tx = 'circle';
                                foreach($config['lineas_credito'] as $lc) {
                                    if($lc['id'] == $cat) { $icono_tx = $lc['icono']; break; }
                                }
                                
                                $signo = ($tipo == 'deuda' || $tipo == 'interes' || ($tipo == 'ajuste' && $monto > 0)) ? '-' : '+'; 
                                $colorMonto = '#10B981'; 
                                if ($signo == '-') $colorMonto = 'var(--text-main)';
                            ?>
                                <div class="tx-row" data-cat="<?php echo htmlspecialchars($cat); ?>">
                                    <div class="tx-info">
                                        <div class="tx-icon-cat"><i data-lucide="<?php echo htmlspecialchars($icono_tx); ?>" class="icon-sm"></i></div>
                                        <div>
                                            <div class="tx-name" title="<?php echo htmlspecialchars($row['concepto']); ?>"><?php echo htmlspecialchars($row['concepto']); ?></div>
                                            <div class="tx-date">
                                                <span><?php echo date('d M Y', strtotime($row['fecha'])); ?></span>
                                                <?php if ($tipo === 'pago'): ?>
                                                    <a href="recibo.php?id=<?php echo (int)$row['id']; ?>" target="_blank" class="recibo-link" title="Descargar o imprimir comprobante de pago">🧾 Recibo</a>
                                                <?php endif; ?>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="tx-amount" style="color: <?php echo $colorMonto; ?>;">
                                        <?php echo $signo; ?>$<?php echo number_format(abs($monto), 0); ?>
                                    </div>
                                </div>
                            <?php endwhile; ?>
                            <div id="empty-row" style="display:none; text-align:center; padding:20px; color:var(--text-muted); font-size:12px;">No hay movimientos en esta línea.</div>
                        <?php else: ?>
                            <div style="text-align:center; padding:20px; color:var(--text-muted); font-size:12px;">No se registran transacciones.</div>
                        <?php endif; ?>
                    </div>
                </div>

               <!-- ADELANTO -->
                <?php if ($adelanto['saldo'] > 0 || ($config['cuota_adelanto'] ?? 0) > 0): ?>
                <div class="adelanto-card">
                    <div class="ad-header">
                        PAGO DE ADELANTO (DÍA 28)
                    </div>
                    <div class="ad-list">
                        <?php 
                            $lista_adelanto = explode("\n", trim($config['items_adelanto']));
                            foreach($lista_adelanto as $item) {
                                if(trim($item) != "") {
                                    echo '<div class="ad-item"><div class="ad-icon"><i data-lucide="file-text" class="icon-sm"></i></div> <div class="ad-text">'.htmlspecialchars(trim($item)).'</div></div>';
                                }
                            }
                        ?>
                    </div>
                    <div class="ad-total">
                        <span>A PAGAR:</span>
                        <strong>$<?php echo number_format($config['cuota_adelanto'], 0); ?></strong>
                    </div>
                </div>
                <?php endif; ?>

            </div>
        </div>
    </div>

    <!-- MODAL CALCULADORA -->
    <div class="modal-overlay" id="calcModal">
        <div class="modal-content">
            <button class="modal-close" onclick="closeModal()"><i data-lucide="x"></i></button>
            <h4 style="font-size: 18px; font-weight: 700; margin-bottom: 8px; color: var(--text-main); display:flex; align-items:center; gap:8px;">
                <i data-lucide="calculator" class="icon-sm"></i> Simulador
            </h4>
            <p style="font-size:12px; color:var(--text-muted); margin-bottom:20px; line-height:1.5;">Calcula matemáticamente cómo un abono adelantado reduce tus meses pendientes de la deuda total.</p>
            
            <input type="number" id="calc-monto" class="calc-input" style="text-align:center;" placeholder="Ej: 200000">
            
            <div class="calc-result" id="calc-output">
                Ingresa un monto para ver el impacto en tu proyección.
            </div>
        </div>
    </div>

    <!-- MODAL ABONAR / PAGAR FACTURA DEL PERÍODO -->
    <div class="modal-overlay" id="pagoFacturaModal">
        <div class="modal-content">
            <button class="modal-close" onclick="closePagoFacturaModal()"><i data-lucide="x"></i></button>
            <h4 style="font-size: 18px; font-weight: 800; margin-bottom: 6px; color: var(--text-main);">
                Abonar / Pagar Factura del Mes
            </h4>
            <p style="font-size:12px; color:var(--text-muted); margin-bottom:18px; line-height:1.5;">
                Al confirmar, este monto se <b>restará automáticamente de la deuda general</b> y bajará el <b>Total Cierre Mensual</b>.
            </p>
            <form method="POST">
                <input type="hidden" name="accion_factura_index" id="accion-factura-tipo" value="pagar_mes_completo">
                <input type="hidden" name="item_idx" id="accion-item-idx" value="">

                <div id="bloque-pago-mes">
                    <label style="font-size:11px; font-weight:700; color:var(--text-muted); display:block; margin-bottom:6px;">MONTO A ABONAR ($)</label>
                    <input type="number" step="1" name="monto_abono_factura" id="input-monto-factura" class="calc-input" value="<?php echo (float)($config['cuota_mes'] ?? 0); ?>" required>

                    <label style="font-size:11px; font-weight:700; color:var(--text-muted); display:block; margin-bottom:6px;">LÍNEA DE CRÉDITO A DESCONTAR</label>
                    <select name="categoria_abono_factura" class="calc-input">
                        <?php foreach ($config['lineas_credito'] as $l): ?>
                            <option value="<?php echo htmlspecialchars($l['id']); ?>"><?php echo htmlspecialchars($l['nombre']); ?></option>
                        <?php endforeach; ?>
                    </select>

                    <label style="display:flex; align-items:center; gap:8px; font-size:12px; font-weight:600; color:var(--text-main); margin-bottom:14px; cursor:pointer;">
                        <input type="checkbox" name="avanzar_cuota_check" value="1" checked style="width:16px; height:16px; accent-color:#4F46E5;">
                        Avanzar +1 cuota en el progreso de diferidos
                    </label>
                </div>

                <div id="bloque-pago-item" style="display:none; margin-bottom:14px; padding:12px; border-radius:12px; background:var(--bg-light-blue); color:#4F46E5; font-size:13px; font-weight:700; text-align:center;">
                </div>

                <?php if (!$es_admin): ?>
                    <label style="font-size:11px; font-weight:700; color:var(--text-muted); display:block; margin-bottom:6px;">PIN DE CONFIRMACIÓN ADMIN</label>
                    <input type="password" name="pin_confirm" class="calc-input" placeholder="Ingresa tu PIN (ej. 1234)" inputmode="numeric" required>
                <?php endif; ?>

                <button type="submit" style="width:100%; background:#10B981; color:white; border:none; padding:14px; border-radius:12px; font-size:14px; font-weight:800; cursor:pointer;">
                    Confirmar Pago y Bajar Deuda
                </button>
            </form>
        </div>
    </div>

    <!-- SCRIPTS -->
    <script>
        lucide.createIcons();

        function irALinea(catId) {
            const seccion = document.getElementById('seccion-movimientos');
            if (seccion) seccion.scrollIntoView({ behavior: 'smooth' });
            const btn = document.getElementById('btn-filtro-' + catId);
            if (btn) filtrarTabla(catId, btn);
        }

        function openPagoFacturaModal() {
            document.getElementById('accion-factura-tipo').value = 'pagar_mes_completo';
            document.getElementById('bloque-pago-mes').style.display = 'block';
            document.getElementById('bloque-pago-item').style.display = 'none';
            document.getElementById('pagoFacturaModal').classList.add('active');
        }

        function confirmarPagoItem(idx, nombre, monto) {
            document.getElementById('accion-factura-tipo').value = 'pagar_item';
            document.getElementById('accion-item-idx').value = idx;
            document.getElementById('bloque-pago-mes').style.display = 'none';
            const box = document.getElementById('bloque-pago-item');
            box.style.display = 'block';
            box.innerHTML = `Pagar ítem: <b>${nombre}</b> por <b>$${monto.toLocaleString('es-CO')}</b>`;
            document.getElementById('pagoFacturaModal').classList.add('active');
        }

        function closePagoFacturaModal() {
            document.getElementById('pagoFacturaModal').classList.remove('active');
        }

        document.getElementById('pagoFacturaModal').addEventListener('click', function(e) {
            if (e.target === this) closePagoFacturaModal();
        });

        // NAVEGACIÓN SIDEBAR CON SCROLL SUAVE
        document.querySelectorAll('.sidebar .nav-icon').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                const href = this.getAttribute('href');
                if (href && href.startsWith('#')) {
                    e.preventDefault();
                    const targetId = href.substring(1);
                    const targetElement = document.getElementById(targetId);
                    
                    if (targetElement) {
                        window.scrollTo({
                            top: targetElement.offsetTop - 40,
                            behavior: 'smooth'
                        });
                    }
                    
                    document.querySelectorAll('.sidebar .nav-icon').forEach(i => i.classList.remove('active'));
                    this.classList.add('active');
                }
            });
        });

        // FILTROS
        function filtrarTabla(categoria, btn) {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            if (btn) btn.classList.add('active');
            const filas = document.querySelectorAll('.tx-row');
            let visibles = 0;
            filas.forEach(fila => {
                if (categoria === 'todas' || fila.getAttribute('data-cat') === categoria) {
                    fila.style.display = 'flex'; visibles++;
                } else { fila.style.display = 'none'; }
            });
            const emptyRow = document.getElementById('empty-row');
            if (emptyRow) emptyRow.style.display = visibles === 0 ? 'block' : 'none';
        }

        // DARK MODE TOGGLE (OLED)
        function toggleTheme() {
            document.body.classList.toggle('dark-mode');
            const isDark = document.body.classList.contains('dark-mode');
            localStorage.setItem('oledTheme', isDark ? 'yes' : 'no');
            
            const btnIcon = document.querySelector('#theme-btn i');
            if(isDark) {
                btnIcon.setAttribute('data-lucide', 'sun');
            } else {
                btnIcon.setAttribute('data-lucide', 'moon');
            }
            lucide.createIcons();
            
            actualizarGraficoTema(isDark);
        }
        
        if(localStorage.getItem('oledTheme') === 'yes') {
            document.body.classList.add('dark-mode');
            document.querySelector('#theme-btn i').setAttribute('data-lucide', 'sun');
            lucide.createIcons();
        }

        // MODAL LÓGICA
        function openModal() { document.getElementById('calcModal').classList.add('active'); }
        function closeModal() { document.getElementById('calcModal').classList.remove('active'); }
        document.getElementById('calcModal').addEventListener('click', function(e) {
            if (e.target === this) closeModal();
        });

        const calcInput = document.getElementById('calc-monto');
        if(calcInput) {
            const saldoBase = parseFloat(document.getElementById('saldo-base').getAttribute('data-saldo'));
            const cuotaPromedio = <?php echo ($config['cuota_mes'] > 0 ? $config['cuota_mes'] : 350000); ?>; 
            const outputBox = document.getElementById('calc-output');
            const mesesArreglo = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

            calcInput.addEventListener('input', function(e) {
                const pagoExtra = parseFloat(e.target.value) || 0;
                if (pagoExtra > 0) {
                    const nuevoSaldo = Math.max(0, saldoBase - pagoExtra);
                    const nuevosMeses = Math.ceil(nuevoSaldo / cuotaPromedio);
                    const fechaCalculo = new Date();
                    fechaCalculo.setMonth(fechaCalculo.getMonth() + nuevosMeses);
                    
                    if (nuevoSaldo === 0) {
                        outputBox.innerHTML = `Cubre el 100% de la deuda. <span class="calc-highlight">¡Cuenta liquidada hoy mismo! 🎉</span>`;
                    } else {
                        outputBox.innerHTML = `Nuevo saldo: $${nuevoSaldo.toLocaleString('es-CO')} <span class="calc-highlight">Nueva libertad: ${mesesArreglo[fechaCalculo.getMonth()]} ${fechaCalculo.getFullYear()}</span>`;
                    }
                } else {
                    outputBox.innerHTML = 'Ingresa un monto para ver el impacto en tu proyección.';
                }
            });
        }

        // CHART.JS (Historial de Pagos)
        let chartInstance = null;
        const ctx = document.getElementById('pagosChart').getContext('2d');
        const dataPagos = [<?php echo implode(',', array_values($pagos_chart)); ?>];
        const labelsMeses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

        const mesActual = new Date().getMonth(); 
        const datosUtiles = dataPagos.slice(0, mesActual + 1);
        const labelsUtiles = labelsMeses.slice(0, mesActual + 1);

        function initChart(isDark) {
            const textColor = isDark ? '#9CA3AF' : '#6B7280';
            const gridColor = isDark ? '#1F2937' : '#E5E7EB';
            
            if (chartInstance) chartInstance.destroy();

            chartInstance = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labelsUtiles,
                    datasets: [{
                        label: 'Pagos Realizados',
                        data: datosUtiles,
                        backgroundColor: '#4F46E5',
                        borderRadius: 6,
                        barThickness: 16
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: {
                            callbacks: {
                                label: function(context) { return '$' + context.raw.toLocaleString('es-CO'); }
                            }
                        }
                    },
                    scales: {
                        y: { 
                            beginAtZero: true, 
                            ticks: { color: textColor, font: {size: 10}, callback: function(value){ return '$'+(value/1000)+'k'; } },
                            grid: { color: gridColor, drawBorder: false }
                        },
                        x: { 
                            ticks: { color: textColor, font: {size: 11} },
                            grid: { display: false, drawBorder: false }
                        }
                    }
                }
            });
        }

        function actualizarGraficoTema(isDark) {
            initChart(isDark);
        }

        initChart(document.body.classList.contains('dark-mode'));
    </script>
</body>
</html>

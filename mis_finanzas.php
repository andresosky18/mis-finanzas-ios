<?php
session_start();
include 'conexion.php';

$archivo_config = 'config.json';
$config_global = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];
$pin_sistema = $config_global['pin_acceso'] ?? '1234';

// AUTENTICACIÓN POR PIN (EXCLUSIVO DE MIS FINANZAS)
$error_pin = '';
if (isset($_GET['logout'])) {
    unset($_SESSION['auth_finanzas_ok']);
    header("Location: mis_finanzas.php");
    exit();
}
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['login_pin'])) {
    if (trim($_POST['pin']) === (string)$pin_sistema) {
        $_SESSION['auth_finanzas_ok'] = true;
        header("Location: mis_finanzas.php");
        exit();
    } else {
        $error_pin = 'PIN incorrecto. Intenta nuevamente.';
    }
}

if (empty($_SESSION['auth_finanzas_ok'])):
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <title>Mis Finanzas - Acceso</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/lucide@latest"></script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', sans-serif; }
        body { background: #0A0A0A; color: #FAFAFA; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .login-card { background: #121215; border: 1px solid #27272A; border-radius: 28px; padding: 40px 32px; width: 100%; max-width: 380px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.5); }
        .logo-box { width: 56px; height: 56px; background: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%); border-radius: 18px; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; color: white; }
        h1 { font-size: 22px; font-weight: 800; margin-bottom: 8px; }
        p { font-size: 13px; color: #A1A1AA; margin-bottom: 24px; }
        .pin-input { width: 100%; background: #09090B; border: 1px solid #27272A; color: white; font-size: 24px; font-weight: 800; letter-spacing: 8px; text-align: center; padding: 14px; border-radius: 14px; outline: none; margin-bottom: 16px; }
        .pin-input:focus { border-color: #6366F1; box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.2); }
        .btn-enter { width: 100%; background: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%); color: white; border: none; padding: 14px; border-radius: 14px; font-size: 14px; font-weight: 700; cursor: pointer; }
        .err { color: #EF4444; font-size: 12px; font-weight: 600; margin-bottom: 12px; }
        .back-link { display: inline-block; margin-top: 20px; color: #71717A; font-size: 12px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="logo-box"><i data-lucide="wallet"></i></div>
        <h1>Mis Finanzas</h1>
        <p>Ingresa tu PIN de seguridad para acceder a tu billetera personal.</p>
        <?php if ($error_pin): ?><div class="err"><?php echo htmlspecialchars($error_pin); ?></div><?php endif; ?>
        <form method="POST">
            <input type="hidden" name="login_pin" value="1">
            <input type="password" name="pin" class="pin-input" placeholder="••••" inputmode="numeric" autofocus required>
            <button type="submit" class="btn-enter">Entrar a Mis Finanzas</button>
        </form>
    </div>
    <script>lucide.createIcons();</script>
</body>
</html>
<?php
exit();
endif;

// 1. CONEXIÓN A LA BASE DE DATOS (ID 3)
$conn->query("CREATE TABLE IF NOT EXISTS mi_billetera (id INT PRIMARY KEY, datos TEXT)");
$result = $conn->query("SELECT datos FROM mi_billetera WHERE id = 3");

$default_data = [
    'sueldo_base' => 2500000,
    'aux_transporte' => 124548,
    'bono_q1' => 160000,
    'ahorro_corvanca' => 900000,
    'deudas' => [
        'Tránsito' => ['total' => 7000000, 'pendiente' => 4000000, 'cuota' => 1000000],
        'Celular' => ['total' => 5000000, 'pendiente' => 4223405, 'cuota' => 133000, 'icono' => 'smartphone'],
        'Moto' => ['total' => 11500000, 'pendiente' => 8512043, 'cuota' => 453000],
        'Universidad' => ['total' => 1280338, 'pendiente' => 1055882, 'cuota' => 112228]
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
    $stmt_init = $conn->prepare("INSERT INTO mi_billetera (id, datos) VALUES (3, ?)");
    $stmt_init->bind_param("s", $json_default);
    $stmt_init->execute();
    $stmt_init->close();
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
    
    if (!isset($data['deudas']['Celular']) && !isset($data['deudas']['celular'])) {
        $data['deudas']['Celular'] = ['total' => 5000000, 'pendiente' => 4223405, 'cuota' => 133000, 'icono' => 'smartphone'];
    }
}

$iconos_deuda = ['Tránsito' => 'car', 'Celular' => 'smartphone', 'Moto' => 'bike', 'Universidad' => 'graduation-cap'];

// FUNCIÓN INTELIGENTE: Detecta si un gasto quincenal corresponde a una deuda activa
function resolverDeudaDeGasto($nombre_gasto, $gasto_info, $deudas) {
    if (!empty($gasto_info['deuda_vinculada']) && isset($deudas[$gasto_info['deuda_vinculada']])) {
        return $gasto_info['deuda_vinculada'];
    }
    // Evitar que "Internet y Celular" (plan de datos) descuente la deuda del equipo "Celular"
    if (stripos($nombre_gasto, 'internet') !== false) {
        return null;
    }
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

// 2. PROCESAR ACCIONES
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['accion'])) {
    $accion = $_POST['accion'];
    $fecha_actual = date('Y-m-d H:i');

    if ($accion == 'editar_sueldo') {
        $data['sueldo_base'] = floatval($_POST['nuevo_sueldo']);
        $data['bono_q1'] = floatval($_POST['nuevo_bono']);
    } 
    elseif ($accion == 'abonar_ahorro') {
        $abono = floatval($_POST['monto']);
        $data['ahorro_corvanca'] += $abono;
        array_unshift($data['historial'], ['fecha' => $fecha_actual, 'concepto' => "Aporte Corvanca", 'monto' => $abono, 'tipo' => 'ahorro']);
    }
    elseif ($accion == 'abonar_deuda') {
        $nombre_deuda = $_POST['deuda'];
        $abono = floatval($_POST['monto']);
        if (isset($data['deudas'][$nombre_deuda])) {
            $data['deudas'][$nombre_deuda]['pendiente'] = max(0, $data['deudas'][$nombre_deuda]['pendiente'] - $abono);
            array_unshift($data['historial'], ['fecha' => $fecha_actual, 'concepto' => "Abono a: $nombre_deuda", 'monto' => $abono, 'tipo' => 'pago']);
        }
    }
    elseif ($accion == 'reversar_historial') {
        $index = intval($_POST['index']);
        if (isset($data['historial'][$index])) {
            $item = $data['historial'][$index];
            $monto = floatval($item['monto']);
            if ($item['tipo'] == 'pago') {
                $nombre_deuda = $item['deuda_key'] ?? str_replace(["Abono a: ", "Pago Quincenal: "], "", $item['concepto']);
                if (isset($data['deudas'][$nombre_deuda])) {
                    $data['deudas'][$nombre_deuda]['pendiente'] += $monto;
                }
                if (!empty($item['gasto_origen'])) {
                    $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$item['gasto_origen']]));
                }
            } elseif ($item['tipo'] == 'ahorro') {
                if ($item['concepto'] == "Aporte Corvanca" || !empty($item['es_corvanca'])) {
                    $data['ahorro_corvanca'] -= $monto;
                    if (!empty($item['gasto_origen'])) {
                        $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$item['gasto_origen']]));
                    }
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
    }
    elseif ($accion == 'editar_deuda') {
        $nombre_original = trim($_POST['nombre_original']);
        $nombre_nuevo = trim($_POST['nombre_deuda_nuevo']);
        $total = floatval($_POST['total_deuda']);
        $pendiente = floatval($_POST['pendiente_deuda']);
        $cuota = floatval($_POST['cuota_deuda']);
        $icono = trim($_POST['icono_deuda']);
        
        if (isset($data['deudas'][$nombre_original])) {
            $nuevas_deudas = [];
            foreach ($data['deudas'] as $key => $val) {
                if ($key === $nombre_original) {
                    $nuevas_deudas[$nombre_nuevo] = [
                        'total' => $total,
                        'pendiente' => $pendiente,
                        'cuota' => $cuota,
                        'icono' => $icono
                    ];
                } else {
                    $nuevas_deudas[$key] = $val;
                }
            }
            $data['deudas'] = $nuevas_deudas;
        }
    }
    elseif ($accion == 'reordenar_deudas') {
        $nuevo_orden = json_decode($_POST['nuevo_orden'], true);
        if (is_array($nuevo_orden)) {
            $nuevas_deudas = [];
            foreach ($nuevo_orden as $nombre) {
                if (isset($data['deudas'][$nombre])) {
                    $nuevas_deudas[$nombre] = $data['deudas'][$nombre];
                }
            }
            foreach ($data['deudas'] as $nombre => $val) {
                if (!isset($nuevas_deudas[$nombre])) $nuevas_deudas[$nombre] = $val;
            }
            $data['deudas'] = $nuevas_deudas;
        }
    }
    elseif ($accion == 'agregar_deuda') {
        $nombre = trim($_POST['nombre_deuda']);
        $total = floatval($_POST['total_deuda']);
        $cuota = floatval($_POST['cuota_deuda']);
        $icono = trim($_POST['icono_deuda']); 
        
        if (!empty($nombre) && $total > 0) {
            $data['deudas'][$nombre] = ['total' => $total, 'pendiente' => $total, 'cuota' => $cuota, 'icono' => $icono];
        }
    }
    elseif ($accion == 'eliminar_deuda') {
        $deuda_eliminar = $_POST['deuda_eliminar'];
        unset($data['deudas'][$deuda_eliminar]);
    }
    // 🔥 MEJORA: AL MARCAR UN GASTO QUINCENAL DE DEUDA, DESCUENTA AUTOMÁTICAMENTE DE LA DEUDA
    elseif ($accion == 'toggle_gasto') {
        $gasto = $_POST['gasto'];
        $gasto_info = $data['gastos_quincenales'][$gasto] ?? null;
        $valor_gasto = $gasto_info ? floatval($gasto_info['valor']) : 0;
        $deuda_asociada = $gasto_info ? resolverDeudaDeGasto($gasto, $gasto_info, $data['deudas']) : null;

        if (in_array($gasto, $data['gastos_marcados'])) {
            // Desmarcar gasto -> Revertir descuento automático si existía
            $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$gasto]));
            if ($deuda_asociada && isset($data['deudas'][$deuda_asociada]) && $valor_gasto > 0) {
                $max_total = floatval($data['deudas'][$deuda_asociada]['total']);
                $data['deudas'][$deuda_asociada]['pendiente'] = min($max_total, $data['deudas'][$deuda_asociada]['pendiente'] + $valor_gasto);
                // Quitar del historial el registro automático de esta quincena
                foreach ($data['historial'] as $idx_h => $h_item) {
                    if (!empty($h_item['gasto_origen']) && $h_item['gasto_origen'] === $gasto) {
                        unset($data['historial'][$idx_h]);
                        $data['historial'] = array_values($data['historial']);
                        break;
                    }
                }
            }
        } else {
            // Marcar gasto como pagado -> Descontar automáticamente de la deuda vinculada
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
    }
    elseif ($accion == 'reset_quincena') {
        $data['gastos_marcados'] = [];
    }
    elseif ($accion == 'agregar_gasto') {
        $nombre = trim($_POST['nombre_gasto']);
        $valor = floatval($_POST['valor_gasto']);
        $label = trim($_POST['label_gasto']);
        $deuda_vinc = trim($_POST['deuda_vinculada'] ?? '');
        if (!empty($nombre) && $valor > 0) {
            $nuevo_g = ['valor' => $valor, 'dias' => [], 'label' => $label];
            if ($deuda_vinc !== '') $nuevo_g['deuda_vinculada'] = $deuda_vinc;
            $data['gastos_quincenales'][$nombre] = $nuevo_g;
        }
    }
    elseif ($accion == 'eliminar_gasto') {
        $gasto_eliminar = $_POST['gasto_eliminar'];
        unset($data['gastos_quincenales'][$gasto_eliminar]);
        $data['gastos_marcados'] = array_values(array_diff($data['gastos_marcados'], [$gasto_eliminar]));
    }
    elseif ($accion == 'abonar_meta') {
        $nombre_meta = $_POST['meta'];
        $abono = floatval($_POST['monto']);
        if (isset($data['metas'][$nombre_meta])) {
            $data['metas'][$nombre_meta]['actual'] += $abono;
            array_unshift($data['historial'], ['fecha' => $fecha_actual, 'concepto' => "Aporte Meta: $nombre_meta", 'monto' => $abono, 'tipo' => 'ahorro']);
        }
    }
    elseif ($accion == 'agregar_meta') {
        $nombre = trim($_POST['nombre_meta']);
        $total = floatval($_POST['total_meta']);
        $icono = trim($_POST['icono_meta']) ?: 'target'; 
        if (!empty($nombre) && $total > 0) {
            $data['metas'][$nombre] = ['total' => $total, 'actual' => 0, 'icono' => $icono];
        }
    }
    elseif ($accion == 'eliminar_meta') {
        $meta_eliminar = $_POST['meta_eliminar'];
        unset($data['metas'][$meta_eliminar]);
    }
    elseif ($accion == 'registrar_gasto_tarjeta') {
        $comercio = trim($_POST['comercio'] ?? 'Compra con Tarjeta');
        $monto = floatval($_POST['monto'] ?? 0);
        $categoria = trim($_POST['categoria'] ?? 'Otros');
        $tarjeta = trim($_POST['tarjeta'] ?? 'Débito');
        $metodo = trim($_POST['metodo'] ?? 'Apple Pay');
        if ($monto > 0) {
            if (!isset($data['gastos_tarjeta']) || !is_array($data['gastos_tarjeta'])) {
                $data['gastos_tarjeta'] = [];
            }
            array_unshift($data['gastos_tarjeta'], [
                'id' => uniqid('card_'),
                'fecha' => $fecha_actual,
                'comercio' => $comercio,
                'monto' => $monto,
                'categoria' => $categoria,
                'tarjeta' => $tarjeta,
                'metodo' => $metodo,
                'esCredito' => (stripos($tarjeta, 'crédito') !== false || stripos($tarjeta, 'credito') !== false || stripos($tarjeta, 'nu') !== false)
            ]);
            array_unshift($data['historial'], [
                'fecha' => $fecha_actual,
                'concepto' => "[$categoria] $comercio • $tarjeta",
                'monto' => $monto,
                'tipo' => 'tarjeta'
            ]);
        }
    }
    elseif ($accion == 'eliminar_gasto_tarjeta') {
        $id_del = $_POST['id'] ?? '';
        if (!empty($id_del) && !empty($data['gastos_tarjeta'])) {
            $data['gastos_tarjeta'] = array_values(array_filter($data['gastos_tarjeta'], function($item) use ($id_del) {
                return ($item['id'] ?? '') !== $id_del;
            }));
        }
    }

    $data['historial'] = array_slice($data['historial'], 0, 30);
    $json_update = json_encode($data, JSON_UNESCAPED_UNICODE);
    $stmt_up = $conn->prepare("UPDATE mi_billetera SET datos = ? WHERE id = 3");
    $stmt_up->bind_param("s", $json_update);
    $stmt_up->execute();
    $stmt_up->close();
    header("Location: mis_finanzas.php");
    exit();
}

// 3. MATEMÁTICA EXACTA Y VARIABLES
$sueldo_quincenal = $data['sueldo_base'] / 2; 
$aux_transporte = $data['aux_transporte'];    
$bono_q1 = $data['bono_q1'];                  
$otros_ingresos_mensual = 1000000;            

$ingreso_bruto_q2 = $sueldo_quincenal + $aux_transporte;             
$ingreso_bruto_q1 = $ingreso_bruto_q2 + $bono_q1;                    

$deducciones_nomina = ['Fondo de salud' => 50000, 'Fondo de pensión' => 50000, 'Parqueadero' => 41333, 'Ahorro Corvanca' => 75000];
$total_deducciones = array_sum($deducciones_nomina);                 

$neto_q2 = $ingreso_bruto_q2 - $total_deducciones;                   
$neto_q1 = $ingreso_bruto_q1 - $total_deducciones;                   

$chart_ahorro = 0; $chart_deudas = 0; $chart_gastos_fijos = 0;
foreach($data['gastos_quincenales'] as $nombre => $g) {
    if (stripos($nombre, 'ahorro') !== false) { $chart_ahorro += $g['valor']; } 
    elseif (stripos($nombre, 'deuda') !== false || resolverDeudaDeGasto($nombre, $g, $data['deudas']) !== null) { $chart_deudas += $g['valor']; } 
    else { $chart_gastos_fijos += $g['valor']; }
}
$total_gastos = $chart_ahorro + $chart_deudas + $chart_gastos_fijos;

$flujo_q1 = $neto_q1 - $total_gastos;                                
$flujo_q2 = $neto_q2 - $total_gastos;                                

$total_ingresos_mensual = $data['sueldo_base'] + ($aux_transporte * 2) + $bono_q1 + $otros_ingresos_mensual;
$total_deuda_pendiente = 0;
foreach($data['deudas'] as $d) { $total_deuda_pendiente += $d['pendiente']; }

$dia_hoy = (int)date('j');
$alertas_activas = [];
foreach($data['gastos_quincenales'] as $nombre => $g) {
    if (!in_array($nombre, $data['gastos_marcados'])) {
        foreach(($g['dias'] ?? []) as $dia_pago) {
            $diff = $dia_pago - $dia_hoy;
            if ($diff >= -2 && $diff <= 3) {
                $alertas_activas[] = $nombre;
                break;
            }
        }
    }
}

$metas_completadas = 0;
foreach($data['metas'] as $m) {
    if ($m['total'] > 0 && $m['actual'] >= $m['total']) { $metas_completadas++; }
}

$meses_espanol = ['Jan'=>'Ene', 'Feb'=>'Feb', 'Mar'=>'Mar', 'Apr'=>'Abr', 'May'=>'May', 'Jun'=>'Jun', 'Jul'=>'Jul', 'Aug'=>'Ago', 'Sep'=>'Sep', 'Oct'=>'Oct', 'Nov'=>'Nov', 'Dec'=>'Dic'];
$mostrar_alerta_transito = (date('Y-m') >= '2026-11');
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="Mis Finanzas">
    <title>Mis Finanzas | SaaS Dashboard</title>
    
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/lucide@latest"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sortablejs@latest/Sortable.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/canvas-confetti@1.6.0/dist/confetti.browser.min.js"></script>

    <style>
        :root {
            --bg-body: #F4F5F7; --card-bg: #FFFFFF; --text-main: #1F2937; --text-muted: #6B7280;
            --border-light: #E5E7EB; --blue-gradient: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%);
            --btn-black: #111827; --btn-black-text: #FFFFFF; --bg-light-blue: #EFF6FF; --bg-light-green: #ECFDF5;
            --bg-light-purple: #F5F3FF; --card-shadow: 0 10px 25px rgba(0,0,0,0.03); --danger: #EF4444; --success: #10B981;
        }

        body.dark-mode {
            --bg-body: #0A0A0A; --card-bg: #121212; --text-main: #F9FAFB; --text-muted: #9CA3AF;
            --border-light: #27272A; --btn-black: #F9FAFB; --btn-black-text: #000000;
            --bg-light-blue: #172554; --bg-light-green: #064E3B; --bg-light-purple: #2E1065;
            --card-shadow: 0 10px 30px rgba(0,0,0,0.4);
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Inter', sans-serif; background-color: var(--bg-body); color: var(--text-main); line-height: 1.5; min-height: 100vh; transition: background-color 0.3s, color 0.3s; }

        .top-navbar { background-color: var(--card-bg); border-bottom: 1px solid var(--border-light); position: sticky; top: 0; z-index: 100; padding-top: env(safe-area-inset-top); }
        .nav-container { max-width: 1200px; margin: 0 auto; padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; }
        .nav-logo { display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 18px; letter-spacing: -0.5px; color: var(--text-main); cursor: pointer; text-decoration: none; }
        .nav-logo .icon-box { background: var(--blue-gradient); color: #fff; width: 32px; height: 32px; border-radius: 8px; display: flex; justify-content: center; align-items: center; }
        .nav-links { display: flex; gap: 24px; align-items: center; }
        .nav-links a { text-decoration: none; color: var(--text-muted); font-size: 14px; font-weight: 600; transition: color 0.2s; cursor: pointer; }
        .nav-links a:hover, .nav-links a.active { color: #4F46E5; }
        .nav-actions { display: flex; align-items: center; gap: 12px; }

        .main-content { max-width: 1200px; margin: 0 auto; padding: 40px 24px; }
        .header-top { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 40px; flex-wrap: wrap; gap: 14px; }
        .page-title { font-size: 28px; font-weight: 800; letter-spacing: -1px; margin-bottom: 4px; }

        .grid-layout { display: grid; gap: 24px; margin-bottom: 24px; }
        .grid-2-cols { grid-template-columns: 1.5fr 1fr; }
        .grid-3-cols { grid-template-columns: 1fr 1fr 1.2fr; }
        .grid-4-cols { grid-template-columns: repeat(4, 1fr); }

        .card { background-color: var(--card-bg); border-radius: 20px; border: 1px solid var(--border-light); box-shadow: var(--card-shadow); padding: 24px; transition: border-color 0.3s, box-shadow 0.3s; }
        .section-title { font-size: 11px; text-transform: uppercase; color: var(--text-muted); letter-spacing: 1px; font-weight: 800; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; }

        /* TOOLTIP GENERAL */
        .tooltip-container { position: relative; display: inline-flex; align-items: center; margin-left: 8px; cursor: help; }
        .tooltip-text { visibility: hidden; width: 230px; background-color: var(--text-main); color: var(--card-bg); text-align: center; border-radius: 8px; padding: 10px; font-size: 11px; line-height: 1.4; position: absolute; z-index: 10; bottom: 130%; left: 50%; margin-left: -115px; opacity: 0; transition: opacity 0.3s; text-transform: none; font-weight: 500; letter-spacing: normal; }
        .tooltip-container:hover .tooltip-text { visibility: visible; opacity: 1; }
        .tooltip-text::after { content: ""; position: absolute; top: 100%; left: 50%; margin-left: -5px; border-width: 5px; border-style: solid; border-color: var(--text-main) transparent transparent transparent; }

        .drag-handle { cursor: grab; color: #D1D5DB; margin-right: 12px; display:flex; align-items:center; transition: color 0.2s;}
        .drag-handle:hover { color: var(--text-muted); }
        .drag-handle:active { cursor: grabbing; }
        .sortable-ghost { opacity: 0.4; background-color: var(--bg-body); border-radius: 12px; }

        .btn { border-radius: 12px; font-weight: 600; font-size: 13px; padding: 10px 16px; border: none; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: all 0.2s; font-family: 'Inter', sans-serif; text-decoration: none; }
        .btn:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
        .btn-primary { background: var(--btn-black); color: var(--btn-black-text); }
        .btn-outline { background: transparent; border: 1px solid var(--border-light); color: var(--text-main); }
        .btn-icon-only { background: transparent; border: none; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; transition: color 0.2s;}
        .btn-icon-only:hover { color: var(--danger); }
        .nav-btn { background: transparent; border: none; cursor: pointer; color: var(--text-muted); display: flex; align-items: center; }

        .metric-box { padding: 20px; border-radius: 16px; border: 1px solid var(--border-light); background: var(--card-bg); display: flex; flex-direction: column; justify-content: center;}
        .metric-label { font-size: 12px; color: var(--text-muted); font-weight: 600; margin-bottom: 8px; }
        .metric-value { font-size: 26px; font-weight: 800; letter-spacing: -1px; }
        
        .data-list { list-style: none; }
        .data-row { display: flex; justify-content: space-between; align-items: center; padding: 14px 0; border-bottom: 1px solid var(--border-light); font-size: 14px; transition: opacity 0.2s; gap: 10px; }
        .data-row:last-child { border-bottom: none; padding-bottom: 0; }
        .row-left { display: flex; align-items: center; gap: 12px; font-weight: 600; flex: 1; }
        .row-right { display: flex; align-items: center; gap: 12px; font-weight: 700; font-variant-numeric: tabular-nums; }
        .badge { font-size: 10px; background: var(--bg-body); padding: 3px 8px; border-radius: 6px; color: var(--text-muted); text-transform: uppercase; font-weight: 700; border: 1px solid var(--border-light); margin-left: 6px; display: inline-block;}
        .badge-auto-deuda { font-size: 10px; background: rgba(99, 102, 241, 0.1); padding: 3px 8px; border-radius: 6px; color: #6366F1; font-weight: 700; border: 1px solid rgba(99, 102, 241, 0.25); margin-left: 6px; display: inline-block; }
        
        .scrollable-list { max-height: 320px; overflow-y: auto; padding-right: 8px; }
        .scrollable-list::-webkit-scrollbar { width: 6px; }
        .scrollable-list::-webkit-scrollbar-track { background: transparent; }
        .scrollable-list::-webkit-scrollbar-thumb { background: var(--border-light); border-radius: 10px; }
        .scrollable-list::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }

        .chk-btn { width: 22px; height: 22px; border-radius: 6px; border: 1px solid var(--text-muted); background: transparent; cursor: pointer; display: flex; align-items: center; justify-content: center; color: transparent; transition: all 0.2s; flex-shrink: 0;}
        .data-row.checked { opacity: 0.45; }
        .data-row.checked .row-left span.txt { text-decoration: line-through; font-weight: 400;}
        .data-row.checked .chk-btn { background: var(--success); border-color: var(--success); color: white; }

        .alert-blink { animation: pulse-border 2s infinite; background: rgba(239, 68, 68, 0.02); border-radius: 8px; padding: 0 12px; margin: 0 -12px; border-left: 3px solid var(--danger) !important;}
        @keyframes pulse-border { 0% { border-color: rgba(239, 68, 68, 0.4); } 50% { border-color: rgba(239, 68, 68, 1); } 100% { border-color: rgba(239, 68, 68, 0.4); } }
        .alert-box { background: var(--bg-light-blue); border: 1px solid var(--border-light); padding: 14px; border-radius: 12px; display: flex; gap: 12px; font-size: 13px; margin-bottom: 24px; align-items: center; font-weight: 500;}

        .progress-container { margin-top: 10px; }
        .progress-bg { background-color: var(--border-light); height: 6px; border-radius: 3px; overflow: hidden; }
        .progress-fill { height: 100%; border-radius: 3px; transition: width 0.5s ease; background: var(--text-main); }
        .progress-meta { font-size: 11px; color: var(--text-muted); margin-top: 8px; display: flex; justify-content: space-between; font-weight: 600;}

        .input-control { background-color: var(--bg-body); border: 1px solid transparent; border-radius: 10px; padding: 12px 16px; width: 100%; outline: none; color: var(--text-main); font-family: 'Inter', sans-serif; font-size: 14px; margin-bottom: 16px; transition: all 0.2s; }
        .input-control:focus { border-color: #4F46E5; box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1); }
        .form-label { font-size: 12px; font-weight: 700; color: var(--text-muted); margin-bottom: 6px; display: block; }
        .modal { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 200; justify-content: center; align-items: center; padding: 20px; backdrop-filter: blur(4px); }
        .modal-content { background: var(--card-bg); border: 1px solid var(--border-light); border-radius: 20px; padding: 32px; width: 100%; max-width: 400px; box-shadow: 0 20px 40px rgba(0,0,0,0.2); }
        .modal-title { font-size: 18px; font-weight: 800; margin-bottom: 24px; letter-spacing: -0.5px;}

        @media (max-width: 1024px) { .grid-2-cols { grid-template-columns: 1fr; } .grid-3-cols { grid-template-columns: 1fr 1fr; } .grid-4-cols { grid-template-columns: repeat(2, 1fr); } }
        @media (max-width: 768px) { .main-content { padding: 20px 16px 90px 16px; } .grid-3-cols, .grid-4-cols { grid-template-columns: 1fr; } .nav-links { display: none; } }
    </style>
</head>
<body id="top">

    <?php if ($metas_completadas > 0): ?>
    <script>window.onload = function() { if (typeof confetti === 'function') confetti({ particleCount: 100, spread: 70, origin: { y: 0.6 } }); };</script>
    <?php endif; ?>

    <nav class="top-navbar">
        <div class="nav-container">
            <a href="#" class="nav-logo" onclick="window.scrollTo(0,0)">
                <div class="icon-box"><i data-lucide="wallet" size="18"></i></div>Finance.
            </a>
            <div class="nav-links">
                <a class="active" onclick="window.scrollTo(0,0)">Dashboard</a>
                <a onclick="document.getElementById('seccion-deudas').scrollIntoView({behavior: 'smooth'})">Deudas</a>
                <a onclick="document.getElementById('seccion-metas').scrollIntoView({behavior: 'smooth'})">Metas</a>
            </div>
            <div class="nav-actions">
                <button class="nav-btn" onclick="toggleDarkMode()" title="Modo Oscuro"><i data-lucide="moon" size="20"></i></button>
                <a href="mis_finanzas.php?logout=1" class="nav-btn" title="Bloquear"><i data-lucide="lock" size="18"></i></a>
            </div>
        </div>
    </nav>

    <main class="main-content">
        <div class="header-top">
            <div>
                <h1 class="page-title">Hola, Andrés</h1>
                <span style="color: var(--text-muted); font-size: 14px;">Aquí está tu balance general actualizado.</span>
            </div>
            <button class="btn btn-primary" onclick="abrirModal('modal-sueldo')"><i data-lucide="settings-2" size="16"></i> Ajustes</button>
        </div>
        
        <div class="grid-layout grid-3-cols">
            <div class="card" style="background: var(--bg-light-green); border-color: transparent; display:flex; flex-direction:column; justify-content:center;">
                <span class="section-title" style="color: #065F46; margin-bottom:8px;">Ingresos Mes</span>
                <div class="metric-value" style="color: #065F46; font-size:32px;">$<?php echo number_format($total_ingresos_mensual, 0); ?></div>
                <span style="font-size:12px; color:#064E3B; opacity:0.8;">Sueldo + Auxilios + Extras</span>
            </div>
            <div class="card" style="background: var(--bg-body); display:flex; flex-direction:column; justify-content:center;">
                <span class="section-title" style="margin-bottom:8px;">Deuda Pendiente</span>
                <div class="metric-value" style="font-size:32px; color: var(--danger);">$<?php echo number_format($total_deuda_pendiente, 0); ?></div>
                <span style="font-size:12px; color:var(--text-muted);">Total Consolidado</span>
            </div>
            <div class="card" style="display:flex; align-items:center; gap: 20px;">
                <div style="flex:1;">
                    <span class="section-title" style="margin-bottom:8px;">Distribución</span>
                    <div style="font-size: 12px; font-weight:600; color: var(--text-muted); margin-bottom:4px;"><span style="color:#4F46E5;">■</span> Fijos</div>
                    <div style="font-size: 12px; font-weight:600; color: var(--text-muted); margin-bottom:4px;"><span style="color:#EF4444;">■</span> Deudas</div>
                    <div style="font-size: 12px; font-weight:600; color: var(--text-muted);"><span style="color:#10B981;">■</span> Ahorro</div>
                </div>
                <div style="width: 120px; height: 120px;"><canvas id="budgetChart"></canvas></div>
            </div>
        </div>

        <div class="section-title">Flujo de Caja Quincenal</div>
        <div class="grid-layout grid-4-cols">
            <div class="metric-box"><span class="metric-label">Ingreso Q1 (Día 10)</span><span class="metric-value">$<?php echo number_format($neto_q1, 0); ?></span></div>
            <div class="metric-box"><span class="metric-label">Ingreso Q2 (Día 30)</span><span class="metric-value">$<?php echo number_format($neto_q2, 0); ?></span></div>
            <div class="metric-box" style="border-color: <?php echo $flujo_q1 >= 0 ? 'var(--success)' : 'var(--danger)'; ?>;"><span class="metric-label">Libre Q1</span><span class="metric-value" style="color: <?php echo $flujo_q1 >= 0 ? 'var(--success)' : 'var(--danger)'; ?>;"><?php echo $flujo_q1 >= 0 ? '' : '-'; ?>$<?php echo number_format(abs($flujo_q1), 0); ?></span></div>
            <div class="metric-box" style="border-color: <?php echo $flujo_q2 >= 0 ? 'var(--success)' : 'var(--danger)'; ?>;"><span class="metric-label">Libre Q2</span><span class="metric-value" style="color: <?php echo $flujo_q2 >= 0 ? 'var(--success)' : 'var(--danger)'; ?>;"><?php echo $flujo_q2 >= 0 ? '' : '-'; ?>$<?php echo number_format(abs($flujo_q2), 0); ?></span></div>
        </div>

        <div class="grid-layout grid-2-cols">
            <!-- GASTOS -->
            <div class="card">
                <div class="section-title">
                    <div style="display: flex; align-items: center;">
                        Presupuesto Fijo
                        <div class="tooltip-container"><i data-lucide="info" size="14" style="color: #6366F1;"></i><span class="tooltip-text">Al marcar un gasto vinculado a una deuda (ej. Moto, Cuota Celular, Universidad), se descuenta automáticamente del saldo de esa deuda.</span></div>
                    </div>
                    <div style="display: flex; gap: 8px;">
                        <button class="btn btn-outline" style="padding: 6px 12px; font-size: 11px;" onclick="abrirModal('modal-gasto')"><i data-lucide="plus" size="14"></i> Añadir</button>
                        <form method="POST" style="margin: 0;"><input type="hidden" name="accion" value="reset_quincena"><button type="submit" class="btn btn-outline" style="padding: 6px 12px; font-size: 11px;"><i data-lucide="rotate-ccw" size="14"></i> Limpiar</button></form>
                    </div>
                </div>

                <?php if(count($alertas_activas) > 0): ?>
                <div class="alert-box" style="background: rgba(239, 68, 68, 0.05); border-color: rgba(239, 68, 68, 0.2); color: var(--danger);">
                    <i data-lucide="alert-triangle" size="20"></i><div>Tienes <strong><?php echo count($alertas_activas); ?> recibo(s)</strong> a punto de vencer.</div>
                </div>
                <?php endif; ?>

                <ul class="data-list">
                    <?php foreach($data['gastos_quincenales'] as $nombre => $g): 
                        $marcado = in_array($nombre, $data['gastos_marcados']);
                        $en_alerta = in_array($nombre, $alertas_activas);
                        $clase_extra = ($en_alerta && !$marcado) ? 'alert-blink' : '';
                        $deuda_auto = resolverDeudaDeGasto($nombre, $g, $data['deudas']);
                    ?>
                    <li class="data-row <?php echo $marcado ? 'checked' : ''; ?> <?php echo $clase_extra; ?>">
                        <div class="row-left">
                            <form method="POST" style="margin:0; display:flex;">
                                <input type="hidden" name="accion" value="toggle_gasto">
                                <input type="hidden" name="gasto" value="<?php echo htmlspecialchars($nombre); ?>">
                                <button type="submit" class="chk-btn" title="<?php echo $deuda_auto ? 'Marcar pagado y descontar de deuda ' . htmlspecialchars($deuda_auto) : 'Marcar como pagado'; ?>"><i data-lucide="check" size="14"></i></button>
                            </form>
                            <div>
                                <span class="txt"><?php echo htmlspecialchars($nombre); ?></span>
                                <?php if(!empty($g['label'])): ?><span class="badge"><?php echo htmlspecialchars($g['label']); ?></span><?php endif; ?>
                                <?php if($deuda_auto): ?><span class="badge-auto-deuda" title="Al marcar este gasto se resta automáticamente de la deuda <?php echo htmlspecialchars($deuda_auto); ?>">⚡ -Deuda <?php echo htmlspecialchars($deuda_auto); ?></span><?php endif; ?>
                            </div>
                        </div>
                        <div class="row-right">
                            <span style="color: var(--text-muted);">-$<?php echo number_format($g['valor'], 0); ?></span>
                            <form method="POST" style="margin:0; display:flex;"><input type="hidden" name="accion" value="eliminar_gasto"><input type="hidden" name="gasto_eliminar" value="<?php echo htmlspecialchars($nombre); ?>"><button type="submit" class="btn-icon-only"><i data-lucide="trash-2" size="16"></i></button></form>
                        </div>
                    </li>
                    <?php endforeach; ?>
                </ul>
            </div>

            <!-- DEDUCCIONES & HISTORIAL -->
            <div style="display: flex; flex-direction: column; gap: 24px;">
                <div class="card">
                    <div class="section-title">
                        <div style="display: flex; align-items: center;">Nómina & Descuentos<div class="tooltip-container"><i data-lucide="info" size="14" style="color: #6366F1;"></i><span class="tooltip-text">Estos son los descuentos automáticos que se hacen de tu nómina antes de que recibas el dinero en cuenta.</span></div></div>
                    </div>
                    <ul class="data-list">
                        <?php foreach($deducciones_nomina as $nombre => $valor): ?>
                        <li class="data-row" style="padding: 10px 0;"><div class="row-left"><?php echo htmlspecialchars($nombre); ?></div><div class="row-right" style="color: var(--danger);">-$<?php echo number_format($valor, 0); ?></div></li>
                        <?php endforeach; ?>
                    </ul>
                </div>

                <div class="card" style="flex-grow: 1; display: flex; flex-direction: column;">
                    <div class="section-title">
                        <div style="display: flex; align-items: center;">Actividad Reciente<div class="tooltip-container"><i data-lucide="info" size="14" style="color: #6366F1;"></i><span class="tooltip-text">Historial de tus últimos abonos. Si te equivocas de monto o de deuda, pulsa la flecha curva para deshacer el pago.</span></div></div>
                    </div>
                    <ul class="data-list scrollable-list">
                        <?php if (empty($data['historial'])): ?>
                            <div style="text-align: center; color: var(--text-muted); font-size: 13px; margin-top: 20px;">Sin abonos registrados.</div>
                        <?php else: ?>
                            <?php foreach($data['historial'] as $index => $h): ?>
                            <li class="data-row" style="padding: 12px 0;">
                                <div class="row-left" style="flex-direction: column; align-items: flex-start; gap: 4px;">
                                    <span><?php echo htmlspecialchars($h['concepto']); ?></span>
                                    <span style="font-size: 11px; color: var(--text-muted); font-weight: 500;"><i data-lucide="clock" size="10" style="display:inline; margin-right:4px;"></i><?php echo date('d M Y - H:i', strtotime($h['fecha'])); ?></span>
                                </div>
                                <div class="row-right">
                                    <span style="color: var(--success);">+$<?php echo number_format($h['monto'], 0); ?></span>
                                    <form method="POST" style="margin:0; display:flex;"><input type="hidden" name="accion" value="reversar_historial"><input type="hidden" name="index" value="<?php echo $index; ?>"><button type="submit" class="btn-icon-only" title="Deshacer Abono"><i data-lucide="undo-2" size="16"></i></button></form>
                                </div>
                            </li>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </ul>
                </div>
            </div>
        </div>

        <div class="grid-layout grid-2-cols">
            <!-- DEUDAS -->
            <div class="card" id="seccion-deudas">
                <div class="section-title">
                    <div style="display: flex; align-items: center;">
                        Auditoría de Deudas
                        <div class="tooltip-container"><i data-lucide="info" size="14" style="color: #6366F1;"></i><span class="tooltip-text">Arrastra desde los 6 puntos para ordenar. Usa el lápiz para editar saldos o nombres. 'Abonar' registra un pago.</span></div>
                    </div>
                    <button class="btn btn-outline" style="padding: 6px 12px; font-size: 11px;" onclick="abrirModal('modal-nueva-deuda')"><i data-lucide="plus" size="14"></i> Nueva</button>
                </div>
                
                <div id="contenedor-deudas">
                    <?php foreach($data['deudas'] as $nombre => $d): 
                        $pagado = $d['total'] - $d['pendiente'];
                        $porcentaje = ($d['total'] > 0) ? ($pagado / $d['total']) * 100 : 0;
                        $porcentaje = min(100, max(0, $porcentaje));
                        
                        $meses_restantes = ($d['cuota'] > 0 && $d['pendiente'] > 0) ? ceil($d['pendiente'] / $d['cuota']) : 0;
                        $mes_ing = date('M', strtotime("+$meses_restantes months"));
                        $ano_ing = date('Y', strtotime("+$meses_restantes months"));
                        $fecha_libre = $meses_restantes > 0 ? $meses_espanol[$mes_ing] . " " . $ano_ing : "Liquidada";

                        $icono_guardado = isset($d['icono']) && $d['icono'] !== '' ? $d['icono'] : '';
                        $icono_str = $icono_guardado ?: ($iconos_deuda[$nombre] ?? 'credit-card');
                        $es_emoji = mb_strlen($icono_str) <= 3 && !preg_match('/^[a-zA-Z0-9-]+$/', $icono_str);
                    ?>
                    <div class="deuda-item" data-id="<?php echo htmlspecialchars($nombre); ?>" style="margin-bottom: 24px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                            <div style="display: flex; align-items: center; gap: 10px; font-weight: 700; font-size: 14px;">
                                <div class="drag-handle"><i data-lucide="grip-vertical" size="18"></i></div>
                                
                                <?php if ($es_emoji): ?>
                                    <span style="font-size: 18px; line-height: 1;"><?php echo htmlspecialchars($icono_str); ?></span>
                                <?php else: ?>
                                    <i data-lucide="<?php echo htmlspecialchars($icono_str); ?>" size="18" style="color: var(--text-muted);"></i>
                                <?php endif; ?>
                                
                                <?php echo htmlspecialchars($nombre); ?>
                            </div>
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <span style="font-weight: 800; font-size: 15px; color: var(--danger);">$<?php echo number_format($d['pendiente'], 0); ?></span>
                                
                                <button class="btn btn-outline" onclick="abrirEditarDeuda('<?php echo htmlspecialchars($nombre); ?>', <?php echo $d['total']; ?>, <?php echo $d['pendiente']; ?>, <?php echo $d['cuota']; ?>, '<?php echo htmlspecialchars($icono_str); ?>')" style="padding: 4px; font-size: 11px;" title="Editar"><i data-lucide="pencil" size="14"></i></button>

                                <?php if($d['pendiente'] > 0): ?>
                                    <button class="btn btn-outline" onclick="abrirAbono('<?php echo htmlspecialchars($nombre); ?>')" style="padding: 4px 10px; font-size: 11px;">Abonar</button>
                                <?php endif; ?>
                                <form method="POST" style="margin:0; display:flex;">
                                    <input type="hidden" name="accion" value="eliminar_deuda">
                                    <input type="hidden" name="deuda_eliminar" value="<?php echo htmlspecialchars($nombre); ?>">
                                    <button type="submit" class="btn-icon-only"><i data-lucide="x" size="16"></i></button>
                                </form>
                            </div>
                        </div>
                        <div class="progress-container">
                            <div class="progress-bg"><div class="progress-fill" style="width: <?php echo $porcentaje; ?>%; background: <?php echo $d['pendiente'] <= 0 ? 'var(--success)' : 'var(--text-main)'; ?>;"></div></div>
                            <div class="progress-meta">
                                <span>ETA: <?php echo $fecha_libre; ?> (Cuota: $<?php echo number_format($d['cuota'], 0); ?>)</span>
                                <span><?php echo number_format($porcentaje, 1); ?>%</span>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
            </div>

            <!-- METAS & AHORRO -->
            <div style="display: flex; flex-direction: column; gap: 24px;" id="seccion-metas">
                <div class="card" style="background: var(--bg-light-purple); border-color: transparent;">
                    <div class="section-title" style="color: var(--text-main);">
                        <div style="display: flex; align-items: center;">Ahorro Base (Corvanca)<div class="tooltip-container"><i data-lucide="info" size="14" style="color: #6366F1;"></i><span class="tooltip-text">Este es tu fondo general de ahorros o de emergencia. Usa 'Abonar' para inyectarle capital.</span></div></div>
                    </div>
                    <div style="display: flex; justify-content: space-between; align-items: flex-end;">
                        <div style="font-size: 32px; font-weight: 800; color: var(--text-main);">$<?php echo number_format($data['ahorro_corvanca'], 0); ?></div>
                        <button class="btn btn-primary" style="background: #4F46E5; color: white;" onclick="abrirModal('modal-ahorro')">Abonar</button>
                    </div>
                </div>

                <div class="card" style="flex: 1;">
                    <div class="section-title">
                        <div style="display: flex; align-items: center;">Wishlist & Metas<div class="tooltip-container"><i data-lucide="info" size="14" style="color: #6366F1;"></i><span class="tooltip-text">Tus objetivos personales. Agrega fondos poco a poco hasta llenar la barra para completar tu meta.</span></div></div>
                        <button class="btn btn-outline" style="padding: 6px 12px; font-size: 11px;" onclick="abrirModal('modal-nueva-meta')"><i data-lucide="plus" size="14"></i> Nueva</button>
                    </div>
                    <?php foreach($data['metas'] as $nombre => $m): 
                        $pct_meta = ($m['total'] > 0) ? ($m['actual'] / $m['total']) * 100 : 0; $pct_meta = min(100, max(0, $pct_meta)); $completada = ($m['actual'] >= $m['total']);
                    ?>
                    <div style="margin-bottom: 24px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                            <div style="display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 14px;">
                                <i data-lucide="<?php echo htmlspecialchars($m['icono']); ?>" size="16" style="color: var(--text-muted);"></i>
                                <?php echo htmlspecialchars($nombre); ?>
                                <form method="POST" style="margin:0;"><input type="hidden" name="accion" value="eliminar_meta"><input type="hidden" name="meta_eliminar" value="<?php echo htmlspecialchars($nombre); ?>"><button type="submit" class="btn-icon-only" style="margin-left: 8px;"><i data-lucide="x" size="14"></i></button></form>
                            </div>
                            <?php if(!$completada): ?><button class="btn btn-outline" onclick="abrirAbonoMeta('<?php echo htmlspecialchars($nombre); ?>')" style="padding: 6px 12px; font-size: 11px; border-color: #8b5cf6; color: #8b5cf6;">Fondear</button><?php else: ?><span style="color: var(--success); font-size: 12px; font-weight: 800;">¡Logrado! 🎉</span><?php endif; ?>
                        </div>
                        <div class="progress-container" style="margin-top: 8px;">
                            <div class="progress-bg"><div class="progress-fill" style="width: <?php echo $pct_meta; ?>%; background: var(--blue-gradient);"></div></div>
                            <div class="progress-meta"><span>$<?php echo number_format($m['actual'], 0); ?></span><span>$<?php echo number_format($m['total'], 0); ?></span></div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>

                <?php if ($mostrar_alerta_transito): ?>
                <div class="alert-box" style="background: var(--bg-light-purple); border-color: transparent;">
                    <i data-lucide="party-popper" style="color: #6D28D9; width:24px; height:24px;"></i>
                    <div><strong style="color: #6D28D9;">¡Ingreso Liberado!</strong> Tienes $1,000,000 extra al mes. Inviértelo en tus Metas o adelanta cuotas.</div>
                </div>
                <?php endif; ?>
            </div>
        </div>
    </main>

    <form id="form-reordenar" method="POST" style="display: none;">
        <input type="hidden" name="accion" value="reordenar_deudas">
        <input type="hidden" name="nuevo_orden" id="input-nuevo-orden">
    </form>

    <!-- MODAL PARA EDITAR LA DEUDA -->
    <div id="modal-editar-deuda" class="modal">
        <div class="modal-content">
            <div class="modal-title">Editar Deuda</div>
            <form method="POST">
                <input type="hidden" name="accion" value="editar_deuda">
                <input type="hidden" name="nombre_original" id="edit-nombre-original">
                
                <label class="form-label">Nombre del crédito</label>
                <input type="text" name="nombre_deuda_nuevo" id="edit-nombre" class="input-control" required>
                
                <label class="form-label">Deuda Total Inicial ($)</label>
                <input type="number" name="total_deuda" id="edit-total" class="input-control" required>
                
                <label class="form-label">Saldo Pendiente Actual ($)</label>
                <input type="number" name="pendiente_deuda" id="edit-pendiente" class="input-control" required>

                <label class="form-label">Cuota Mensual ($)</label>
                <input type="number" name="cuota_deuda" id="edit-cuota" class="input-control" required>
                
                <label class="form-label">Ícono (Lucide o Emoji 📱)</label>
                <input type="text" name="icono_deuda" id="edit-icono" class="input-control">
                
                <div style="display: flex; gap: 12px; margin-top: 8px;">
                    <button type="submit" class="btn btn-primary" style="flex:1; justify-content:center;">Guardar Cambios</button>
                    <button type="button" class="btn btn-outline" onclick="cerrarModal('modal-editar-deuda')" style="flex:1; justify-content:center;">Cancelar</button>
                </div>
            </form>
        </div>
    </div>

    <!-- OTROS MODALES -->
    <div id="modal-gasto" class="modal">
        <div class="modal-content">
            <div class="modal-title">Añadir Gasto Fijo</div>
            <form method="POST">
                <input type="hidden" name="accion" value="agregar_gasto">
                <label class="form-label">Nombre del gasto</label>
                <input type="text" name="nombre_gasto" class="input-control" placeholder="Ej: Gimnasio o Cuota Moto" required>
                <label class="form-label">Valor ($)</label>
                <input type="number" name="valor_gasto" class="input-control" placeholder="Ej: 60000" required>
                <label class="form-label">Día de pago (Opcional)</label>
                <input type="text" name="label_gasto" class="input-control" placeholder="Ej: Día 15">
                <label class="form-label">Vincular a Deuda (Descuenta automático al marcar)</label>
                <select name="deuda_vinculada" class="input-control">
                    <option value="">Ninguna (Gasto normal)</option>
                    <?php foreach($data['deudas'] as $nom_d => $info_d): ?>
                        <option value="<?php echo htmlspecialchars($nom_d); ?>"><?php echo htmlspecialchars($nom_d); ?></option>
                    <?php endforeach; ?>
                </select>
                <div style="display: flex; gap: 12px; margin-top: 8px;">
                    <button type="submit" class="btn btn-primary" style="flex:1; justify-content:center;">Guardar</button>
                    <button type="button" class="btn btn-outline" onclick="cerrarModal('modal-gasto')" style="flex:1; justify-content:center;">Cancelar</button>
                </div>
            </form>
        </div>
    </div>
    <div id="modal-nueva-meta" class="modal"><div class="modal-content"><div class="modal-title">Nueva Meta de Ahorro</div><form method="POST"><input type="hidden" name="accion" value="agregar_meta"><label class="form-label">¿Qué quieres lograr?</label><input type="text" name="nombre_meta" class="input-control" placeholder="Ej: Viaje" required><label class="form-label">Costo Total ($)</label><input type="number" name="total_meta" class="input-control" placeholder="Ej: 2000000" required><label class="form-label">Nombre de Ícono (Lucide)</label><input type="text" name="icono_meta" class="input-control" placeholder="Ej: plane, car, home" value="target"><div style="display: flex; gap: 12px; margin-top: 8px;"><button type="submit" class="btn btn-primary" style="flex:1; justify-content:center;">Crear Meta</button><button type="button" class="btn btn-outline" onclick="cerrarModal('modal-nueva-meta')" style="flex:1; justify-content:center;">Cancelar</button></div></form></div></div>
    <div id="modal-nueva-deuda" class="modal"><div class="modal-content"><div class="modal-title">Añadir Deuda Activa</div><form method="POST"><input type="hidden" name="accion" value="agregar_deuda"><label class="form-label">Nombre del crédito</label><input type="text" name="nombre_deuda" class="input-control" placeholder="Ej: Tarjeta de Crédito" required><label class="form-label">Deuda Total Inicial ($)</label><input type="number" name="total_deuda" class="input-control" placeholder="Ej: 2000000" required><label class="form-label">Cuota Mensual ($)</label><input type="number" name="cuota_deuda" class="input-control" placeholder="Ej: 150000" required><label class="form-label">Ícono (Escribe un Lucide o pega un Emoji 📱)</label><input type="text" name="icono_deuda" class="input-control" placeholder="Ej: credit-card o 🏍️"><div style="display: flex; gap: 12px; margin-top: 8px;"><button type="submit" class="btn btn-primary" style="flex:1; justify-content:center;">Añadir</button><button type="button" class="btn btn-outline" onclick="cerrarModal('modal-nueva-deuda')" style="flex:1; justify-content:center;">Cancelar</button></div></form></div></div>
    <div id="modal-abono" class="modal"><div class="modal-content"><div class="modal-title">Registrar Pago</div><form method="POST"><input type="hidden" name="accion" value="abonar_deuda"><input type="hidden" name="deuda" id="deuda-input"><label class="form-label">Monto a descontar ($)</label><input type="number" name="monto" class="input-control" placeholder="Ej: 150000" required><div style="display: flex; gap: 12px; margin-top: 8px;"><button type="submit" class="btn btn-primary" style="flex:1; justify-content:center; background: var(--danger); color: white; border:none;">Abonar</button><button type="button" class="btn btn-outline" onclick="cerrarModal('modal-abono')" style="flex:1; justify-content:center;">Cancelar</button></div></form></div></div>
    <div id="modal-meta" class="modal"><div class="modal-content"><div class="modal-title">Fondear Meta</div><form method="POST"><input type="hidden" name="accion" value="abonar_meta"><input type="hidden" name="meta" id="meta-input"><label class="form-label">Monto a inyectar ($)</label><input type="number" name="monto" class="input-control" placeholder="Ej: 50000" required><div style="display: flex; gap: 12px; margin-top: 8px;"><button type="submit" class="btn btn-primary" style="flex:1; justify-content:center; background: #8b5cf6; color: white; border:none;">Fondear</button><button type="button" class="btn btn-outline" onclick="cerrarModal('modal-meta')" style="flex:1; justify-content:center;">Cancelar</button></div></form></div></div>
    <div id="modal-sueldo" class="modal"><div class="modal-content"><div class="modal-title">Configurar Nómina</div><form method="POST"><input type="hidden" name="accion" value="editar_sueldo"><label class="form-label">Sueldo Base ($)</label><input type="number" name="nuevo_sueldo" class="input-control" value="<?php echo $data['sueldo_base']; ?>" required><label class="form-label">Bono Q1 ($)</label><input type="number" name="nuevo_bono" class="input-control" value="<?php echo $data['bono_q1']; ?>" required><div style="display: flex; gap: 12px; margin-top: 8px;"><button type="submit" class="btn btn-primary" style="flex:1; justify-content:center;">Guardar</button><button type="button" class="btn btn-outline" onclick="cerrarModal('modal-sueldo')" style="flex:1; justify-content:center;">Cancelar</button></div></form></div></div>
    <div id="modal-ahorro" class="modal"><div class="modal-content"><div class="modal-title">Aporte Corvanca</div><form method="POST"><input type="hidden" name="accion" value="abonar_ahorro"><label class="form-label">Monto a sumar ($)</label><input type="number" name="monto" class="input-control" value="75000" required><div style="display: flex; gap: 12px; margin-top: 8px;"><button type="submit" class="btn btn-primary" style="flex:1; justify-content:center; background: var(--success); color: white; border:none;">Abonar</button><button type="button" class="btn btn-outline" onclick="cerrarModal('modal-ahorro')" style="flex:1; justify-content:center;">Cancelar</button></div></form></div></div>

    <script>
        lucide.createIcons();
        function abrirModal(id) { document.getElementById(id).style.display = 'flex'; }
        function cerrarModal(id) { document.getElementById(id).style.display = 'none'; }
        function abrirAbono(nombre) { document.getElementById('deuda-input').value = nombre; abrirModal('modal-abono'); }
        function abrirAbonoMeta(nombre) { document.getElementById('meta-input').value = nombre; abrirModal('modal-meta'); }
        
        function toggleDarkMode() {
            document.body.classList.toggle('dark-mode');
            localStorage.setItem('oledTheme', document.body.classList.contains('dark-mode') ? 'yes' : 'no');
        }
        if (localStorage.getItem('oledTheme') === 'yes') {
            document.body.classList.add('dark-mode');
        }

        function abrirEditarDeuda(nombre, total, pendiente, cuota, icono) {
            document.getElementById('edit-nombre-original').value = nombre;
            document.getElementById('edit-nombre').value = nombre;
            document.getElementById('edit-total').value = total;
            document.getElementById('edit-pendiente').value = pendiente;
            document.getElementById('edit-cuota').value = cuota;
            document.getElementById('edit-icono').value = icono;
            abrirModal('modal-editar-deuda');
        }

        const contenedorDeudas = document.getElementById('contenedor-deudas');
        if (contenedorDeudas) {
            new Sortable(contenedorDeudas, {
                handle: '.drag-handle', 
                animation: 200, 
                ghostClass: 'sortable-ghost', 
                onEnd: function () {
                    let items = contenedorDeudas.querySelectorAll('.deuda-item');
                    let nuevoOrden = [];
                    items.forEach(item => nuevoOrden.push(item.getAttribute('data-id')));
                    document.getElementById('input-nuevo-orden').value = JSON.stringify(nuevoOrden);
                    document.getElementById('form-reordenar').submit();
                }
            });
        }

        const ctx = document.getElementById('budgetChart').getContext('2d');
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Gastos Fijos', 'Pago Deudas', 'Ahorro'],
                datasets: [{ data: [<?php echo $chart_gastos_fijos; ?>, <?php echo $chart_deudas; ?>, <?php echo $chart_ahorro; ?>], backgroundColor: ['#4F46E5', '#EF4444', '#10B981'], borderWidth: 0, hoverOffset: 4 }]
            },
            options: { responsive: true, maintainAspectRatio: false, cutout: '75%', plugins: { legend: { display: false }, tooltip: { callbacks: { label: function(context) { let label = context.label || ''; if (label) { label += ': '; } if (context.parsed !== null) { label += new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 }).format(context.parsed); } return label; } } } } }
        });
    </script>
</body>
</html>

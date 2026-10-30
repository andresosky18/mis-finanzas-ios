<?php
session_start();
include 'conexion.php';

$archivo_config = 'config.json';
$config = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];
$pin_sistema = $config['pin_acceso'] ?? '1234';

// AUTENTICACIÓN POR PIN
$error_pin = '';
if (isset($_GET['logout'])) {
    unset($_SESSION['auth_pin_ok']);
    header("Location: admin.php");
    exit();
}
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['login_pin'])) {
    if (trim($_POST['pin']) === (string)$pin_sistema) {
        $_SESSION['auth_pin_ok'] = true;
        header("Location: admin.php");
        exit();
    } else {
        $error_pin = 'PIN incorrecto. Intenta nuevamente.';
    }
}

if (empty($_SESSION['auth_pin_ok'])):
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Acceso Protegido - Admin</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/lucide@latest"></script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', sans-serif; }
        body { background: #09090B; color: #FAFAFA; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
        .login-card { background: #121215; border: 1px solid #27272A; border-radius: 24px; padding: 40px 32px; width: 100%; max-width: 380px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.5); }
        .logo-box { width: 52px; height: 52px; background: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%); border-radius: 16px; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; color: white; }
        h1 { font-size: 20px; font-weight: 800; margin-bottom: 8px; }
        p { font-size: 13px; color: #A1A1AA; margin-bottom: 24px; }
        .pin-input { width: 100%; background: #09090B; border: 1px solid #27272A; color: white; font-size: 24px; font-weight: 800; letter-spacing: 8px; text-align: center; padding: 14px; border-radius: 12px; outline: none; margin-bottom: 16px; }
        .pin-input:focus { border-color: #6366F1; box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.2); }
        .btn-enter { width: 100%; background: #FFFFFF; color: #09090B; border: none; padding: 14px; border-radius: 12px; font-size: 14px; font-weight: 700; cursor: pointer; transition: 0.2s; }
        .btn-enter:hover { background: #E4E4E7; }
        .err { color: #EF4444; font-size: 12px; font-weight: 600; margin-bottom: 12px; }
        .back-link { display: inline-block; margin-top: 20px; color: #71717A; font-size: 12px; text-decoration: none; }
        .back-link:hover { color: #FAFAFA; }
    </style>
</head>
<body>
    <div class="login-card">
        <div class="logo-box"><i data-lucide="shield-lock"></i></div>
        <h1>Admin Workspace</h1>
        <p>Ingresa tu PIN de seguridad para administrar saldos y facturación.</p>
        <?php if ($error_pin): ?><div class="err"><?php echo htmlspecialchars($error_pin); ?></div><?php endif; ?>
        <form method="POST">
            <input type="hidden" name="login_pin" value="1">
            <input type="password" name="pin" class="pin-input" placeholder="••••" inputmode="numeric" autofocus required>
            <button type="submit" class="btn-enter">Desbloquear Panel</button>
        </form>
        <a href="index.php" class="back-link">← Volver al Dashboard Público</a>
    </div>
    <script>lucide.createIcons();</script>
</body>
</html>
<?php
exit();
endif;

// MIGRACIÓN DE DATOS EN CONFIG.JSON
if (!isset($config['lineas_credito'])) {
    $config['lineas_credito'] = [
        ['id' => 'dron', 'nombre' => 'Dron + Memoria', 'icono' => 'plane', 'color' => '#3b82f6'],
        ['id' => 'reloj', 'nombre' => 'Reloj', 'icono' => 'watch', 'color' => '#f2c10d']
    ];
}
if (!isset($config['cuotas_dinamicas'])) {
    $config['cuotas_dinamicas'] = [
        ['nombre' => 'Dron', 'icono' => 'plane', 'act' => $config['dron_act'] ?? 7, 'tot' => $config['dron_tot'] ?? 18],
        ['nombre' => 'reloj', 'icono' => 'watch', 'act' => 3, 'tot' => 18]
    ];
}
if (!isset($config['facturacion_items']) || !is_array($config['facturacion_items'])) {
    $items_migrados = [];
    $lineas_raw = explode("\n", trim($config['items_mes'] ?? ''));
    $default_cat = $config['lineas_credito'][0]['id'] ?? 'dron';
    foreach ($lineas_raw as $l_txt) {
        $limpio = trim(str_replace('•', '', $l_txt));
        if ($limpio !== '') {
            $cat_guess = $default_cat;
            foreach ($config['lineas_credito'] as $lc) {
                if (stripos($limpio, $lc['id']) !== false || stripos($limpio, $lc['nombre']) !== false) {
                    $cat_guess = $lc['id'];
                    break;
                }
            }
            $items_migrados[] = [
                'nombre' => $limpio,
                'monto' => 0,
                'categoria' => $cat_guess,
                'pagado' => false
            ];
        }
    }
    $config['facturacion_items'] = $items_migrados;
}

// 1. PROCESAR CONFIGURACIONES DEL MES Y FACTURACIÓN INTELIGENTE (Archivo config.json)
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['guardar_config'])) {
    $config_actual = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];

    $item_nombres = $_POST['item_nombre'] ?? [];
    $item_montos = $_POST['item_monto'] ?? [];
    $item_cats = $_POST['item_categoria'] ?? [];
    $item_pagados = $_POST['item_pagado'] ?? [];
    $item_sumar_deuda = $_POST['item_sumar_deuda'] ?? [];

    $nuevos_items = [];
    $lineas_texto = [];
    $suma_items_pendientes = 0;

    for ($i = 0; $i < count($item_nombres); $i++) {
        $nom = trim($item_nombres[$i]);
        if ($nom !== '') {
            $mto = (float)($item_montos[$i] ?? 0);
            $cat = trim($item_cats[$i] ?? ($config['lineas_credito'][0]['id'] ?? 'dron'));
            $pag = isset($item_pagados[$i]) && $item_pagados[$i] == '1';
            $sumar_deuda = isset($item_sumar_deuda[$i]) && $item_sumar_deuda[$i] == '1';

            // Opción 3: Si marcó "Sumar a Deuda", registramos automáticamente la compra/interés en la BD
            if ($sumar_deuda && $mto > 0) {
                $tipo_mov = (stripos($nom, 'interes') !== false || stripos($nom, 'interés') !== false) ? 'interes' : 'deuda';
                $concepto_mov = "Factura (" . ($_POST['fecha_corte'] ?? 'Mes') . "): " . $nom;
                $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
                $stmt->bind_param("sdss", $tipo_mov, $mto, $concepto_mov, $cat);
                $stmt->execute();
                $stmt->close();
            }

            if (!$pag && $mto > 0) {
                $suma_items_pendientes += $mto;
            }

            $nuevos_items[] = [
                'nombre' => $nom,
                'monto' => $mto,
                'categoria' => $cat,
                'pagado' => $pag
            ];
            $lineas_texto[] = $nom;
        }
    }

    // Si los ítems tienen precios individuales y se activó el cálculo automático, usar la suma; si no, el valor manual
    $cuota_mes_final = (float)$_POST['cuota_mes'];
    if (!empty($_POST['auto_calcular_total']) && $suma_items_pendientes > 0) {
        $cuota_mes_final = $suma_items_pendientes;
    }

    $nueva_config = [
        'fecha_corte' => $_POST['fecha_corte'],
        'cuota_mes' => $cuota_mes_final,
        'cuota_adelanto' => (float)$_POST['cuota_adelanto'],
        'items_mes' => implode("\r\n", $lineas_texto),
        'items_adelanto' => $_POST['items_adelanto'],
        'facturacion_items' => $nuevos_items
    ];

    if (!empty($_POST['nuevo_pin'])) {
        $nueva_config['pin_acceso'] = trim($_POST['nuevo_pin']);
    }

    $nueva_config = array_merge($config_actual, $nueva_config);
    file_put_contents($archivo_config, json_encode($nueva_config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    header("Location: admin.php?tab=tab-cfg");
    exit();
}

// 1B. PAGAR UN ÍTEM INDIVIDUAL DE LA FACTURA O LIQUIDAR FACTURA COMPLETA
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['pagar_item_factura'])) {
    $idx = (int)$_POST['item_index'];
    if (isset($config['facturacion_items'][$idx])) {
        $item = $config['facturacion_items'][$idx];
        $monto_pago = (float)$item['monto'];
        $cat_pago = $item['categoria'];
        $nom_pago = $item['nombre'];

        if (!$item['pagado']) {
            $config['facturacion_items'][$idx]['pagado'] = true;
            if ($monto_pago > 0) {
                // 1. Bajar deuda en la base de datos
                $concepto = "Pago Factura: " . $nom_pago;
                $tipo = 'pago';
                $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
                $stmt->bind_param("sdss", $tipo, $monto_pago, $concepto, $cat_pago);
                $stmt->execute();
                $stmt->close();

                // 2. Bajar Total Cierre Mensual en config.json
                $config['cuota_mes'] = max(0, (float)$config['cuota_mes'] - $monto_pago);
            }
            file_put_contents($archivo_config, json_encode($config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
        }
    }
    header("Location: admin.php?tab=tab-cfg");
    exit();
}

if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['liquidar_factura_mes'])) {
    $cuota_actual = (float)($config['cuota_mes'] ?? 0);
    $items = $config['facturacion_items'] ?? [];
    $pagos_por_cat = [];
    $suma_items = 0;

    foreach ($items as $k => $it) {
        if (empty($it['pagado'])) {
            $config['facturacion_items'][$k]['pagado'] = true;
            $m = (float)($it['monto'] ?? 0);
            $c = $it['categoria'] ?? ($config['lineas_credito'][0]['id'] ?? 'dron');
            if ($m > 0) {
                $pagos_por_cat[$c] = ($pagos_por_cat[$c] ?? 0) + $m;
                $suma_items += $m;
            }
        }
    }

    // Si los ítems tenían monto desglosado, insertar pago por cada categoría
    if ($suma_items > 0) {
        foreach ($pagos_por_cat as $cat_id => $monto_cat) {
            $concepto = "Pago Factura Corte " . ($config['fecha_corte'] ?? '');
            $tipo = 'pago';
            $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
            $stmt->bind_param("sdss", $tipo, $monto_cat, $concepto, $cat_id);
            $stmt->execute();
            $stmt->close();
        }
    } elseif ($cuota_actual > 0) {
        // Si no había montos individuales sino solo el total del mes, abonarlo a la línea seleccionada
        $cat_destino = $_POST['categoria_liquidacion'] ?? ($config['lineas_credito'][0]['id'] ?? 'dron');
        $concepto = "Pago Total Factura (" . ($config['fecha_corte'] ?? 'Mes') . ")";
        $tipo = 'pago';
        $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("sdss", $tipo, $cuota_actual, $concepto, $cat_destino);
        $stmt->execute();
        $stmt->close();
    }

    // Avanzar +1 en las cuotas diferidas si se marcó la opción
    if (!empty($_POST['avanzar_cuotas']) && isset($config['cuotas_dinamicas'])) {
        foreach ($config['cuotas_dinamicas'] as $idx_c => $cd) {
            if ($cd['act'] < $cd['tot']) {
                $config['cuotas_dinamicas'][$idx_c]['act']++;
            }
        }
    }

    $config['cuota_mes'] = 0;
    file_put_contents($archivo_config, json_encode($config, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    header("Location: admin.php?tab=tab-cfg");
    exit();
}

// 2. PROCESAR LÍNEAS DE CRÉDITO DINÁMICAS
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['guardar_lineas'])) {
    $config_actual = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];
    
    $ids = $_POST['linea_id'] ?? [];
    $nombres = $_POST['linea_nombre'] ?? [];
    $iconos = $_POST['linea_icono'] ?? [];
    $colores = $_POST['linea_color'] ?? [];
    
    $lineas_credito = [];
    for ($i = 0; $i < count($nombres); $i++) {
        if (!empty(trim($nombres[$i])) && !empty(trim($ids[$i]))) {
            $lineas_credito[] = [
                'id' => strtolower(trim(str_replace(' ', '_', $ids[$i]))),
                'nombre' => trim($nombres[$i]),
                'icono' => trim($iconos[$i]),
                'color' => trim($colores[$i])
            ];
        }
    }
    
    $config_actual['lineas_credito'] = $lineas_credito;
    file_put_contents($archivo_config, json_encode($config_actual, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    header("Location: admin.php?tab=tab-lines"); 
    exit();
}

// 3. PROCESAR NUEVOS VALORES DE CUOTAS DINÁMICAS
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['guardar_cuotas_dinamicas'])) {
    $config_actual = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];
    
    $nombres = $_POST['nombres'] ?? [];
    $iconos = $_POST['iconos'] ?? [];
    $acts = $_POST['acts'] ?? [];
    $tots = $_POST['tots'] ?? [];
    
    $cuotas_dinamicas = [];
    for ($i = 0; $i < count($nombres); $i++) {
        if (!empty(trim($nombres[$i]))) {
            $cuotas_dinamicas[] = [
                'nombre' => trim($nombres[$i]),
                'icono' => trim($iconos[$i]),
                'act' => (int)$acts[$i],
                'tot' => (int)$tots[$i]
            ];
        }
    }
    
    $config_actual['cuotas_dinamicas'] = $cuotas_dinamicas;
    file_put_contents($archivo_config, json_encode($config_actual, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    header("Location: admin.php?tab=tab-cuotas"); 
    exit();
}

// 4. PROCESAR NUEVOS MOVIMIENTOS Y AJUSTES
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['registrar_movimiento'])) {
    $tipo = $_POST['tipo'];
    $monto = (float)$_POST['monto'];
    $concepto = $_POST['concepto'];
    $categoria = $_POST['categoria'];

    $stmt = $conn->prepare("INSERT INTO movimientos (tipo, monto, concepto, categoria) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("sdss", $tipo, $monto, $concepto, $categoria);
    $stmt->execute();
    $stmt->close();

    // Opción 2: Si es un pago y está marcado "Descontar del Total Cierre Mensual", restarlo de cuota_mes
    $config_actual = file_exists($archivo_config) ? json_decode(file_get_contents($archivo_config), true) : [];
    $modifico_cfg = false;

    if ($tipo === 'pago' && !empty($_POST['descontar_factura'])) {
        $cuota_actual = (float)($config_actual['cuota_mes'] ?? 0);
        $config_actual['cuota_mes'] = max(0, $cuota_actual - $monto);
        $modifico_cfg = true;
    }

    // Si es una deuda/compra y marcó "Añadir también a la lista de Facturación del Período"
    if (($tipo === 'deuda' || $tipo === 'interes') && !empty($_POST['agregar_a_factura'])) {
        if (!isset($config_actual['facturacion_items']) || !is_array($config_actual['facturacion_items'])) {
            $config_actual['facturacion_items'] = [];
        }
        $config_actual['facturacion_items'][] = [
            'nombre' => $concepto,
            'monto' => $monto,
            'categoria' => $categoria,
            'pagado' => false
        ];
        $config_actual['cuota_mes'] = (float)($config_actual['cuota_mes'] ?? 0) + $monto;
        $lineas_txt = array_map(function($it) { return $it['nombre']; }, $config_actual['facturacion_items']);
        $config_actual['items_mes'] = implode("\r\n", $lineas_txt);
        $modifico_cfg = true;
    }

    // Si es un pago y marcó avanzar +1 cuota diferida de esa categoría
    if ($tipo === 'pago' && !empty($_POST['avanzar_cuota_cat']) && isset($config_actual['cuotas_dinamicas'])) {
        foreach ($config_actual['cuotas_dinamicas'] as $k => $cd) {
            if (stripos($cd['nombre'], $categoria) !== false || stripos($categoria, $cd['nombre']) !== false) {
                if ($cd['act'] < $cd['tot']) {
                    $config_actual['cuotas_dinamicas'][$k]['act']++;
                    $modifico_cfg = true;
                }
            }
        }
    }

    if ($modifico_cfg) {
        file_put_contents($archivo_config, json_encode($config_actual, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
    }

    header("Location: admin.php"); 
    exit();
}

// 5. ELIMINAR / REVERTIR UN MOVIMIENTO DEL REGISTRO CONTABLE
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_POST['eliminar_movimiento'])) {
    $id_eliminar = (int)$_POST['id_movimiento'];
    if ($id_eliminar > 0) {
        $stmt = $conn->prepare("DELETE FROM movimientos WHERE id = ?");
        $stmt->bind_param("i", $id_eliminar);
        $stmt->execute();
        $stmt->close();
    }
    header("Location: admin.php");
    exit();
}

$historial = $conn->query("SELECT * FROM movimientos ORDER BY fecha DESC");
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SaaS Admin - Workspace</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/lucide@latest"></script>
    
    <style>
        :root {
            /* Light Theme */
            --bg-body: #FAFAFA;
            --card-bg: #FFFFFF;
            --text-main: #09090B;
            --text-muted: #71717A;
            --border-light: #E4E4E7;
            --btn-primary: #000000;
            --btn-primary-text: #FFFFFF;
            --btn-primary-hover: #27272A;
            --input-bg: #FFFFFF;
            --card-shadow: 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06);
            --tab-bg: #F4F4F5;
            --tab-active-bg: #FFFFFF;
            --tab-active-text: #09090B;
            --tab-hover-bg: #E4E4E7;
        }

        body.dark-mode {
            /* OLED Dark Theme */
            --bg-body: #000000;
            --card-bg: #09090B;
            --text-main: #FAFAFA;
            --text-muted: #A1A1AA;
            --border-light: #27272A;
            --btn-primary: #FFFFFF;
            --btn-primary-text: #000000;
            --btn-primary-hover: #E4E4E7;
            --input-bg: #000000;
            --card-shadow: 0 4px 30px rgba(255,255,255,0.02);
            --tab-bg: #18181B;
            --tab-active-bg: #27272A;
            --tab-active-text: #FFFFFF;
            --tab-hover-bg: #27272A;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', sans-serif; scroll-behavior: smooth; }
        body { background-color: var(--bg-body); color: var(--text-main); display: flex; flex-direction: column; min-height: 100vh; transition: background-color 0.3s, color 0.3s; }
        
        .lucide { stroke-width: 2.5; }
        .icon-sm { width: 16px; height: 16px; display: inline-block; vertical-align: middle;}
        .icon-md { width: 20px; height: 20px; display: inline-block; vertical-align: middle;}

        /* TOP NAVIGATION ELEGANT (Vercel Style) */
        .top-nav { background: var(--card-bg); border-bottom: 1px solid var(--border-light); padding: 0 40px; height: 70px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100;}
        .nav-left { display: flex; align-items: center; gap: 32px; }
        .nav-logo { display: flex; align-items: center; gap: 12px; font-weight: 800; font-size: 16px; color: var(--text-main); text-decoration: none;}
        .logo-box { background: var(--btn-primary); color: var(--btn-primary-text); width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; }
        
        .nav-links { display: flex; gap: 24px; }
        .nav-link { color: var(--text-muted); text-decoration: none; font-size: 14px; font-weight: 500; transition: color 0.2s; display: flex; align-items: center; gap: 6px;}
        .nav-link:hover, .nav-link.active { color: var(--text-main); }
        
        .nav-right { display: flex; align-items: center; gap: 12px; }
        .theme-toggle { background: transparent; border: 1px solid var(--border-light); color: var(--text-main); border-radius: 50%; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 36px; height: 36px; transition: 0.2s;}
        .theme-toggle:hover { background: var(--tab-bg); }

        /* MAIN CONTAINER */
        .main-container { max-width: 1300px; margin: 40px auto; padding: 0 40px; width: 100%; display: grid; grid-template-columns: 1fr 420px; gap: 40px; align-items: start; }
        @media (max-width: 1000px) { .main-container { grid-template-columns: 1fr; padding: 0 20px; } .top-nav { padding: 0 20px; } }

        /* PÍLDORAS (Segmented Control) */
        .tabs-wrapper { background: var(--tab-bg); padding: 6px; border-radius: 12px; display: flex; gap: 4px; margin-bottom: 32px; overflow-x: auto; border: 1px solid var(--border-light);}
        .tab-btn { flex: 1; background: transparent; border: none; padding: 12px 16px; border-radius: 8px; font-size: 13px; font-weight: 600; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; transition: 0.2s; white-space: nowrap;}
        .tab-btn:hover { background: var(--tab-hover-bg); color: var(--text-main); }
        .tab-btn.active { background: var(--tab-active-bg); color: var(--tab-active-text); box-shadow: 0 1px 3px rgba(0,0,0,0.1); }

        /* FORMULARIO CONTAINER */
        .form-container { background: var(--card-bg); border: 1px solid var(--border-light); border-radius: 16px; padding: 32px; box-shadow: var(--card-shadow); }
        .tab-content { display: none; animation: fadeIn 0.3s ease; }
        .tab-content.active { display: block; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }

        .form-header-title { font-size: 20px; font-weight: 800; margin-bottom: 8px; color: var(--text-main); }
        .form-desc { font-size: 14px; color: var(--text-muted); margin-bottom: 24px; line-height: 1.5; }

        .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 24px; }
        @media (max-width: 700px) { .form-row { grid-template-columns: 1fr; } }
        
        .form-group { width: 100%; margin-bottom: 20px;}
        .form-label { display: block; font-size: 12px; color: var(--text-main); font-weight: 600; margin-bottom: 8px; }
        .input-control { width: 100%; background-color: var(--input-bg); border: 1px solid var(--border-light); color: var(--text-main); padding: 12px 16px; border-radius: 8px; font-size: 14px; font-weight: 500; outline: none; transition: all 0.2s ease; box-shadow: 0 1px 2px rgba(0,0,0,0.05) inset;}
        .input-control:focus { border-color: #3B82F6; box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1); }
        textarea.input-control { resize: vertical; min-height: 90px; line-height: 1.6; }

        .check-card { display: flex; align-items: center; gap: 10px; padding: 12px 16px; background: var(--tab-bg); border: 1px solid var(--border-light); border-radius: 10px; margin-bottom: 12px; font-size: 13px; font-weight: 500; cursor: pointer; }
        .check-card input[type="checkbox"] { width: 18px; height: 18px; accent-color: #4F46E5; cursor: pointer; }

        .btn-submit { background: var(--btn-primary); color: var(--btn-primary-text); border: none; padding: 12px 24px; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: 0.2s; display:inline-flex; align-items:center; justify-content:center; gap:8px;}
        .btn-submit:hover { background: var(--btn-primary-hover); }
        
        .btn-eliminar { background: transparent; color: #EF4444; border: 1px solid var(--border-light); width: 42px; height: 42px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: 0.2s;}
        .btn-eliminar:hover { background: #FEE2E2; border-color: #EF4444; }
        body.dark-mode .btn-eliminar:hover { background: #450a0a; }

        .item-dinamico { display: flex; flex-wrap: wrap; gap: 12px; background: var(--tab-bg); padding: 16px; border-radius: 12px; border: 1px solid var(--border-light); align-items: flex-end; margin-bottom: 12px; transition: 0.2s;}
        .col-icono { flex: 0 0 70px; }
        .col-nombre { flex: 1 1 130px; }
        .col-num { flex: 0 0 65px; }
        .col-btn { flex: 0 0 42px; }
        .col-color { flex: 0 0 80px; }

        /* PANEL LATERAL DE AUDITORÍA */
        .audit-panel { background: var(--card-bg); border: 1px solid var(--border-light); border-radius: 20px; box-shadow: var(--card-shadow); height: calc(100vh - 120px); position: sticky; top: 90px; display: flex; flex-direction: column; overflow: hidden; }
        .audit-header { padding: 24px; border-bottom: 1px solid var(--border-light); display: flex; align-items: center; gap: 16px;}
        .audit-title { font-size: 16px; font-weight: 800; color: var(--text-main); line-height: 1.2; display: flex; flex-direction: column;}
        .audit-list { flex: 1; overflow-y: auto; padding: 0 24px;}
        .audit-list::-webkit-scrollbar { width: 6px; }
        .audit-list::-webkit-scrollbar-thumb { background: var(--border-light); border-radius: 3px; }
        
        .audit-item { padding: 18px 0; border-bottom: 1px dashed var(--border-light); display: flex; justify-content: space-between; align-items: flex-start; gap: 10px;}
        .audit-item:last-child { border-bottom: none; }
        .ai-info { display: flex; flex-direction: column; gap: 6px; flex: 1; overflow: hidden;}
        .ai-title { font-size: 13px; font-weight: 800; color: var(--text-main); text-transform: uppercase; letter-spacing: 0.3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;}
        
        .ai-meta { font-size: 11px; color: var(--text-muted); font-weight: 500; display:flex; align-items:center; gap:6px; flex-wrap: wrap;}
        .ai-badge { padding: 3px 8px; border-radius: 12px; background: transparent; border: 1px solid var(--border-light); font-size: 9px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.5px; text-decoration: none;}
        .ai-badge-recibo { color: #10B981; border-color: rgba(16, 185, 129, 0.4); background: rgba(16, 185, 129, 0.08); cursor: pointer; }
        .ai-badge-recibo:hover { background: #10B981; color: white; }
        
        .ai-right { display: flex; align-items: center; gap: 8px; }
        .ai-amount { font-size: 14px; font-weight: 800; text-align: right; white-space: nowrap;}
        .color-pago { color: #10B981; }
        .color-deuda { color: #EF4444; }
    </style>
</head>
<body>

    <!-- TOP NAVIGATION -->
    <nav class="top-nav">
        <div class="nav-left">
            <a href="index.php" class="nav-logo">
                <div class="logo-box"><i data-lucide="zap" class="icon-sm"></i></div>
                Admin Workspace
            </a>
            <div class="nav-links">
                <a href="index.php" class="nav-link"><i data-lucide="arrow-left" class="icon-sm"></i> Volver al Dashboard</a>
            </div>
        </div>
        <div class="nav-right">
            <button class="theme-toggle" onclick="toggleTheme()" title="Cambiar Tema" id="theme-btn">
                <i data-lucide="moon" class="icon-sm"></i>
            </button>
            <a href="admin.php?logout=1" class="nav-link" style="font-size:12px; color:#EF4444;"><i data-lucide="log-out" class="icon-sm"></i> Salir</a>
        </div>
    </nav>

    <!-- MAIN CONTENT -->
    <main class="main-container">
        
        <!-- COLUMNA IZQUIERDA (CONFIGURACIONES) -->
        <div>
            
            <!-- PESTAÑAS TIPO SEGMENTED CONTROL -->
            <div class="tabs-wrapper">
                <button class="tab-btn active" data-tab="tab-tx" onclick="openTab('tab-tx', this)"><i data-lucide="plus-circle" class="icon-sm"></i> Operación</button>
                <button class="tab-btn" data-tab="tab-cfg" onclick="openTab('tab-cfg', this)"><i data-lucide="calendar" class="icon-sm"></i> Facturación</button>
                <button class="tab-btn" data-tab="tab-adj" onclick="openTab('tab-adj', this)"><i data-lucide="ghost" class="icon-sm"></i> Ajuste Interno</button>
                <button class="tab-btn" data-tab="tab-lines" onclick="openTab('tab-lines', this)"><i data-lucide="layers" class="icon-sm"></i> Líneas</button>
                <button class="tab-btn" data-tab="tab-cuotas" onclick="openTab('tab-cuotas', this)"><i data-lucide="layout-list" class="icon-sm"></i> Cuotas</button>
            </div>

            <!-- CONTENEDOR DEL FORMULARIO ACTIVO -->
            <div class="form-container">
                
                <!-- TAB 1: REGISTRAR OPERACIÓN -->
                <div id="tab-tx" class="tab-content active">
                    <h2 class="form-header-title">Registrar Transacción</h2>
                    <p class="form-desc">Ingresa un nuevo pago, deuda o interés. Al registrar un pago puedes descontarlo automáticamente del Total de Cierre Mensual y avanzar la cuota.</p>
                    
                    <form method="POST">
                        <input type="hidden" name="registrar_movimiento" value="1">
                        
                        <div class="form-row">
                            <div class="form-group" style="margin-bottom:0;">
                                <label class="form-label">Acción</label>
                                <select name="tipo" id="select-tipo-op" class="input-control" required onchange="actualizarOpcionesOperacion(this.value)">
                                    <option value="pago">Recibir Pago (Resta a deuda)</option>
                                    <option value="deuda">Sumar Deuda (Nueva compra)</option>
                                    <option value="interes">Añadir Interés</option>
                                </select>
                            </div>
                            <div class="form-group" style="margin-bottom:0;">
                                <label class="form-label">Línea de Crédito Afectada</label>
                                <select name="categoria" class="input-control" required>
                                    <?php foreach ($config['lineas_credito'] as $l): ?>
                                        <option value="<?php echo htmlspecialchars($l['id']); ?>">
                                            <?php echo htmlspecialchars($l['nombre']); ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                        </div>

                        <div class="form-row">
                            <div class="form-group" style="margin-bottom:0;">
                                <label class="form-label">Monto Exacto ($)</label>
                                <input type="number" step="0.01" name="monto" class="input-control" required placeholder="Ej: 372875">
                            </div>
                            <div class="form-group" style="margin-bottom:0;">
                                <label class="form-label">Descripción</label>
                                <input type="text" name="concepto" class="input-control" required placeholder="Ej: Abono de cuota Octubre" autocomplete="off">
                            </div>
                        </div>

                        <div id="opciones-pago-auto" style="margin-bottom: 24px;">
                            <label class="check-card">
                                <input type="checkbox" name="descontar_factura" value="1" checked>
                                <span><b>Restar automáticamente del Total Cierre Mensual</b> (actual: $<?php echo number_format($config['cuota_mes'] ?? 0, 0); ?>) en la tarjeta de Facturación</span>
                            </label>
                            <label class="check-card">
                                <input type="checkbox" name="avanzar_cuota_cat" value="1">
                                <span><b>Avanzar +1 cuota diferida</b> automáticamente en la barra de progreso de esta línea</span>
                            </label>
                        </div>

                        <div id="opciones-deuda-auto" style="margin-bottom: 24px; display: none;">
                            <label class="check-card">
                                <input type="checkbox" name="agregar_a_factura" value="1" checked>
                                <span><b>Incluir automáticamente en "Facturación del Período"</b> y sumar al Total Cierre Mensual</span>
                            </label>
                        </div>
                        
                        <button type="submit" class="btn-submit"><i data-lucide="check" class="icon-sm"></i> Guardar Operación</button>
                    </form>
                </div>

                <!-- TAB 2: AJUSTE SILENCIOSO -->
                <div id="tab-adj" class="tab-content">
                    <h2 class="form-header-title" style="color:#8B5CF6;">Ajuste Interno</h2>
                    <p class="form-desc">Modifica saldos contables sin dejar rastro en el panel frontal del cliente. Usa <b>números negativos</b> para restar saldo a la deuda.</p>
                    
                    <form method="POST">
                        <input type="hidden" name="registrar_movimiento" value="1">
                        <input type="hidden" name="tipo" value="ajuste">
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label class="form-label">Cuenta a ajustar</label>
                                <select name="categoria" class="input-control" required>
                                    <?php foreach ($config['lineas_credito'] as $l): ?>
                                        <option value="<?php echo htmlspecialchars($l['id']); ?>">
                                            <?php echo htmlspecialchars($l['nombre']); ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Monto de corrección ($)</label>
                                <input type="number" step="0.01" name="monto" class="input-control" required placeholder="Ej: 50000 o -50000">
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label class="form-label">Motivo (Visible solo aquí)</label>
                            <input type="text" name="concepto" class="input-control" required placeholder="Ej: Corrección de error de sistema" autocomplete="off">
                        </div>
                        
                        <button type="submit" class="btn-submit" style="background:#8B5CF6;"><i data-lucide="settings" class="icon-sm"></i> Aplicar Ajuste</button>
                    </form>
                </div>

                <!-- TAB 3: FACTURACIÓN INTELIGENTE -->
                <div id="tab-cfg" class="tab-content">
                    <div style="display:flex; justify-content:space-between; align-items:flex-start; flex-wrap:wrap; gap:12px; margin-bottom:16px;">
                        <div>
                            <h2 class="form-header-title">Facturación del Período</h2>
                            <p class="form-desc" style="margin-bottom:0;">Asigna monto y línea de crédito a cada ítem, súmalos como deuda o márcalos como pagados para descontar la deuda automáticamente.</p>
                        </div>
                    </div>

                    <!-- ACCIÓN RÁPIDA: LIQUIDAR FACTURA DEL MES -->
                    <?php if (($config['cuota_mes'] ?? 0) > 0): ?>
                    <form method="POST" style="background: rgba(16, 185, 129, 0.08); border: 1px solid rgba(16, 185, 129, 0.3); padding: 16px; border-radius: 12px; margin-bottom: 24px; display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px;">
                        <input type="hidden" name="liquidar_factura_mes" value="1">
                        <div>
                            <div style="font-size:13px; font-weight:800; color:#10B981;">¿Ya te pagaron el corte de <?php echo htmlspecialchars($config['fecha_corte']); ?> ($<?php echo number_format($config['cuota_mes'], 0); ?>)?</div>
                            <div style="font-size:12px; color:var(--text-muted); margin-top:2px;">Descuenta automáticamente de la deuda en BD y deja el cierre mensual en $0.</div>
                            <label style="display:inline-flex; align-items:center; gap:6px; font-size:12px; margin-top:8px; cursor:pointer;">
                                <input type="checkbox" name="avanzar_cuotas" value="1" checked> Avanzar +1 en todas las cuotas diferidas (ej. 7/18 → 8/18)
                            </label>
                        </div>
                        <div style="display:flex; align-items:center; gap:8px;">
                            <select name="categoria_liquidacion" class="input-control" style="width:auto; padding:8px 12px; font-size:12px;">
                                <?php foreach ($config['lineas_credito'] as $l): ?>
                                    <option value="<?php echo htmlspecialchars($l['id']); ?>">Abonar a: <?php echo htmlspecialchars($l['nombre']); ?></option>
                                <?php endforeach; ?>
                            </select>
                            <button type="submit" class="btn-submit" style="background:#10B981; color:white; padding:10px 16px; font-size:13px;"><i data-lucide="check-circle-2" class="icon-sm"></i> Marcar Mes Pagado</button>
                        </div>
                    </form>
                    <?php endif; ?>
                    
                    <form method="POST" id="form-facturacion">
                        <input type="hidden" name="guardar_config" value="1">
                        
                        <div class="form-row">
                            <div class="form-group" style="margin-bottom:0;">
                                <label class="form-label">Texto Fecha de Cierre</label>
                                <input type="text" name="fecha_corte" class="input-control" required value="<?php echo htmlspecialchars($config['fecha_corte'] ?? ''); ?>" placeholder="Ej: 18 DE OCTUBRE">
                            </div>
                            <div class="form-group" style="margin-bottom:0;">
                                <label class="form-label">Total Cierre Mensual ($)</label>
                                <input type="number" step="1" name="cuota_mes" id="input-cuota-mes" class="input-control" required value="<?php echo $config['cuota_mes'] ?? 0; ?>">
                            </div>
                        </div>

                        <label class="check-card" style="margin-bottom: 24px;">
                            <input type="checkbox" name="auto_calcular_total" id="chk-auto-total" value="1" onchange="recalcularTotalFactura()">
                            <span>Calcular "Total Cierre Mensual" automáticamente sumando los montos de los ítems pendientes abajo</span>
                        </label>

                        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
                            <label class="form-label" style="margin-bottom:0; font-size:13px;">Ítems Facturados en el Período</label>
                            <button type="button" onclick="agregarFilaItemFactura()" style="background:transparent; color:#3B82F6; border:1px solid #3B82F6; padding:6px 12px; border-radius:8px; font-size:12px; font-weight:700; cursor:pointer;">+ Añadir Ítem</button>
                        </div>

                        <div id="contenedor-items-factura" style="margin-bottom: 24px;">
                            <?php foreach ($config['facturacion_items'] as $idx => $item): 
                                $esta_pagado = !empty($item['pagado']);
                            ?>
                            <div class="item-dinamico" style="<?php echo $esta_pagado ? 'opacity:0.6;' : ''; ?>">
                                <div class="col-nombre" style="flex: 2 1 160px;">
                                    <label class="form-label">Concepto / Ítem</label>
                                    <input type="text" name="item_nombre[]" class="input-control" value="<?php echo htmlspecialchars($item['nombre']); ?>" required>
                                </div>
                                <div class="col-nombre" style="flex: 1 1 110px;">
                                    <label class="form-label">Monto ($)</label>
                                    <input type="number" step="1" name="item_monto[]" class="input-control item-monto-input" value="<?php echo (float)($item['monto'] ?? 0); ?>" oninput="recalcularTotalFactura()">
                                </div>
                                <div class="col-nombre" style="flex: 1 1 130px;">
                                    <label class="form-label">Línea de Crédito</label>
                                    <select name="item_categoria[]" class="input-control">
                                        <?php foreach ($config['lineas_credito'] as $l): ?>
                                            <option value="<?php echo htmlspecialchars($l['id']); ?>" <?php echo ($item['categoria'] ?? '') === $l['id'] ? 'selected' : ''; ?>>
                                                <?php echo htmlspecialchars($l['nombre']); ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                </div>
                                <div style="flex: 0 0 auto; display:flex; flex-direction:column; gap:6px; padding-bottom:4px;">
                                    <label style="font-size:11px; display:flex; align-items:center; gap:5px; cursor:pointer;" title="Marca esto si es una compra nueva y quieres que se sume al saldo de deuda en la BD al guardar">
                                        <input type="checkbox" name="item_sumar_deuda[<?php echo $idx; ?>]" value="1"> +Deuda BD
                                    </label>
                                    <label style="font-size:11px; display:flex; align-items:center; gap:5px; cursor:pointer; color:#10B981; font-weight:700;">
                                        <input type="checkbox" name="item_pagado[<?php echo $idx; ?>]" class="item-pagado-chk" value="1" <?php echo $esta_pagado ? 'checked' : ''; ?> onchange="recalcularTotalFactura()"> Pagado
                                    </label>
                                </div>
                                <?php if (!$esta_pagado && (float)($item['monto'] ?? 0) > 0): ?>
                                <div style="flex: 0 0 auto;">
                                    <button type="button" onclick="pagarItemIndividual(<?php echo $idx; ?>)" style="background:#10B981; color:white; border:none; height:42px; padding:0 12px; border-radius:8px; font-size:11px; font-weight:700; cursor:pointer;" title="Registrar pago de este ítem y descontar de la deuda">Abonar</button>
                                </div>
                                <?php endif; ?>
                                <div class="col-btn">
                                    <button type="button" class="btn-eliminar" onclick="this.parentElement.parentElement.remove(); recalcularTotalFactura();"><i data-lucide="x" class="icon-sm"></i></button>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>

                        <div class="form-row">
                            <div class="form-group">
                                <label class="form-label">Cuota Adelanto Mensual ($)</label>
                                <input type="number" step="1" name="cuota_adelanto" class="input-control" required value="<?php echo $config['cuota_adelanto'] ?? 0; ?>">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Cambiar PIN de Acceso (Actual: <?php echo htmlspecialchars($pin_sistema); ?>)</label>
                                <input type="text" name="nuevo_pin" class="input-control" value="<?php echo htmlspecialchars($pin_sistema); ?>" placeholder="Ej: 1234">
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label class="form-label">Detalle Factura Adelanto</label>
                            <textarea name="items_adelanto" class="input-control" required placeholder="Uno por línea..."><?php echo htmlspecialchars($config['items_adelanto'] ?? ""); ?></textarea>
                        </div>
                        
                        <button type="submit" class="btn-submit"><i data-lucide="check" class="icon-sm"></i> Guardar Facturación</button>
                    </form>

                    <form id="form-pagar-item" method="POST" style="display:none;">
                        <input type="hidden" name="pagar_item_factura" value="1">
                        <input type="hidden" name="item_index" id="input-item-index">
                    </form>
                </div>

                <!-- TAB 4: LÍNEAS DE CRÉDITO -->
                <div id="tab-lines" class="tab-content">
                    <h2 class="form-header-title">Líneas Maestras</h2>
                    <p class="form-desc">Edita las cuentas base del sistema. Las burbujas principales del inicio se actualizan automáticamente con estas líneas.</p>
                    
                    <form method="POST">
                        <input type="hidden" name="guardar_lineas" value="1">
                        
                        <div id="contenedor-lineas">
                            <?php foreach ($config['lineas_credito'] as $l): ?>
                            <div class="item-dinamico">
                                <div class="col-icono">
                                    <label class="form-label">Ícono</label>
                                    <input type="text" name="linea_icono[]" class="input-control" value="<?php echo htmlspecialchars($l['icono']); ?>" required>
                                </div>
                                <div class="col-nombre">
                                    <label class="form-label">Nombre</label>
                                    <input type="text" name="linea_nombre[]" class="input-control" value="<?php echo htmlspecialchars($l['nombre']); ?>" required>
                                </div>
                                <div class="col-nombre">
                                    <label class="form-label">ID Interno</label>
                                    <input type="text" name="linea_id[]" class="input-control" value="<?php echo htmlspecialchars($l['id']); ?>" required>
                                </div>
                                <div class="col-color">
                                    <label class="form-label">Color</label>
                                    <input type="color" name="linea_color[]" class="input-control" style="padding: 2px; height: 42px; cursor: pointer;" value="<?php echo htmlspecialchars($l['color']); ?>" required>
                                </div>
                                <div class="col-btn">
                                    <button type="button" class="btn-eliminar" onclick="this.parentElement.parentElement.remove()"><i data-lucide="x" class="icon-sm"></i></button>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        
                        <div style="display: flex; gap: 16px; margin-top: 24px;">
                            <button type="button" onclick="agregarFilaLinea()" style="background: transparent; color: var(--text-main); border: 1px dashed var(--border-light); padding: 12px 24px; border-radius: 8px; cursor: pointer; font-weight:600;"><i data-lucide="plus" class="icon-sm"></i> Añadir</button>
                            <button type="submit" class="btn-submit">Guardar Líneas</button>
                        </div>
                    </form>
                </div>

                <!-- TAB 5: CUOTAS DIFERIDAS -->
                <div id="tab-cuotas" class="tab-content">
                    <h2 class="form-header-title">Cuotas Individuales</h2>
                    <p class="form-desc">Gestiona las barras de progreso. Usa nombres de Lucide (ej: <code>plane</code>, <code>watch</code>, <code>camera</code>).</p>
                    
                    <form method="POST">
                        <input type="hidden" name="guardar_cuotas_dinamicas" value="1">
                        
                        <div id="contenedor-cuotas">
                            <?php foreach ($config['cuotas_dinamicas'] as $c): ?>
                            <div class="item-dinamico">
                                <div class="col-icono">
                                    <label class="form-label">Ícono</label>
                                    <input type="text" name="iconos[]" class="input-control" value="<?php echo htmlspecialchars($c['icono']); ?>" required>
                                </div>
                                <div class="col-nombre">
                                    <label class="form-label">Nombre</label>
                                    <input type="text" name="nombres[]" class="input-control" value="<?php echo htmlspecialchars($c['nombre']); ?>" required>
                                </div>
                                <div class="col-num">
                                    <label class="form-label">Act</label>
                                    <input type="number" name="acts[]" class="input-control text-center" value="<?php echo $c['act']; ?>" required>
                                </div>
                                <div class="col-num">
                                    <label class="form-label">Tot</label>
                                    <input type="number" name="tots[]" class="input-control text-center" value="<?php echo $c['tot']; ?>" required>
                                </div>
                                <div class="col-btn">
                                    <button type="button" class="btn-eliminar" onclick="this.parentElement.parentElement.remove()"><i data-lucide="x" class="icon-sm"></i></button>
                                </div>
                            </div>
                            <?php endforeach; ?>
                        </div>
                        
                        <div style="display: flex; gap: 16px; margin-top: 24px;">
                            <button type="button" onclick="agregarFilaCuota()" style="background: transparent; color: var(--text-main); border: 1px dashed var(--border-light); padding: 12px 24px; border-radius: 8px; cursor: pointer; font-weight:600;"><i data-lucide="plus" class="icon-sm"></i> Añadir</button>
                            <button type="submit" class="btn-submit">Guardar Cuotas</button>
                        </div>
                    </form>
                </div>

            </div>
        </div>

        <!-- PANEL DERECHO (AUDITORÍA FIJA CON RECIBO Y REVERSIÓN) -->
        <div class="audit-panel">
            <div class="audit-header">
                <i data-lucide="file-clock" style="width: 44px; height: 44px; stroke-width: 1.5; color: var(--text-main);"></i>
                <h3 class="audit-title">
                    <span>Registro</span>
                    <span>Contable</span>
                </h3>
            </div>
            
            <div class="audit-list">
                <?php if ($historial && $historial->num_rows > 0): ?>
                    <?php while($row = $historial->fetch_assoc()): ?>
                        <div class="audit-item">
                            <div class="ai-info">
                                <div class="ai-title" title="<?php echo htmlspecialchars($row['concepto']); ?>">
                                    <?php echo htmlspecialchars($row['concepto']); ?>
                                </div>
                                <div class="ai-meta">
                                    <i data-lucide="calendar" style="width:12px; height:12px; stroke-width:2.5;"></i> <?php echo date('d/m/Y - H:i', strtotime($row['fecha'])); ?>
                                    <span class="ai-badge">
                                        <?php 
                                        $cat_db = strtolower(trim($row['categoria']));
                                        $cat_nombre = $cat_db;
                                        foreach($config['lineas_credito'] as $lc) {
                                            if($lc['id'] == $cat_db) { $cat_nombre = $lc['nombre']; break; }
                                        }
                                        echo htmlspecialchars($cat_nombre);
                                        ?>
                                    </span>
                                    <?php if($row['tipo'] == 'ajuste'): ?>
                                        <span class="ai-badge" style="color:#8B5CF6; border-color:#8B5CF6; background: rgba(139,92,246,0.1);">AJUSTE</span>
                                    <?php endif; ?>
                                    <?php if($row['tipo'] == 'pago'): ?>
                                        <a href="recibo.php?id=<?php echo (int)$row['id']; ?>" target="_blank" class="ai-badge ai-badge-recibo" title="Ver Recibo Oficial PDF">
                                            🧾 Recibo #<?php echo (int)$row['id']; ?>
                                        </a>
                                    <?php endif; ?>
                                </div>
                            </div>
                            <div class="ai-right">
                                <div class="ai-amount">
                                    <?php 
                                        $monto = (float)$row['monto'];
                                        $esResta = ($row['tipo'] == 'pago' || ($row['tipo'] == 'ajuste' && $monto < 0));
                                        $signo = $esResta ? '-' : '+';
                                        $claseColor = $esResta ? 'color-pago' : 'color-deuda';
                                        
                                        echo '<span class="'.$claseColor.'">' . $signo . '$' . number_format(abs($monto), 0) . '</span>'; 
                                    ?>
                                </div>
                                <form method="POST" onsubmit="return confirm('¿Eliminar este movimiento contable?');" style="margin:0;">
                                    <input type="hidden" name="eliminar_movimiento" value="1">
                                    <input type="hidden" name="id_movimiento" value="<?php echo (int)$row['id']; ?>">
                                    <button type="submit" style="background:transparent; border:none; color:var(--text-muted); cursor:pointer; padding:4px;" title="Eliminar movimiento">
                                        <i data-lucide="trash-2" style="width:14px; height:14px;"></i>
                                    </button>
                                </form>
                            </div>
                        </div>
                    <?php endwhile; ?>
                <?php else: ?>
                    <div style="text-align: center; color: var(--text-muted); padding: 60px 0; font-size:13px;">Base limpia. No hay movimientos.</div>
                <?php endif; ?>
            </div>
        </div>

    </main>

    <script>
    lucide.createIcons();

    function openTab(targetId, btnElement) {
        document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
        document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
        
        document.getElementById(targetId).classList.add('active');
        if (btnElement) btnElement.classList.add('active');
    }

    // Abrir pestaña si viene por URL (?tab=tab-cfg)
    const urlParams = new URLSearchParams(window.location.search);
    const tabParam = urlParams.get('tab');
    if (tabParam && document.getElementById(tabParam)) {
        const btn = document.querySelector(`.tab-btn[data-tab="${tabParam}"]`);
        openTab(tabParam, btn);
    }

    function actualizarOpcionesOperacion(tipo) {
        document.getElementById('opciones-pago-auto').style.display = (tipo === 'pago') ? 'block' : 'none';
        document.getElementById('opciones-deuda-auto').style.display = (tipo === 'deuda' || tipo === 'interes') ? 'block' : 'none';
    }

    function pagarItemIndividual(idx) {
        document.getElementById('input-item-index').value = idx;
        document.getElementById('form-pagar-item').submit();
    }

    function recalcularTotalFactura() {
        const autoChk = document.getElementById('chk-auto-total');
        if (!autoChk || !autoChk.checked) return;
        let suma = 0;
        const filas = document.querySelectorAll('#contenedor-items-factura .item-dinamico');
        filas.forEach(fila => {
            const montoInput = fila.querySelector('.item-monto-input');
            const pagadoChk = fila.querySelector('.item-pagado-chk');
            const val = parseFloat(montoInput ? montoInput.value : 0) || 0;
            const isPaid = pagadoChk && pagadoChk.checked;
            if (!isPaid && val > 0) suma += val;
        });
        document.getElementById('input-cuota-mes').value = Math.round(suma);
    }

    function agregarFilaItemFactura() {
        const container = document.getElementById('contenedor-items-factura');
        const idx = container.children.length;
        const opcionesLineas = `<?php foreach ($config['lineas_credito'] as $l): ?><option value="<?php echo htmlspecialchars($l['id']); ?>"><?php echo htmlspecialchars($l['nombre']); ?></option><?php endforeach; ?>`;
        const html = `
        <div class="item-dinamico">
            <div class="col-nombre" style="flex: 2 1 160px;">
                <label class="form-label">Concepto / Ítem</label>
                <input type="text" name="item_nombre[]" class="input-control" placeholder="Ej: Compra / Cuota" required>
            </div>
            <div class="col-nombre" style="flex: 1 1 110px;">
                <label class="form-label">Monto ($)</label>
                <input type="number" step="1" name="item_monto[]" class="input-control item-monto-input" value="0" oninput="recalcularTotalFactura()">
            </div>
            <div class="col-nombre" style="flex: 1 1 130px;">
                <label class="form-label">Línea de Crédito</label>
                <select name="item_categoria[]" class="input-control">${opcionesLineas}</select>
            </div>
            <div style="flex: 0 0 auto; display:flex; flex-direction:column; gap:6px; padding-bottom:4px;">
                <label style="font-size:11px; display:flex; align-items:center; gap:5px; cursor:pointer;">
                    <input type="checkbox" name="item_sumar_deuda[${idx}]" value="1" checked> +Deuda BD
                </label>
                <label style="font-size:11px; display:flex; align-items:center; gap:5px; cursor:pointer; color:#10B981; font-weight:700;">
                    <input type="checkbox" name="item_pagado[${idx}]" class="item-pagado-chk" value="1" onchange="recalcularTotalFactura()"> Pagado
                </label>
            </div>
            <div class="col-btn">
                <button type="button" class="btn-eliminar" onclick="this.parentElement.parentElement.remove(); recalcularTotalFactura();"><i data-lucide="x" class="icon-sm"></i></button>
            </div>
        </div>`;
        container.insertAdjacentHTML('beforeend', html);
        lucide.createIcons();
    }

    // DARK MODE TOGGLE
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
    }
    
    if(localStorage.getItem('oledTheme') === 'yes') {
        document.body.classList.add('dark-mode');
        document.querySelector('#theme-btn i').setAttribute('data-lucide', 'sun');
        lucide.createIcons();
    }

    function agregarFilaCuota() {
        const html = `
        <div class="item-dinamico">
            <div class="col-icono"><label class="form-label">Ícono</label><input type="text" name="iconos[]" class="input-control" placeholder="box" required></div>
            <div class="col-nombre"><label class="form-label">Nombre</label><input type="text" name="nombres[]" class="input-control" placeholder="Nuevo Ítem" required></div>
            <div class="col-num"><label class="form-label">Act</label><input type="number" name="acts[]" class="input-control text-center" value="0" required></div>
            <div class="col-num"><label class="form-label">Tot</label><input type="number" name="tots[]" class="input-control text-center" value="0" required></div>
            <div class="col-btn"><button type="button" class="btn-eliminar" onclick="this.parentElement.parentElement.remove()"><i data-lucide="x" class="icon-sm"></i></button></div>
        </div>`;
        document.getElementById('contenedor-cuotas').insertAdjacentHTML('beforeend', html);
        lucide.createIcons();
    }
    
    function agregarFilaLinea() {
        const html = `
        <div class="item-dinamico">
            <div class="col-icono"><label class="form-label">Ícono</label><input type="text" name="linea_icono[]" class="input-control" placeholder="star" required></div>
            <div class="col-nombre"><label class="form-label">Nombre</label><input type="text" name="linea_nombre[]" class="input-control" placeholder="Nueva Cuenta" required></div>
            <div class="col-nombre"><label class="form-label">ID Interno</label><input type="text" name="linea_id[]" class="input-control" placeholder="nueva_cuenta" required></div>
            <div class="col-color"><label class="form-label">Color</label><input type="color" name="linea_color[]" class="input-control" style="padding: 2px; height: 42px; cursor: pointer;" value="#4f46e5" required></div>
            <div class="col-btn"><button type="button" class="btn-eliminar" onclick="this.parentElement.parentElement.remove()"><i data-lucide="x" class="icon-sm"></i></button></div>
        </div>`;
        document.getElementById('contenedor-lineas').insertAdjacentHTML('beforeend', html);
        lucide.createIcons();
    }
    </script>
</body>
</html>

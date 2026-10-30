<?php
include 'conexion.php';

// Obtener el ID del movimiento
$id = isset($_GET['id']) ? intval($_GET['id']) : 0;
$query = $conn->query("SELECT * FROM movimientos WHERE id = $id AND tipo = 'pago'");

if ($query && $query->num_rows > 0) {
    $pago = $query->fetch_assoc();
} else {
    die("Recibo no encontrado o inválido.");
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Comprobante_Pago_<?php echo $pago['id']; ?></title>
    <style>
        body { font-family: 'Courier New', Courier, monospace; background: #e2e8f0; display: flex; justify-content: center; padding: 40px; margin: 0; }
        .ticket { background: #fff; width: 320px; padding: 30px; border-radius: 8px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); color: #1e293b; }
        .header { text-align: center; border-bottom: 2px dashed #cbd5e1; padding-bottom: 20px; margin-bottom: 20px; }
        .logo { font-size: 28px; font-weight: bold; letter-spacing: -1px; }
        .sub { font-size: 12px; color: #64748b; text-transform: uppercase; margin-top: 5px; }
        .row { display: flex; justify-content: space-between; margin-bottom: 12px; font-size: 14px; }
        .label { font-weight: bold; color: #475569; }
        .value { text-align: right; }
        .total-box { margin-top: 20px; padding-top: 20px; border-top: 2px dashed #cbd5e1; text-align: center; }
        .total-label { font-size: 14px; font-weight: bold; color: #64748b; text-transform: uppercase; }
        .total-amount { font-size: 32px; font-weight: bold; color: #10b981; margin: 10px 0; }
        .footer { text-align: center; font-size: 11px; color: #94a3b8; margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 15px; }
        .watermark { text-align: center; color: #10b981; font-weight: bold; border: 2px solid #10b981; padding: 5px; border-radius: 4px; display: inline-block; transform: rotate(-5deg); margin-top: 10px;}
        
        @media print {
            body { background: #fff; padding: 0; }
            .ticket { box-shadow: none; border: 1px solid #e2e8f0; }
        }
    </style>
</head>
<body>

    <div class="ticket">
        <div class="header">
            <div class="logo">FINANCE // LEDGER</div>
            <div class="sub">Comprobante de Pago Oficial</div>
        </div>

        <div class="row">
            <span class="label">N° de Recibo:</span>
            <span class="value">#000<?php echo $pago['id']; ?></span>
        </div>
        <div class="row">
            <span class="label">Fecha:</span>
            <span class="value"><?php echo date('d/m/Y H:i', strtotime($pago['fecha'])); ?></span>
        </div>
        <div class="row">
            <span class="label">Asignación:</span>
            <span class="value" style="text-transform: capitalize;"><?php echo htmlspecialchars($pago['categoria']); ?></span>
        </div>
        <div class="row">
            <span class="label">Detalle:</span>
            <span class="value"><?php echo htmlspecialchars($pago['concepto']); ?></span>
        </div>

        <div class="total-box">
            <div class="total-label">Importe Abonado</div>
            <div class="total-amount">$<?php echo number_format($pago['monto'], 0); ?></div>
            <div class="watermark">✔ PAZ Y SALVO PARCIAL</div>
        </div>

        <div class="footer">
            Documento generado automáticamente por el sistema de control financiero.<br>
            Gracias por su pago.
        </div>
    </div>

    <script>
        // Lanza la ventana de impresión/Guardar como PDF automáticamente al cargar
        window.onload = function() { window.print(); }
    </script>
</body>
</html>
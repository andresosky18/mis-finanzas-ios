<?php
$host = "sqlXXX.infinityfree.com"; 
$user = "if0_XXXXXXXX"; 
$pass = "TU_PASSWORD_AQUI"; 
$db_name = "if0_XXXXXXXX_pagos"; 

$conn = new mysqli($host, $user, $pass, $db_name);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    die("Error de conexión: " . $conn->connect_error);
}
?>

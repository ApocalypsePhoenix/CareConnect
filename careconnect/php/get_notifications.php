<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';

$user_id = $_GET['user_id'] ?? null;

if (!$user_id) {
    echo json_encode(["success" => false, "message" => "User ID required"]);
    exit;
}

$database = new Database();
$db = $database->getConnection();

try {
    $query = "SELECT * FROM notifications WHERE user_id = :uid ORDER BY created_at DESC LIMIT 50";
    $stmt = $db->prepare($query);
    $stmt->execute([':uid' => $user_id]);
    
    $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(["success" => true, "notifications" => $notifications]);
} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
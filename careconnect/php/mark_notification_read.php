<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';

$data = json_decode(file_get_contents("php://input"), true);
$user_id = $data['user_id'] ?? null;

if (!$user_id) {
    echo json_encode(["success" => false, "message" => "User ID required"]);
    exit;
}

$database = new Database();
$db = $database->getConnection();

try {
    // Marks all notifications as read for this specific user
    $query = "UPDATE notifications SET is_read = 1 WHERE user_id = :uid";
    $stmt = $db->prepare($query);
    $stmt->execute([':uid' => $user_id]);
    
    echo json_encode(["success" => true]);
} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
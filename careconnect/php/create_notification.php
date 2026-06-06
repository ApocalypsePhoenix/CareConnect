<?php
// Note: You can use this API in the future to trigger alerts!
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';

$data = json_decode(file_get_contents("php://input"), true);
$user_id = $data['user_id'] ?? null;
$title = $data['title'] ?? 'New Alert';
$message = $data['message'] ?? '';

if (!$user_id || empty($message)) {
    echo json_encode(["success" => false, "message" => "User ID and message required"]);
    exit;
}

$database = new Database();
$db = $database->getConnection();

try {
    $query = "INSERT INTO notifications (user_id, title, message) VALUES (:uid, :title, :msg)";
    $stmt = $db->prepare($query);
    $stmt->execute([':uid' => $user_id, ':title' => $title, ':msg' => $message]);
    
    echo json_encode(["success" => true]);
} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
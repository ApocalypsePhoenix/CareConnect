<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"), true);

// Verify required fields
if (empty($data['user_id']) || empty($data['topic']) || empty($data['message'])) {
    echo json_encode(["success" => false, "message" => "Missing required fields."]);
    exit;
}

try {
    $query = "INSERT INTO support_tickets (user_id, role, topic, message) 
              VALUES (:user_id, :role, :topic, :message)";
    $stmt = $db->prepare($query);
    $stmt->execute([
        ':user_id' => $data['user_id'],
        ':role' => $data['role'] ?? 'Unknown',
        ':topic' => $data['topic'],
        ':message' => $data['message']
    ]);

    echo json_encode(["success" => true, "message" => "Your message has been sent successfully. Admin will review it soon!"]);
} catch (PDOException $e) {
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
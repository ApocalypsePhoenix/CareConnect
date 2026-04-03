<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With, Accept");

// Handle preflight CORS requests from the local dashboard file
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['user_id']) && isset($data['status'])) {
    try {
        // Map our status strings back to the TINYINT column
        $is_verified = 0; // PENDING
        if ($data['status'] === 'APPROVED') {
            $is_verified = 1;
        } elseif ($data['status'] === 'REJECTED') {
            $is_verified = 2; // We use 2 for Rejected
        }

        $query = "UPDATE worker_details SET is_verified = :is_verified WHERE user_id = :user_id";
        $stmt = $db->prepare($query);
        
        $stmt->bindParam(':is_verified', $is_verified);
        $stmt->bindParam(':user_id', $data['user_id']);
        
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Worker status updated successfully."]);
        } else {
            echo json_encode(["success" => false, "message" => "Failed to update worker status."]);
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Server error: " . $e->getMessage()]);
    }
} else {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing user_id or status."]);
}
?>
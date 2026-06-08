<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Handle preflight CORS request for local testing
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (!empty($data->id) && !empty($data->status)) {
    try {
        $query = "UPDATE support_tickets SET status = :status WHERE id = :id";
        $stmt = $db->prepare($query);
        
        $stmt->bindParam(':status', $data->status);
        $stmt->bindParam(':id', $data->id);
        
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Ticket status updated to " . $data->status]);
        } else {
            echo json_encode(["success" => false, "message" => "Failed to update ticket."]);
        }
    } catch (PDOException $e) {
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Incomplete data provided."]);
}
?>
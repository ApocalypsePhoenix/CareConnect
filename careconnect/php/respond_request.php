<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['request_id']) && isset($data['action']) && isset($data['worker_id'])) {
    
    if ($data['action'] === 'Accepted') {
        // Assign the worker and change status to 'Accepted'
        $stmt = $db->prepare("UPDATE bookings SET status = 'Accepted', worker_id = :worker_id WHERE id = :id AND status = 'Pending'");
        $stmt->execute([':worker_id' => $data['worker_id'], ':id' => $data['request_id']]);
        
        if ($stmt->rowCount() > 0) {
            // AUTOMATICALLY TAKE WORKER OFFLINE (is_available = 0)
            $offlineStmt = $db->prepare("UPDATE worker_details SET is_available = 0 WHERE user_id = :worker_id");
            $offlineStmt->execute([':worker_id' => $data['worker_id']]);
            
            echo json_encode(["success" => true]);
        } else {
            // Someone else tapped Accept a millisecond earlier!
            echo json_encode(["success" => false, "message" => "This job was just taken by another worker!"]);
        }
    } else {
        echo json_encode(["success" => true]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Missing data."]);
}
?>
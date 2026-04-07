<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$client_id = isset($_GET['client_id']) ? $_GET['client_id'] : null;
$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : null;

try {
    if ($worker_id) {
        // Worker is asking: Get the client's details
        // ADDED 'Pending_Approval' to the list below
        $stmt = $db->prepare("SELECT b.*, u.name as client_name, u.phone as client_phone 
                              FROM bookings b JOIN users u ON b.client_id = u.id 
                              WHERE b.worker_id = :w_id AND b.status IN ('Pending_Approval', 'Accepted', 'On_The_Way', 'Arrived', 'In_Progress') LIMIT 1");
        $stmt->execute([':w_id' => $worker_id]);
    } else if ($client_id) {
        // Client is asking: Get the worker's details
        // ADDED 'Pending_Approval' to the list below
        $stmt = $db->prepare("SELECT b.*, u.name as worker_name, u.phone as worker_phone, u.profile_image as worker_image 
                              FROM bookings b JOIN users u ON b.worker_id = u.id 
                              WHERE b.client_id = :c_id AND b.status IN ('Pending_Approval', 'Accepted', 'On_The_Way', 'Arrived', 'In_Progress') LIMIT 1");
        $stmt->execute([':c_id' => $client_id]);
    } else {
        echo json_encode(["success" => false, "message" => "Missing ID"]);
        exit;
    }

    if ($stmt->rowCount() > 0) {
        $service = $stmt->fetch(PDO::FETCH_ASSOC);
        echo json_encode(["success" => true, "has_service" => true, "service" => $service]);
    } else {
        echo json_encode(["success" => true, "has_service" => false]);
    }
} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
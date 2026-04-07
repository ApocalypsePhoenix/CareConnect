<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['booking_id']) && isset($data['status'])) {
    // Update the booking to the exact step the worker is currently on
    $stmt = $db->prepare("UPDATE bookings SET status = :status WHERE id = :id");
    $stmt->execute([':status' => $data['status'], ':id' => $data['booking_id']]);
    
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["success" => false]);
}
?>
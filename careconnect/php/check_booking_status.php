<?php
// When a job disappears from a user's screen, the app will ping this file to ask, "Wait, what happened to that job?"

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$booking_id = isset($_GET['booking_id']) ? $_GET['booking_id'] : null;

if ($booking_id) {
    try {
        $stmt = $db->prepare("SELECT status FROM bookings WHERE id = :id");
        $stmt->execute([':id' => $booking_id]);
        
        if ($stmt->rowCount() > 0) {
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            echo json_encode(["success" => true, "status" => $row['status']]);
            exit;
        }
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
        exit;
    }
}
echo json_encode(["success" => false, "message" => "Missing booking ID"]);
?>
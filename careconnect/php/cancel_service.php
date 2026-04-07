<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['booking_id']) && isset($data['role'])) {
    $booking_id = $data['booking_id'];
    $role = $data['role'];

    try {
        // First get the worker_id so we can free them up
        $stmt = $db->prepare("SELECT worker_id FROM bookings WHERE id = :id");
        $stmt->execute([':id' => $booking_id]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);
        $worker_id = $booking ? $booking['worker_id'] : null;

        // UPDATED: Both Worker and Client cancellations now TERMINATE the service permanently
        $update = $db->prepare("UPDATE bookings SET status = 'Cancelled' WHERE id = :id");
        $update->execute([':id' => $booking_id]);

        // Free up the worker (make them available again for new jobs)
        if ($worker_id) {
            $freeWorker = $db->prepare("UPDATE worker_details SET is_available = 1 WHERE user_id = :w_id");
            $freeWorker->execute([':w_id' => $worker_id]);
        }

        echo json_encode(["success" => true]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Missing data."]);
}
?>
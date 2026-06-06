<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['booking_id']) && isset($data['worker_id'])) {
    try {
        // 1. Set booking back to Pending, BUT LEAVE worker_id INTACT!
        // This acts as a memory so the system knows exactly who was declined.
        $stmt = $db->prepare("UPDATE bookings SET status = 'Pending' WHERE id = :id");
        $stmt->execute([':id' => $data['booking_id']]);

        // 2. Free up the worker so they can look for other jobs
        $freeWorker = $db->prepare("UPDATE worker_details SET is_available = 1 WHERE user_id = :w_id");
        $freeWorker->execute([':w_id' => $data['worker_id']]);

        // ====================================================================
        // 3. NEW: CREATE NOTIFICATION FOR THE WORKER
        // ====================================================================
        try {
            $worker_id = $data['worker_id'];
            $notif_title = "Request Declined";
            $notif_message = "The client has reviewed your profile and declined the request. You have been made available for other incoming jobs.";
            
            $notif_query = "INSERT INTO notifications (user_id, title, message, type) VALUES (:uid, :title, :msg, 'cancellation')";
            $notif_stmt = $db->prepare($notif_query);
            $notif_stmt->execute([
                ':uid' => $worker_id, 
                ':title' => $notif_title, 
                ':msg' => $notif_message
            ]);
        } catch (Exception $e) {
            // Silently catch so a notification failure doesn't break the actual decline process
        }
        // ====================================================================

        echo json_encode(["success" => true]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Missing data"]);
}
?>
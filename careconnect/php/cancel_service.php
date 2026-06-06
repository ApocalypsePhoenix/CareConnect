<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['booking_id']) && isset($data['role'])) {
    $booking_id = $data['booking_id'];
    $role = $data['role']; // 'Client' or 'Worker'

    try {
        // First get the booking info so we know who to notify and free up
        $stmt = $db->prepare("SELECT client_id, worker_id, service_needed FROM bookings WHERE id = :id");
        $stmt->execute([':id' => $booking_id]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);
        
        $worker_id = $booking ? $booking['worker_id'] : null;
        $client_id = $booking ? $booking['client_id'] : null;
        $service = $booking ? $booking['service_needed'] : 'Service';

        // UPDATED: Both Worker and Client cancellations now TERMINATE the service permanently
        $update = $db->prepare("UPDATE bookings SET status = 'Cancelled' WHERE id = :id");
        $update->execute([':id' => $booking_id]);

        // Free up the worker (make them available again for new jobs)
        if ($worker_id) {
            $freeWorker = $db->prepare("UPDATE worker_details SET is_available = 1 WHERE user_id = :w_id");
            $freeWorker->execute([':w_id' => $worker_id]);
        }

        // ====================================================================
        // NEW: SMART NOTIFICATION FOR CANCELLATION
        // ====================================================================
        try {
            if ($booking) {
                $notify_user_id = null;
                $notif_title = "Booking Cancelled";
                $notif_message = "";

                // If Client cancelled, notify the Worker
                if ($role === 'Client' && $worker_id) {
                    $notify_user_id = $worker_id;
                    $notif_message = "The client has cancelled the upcoming $service. You are now available for other jobs.";
                } 
                // If Worker cancelled, notify the Client
                else if ($role === 'Worker' && $client_id) {
                    $notify_user_id = $client_id;
                    $notif_message = "Your assigned caregiver had to cancel the $service. Please submit a new booking request.";
                }

                if ($notify_user_id !== null) {
                    $notif_query = "INSERT INTO notifications (user_id, title, message, type) VALUES (:uid, :title, :msg, 'cancellation')";
                    $notif_stmt = $db->prepare($notif_query);
                    $notif_stmt->execute([
                        ':uid' => $notify_user_id, 
                        ':title' => $notif_title, 
                        ':msg' => $notif_message
                    ]);
                }
            }
        } catch (Exception $e) {
            // Silently catch so a notification failure doesn't break the actual cancellation
        }
        // ====================================================================

        echo json_encode(["success" => true]);
    } catch (Exception $e) {
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Missing data."]);
}
?>
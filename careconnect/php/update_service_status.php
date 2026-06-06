<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['booking_id']) && isset($data['status'])) {
    $booking_id = $data['booking_id'];
    $new_status = $data['status'];

    // 1. Update the booking to the exact step the worker/client is currently on
    $stmt = $db->prepare("UPDATE bookings SET status = :status WHERE id = :id");
    $stmt->execute([':status' => $new_status, ':id' => $booking_id]);
    
    // ====================================================================
    // 2. NEW: SMART NOTIFICATION SYSTEM
    // ====================================================================
    try {
        // Fetch booking details so we know WHO to notify
        $infoStmt = $db->prepare("SELECT client_id, worker_id, service_needed FROM bookings WHERE id = :id");
        $infoStmt->execute([':id' => $booking_id]);
        $bookingInfo = $infoStmt->fetch(PDO::FETCH_ASSOC);

        if ($bookingInfo) {
            $client_id = $bookingInfo['client_id'];
            $worker_id = $bookingInfo['worker_id'];
            $service = $bookingInfo['service_needed'];

            $notify_user_id = null;
            $notif_title = "";
            $notif_message = "";

            // Decide who gets the notification based on the new status!
            switch ($new_status) {
                case 'Accepted':
                    // Client approved the worker. Notify the Worker.
                    $notify_user_id = $worker_id;
                    $notif_title = "Job Approved!";
                    $notif_message = "The client has approved you for the $service. You can now head to the location.";
                    break;
                case 'On_The_Way':
                    // Worker is on the way. Notify the Client.
                    $notify_user_id = $client_id;
                    $notif_title = "Caregiver On The Way";
                    $notif_message = "Your caregiver is currently on the way to the pickup location.";
                    break;
                case 'Arrived':
                    // Worker arrived. Notify the Client.
                    $notify_user_id = $client_id;
                    $notif_title = "Caregiver Arrived";
                    $notif_message = "Your caregiver has arrived at the location.";
                    break;
                case 'In_Progress':
                    // Service started. Notify the Client.
                    $notify_user_id = $client_id;
                    $notif_title = "Service Started";
                    $notif_message = "Your $service has officially started.";
                    break;
                case 'Pending_Payment':
                    // Worker finished service. Notify the Client to pay.
                    $notify_user_id = $client_id;
                    $notif_title = "Service Completed";
                    $notif_message = "Your $service is finished. Please open the app to complete your payment.";
                    break;
                case 'Completed':
                    // Client paid. Notify the Worker!
                    $notify_user_id = $worker_id;
                    $notif_title = "Payment Received!";
                    $notif_message = "The client has completed the payment. Thank you for your hard work!";
                    
                    // AUTOMATIC BONUS: Put the worker back online so they can get new jobs!
                    if ($worker_id) {
                        $onlineStmt = $db->prepare("UPDATE worker_details SET is_available = 1 WHERE user_id = :worker_id");
                        $onlineStmt->execute([':worker_id' => $worker_id]);
                    }
                    break;
            }

            // If we set a user to notify, insert it into the database
            if ($notify_user_id !== null) {
                $notif_query = "INSERT INTO notifications (user_id, title, message, type) VALUES (:uid, :title, :msg, 'status_update')";
                $notif_stmt = $db->prepare($notif_query);
                $notif_stmt->execute([
                    ':uid' => $notify_user_id, 
                    ':title' => $notif_title, 
                    ':msg' => $notif_message
                ]);
            }
        }
    } catch (Exception $e) {
        // Silently catch so a notification failure doesn't break the app flow!
    }
    // ====================================================================

    echo json_encode(["success" => true]);
} else {
    echo json_encode(["success" => false, "message" => "Missing data"]);
}
?>
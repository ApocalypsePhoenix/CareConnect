<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['request_id']) && isset($data['action']) && isset($data['worker_id'])) {
    
    if ($data['action'] === 'Accepted') {
        // Assign the worker and change status to 'Pending_Approval' to wait for client approval
        $stmt = $db->prepare("UPDATE bookings SET status = 'Pending_Approval', worker_id = :worker_id WHERE id = :id AND status = 'Pending'");
        $stmt->execute([':worker_id' => $data['worker_id'], ':id' => $data['request_id']]);
        
        if ($stmt->rowCount() > 0) {
            // AUTOMATICALLY TAKE WORKER OFFLINE (is_available = 0)
            $offlineStmt = $db->prepare("UPDATE worker_details SET is_available = 0 WHERE user_id = :worker_id");
            $offlineStmt->execute([':worker_id' => $data['worker_id']]);
            
            // ====================================================================
            // NEW: CREATE NOTIFICATION FOR THE CLIENT
            // ====================================================================
            try {
                // First, we need to know WHICH client owns this booking
                $clientStmt = $db->prepare("SELECT client_id, service_needed FROM bookings WHERE id = :id");
                $clientStmt->execute([':id' => $data['request_id']]);
                $bookingInfo = $clientStmt->fetch(PDO::FETCH_ASSOC);

                if ($bookingInfo) {
                    $client_id = $bookingInfo['client_id'];
                    $service_needed = $bookingInfo['service_needed'];

                    $notif_title = "Worker Found!";
                    $notif_message = "A caregiver has accepted your request for $service_needed. Please review and approve them.";
                    
                    $notif_query = "INSERT INTO notifications (user_id, title, message, type) VALUES (:uid, :title, :msg, 'action_required')";
                    $notif_stmt = $db->prepare($notif_query);
                    $notif_stmt->execute([
                        ':uid' => $client_id, 
                        ':title' => $notif_title, 
                        ':msg' => $notif_message
                    ]);
                }
            } catch (Exception $e) {
                // Silently catch so a notification failure doesn't break the actual app flow!
            }
            // ====================================================================

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
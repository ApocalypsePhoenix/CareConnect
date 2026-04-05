<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : null;

// CONDITION 1: Check if the worker already has an active job
if ($worker_id) {
    $busyStmt = $db->prepare("SELECT id FROM bookings WHERE worker_id = :worker_id AND status IN ('Accepted', 'In Progress') LIMIT 1");
    $busyStmt->execute([':worker_id' => $worker_id]);
    
    if ($busyStmt->rowCount() > 0) {
        // Tell the app this worker is busy! Send NO requests.
        echo json_encode(["success" => true, "is_busy" => true, "requests" => []]);
        exit;
    }
}

// CONDITION 2: Fetch only "Pending" bookings (Accepted ones disappear for everyone else!)
$stmt = $db->prepare("SELECT id, patient_name as client_name, service_needed, pickup_location as location, DATE_FORMAT(created_at, '%b %d, %h:%i %p') as date, CONCAT(medical_condition, ' - ', special_needs) as details FROM bookings WHERE status = 'Pending' ORDER BY created_at DESC");
$stmt->execute();
$requests = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo json_encode(["success" => true, "is_busy" => false, "requests" => $requests]);
?>
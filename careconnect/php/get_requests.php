<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : null;
$worker_lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 0;
$worker_lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 0;

// CONDITION 1: Check if the worker already has an active job in ANY active state
if ($worker_id) {
    $busyStmt = $db->prepare("SELECT id FROM bookings WHERE worker_id = :worker_id AND status IN ('Accepted', 'On_The_Way', 'Arrived', 'In_Progress') LIMIT 1");
    $busyStmt->execute([':worker_id' => $worker_id]);
    
    if ($busyStmt->rowCount() > 0) {
        echo json_encode(["success" => true, "is_busy" => true, "requests" => []]);
        exit;
    }
}

// CONDITION 2: Fetch "Pending" bookings within a 5 KM Radius using Haversine formula
if ($worker_lat != 0 && $worker_lng != 0) {
    $query = "SELECT id, patient_name as client_name, service_needed, pickup_location as location, 
              DATE_FORMAT(created_at, '%b %d, %h:%i %p') as date, 
              CONCAT(medical_condition, ' - ', special_needs) as details,
              (6371 * acos(cos(radians(:w_lat)) * cos(radians(pickup_lat)) * cos(radians(pickup_lng) - radians(:w_lng)) + sin(radians(:w_lat)) * sin(radians(pickup_lat)))) AS distance 
              FROM bookings 
              WHERE status = 'Pending' 
              AND pickup_lat IS NOT NULL 
              AND pickup_lng IS NOT NULL 
              HAVING distance <= 5 
              ORDER BY distance ASC, created_at DESC";
              
    $stmt = $db->prepare($query);
    $stmt->bindParam(':w_lat', $worker_lat);
    $stmt->bindParam(':w_lng', $worker_lng);
    $stmt->execute();
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
} else {
    $requests = [];
}

echo json_encode(["success" => true, "is_busy" => false, "requests" => $requests]);
?>
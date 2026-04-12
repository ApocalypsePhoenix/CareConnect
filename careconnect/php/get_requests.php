<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : null;
$worker_lat = isset($_GET['lat']) ? (float)$_GET['lat'] : 0;
$worker_lng = isset($_GET['lng']) ? (float)$_GET['lng'] : 0;

if (!$worker_id) {
    echo json_encode(["success" => false, "message" => "Missing Worker ID"]);
    exit;
}

// 1. Check if the worker already has an active job
$busyStmt = $db->prepare("SELECT id FROM bookings WHERE worker_id = :worker_id AND status IN ('Accepted', 'On_The_Way', 'Arrived', 'In_Progress') LIMIT 1");
$busyStmt->execute([':worker_id' => $worker_id]);

if ($busyStmt->rowCount() > 0) {
    echo json_encode(["success" => true, "is_busy" => true, "requests" => []]);
    exit;
}

// 2. FETCH THE WORKER'S PERSONAL ATTRIBUTES
$workerStmt = $db->prepare("SELECT gender, race, spoken_language FROM users WHERE id = :id LIMIT 1");
$workerStmt->execute([':id' => $worker_id]);
$worker = $workerStmt->fetch(PDO::FETCH_ASSOC);

$w_gender = $worker ? $worker['gender'] : '';
$w_race = $worker ? $worker['race'] : '';
$w_lang = $worker ? $worker['spoken_language'] : '';

// 3. SMART MATCHING: Fetch "Pending" bookings within 5 KM that match the Worker's attributes
if ($worker_lat != 0 && $worker_lng != 0) {
    $query = "SELECT id, patient_name as client_name, service_needed, pickup_location as location, 
              DATE_FORMAT(created_at, '%b %d, %h:%i %p') as date, 
              CONCAT(medical_condition, ' - ', special_needs) as details,
              (6371 * acos(cos(radians(:w_lat)) * cos(radians(pickup_lat)) * cos(radians(pickup_lng) - radians(:w_lng)) + sin(radians(:w_lat)) * sin(radians(pickup_lat)))) AS distance 
              FROM bookings 
              WHERE status = 'Pending' 
              AND (worker_id IS NULL OR worker_id != :w_id) 
              AND (preferred_gender = 'Any' OR preferred_gender = :w_gender)
              AND (preferred_language = 'Any' OR preferred_language = :w_lang)
              AND (preferred_race = 'Any' OR preferred_race = :w_race)
              AND pickup_lat IS NOT NULL 
              AND pickup_lng IS NOT NULL 
              HAVING distance <= 5 
              ORDER BY distance ASC, created_at DESC";
              
    $stmt = $db->prepare($query);
    $stmt->bindParam(':w_lat', $worker_lat);
    $stmt->bindParam(':w_lng', $worker_lng);
    $stmt->bindParam(':w_id', $worker_id); 
    
    // Bind the worker's actual identity to test against the client's preferences
    $stmt->bindParam(':w_gender', $w_gender); 
    $stmt->bindParam(':w_lang', $w_lang); 
    $stmt->bindParam(':w_race', $w_race); 

    $stmt->execute();
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
} else {
    $requests = [];
}

echo json_encode(["success" => true, "is_busy" => false, "requests" => $requests]);
?>
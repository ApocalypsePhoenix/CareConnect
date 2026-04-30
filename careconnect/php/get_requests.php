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

// 3. SMART MATCHING: Fetch "Pending" bookings
if ($worker_lat != 0 && $worker_lng != 0) {
    // ADDED: pickup_lat, pickup_lng, dropoff_lat, dropoff_lng for the exact distance math
    $query = "SELECT b.id, b.patient_name, b.patient_age, b.medical_condition, b.special_needs,
              b.service_needed, b.pickup_location as location, 
              b.pickup_lat, b.pickup_lng, b.dropoff_lat, b.dropoff_lng,
              b.expected_duration as duration,
              DATE_FORMAT(b.created_at, '%b %d, %h:%i %p') as date, 
              u.name as client_name, u.phone as client_phone, u.profile_image as client_image,
              (6371 * acos(cos(radians(:w_lat)) * cos(radians(b.pickup_lat)) * cos(radians(b.pickup_lng) - radians(:w_lng)) + sin(radians(:w_lat)) * sin(radians(b.pickup_lat)))) AS distance 
              FROM bookings b
              JOIN users u ON b.client_id = u.id
              WHERE b.status = 'Pending' 
              AND (b.worker_id IS NULL OR b.worker_id != :w_id) 
              AND (b.preferred_gender = 'Any' OR b.preferred_gender = :w_gender)
              AND (b.preferred_language = 'Any' OR b.preferred_language = :w_lang)
              AND (b.preferred_race = 'Any' OR b.preferred_race = :w_race)
              AND b.pickup_lat IS NOT NULL 
              AND b.pickup_lng IS NOT NULL 
              HAVING distance <= 5 
              ORDER BY distance ASC, b.created_at DESC";
              
    $stmt = $db->prepare($query);
    $stmt->bindParam(':w_lat', $worker_lat);
    $stmt->bindParam(':w_lng', $worker_lng);
    $stmt->bindParam(':w_id', $worker_id); 
    
    $stmt->bindParam(':w_gender', $w_gender); 
    $stmt->bindParam(':w_lang', $w_lang); 
    $stmt->bindParam(':w_race', $w_race); 

    $stmt->execute();
    $requests = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // --- APPLY THE EXACT MATH FROM FLUTTER TO CALCULATE THE PAYMENT ---
    foreach ($requests as &$req) {
        $serviceAmount = 0.0;
        $serviceType = $req['service_needed'] ?? '';
        $durationStr = $req['duration'] ?? '1 hour';
        
        // Extract hours (e.g. "2 hours" -> 2)
        preg_match('/(\d+)/', $durationStr, $matches);
        $hours = isset($matches[1]) ? (int)$matches[1] : 1;
        
        if ($serviceType == 'Mobility Service') {
            $baseFee = 15.0; 
            $hourlyRate = 10.0; 
            $distanceFee = 0.0;
            
            // Replicate Geolocator.distanceBetween() in PHP
            if (!empty($req['pickup_lat']) && !empty($req['dropoff_lat'])) {
                $pLat = (float)$req['pickup_lat'];
                $pLng = (float)$req['pickup_lng'];
                $dLat = (float)$req['dropoff_lat'];
                $dLng = (float)$req['dropoff_lng'];
                
                $earthRadius = 6371000; // in meters
                $dLatRad = deg2rad($dLat - $pLat);
                $dLonRad = deg2rad($dLng - $pLng);
                $a = sin($dLatRad/2) * sin($dLatRad/2) + cos(deg2rad($pLat)) * cos(deg2rad($dLat)) * sin($dLonRad/2) * sin($dLonRad/2);
                $c = 2 * atan2(sqrt($a), sqrt(1-$a));
                $distanceInMeters = $earthRadius * $c;
                
                $distanceFee = ($distanceInMeters / 1000) * 1.50; 
            }
            $serviceAmount = $baseFee + ($hours * $hourlyRate) + $distanceFee;
            
        } else if ($serviceType == 'Physiotherapy/Rehabilitation') {
            $serviceAmount = $hours * 50.0;
        } else {
            $serviceAmount = $hours * 30.0;
        }

        // Apply admin deduction (3%)
        $adminFee = $serviceAmount * 0.03; 
        $workerEarns = $serviceAmount - $adminFee;

        // Assign the calculated amount to the request object sent to the app
        if (empty($req['payment']) || (float)$req['payment'] == 0) {
            $updateStmt = $db->prepare("UPDATE bookings SET payment_amount = :payment WHERE id = :id");
            $updateStmt->execute([':payment' => $workerEarns, ':id' => $req['id']]);
        }

        $req['payment'] = number_format($workerEarns, 2, '.', '');
    }
} else {
    $requests = [];
}

echo json_encode(["success" => true, "is_busy" => false, "requests" => $requests]);
?>
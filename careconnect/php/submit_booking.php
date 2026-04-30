<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

// Handle both standard POST data and raw JSON (depending on how Flutter sends it)
$data = $_POST;
if (empty($data)) {
    $json = file_get_contents('php://input');
    $data = json_decode($json, true) ?: [];
}

// Ensure we at least have a client ID
if (empty($data['client_id'])) {
    echo json_encode(["success" => false, "message" => "Missing client ID or invalid data format."]);
    exit;
}

// Extract all the data from the request
$client_id = $data['client_id'];
$patient_name = $data['patient_name'] ?? '';
$patient_age = $data['patient_age'] ?? '';
$medical_condition = $data['medical_condition'] ?? '';
$special_needs = $data['special_needs'] ?? '';
$service_needed = $data['service_needed'] ?? '';
$pickup_location = $data['pickup_location'] ?? '';
$pickup_lat = isset($data['pickup_lat']) && $data['pickup_lat'] !== '' ? (float)$data['pickup_lat'] : null;
$pickup_lng = isset($data['pickup_lng']) && $data['pickup_lng'] !== '' ? (float)$data['pickup_lng'] : null;
$dropoff_location = $data['dropoff_location'] ?? '';
$dropoff_lat = isset($data['dropoff_lat']) && $data['dropoff_lat'] !== '' ? (float)$data['dropoff_lat'] : null;
$dropoff_lng = isset($data['dropoff_lng']) && $data['dropoff_lng'] !== '' ? (float)$data['dropoff_lng'] : null;
$expected_duration = $data['expected_duration'] ?? '1 hour';
$preferred_language = $data['preferred_language'] ?? 'Any';
$preferred_gender = $data['preferred_gender'] ?? 'Any';
$preferred_race = $data['preferred_race'] ?? 'Any';

// ====================================================================
// 1. EXACT MATH CALCULATION (Same as Flutter App)
// ====================================================================
$serviceAmount = 0.0;
preg_match('/(\d+)/', $expected_duration, $matches);
$hours = isset($matches[1]) ? (int)$matches[1] : 1;

if ($service_needed == 'Mobility Service') {
    $baseFee = 15.0; 
    $hourlyRate = 10.0; 
    $distanceFee = 0.0;
    
    // Calculate distance if coordinates are provided
    if ($pickup_lat !== null && $dropoff_lat !== null) {
        $earthRadius = 6371000; // in meters
        $dLatRad = deg2rad($dropoff_lat - $pickup_lat);
        $dLonRad = deg2rad($dropoff_lng - $pickup_lng);
        $a = sin($dLatRad/2) * sin($dLatRad/2) + cos(deg2rad($pickup_lat)) * cos(deg2rad($dropoff_lat)) * sin($dLonRad/2) * sin($dLonRad/2);
        $c = 2 * atan2(sqrt($a), sqrt(1-$a));
        $distanceInMeters = $earthRadius * $c;
        
        $distanceFee = ($distanceInMeters / 1000) * 1.50; 
    }
    $serviceAmount = $baseFee + ($hours * $hourlyRate) + $distanceFee;
    
} else if ($service_needed == 'Physiotherapy/Rehabilitation') {
    $serviceAmount = $hours * 50.0;
} else {
    // Daily Assistance / Nursing Care
    $serviceAmount = $hours * 30.0;
}

// Deduct 3% Admin Fee to get Worker's Earnings
$adminFee = $serviceAmount * 0.03; 
$workerEarns = $serviceAmount - $adminFee;
$payment_amount = number_format($workerEarns, 2, '.', '');

// ====================================================================
// 2. INSERT INTO DATABASE (Now includes payment_amount!)
// ====================================================================
try {
    $query = "INSERT INTO bookings (
                client_id, patient_name, patient_age, medical_condition, special_needs, 
                service_needed, pickup_location, pickup_lat, pickup_lng, 
                dropoff_location, dropoff_lat, dropoff_lng, 
                expected_duration, preferred_language, preferred_gender, preferred_race, 
                payment_amount, status
              ) VALUES (
                :client_id, :patient_name, :patient_age, :medical_condition, :special_needs, 
                :service_needed, :pickup_location, :pickup_lat, :pickup_lng, 
                :dropoff_location, :dropoff_lat, :dropoff_lng, 
                :expected_duration, :preferred_language, :preferred_gender, :preferred_race, 
                :payment_amount, 'Pending'
              )";
              
    $stmt = $db->prepare($query);
    
    // Bind all parameters
    $stmt->bindParam(':client_id', $client_id);
    $stmt->bindParam(':patient_name', $patient_name);
    $stmt->bindParam(':patient_age', $patient_age);
    $stmt->bindParam(':medical_condition', $medical_condition);
    $stmt->bindParam(':special_needs', $special_needs);
    $stmt->bindParam(':service_needed', $service_needed);
    $stmt->bindParam(':pickup_location', $pickup_location);
    $stmt->bindParam(':pickup_lat', $pickup_lat);
    $stmt->bindParam(':pickup_lng', $pickup_lng);
    $stmt->bindParam(':dropoff_location', $dropoff_location);
    $stmt->bindParam(':dropoff_lat', $dropoff_lat);
    $stmt->bindParam(':dropoff_lng', $dropoff_lng);
    $stmt->bindParam(':expected_duration', $expected_duration);
    $stmt->bindParam(':preferred_language', $preferred_language);
    $stmt->bindParam(':preferred_gender', $preferred_gender);
    $stmt->bindParam(':preferred_race', $preferred_race);
    
    // Bind the newly calculated payment amount!
    $stmt->bindParam(':payment_amount', $payment_amount);

    if ($stmt->execute()) {
        $booking_id = $db->lastInsertId();
        echo json_encode([
            "success" => true, 
            "message" => "Booking submitted successfully!", 
            "booking_id" => $booking_id,
            "calculated_payment" => $payment_amount // Send back just so the app knows!
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Failed to submit booking."]);
    }

} catch (PDOException $e) {
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
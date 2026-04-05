<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"), true);

if (!empty($data['client_id']) && !empty($data['service_needed'])) {
    try {
        $query = "INSERT INTO bookings (client_id, patient_name, patient_age, medical_condition, special_needs, service_needed, pickup_location, pickup_lat, pickup_lng, dropoff_location, dropoff_lat, dropoff_lng, expected_duration, preferred_language, preferred_gender) 
                  VALUES (:client_id, :patient_name, :patient_age, :medical_condition, :special_needs, :service_needed, :pickup_location, :pickup_lat, :pickup_lng, :dropoff_location, :dropoff_lat, :dropoff_lng, :expected_duration, :preferred_language, :preferred_gender)";
        
        $stmt = $db->prepare($query);
        $stmt->execute([
            ':client_id' => $data['client_id'],
            ':patient_name' => $data['patient_name'],
            ':patient_age' => $data['patient_age'],
            ':medical_condition' => $data['medical_condition'],
            ':special_needs' => $data['special_needs'],
            ':service_needed' => $data['service_needed'],
            ':pickup_location' => $data['pickup_location'],
            ':pickup_lat' => $data['pickup_lat'],
            ':pickup_lng' => $data['pickup_lng'],
            ':dropoff_location' => $data['dropoff_location'],
            ':dropoff_lat' => $data['dropoff_lat'],
            ':dropoff_lng' => $data['dropoff_lng'],
            ':expected_duration' => $data['expected_duration'],
            ':preferred_language' => $data['preferred_language'],
            ':preferred_gender' => $data['preferred_gender']
        ]);

        echo json_encode(["success" => true, "message" => "Booking submitted successfully!"]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Error: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Incomplete data."]);
}
?>
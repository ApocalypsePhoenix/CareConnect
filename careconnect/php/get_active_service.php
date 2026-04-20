<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$client_id = isset($_GET['client_id']) ? $_GET['client_id'] : null;
$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : null;

try {
    if ($worker_id) {
        // ADDED 'Pending_Payment' TO THE IN CLAUSE
        $stmt = $db->prepare("SELECT b.*, u.name as client_name, u.phone as client_phone 
                              FROM bookings b JOIN users u ON b.client_id = u.id 
                              WHERE b.worker_id = :w_id AND b.status IN ('Pending_Approval', 'Accepted', 'On_The_Way', 'Arrived', 'In_Progress', 'Pending_Payment') LIMIT 1");
        $stmt->execute([':w_id' => $worker_id]);
    } else if ($client_id) {
        // ADDED 'Pending_Payment' TO THE IN CLAUSE
        $stmt = $db->prepare("SELECT b.*, u.name as worker_name, u.phone as worker_phone, u.gender as worker_gender, u.age as worker_age, u.race as worker_race, u.spoken_language as worker_language, w.profile_pic_url as worker_passport 
                              FROM bookings b 
                              JOIN users u ON b.worker_id = u.id 
                              LEFT JOIN worker_details w ON u.id = w.user_id
                              WHERE b.client_id = :c_id AND b.status IN ('Pending_Approval', 'Accepted', 'On_The_Way', 'Arrived', 'In_Progress', 'Pending_Payment') LIMIT 1");
        $stmt->execute([':c_id' => $client_id]);
    } else {
        echo json_encode(["success" => false, "message" => "Missing ID"]);
        exit;
    }

    if ($stmt->rowCount() > 0) {
        $service = $stmt->fetch(PDO::FETCH_ASSOC);
        echo json_encode(["success" => true, "has_service" => true, "service" => $service]);
    } else {
        echo json_encode(["success" => true, "has_service" => false]);
    }
} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php';
$db = (new Database())->getConnection();
$data = json_decode(file_get_contents("php://input"), true);

if (isset($data['worker_id']) && isset($data['is_online'])) {
    $stmt = $db->prepare("UPDATE worker_details SET is_available = :online WHERE user_id = :id");
    $stmt->execute([':online' => $data['is_online'], ':id' => $data['worker_id']]);
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["success" => false]);
}
?>
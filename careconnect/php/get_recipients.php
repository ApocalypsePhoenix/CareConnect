<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

if (!empty($_GET['user_id'])) {
    try {
        $query = "SELECT id, name, age, relationship, medical_condition, special_needs 
                  FROM recipients 
                  WHERE user_id = :user_id 
                  ORDER BY created_at DESC";
        
        $stmt = $db->prepare($query);
        $stmt->bindParam(':user_id', $_GET['user_id']);
        $stmt->execute();

        $recipients = $stmt->fetchAll(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode(array("success" => true, "recipients" => $recipients));
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(array("success" => false, "message" => "Server error."));
    }
} else {
    http_response_code(400);
    echo json_encode(array("success" => false, "message" => "User ID is required."));
}
?>
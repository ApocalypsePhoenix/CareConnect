<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

try {
    $query = "SELECT s.id, s.user_id, s.role, s.topic, s.message, s.status, s.created_at, 
                     u.name as user_name, u.email as user_email
              FROM support_tickets s
              LEFT JOIN users u ON s.user_id = u.id
              ORDER BY s.created_at DESC";
              
    $stmt = $db->prepare($query);
    $stmt->execute();
    
    $tickets = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(["success" => true, "tickets" => $tickets]);
} catch (PDOException $e) {
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
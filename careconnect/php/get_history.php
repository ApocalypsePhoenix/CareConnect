<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_connect.php';
$db = (new Database())->getConnection();

$client_id = isset($_GET['client_id']) ? $_GET['client_id'] : null;
$worker_id = isset($_GET['worker_id']) ? $_GET['worker_id'] : null;

try {
    if ($client_id) {
        // Fetch history for the Client
        $stmt = $db->prepare("
            SELECT b.*, w.name as worker_name, DATE_FORMAT(b.created_at, '%b %d, %Y - %h:%i %p') as formatted_date 
            FROM bookings b 
            LEFT JOIN users w ON b.worker_id = w.id 
            WHERE b.client_id = :id AND b.status IN ('Completed', 'Cancelled')
            ORDER BY b.created_at DESC
        ");
        $stmt->execute([':id' => $client_id]);
    } else if ($worker_id) {
        // Fetch history for the Worker
        $stmt = $db->prepare("
            SELECT b.*, c.name as client_name, DATE_FORMAT(b.created_at, '%b %d, %Y - %h:%i %p') as formatted_date 
            FROM bookings b 
            JOIN users c ON b.client_id = c.id 
            WHERE b.worker_id = :id AND b.status IN ('Completed', 'Cancelled')
            ORDER BY b.created_at DESC
        ");
        $stmt->execute([':id' => $worker_id]);
    } else {
        echo json_encode(["success" => false, "message" => "Missing ID"]);
        exit;
    }

    $history = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(["success" => true, "history" => $history]);

} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
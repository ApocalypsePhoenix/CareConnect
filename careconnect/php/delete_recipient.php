<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php'; 

$database = new Database();
$db = $database->getConnection();

if (isset($_POST['id'])) {
    $id = $_POST['id'];
    
    try {
        // Securely prepare the DELETE statement using PDO
        $query = "DELETE FROM recipients WHERE id = :id";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':id', $id);
        
        if ($stmt->execute()) {
            // Check if a row was actually deleted
            if ($stmt->rowCount() > 0) {
                echo json_encode(["success" => true, "message" => "Recipient deleted successfully."]);
            } else {
                echo json_encode(["success" => false, "message" => "Recipient not found or already deleted."]);
            }
        } else {
            echo json_encode(["success" => false, "message" => "Database error: Failed to delete."]);
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Server error: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Missing Recipient ID. Check if Flutter is sending 'id'."]);
}
?>
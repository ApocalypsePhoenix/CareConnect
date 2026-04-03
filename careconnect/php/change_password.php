<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

include_once 'db_connect.php'; 

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"), true);

if (!empty($data['user_id']) && !empty($data['current_password']) && !empty($data['new_password'])) {
    try {
        // Fetch current password hash from database
        $query = "SELECT password_hash FROM users WHERE id = :id";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':id', $data['user_id']);
        $stmt->execute();

        if ($stmt->rowCount() > 0) {
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            
            // Verify if the old password they typed matches the database
            if (password_verify($data['current_password'], $row['password_hash'])) {
                
                // Hash the new password securely
                $new_hash = password_hash($data['new_password'], PASSWORD_BCRYPT);
                
                // Save the new password
                $updateQuery = "UPDATE users SET password_hash = :hash WHERE id = :id";
                $updateStmt = $db->prepare($updateQuery);
                $updateStmt->bindParam(':hash', $new_hash);
                $updateStmt->bindParam(':id', $data['user_id']);
                
                if ($updateStmt->execute()) {
                    echo json_encode(["success" => true, "message" => "Password updated successfully."]);
                } else {
                    echo json_encode(["success" => false, "message" => "Failed to update password."]);
                }
            } else {
                echo json_encode(["success" => false, "message" => "Current password is incorrect."]);
            }
        } else {
            echo json_encode(["success" => false, "message" => "User not found."]);
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Server error: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Incomplete data provided."]);
}
?>
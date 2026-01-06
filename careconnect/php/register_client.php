<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include_once 'db_connect.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"), true);

if (
    !empty($data['name']) &&
    !empty($data['email']) &&
    !empty($data['password']) &&
    !empty($data['age']) && // Ensure age is provided
    isset($data['recipients'])
) {
    try {
        $db->beginTransaction();

        // 1. Create the Main User Account (including age)
        $userQuery = "INSERT INTO users (name, ic_number, age, phone, gender, address, email, password_hash, role) 
                      VALUES (:name, :ic, :age, :phone, :gender, :address, :email, :password, :role)";
        
        $userStmt = $db->prepare($userQuery);
        $password_hash = password_hash($data['password'], PASSWORD_BCRYPT);

        $userStmt->bindParam(':name', $data['name']);
        $userStmt->bindParam(':ic', $data['ic_number']);
        $userStmt->bindParam(':age', $data['age']); // Bind age
        $userStmt->bindParam(':phone', $data['phone']);
        $userStmt->bindParam(':gender', $data['gender']);
        $userStmt->bindParam(':address', $data['address']);
        $userStmt->bindParam(':email', $data['email']);
        $userStmt->bindParam(':password', $password_hash);
        $userStmt->bindParam(':role', $data['role']);

        if (!$userStmt->execute()) {
            throw new Exception("Failed to create user account.");
        }

        $userId = $db->lastInsertId();

        // 2. Loop through and save all Care Recipients
        $recipientQuery = "INSERT INTO recipients (user_id, name, age, relationship, medical_condition, special_needs) 
                           VALUES (:user_id, :name, :age, :relationship, :condition, :needs)";
        
        $recipientStmt = $db->prepare($recipientQuery);

        foreach ($data['recipients'] as $recipient) {
            $recipientStmt->bindParam(':user_id', $userId);
            $recipientStmt->bindParam(':name', $recipient['name']);
            $recipientStmt->bindParam(':age', $recipient['age']);
            $recipientStmt->bindParam(':relationship', $recipient['relationship']);
            $recipientStmt->bindParam(':condition', $recipient['medical_condition']);
            $recipientStmt->bindParam(':needs', $recipient['special_needs']);

            if (!$recipientStmt->execute()) {
                throw new Exception("Failed to save recipient: " . $recipient['name']);
            }
        }

        $db->commit();
        http_response_code(201);
        echo json_encode(array("success" => true, "message" => "Registration successful.", "userId" => $userId));

    } catch (Exception $e) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        http_response_code(500);
        echo json_encode(array("success" => false, "message" => "Server Error: " . $e->getMessage()));
    }
} else {
    http_response_code(400);
    echo json_encode(array("success" => false, "message" => "Incomplete registration data."));
}
?>
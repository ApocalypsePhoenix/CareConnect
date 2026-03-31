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

        // --- Handle Profile Picture Upload ---
        $profileImagePath = null;
        if (!empty($data['profile_image'])) {
            // Determine folder based on role
            $roleFolder = (isset($data['role']) && $data['role'] === 'Worker') ? 'workers/' : 'clients/';
            
            // File system path (where PHP saves it, relative to the php/ folder)
            $systemUploadDir = '../images/' . $roleFolder;
            
            // Web path (what save in the database to fetch via URL later)
            $dbImagePath = 'images/' . $roleFolder;

            // Create the directory if it doesn't exist
            if (!is_dir($systemUploadDir)) {
                mkdir($systemUploadDir, 0755, true);
            }

            // Decode the Base64 string sent from Flutter
            $base64Data = $data['profile_image'];
            $decodedImage = base64_decode($base64Data);

            if ($decodedImage !== false) {
                // Generate a unique filename
                $fileName = uniqid('profile_') . '.jpg';
                $filePath = $systemUploadDir . $fileName;

                // Save the file to your Hostinger server
                if (file_put_contents($filePath, $decodedImage)) {
                    // Save relative web path to DB (e.g., "images/clients/profile_123.jpg")
                    $profileImagePath = $dbImagePath . $fileName; 
                }
            }
        }

        // 1. Create the Main User Account (including age and profile image)
        $userQuery = "INSERT INTO users (name, ic_number, age, phone, gender, address, email, password_hash, role, profile_image) 
                      VALUES (:name, :ic, :age, :phone, :gender, :address, :email, :password, :role, :profile_image)";
        
        $userStmt = $db->prepare($userQuery);
        $password_hash = password_hash($data['password'], PASSWORD_BCRYPT);

        $userStmt->bindParam(':name', $data['name']);
        $userStmt->bindParam(':ic', $data['ic_number']);
        $userStmt->bindParam(':age', $data['age']); 
        $userStmt->bindParam(':phone', $data['phone']);
        $userStmt->bindParam(':gender', $data['gender']);
        $userStmt->bindParam(':address', $data['address']);
        $userStmt->bindParam(':email', $data['email']);
        $userStmt->bindParam(':password', $password_hash);
        $userStmt->bindParam(':role', $data['role']);
        $userStmt->bindParam(':profile_image', $profileImagePath); // Bind the new image path

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
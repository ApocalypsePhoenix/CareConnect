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

if (!empty($data['id']) && !empty($data['name'])) {
    try {
        // 1. Fetch current user details to get role and existing image
        $roleStmt = $db->prepare("SELECT role, profile_image FROM users WHERE id = :id");
        $roleStmt->bindParam(':id', $data['id']);
        $roleStmt->execute();
        $currentUser = $roleStmt->fetch(PDO::FETCH_ASSOC);

        if (!$currentUser) {
            throw new Exception("User not found.");
        }

        $profileImagePath = $currentUser['profile_image']; // Keep existing image by default

        // 2. Handle Profile Picture Upload (if a new one was selected)
        if (!empty($data['profile_image_base64'])) {
            $roleFolder = ($currentUser['role'] === 'Worker') ? 'workers/' : 'clients/';
            $systemUploadDir = '../images/' . $roleFolder;
            $dbImagePath = 'images/' . $roleFolder;

            if (!is_dir($systemUploadDir)) {
                mkdir($systemUploadDir, 0755, true);
            }

            $decodedImage = base64_decode($data['profile_image_base64']);
            if ($decodedImage !== false) {
                $fileName = uniqid('profile_') . '.jpg';
                $filePath = $systemUploadDir . $fileName;
                
                if (file_put_contents($filePath, $decodedImage)) {
                    // Optional: Delete the old image from the server to save space
                    if (!empty($profileImagePath) && file_exists('../' . $profileImagePath)) {
                        unlink('../' . $profileImagePath);
                    }
                    $profileImagePath = $dbImagePath . $fileName; // Assign new path
                }
            }
        }

        // 3. Update the database (Now includes ic_number and gender)
        $updateQuery = "UPDATE users SET name=:name, ic_number=:ic_number, gender=:gender, phone=:phone, address=:address, age=:age, profile_image=:profile_image WHERE id=:id";
        $stmt = $db->prepare($updateQuery);
        $stmt->bindParam(':name', $data['name']);
        $stmt->bindParam(':ic_number', $data['ic_number']);
        $stmt->bindParam(':gender', $data['gender']);
        $stmt->bindParam(':phone', $data['phone']);
        $stmt->bindParam(':address', $data['address']);
        $stmt->bindParam(':age', $data['age']);
        $stmt->bindParam(':profile_image', $profileImagePath);
        $stmt->bindParam(':id', $data['id']);

        if ($stmt->execute()) {
            // 4. Fetch the updated user data to return back to the app
            // Make sure to fetch ic_number and gender to return them!
            $fetchStmt = $db->prepare("SELECT id, name, ic_number, gender, email, age, phone, address, role, profile_image FROM users WHERE id = :id");
            $fetchStmt->bindParam(':id', $data['id']);
            $fetchStmt->execute();
            $updatedUser = $fetchStmt->fetch(PDO::FETCH_ASSOC);

            http_response_code(200);
            echo json_encode(["success" => true, "message" => "Profile updated successfully.", "user" => $updatedUser]);
        } else {
            throw new Exception("Failed to update profile.");
        }

    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Server Error: " . $e->getMessage()]);
    }
} else {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete data provided."]);
}
?>
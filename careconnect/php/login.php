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

if (!empty($data['email']) && !empty($data['password'])) {
    try {
        // We use a LEFT JOIN to attach the worker's 'is_verified' status from the worker_details table
        $query = "SELECT u.id, u.name, u.ic_number, u.gender, u.email, u.age, u.phone, u.address, u.password_hash, u.role, u.profile_image, w.is_verified 
                  FROM users u 
                  LEFT JOIN worker_details w ON u.id = w.user_id 
                  WHERE u.email = :email LIMIT 1";
                  
        $stmt = $db->prepare($query);
        $stmt->bindParam(':email', $data['email']);
        $stmt->execute();

        if ($stmt->rowCount() > 0) {
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (password_verify($data['password'], $row['password_hash'])) {
                
                // --- UPDATED: Split Pending and Rejected Logic ---
                if ($row['role'] === 'Worker') {
                    
                    // Status 0: Pending Verification
                    if ($row['is_verified'] == 0) {
                        http_response_code(403); // 403 Forbidden
                        echo json_encode(array(
                            "success" => false, 
                            "message" => "Your account is pending verification by the admin. You cannot login yet."
                        ));
                        exit;
                    } 
                    // Status 2: Rejected Application
                    elseif ($row['is_verified'] == 2) {
                        http_response_code(403); // 403 Forbidden
                        echo json_encode(array(
                            "success" => false, 
                            "message" => "Your worker application has been rejected by the admin. Please review your documents or contact support."
                        ));
                        exit;
                    }
                }

                // If verified (or if it's a Client), proceed with login
                unset($row['password_hash']); // Do not send password back to the app
                unset($row['is_verified']);   // Hide the verification status from the frontend payload
                
                http_response_code(200);
                echo json_encode(array(
                    "success" => true, 
                    "message" => "Login successful.", 
                    "user" => $row
                ));
            } else {
                http_response_code(401);
                echo json_encode(array("success" => false, "message" => "Invalid email or password."));
            }
        } else {
            http_response_code(401);
            echo json_encode(array("success" => false, "message" => "Invalid email or password."));
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(array("success" => false, "message" => "Server error."));
    }
} else {
    http_response_code(400);
    echo json_encode(array("success" => false, "message" => "Email and password are required."));
}
?>
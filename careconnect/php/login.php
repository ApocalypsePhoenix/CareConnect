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
        // UPDATED: Added u.account_status, u.warning_count, u.average_rating
        $query = "SELECT u.id, u.name, u.ic_number, u.gender, u.race, u.spoken_language, u.email, u.age, u.phone, u.address, u.password_hash, u.role, u.profile_image, 
                         u.account_status, u.warning_count, u.average_rating,
                         w.is_verified, w.mobility_service, w.physio_service, w.nursing_service,
                         w.profile_pic_url, w.ic_doc_url, w.license_doc_url, w.cert_doc_url 
                  FROM users u 
                  LEFT JOIN worker_details w ON u.id = w.user_id 
                  WHERE u.email = :email LIMIT 1";
                  
        $stmt = $db->prepare($query);
        $stmt->bindParam(':email', $data['email']);
        $stmt->execute();

        if ($stmt->rowCount() > 0) {
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (password_verify($data['password'], $row['password_hash'])) {
                
                // CHECK IF USER IS BANNED
                if (isset($row['account_status']) && $row['account_status'] === 'Banned') {
                    http_response_code(403); // Forbidden
                    echo json_encode(array("success" => false, "message" => "ACCOUNT_BANNED"));
                    exit;
                }
                
                if ($row['role'] === 'Worker') {
                    if ($row['is_verified'] == 0) {
                        http_response_code(403); 
                        echo json_encode(array("success" => false, "message" => "Your account is pending verification by the admin. You cannot login yet."));
                        exit;
                    } elseif ($row['is_verified'] == 2) {
                        http_response_code(403); 
                        echo json_encode(array("success" => false, "message" => "Your worker application has been rejected by the admin. Please review your documents or contact support."));
                        exit;
                    }
                }

                unset($row['password_hash']); 
                unset($row['is_verified']);   
                
                http_response_code(200);
                echo json_encode(array("success" => true, "message" => "Login successful.", "user" => $row));
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
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

// Robust input check: Parse both raw JSON (application/json) and standard form inputs (x-www-form-urlencoded)
$data = json_decode(file_get_contents("php://input"), true);
if (empty($data)) {
    $data = $_POST;
}

$login_type = $data['login_type'] ?? 'standard';

if ($login_type === 'google') {
    $email = $data['email'] ?? '';
    $id_token = $data['id_token'] ?? '';

    if (empty($email) || empty($id_token)) {
        http_response_code(400);
        echo json_encode(array("success" => false, "message" => "Email and verification ID token are required for Google login."));
        exit;
    }

    // Securely verify Google ID token authenticity directly with Google's public token check endpoint
    $url = "https://oauth2.googleapis.com/tokeninfo?id_token=" . urlencode($id_token);
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($http_code === 200) {
        $token_info = json_decode($response, true);
        $verified_email = $token_info['email'] ?? '';

        // Double check verified email against request payload to prevent target spoofing
        if (strtolower($verified_email) !== strtolower($email)) {
            http_response_code(401);
            echo json_encode(array("success" => false, "message" => "Security verification mismatch. Sign-in canceled."));
            exit;
        }

        try {
            // Retrieve fully localized user details using verified Google Email
            $query = "SELECT u.id, u.name, u.ic_number, u.gender, u.race, u.spoken_language, u.email, u.age, u.phone, u.address, u.password_hash, u.role, u.profile_image, 
                             u.account_status, u.warning_count, u.average_rating,
                             w.is_verified, w.mobility_service, w.physio_service, w.nursing_service,
                             w.profile_pic_url, w.ic_doc_url, w.license_doc_url, w.cert_doc_url 
                      FROM users u 
                      LEFT JOIN worker_details w ON u.id = w.user_id 
                      WHERE u.email = :email LIMIT 1";
                      
            $stmt = $db->prepare($query);
            $stmt->bindParam(':email', $email);
            $stmt->execute();

            if ($stmt->rowCount() > 0) {
                $row = $stmt->fetch(PDO::FETCH_ASSOC);

                // CHECK IF ACCOUNT IS BANNED
                if (isset($row['account_status']) && $row['account_status'] === 'Banned') {
                    http_response_code(403); // Forbidden
                    echo json_encode(array("success" => false, "message" => "ACCOUNT_BANNED"));
                    exit;
                }

                // Check Worker Validation Status 
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

                // Exclude raw security vectors from payload response
                unset($row['password_hash']); 
                unset($row['is_verified']);   
                
                http_response_code(200);
                echo json_encode(array("success" => true, "status" => "success", "message" => "Login successful.", "user" => $row));
            } else {
                http_response_code(444); // Distinct Custom status: Email verified with Google, but unregistered in CareConnect database
                echo json_encode(array("success" => false, "message" => "This Google account is not registered. Please sign up first."));
            }
        } catch (Exception $e) {
            http_response_code(500);
            echo json_encode(array("success" => false, "message" => "Server error."));
        }
    } else {
        http_response_code(401);
        echo json_encode(array("success" => false, "message" => "Google token authentication failed."));
    }

} else {
    // Standard credential verification flow
    if (!empty($data['email']) && !empty($data['password'])) {
        try {
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
                    
                    // CHECK IF ACCOUNT IS BANNED
                    if (isset($row['account_status']) && $row['account_status'] === 'Banned') {
                        http_response_code(403); // Forbidden
                        echo json_encode(array("success" => false, "message" => "ACCOUNT_BANNED"));
                        exit;
                    }
                    
                    // Check Worker Validation Status
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
                    echo json_encode(array("success" => true, "status" => "success", "message" => "Login successful.", "user" => $row));
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
}
?>
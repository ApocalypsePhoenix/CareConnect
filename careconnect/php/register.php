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

// Validation modified to ensure we have the core user data
if (
    !empty($data['name']) &&
    !empty($data['email']) &&
    !empty($data['password']) &&
    !empty($data['age']) && 
    !empty($data['role'])
) {
    try {
        $db->beginTransaction();

        // --- 1. Handle Profile Picture Upload ---
        $profileImagePath = null;
        if (!empty($data['profile_image'])) {
            $roleFolder = ($data['role'] === 'Worker') ? 'workers/' : 'clients/';
            $systemUploadDir = '../images/' . $roleFolder;
            $dbImagePath = 'images/' . $roleFolder;

            if (!is_dir($systemUploadDir)) {
                mkdir($systemUploadDir, 0755, true);
            }

            $decodedImage = base64_decode($data['profile_image']);
            if ($decodedImage !== false) {
                $fileName = uniqid('profile_') . '.jpg';
                $filePath = $systemUploadDir . $fileName;

                if (file_put_contents($filePath, $decodedImage)) {
                    $profileImagePath = $dbImagePath . $fileName; 
                }
            }
        }

        // --- 2. Handle Worker PDF Documents Upload ---
        $passportDocPath = null;
        $icDocPath = null;
        $licenseDocPath = null;
        $certDocPath = null;

        if ($data['role'] === 'Worker') {
            $workerDocsDir = '../images/workers/docs/';
            $dbDocsPath = 'images/workers/docs/';
            
            if (!is_dir($workerDocsDir)) {
                mkdir($workerDocsDir, 0755, true);
            }

            // Decode and save Passport Image
            if (!empty($data['passport_image'])) {
                $decodedPassport = base64_decode($data['passport_image']);
                if ($decodedPassport !== false) {
                    $fileName = uniqid('passport_') . '.jpg';
                    if (file_put_contents($workerDocsDir . $fileName, $decodedPassport)) {
                        $passportDocPath = $dbDocsPath . $fileName;
                    }
                }
            }

            // Decode and save IC PDF
            if (!empty($data['ic_image'])) {
                $decodedIc = base64_decode($data['ic_image']);
                if ($decodedIc !== false) {
                    $fileName = uniqid('ic_') . '.pdf';
                    if (file_put_contents($workerDocsDir . $fileName, $decodedIc)) {
                        $icDocPath = $dbDocsPath . $fileName;
                    }
                }
            }

            // Decode and save Driving License PDF
            if (!empty($data['license_image'])) {
                $decodedLicense = base64_decode($data['license_image']);
                if ($decodedLicense !== false) {
                    $fileName = uniqid('license_') . '.pdf';
                    if (file_put_contents($workerDocsDir . $fileName, $decodedLicense)) {
                        $licenseDocPath = $dbDocsPath . $fileName;
                    }
                }
            }

            // Decode and save Certificate PDF
            if (!empty($data['cert_image'])) {
                $decodedCert = base64_decode($data['cert_image']);
                if ($decodedCert !== false) {
                    $fileName = uniqid('cert_') . '.pdf';
                    if (file_put_contents($workerDocsDir . $fileName, $decodedCert)) {
                        $certDocPath = $dbDocsPath . $fileName;
                    }
                }
            }
        }

        // --- 3. Create the Main User Account ---
        // INCLUDES race and spoken_language
        $userQuery = "INSERT INTO users (name, ic_number, age, phone, gender, race, spoken_language, address, email, password_hash, role, profile_image) 
                      VALUES (:name, :ic, :age, :phone, :gender, :race, :language, :address, :email, :password, :role, :profile_image)";
        
        $userStmt = $db->prepare($userQuery);
        $password_hash = password_hash($data['password'], PASSWORD_BCRYPT);

        $userStmt->bindParam(':name', $data['name']);
        $userStmt->bindParam(':ic', $data['ic_number']);
        $userStmt->bindParam(':age', $data['age']); 
        $userStmt->bindParam(':phone', $data['phone']);
        $userStmt->bindParam(':gender', $data['gender']);
        
        // Bind the new race and language variables with defaults
        $race = !empty($data['race']) ? $data['race'] : 'Malay';
        $language = !empty($data['spoken_language']) ? $data['spoken_language'] : 'Malay';
        $userStmt->bindParam(':race', $race); 
        $userStmt->bindParam(':language', $language); 

        $userStmt->bindParam(':address', $data['address']);
        $userStmt->bindParam(':email', $data['email']);
        $userStmt->bindParam(':password', $password_hash);
        $userStmt->bindParam(':role', $data['role']);
        $userStmt->bindParam(':profile_image', $profileImagePath);

        if (!$userStmt->execute()) {
            throw new Exception("Failed to create user account.");
        }

        $userId = $db->lastInsertId();

        // --- 4. Handle Role-Specific Data ---
        
        if ($data['role'] === 'Worker' && isset($data['worker_services'])) {
            $servicesQuery = "INSERT INTO worker_details 
                              (user_id, mobility_service, physio_service, nursing_service, is_verified, profile_pic_url, ic_doc_url, license_doc_url, cert_doc_url) 
                              VALUES (:user_id, :mobility, :physio, :nursing, 0, :profile_pic, :ic_doc, :license_doc, :cert_doc)";
            
            $servicesStmt = $db->prepare($servicesQuery);
            
            $mobility = !empty($data['worker_services']['Mobility Service']) ? 1 : 0;
            $physio = !empty($data['worker_services']['Physiotherapy/Rehabilitation']) ? 1 : 0;
            $nursing = !empty($data['worker_services']['Daily Assistance/Nursing Care']) ? 1 : 0;

            $servicesStmt->bindParam(':user_id', $userId);
            $servicesStmt->bindParam(':mobility', $mobility);
            $servicesStmt->bindParam(':physio', $physio);
            $servicesStmt->bindParam(':nursing', $nursing);
            $servicesStmt->bindParam(':profile_pic', $passportDocPath); 
            $servicesStmt->bindParam(':ic_doc', $icDocPath);
            $servicesStmt->bindParam(':license_doc', $licenseDocPath);
            $servicesStmt->bindParam(':cert_doc', $certDocPath);

            if (!$servicesStmt->execute()) {
                throw new Exception("Failed to save worker details and documents.");
            }
        } 
        elseif ($data['role'] === 'Client' && isset($data['recipients']) && is_array($data['recipients'])) {
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
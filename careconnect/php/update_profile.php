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
        $db->beginTransaction();

        // 1. Fetch current user details (UPDATED to get current services)
        $roleStmt = $db->prepare("SELECT u.role, u.profile_image, u.race, u.spoken_language, w.mobility_service, w.physio_service, w.nursing_service FROM users u LEFT JOIN worker_details w ON u.id = w.user_id WHERE u.id = :id");
        $roleStmt->bindParam(':id', $data['id']);
        $roleStmt->execute();
        $currentUser = $roleStmt->fetch(PDO::FETCH_ASSOC);

        if (!$currentUser) {
            throw new Exception("User not found.");
        }

        $profileImagePath = $currentUser['profile_image']; 

        // 2. Handle Profile Picture Upload (General Avatar)
        if (!empty($data['profile_image_base64'])) {
            $roleFolder = ($currentUser['role'] === 'Worker') ? 'workers/' : 'clients/';
            $systemUploadDir = '../images/' . $roleFolder;
            $dbImagePath = 'images/' . $roleFolder;

            if (!is_dir($systemUploadDir)) mkdir($systemUploadDir, 0755, true);

            $decodedImage = base64_decode($data['profile_image_base64']);
            if ($decodedImage !== false) {
                $fileName = uniqid('profile_') . '.jpg';
                $filePath = $systemUploadDir . $fileName;
                
                if (file_put_contents($filePath, $decodedImage)) {
                    if (!empty($profileImagePath) && file_exists('../' . $profileImagePath)) {
                        unlink('../' . $profileImagePath);
                    }
                    $profileImagePath = $dbImagePath . $fileName; 
                }
            }
        }

        $race = isset($data['race']) ? $data['race'] : $currentUser['race'];
        $language = isset($data['spoken_language']) ? $data['spoken_language'] : $currentUser['spoken_language'];

        // 3. Update the main users table
        $updateQuery = "UPDATE users SET name=:name, ic_number=:ic_number, gender=:gender, race=:race, spoken_language=:lang, phone=:phone, address=:address, age=:age, profile_image=:profile_image WHERE id=:id";
        $stmt = $db->prepare($updateQuery);
        $stmt->execute([
            ':name' => $data['name'], ':ic_number' => $data['ic_number'], ':gender' => $data['gender'],
            ':race' => $race, ':lang' => $language, ':phone' => $data['phone'], 
            ':address' => $data['address'], ':age' => $data['age'], ':profile_image' => $profileImagePath, ':id' => $data['id']
        ]);

        // 4. Update worker_details and Handle New Document Uploads
        if ($currentUser['role'] === 'Worker') {
            $docsUpdated = false;
            $workerDocsDir = '../images/workers/docs/';
            $dbDocsPath = 'images/workers/docs/';
            if (!is_dir($workerDocsDir)) mkdir($workerDocsDir, 0755, true);

            // Handle Passport
            if (!empty($data['passport_image_base64'])) {
                $decoded = base64_decode($data['passport_image_base64']);
                if ($decoded !== false) {
                    $fileName = uniqid('passport_') . '.jpg';
                    if (file_put_contents($workerDocsDir . $fileName, $decoded)) {
                        $db->prepare("UPDATE worker_details SET profile_pic_url = :path WHERE user_id = :id")->execute([':path' => $dbDocsPath . $fileName, ':id' => $data['id']]);
                        $docsUpdated = true;
                    }
                }
            }
            // Handle IC
            if (!empty($data['ic_image_base64'])) {
                $decoded = base64_decode($data['ic_image_base64']);
                if ($decoded !== false) {
                    $fileName = uniqid('ic_') . '.pdf';
                    if (file_put_contents($workerDocsDir . $fileName, $decoded)) {
                        $db->prepare("UPDATE worker_details SET ic_doc_url = :path WHERE user_id = :id")->execute([':path' => $dbDocsPath . $fileName, ':id' => $data['id']]);
                        $docsUpdated = true;
                    }
                }
            }
            // Handle License
            if (!empty($data['license_image_base64'])) {
                $decoded = base64_decode($data['license_image_base64']);
                if ($decoded !== false) {
                    $fileName = uniqid('license_') . '.pdf';
                    if (file_put_contents($workerDocsDir . $fileName, $decoded)) {
                        $db->prepare("UPDATE worker_details SET license_doc_url = :path WHERE user_id = :id")->execute([':path' => $dbDocsPath . $fileName, ':id' => $data['id']]);
                        $docsUpdated = true;
                    }
                }
            }
            // Handle Cert
            if (!empty($data['cert_image_base64'])) {
                $decoded = base64_decode($data['cert_image_base64']);
                if ($decoded !== false) {
                    $fileName = uniqid('cert_') . '.pdf';
                    if (file_put_contents($workerDocsDir . $fileName, $decoded)) {
                        $db->prepare("UPDATE worker_details SET cert_doc_url = :path WHERE user_id = :id")->execute([':path' => $dbDocsPath . $fileName, ':id' => $data['id']]);
                        $docsUpdated = true;
                    }
                }
            }

            // Update Services Checkboxes
            if (isset($data['worker_services'])) {
                $mob = !empty($data['worker_services']['Mobility Service']) ? 1 : 0;
                $phy = !empty($data['worker_services']['Physiotherapy/Rehabilitation']) ? 1 : 0;
                $nur = !empty($data['worker_services']['Daily Assistance/Nursing Care']) ? 1 : 0;
                
                // NEW: If services changed, flag for admin review!
                if ($mob != $currentUser['mobility_service'] || $phy != $currentUser['physio_service'] || $nur != $currentUser['nursing_service']) {
                    $docsUpdated = true;
                }

                $servicesQuery = "UPDATE worker_details SET mobility_service=:mob, physio_service=:phy, nursing_service=:nur WHERE user_id=:id";
                $servStmt = $db->prepare($servicesQuery);
                $servStmt->execute([':mob' => $mob, ':phy' => $phy, ':nur' => $nur, ':id' => $data['id']]);
            }

            // If any documents OR services were updated, flag them for Admin Review (Status 3 = Soft Pending)
            if ($docsUpdated) {
                $db->prepare("UPDATE worker_details SET is_verified = 3 WHERE user_id = :id")->execute([':id' => $data['id']]);
            }
        }

        $db->commit();

        // 5. Fetch the updated user data to return back to the app (UPDATED to fetch URLs)
        $fetchStmt = $db->prepare("SELECT u.id, u.name, u.ic_number, u.gender, u.race, u.spoken_language, u.email, u.age, u.phone, u.address, u.role, u.profile_image, 
                                          w.mobility_service, w.physio_service, w.nursing_service, w.profile_pic_url, w.ic_doc_url, w.license_doc_url, w.cert_doc_url 
                                   FROM users u LEFT JOIN worker_details w ON u.id = w.user_id WHERE u.id = :id");
        $fetchStmt->bindParam(':id', $data['id']);
        $fetchStmt->execute();
        $updatedUser = $fetchStmt->fetch(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode(["success" => true, "message" => "Profile updated successfully.", "user" => $updatedUser]);

    } catch (Exception $e) {
        if ($db->inTransaction()) $db->rollBack();
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Server Error: " . $e->getMessage()]);
    }
} else {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete data provided."]);
}
?>
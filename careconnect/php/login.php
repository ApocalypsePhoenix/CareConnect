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
        // Select age as well
        $query = "SELECT id, name, email, age, password_hash, role FROM users WHERE email = :email LIMIT 1";
        $stmt = $db->prepare($query);
        $stmt->bindParam(':email', $data['email']);
        $stmt->execute();

        if ($stmt->rowCount() > 0) {
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (password_verify($data['password'], $row['password_hash'])) {
                unset($row['password_hash']);
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
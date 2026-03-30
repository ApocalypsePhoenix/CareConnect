<?php
// Add CORS headers
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

try {
    require_once 'db_connect.php';

    // Instantiate the Database class from your db_connect.php and get the connection
    $database = new Database();
    $dbConnection = $database->getConnection();

    if ($dbConnection === null) {
        echo json_encode(array('success' => false, 'message' => 'Fatal Error: Could not connect to the database.'));
        exit;
    }

    // Get JSON input from Flutter
    $json_input = file_get_contents("php://input");
    $data = json_decode($json_input, true);

    // Fallback just in case data was sent as form-urlencoded
    if (!$data) {
        $data = $_POST;
    }

    $user_id = isset($data['user_id']) ? (int)$data['user_id'] : 0;
    $name = isset($data['name']) ? trim($data['name']) : '';
    $relationship = isset($data['relationship']) ? trim($data['relationship']) : '';
    $age = isset($data['age']) ? (int)$data['age'] : 0;
    $medical_condition = isset($data['medical_condition']) ? trim($data['medical_condition']) : '';
    $special_needs = isset($data['special_needs']) ? trim($data['special_needs']) : '';

    // Validate required fields
    if (empty($user_id) || empty($name)) {
        echo json_encode(array('success' => false, 'message' => 'User ID and Name are required.'));
        exit;
    }

    // Prepare the statement targeting the 'recipients' table
    $sql = "INSERT INTO recipients (user_id, name, relationship, age, medical_condition, special_needs) 
            VALUES (?, ?, ?, ?, ?, ?)";
    
    // Execute the PDO statement
    $stmt = $dbConnection->prepare($sql);
    if (!$stmt) {
        echo json_encode(array('success' => false, 'message' => 'PDO Prepare Error.'));
        exit;
    }
    
    $stmt->execute([$user_id, $name, $relationship, $age, $medical_condition, $special_needs]);
    
    echo json_encode(array('success' => true, 'message' => 'Recipient added successfully.'));

} catch (\Throwable $e) {
    // Catch ANY fatal error and return it to Flutter safely
    http_response_code(200); 
    echo json_encode(array(
        'success' => false, 
        'message' => 'Fatal Error Caught: ' . $e->getMessage()
    ));
}
?>